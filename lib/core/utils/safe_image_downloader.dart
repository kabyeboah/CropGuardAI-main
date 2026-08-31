import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'app_logger.dart';

// ── Image Download Security Exceptions ───────────────────────────────────────

sealed class ImageDownloadException implements Exception {
  final String message;
  const ImageDownloadException(this.message);

  @override
  String toString() => message;
}

final class ImageSecurityException extends ImageDownloadException {
  const ImageSecurityException(
      [super.message = 'The image URL was blocked by security policy.']);
}

final class ImageDownloadLimitException extends ImageDownloadException {
  const ImageDownloadLimitException(
      [super.message =
          'Image payload exceeds the maximum allowed size (15 MB).']);
}

final class NonImageException extends ImageDownloadException {
  const NonImageException(
      [super.message =
          'The downloaded response does not contain valid image data.']);
}

final class ImageNetworkException extends ImageDownloadException {
  final int? statusCode;
  const ImageNetworkException(super.message, {this.statusCode});
}

// ── Downloader Implementation ────────────────────────────────────────────────

typedef AddressLookup = Future<List<InternetAddress>> Function(String host);

/// Hardened image downloader with SSRF protection, payload limiting,
/// safe redirect following, and image magic bytes validation.
class SafeImageDownloader {
  static const int maxDownloadSizeBytes = 15 * 1024 * 1024; // 15 MB
  static const int maxRedirects = 3;
  static const Duration requestTimeout = Duration(seconds: 15);

  final HttpClient? _customHttpClient;
  final AddressLookup? _customAddressLookup;

  SafeImageDownloader({
    HttpClient? httpClient,
    AddressLookup? addressLookup,
  })  : _customHttpClient = httpClient,
        _customAddressLookup = addressLookup;

  /// Downloads an image securely from [urlString], validating the destination against
  /// SSRF/private networks, enforcing size limits, and verifying image magic bytes.
  Future<File> downloadImage(String urlString) async {
    final uri = Uri.tryParse(urlString.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const ImageSecurityException('Invalid URL structure.');
    }

    _validateUriScheme(uri);
    await _validateHost(uri.host);

    final client = _customHttpClient ?? HttpClient();
    client.autoUncompress = true;
    client.connectionTimeout = requestTimeout;

    try {
      var currentUri = uri;
      var redirectCount = 0;
      HttpClientResponse? response;

      while (redirectCount <= maxRedirects) {
        _validateUriScheme(currentUri);
        await _validateHost(currentUri.host);

        final request = await client.getUrl(currentUri).timeout(requestTimeout);
        request.followRedirects =
            false; // Manually validate each redirect destination!
        request.headers.set(HttpHeaders.acceptHeader, 'image/*, */*;q=0.8');
        request.headers.set(HttpHeaders.userAgentHeader, 'CropGuardAI/1.0');

        response = await request.close().timeout(requestTimeout);

        if (response.isRedirect) {
          redirectCount++;
          if (redirectCount > maxRedirects) {
            throw const ImageSecurityException(
                'Too many redirects (maximum 3 allowed).');
          }

          final locationHeader =
              response.headers.value(HttpHeaders.locationHeader);
          if (locationHeader == null || locationHeader.isEmpty) {
            throw const ImageSecurityException(
                'Redirect without Location header.');
          }

          final nextUri = currentUri.resolve(locationHeader);
          currentUri = nextUri;
          continue;
        }

        break;
      }

      if (response == null) {
        throw const ImageNetworkException('No response received.');
      }

      if (response.statusCode != HttpStatus.ok) {
        throw ImageNetworkException(
          'HTTP download failed with status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      // Check Content-Length if present
      final contentLength = response.contentLength;
      if (contentLength > maxDownloadSizeBytes) {
        throw ImageDownloadLimitException(
          'Image size ($contentLength bytes) exceeds 15 MB limit.',
        );
      }

      // Validate Content-Type header if provided
      final contentType = response.headers.contentType?.mimeType ??
          response.headers.value(HttpHeaders.contentTypeHeader) ??
          '';
      if (contentType.isNotEmpty &&
          !contentType.startsWith('image/') &&
          !contentType.contains('application/octet-stream')) {
        throw NonImageException(
            'Response content-type "$contentType" is not an image.');
      }

      // Stream response bytes with strict cumulative byte counter
      final builder = BytesBuilder(copy: false);
      var totalBytes = 0;

      await for (final chunk in response.timeout(requestTimeout)) {
        totalBytes += chunk.length;
        if (totalBytes > maxDownloadSizeBytes) {
          throw const ImageDownloadLimitException(
            'Downloaded payload exceeded maximum size limit of 15 MB.',
          );
        }
        builder.add(chunk);
      }

      final downloadedBytes = builder.takeBytes();
      if (downloadedBytes.isEmpty) {
        throw const NonImageException('Downloaded file is empty (0 bytes).');
      }

      // Magic byte validation & file extension determination
      final extension = _detectImageFormatExtension(downloadedBytes);
      if (extension == null) {
        throw const NonImageException(
          'Downloaded content magic bytes do not match a recognized image format (JPEG, PNG, WebP, GIF, BMP, HEIC).',
        );
      }

      Directory tempDir;
      try {
        tempDir = await getTemporaryDirectory();
      } catch (_) {
        tempDir = Directory.systemTemp;
      }
      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/safe_url_image_$timeStamp.$extension');
      await file.writeAsBytes(downloadedBytes, flush: true);

      AppLogger.i(
          'SafeImageDownloader: Successfully downloaded $totalBytes bytes ($extension) to ${file.path}');
      return file;
    } on ImageDownloadException {
      rethrow;
    } on TimeoutException {
      throw const ImageNetworkException(
          'Connection timed out while downloading image.');
    } on SocketException catch (e) {
      throw ImageNetworkException(
          'Network error connecting to image host: ${e.message}');
    } catch (e) {
      if (e is ImageDownloadException) rethrow;
      throw ImageNetworkException('Failed to download image: $e');
    } finally {
      if (_customHttpClient == null) {
        client.close(force: true);
      }
    }
  }

  /// Verifies that the URL scheme is strictly http or https.
  static void _validateUriScheme(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw ImageSecurityException(
        'Unsafe URL scheme "$scheme". Only HTTP and HTTPS are permitted.',
      );
    }
  }

  /// Validates the destination hostname and resolves DNS to detect private / restricted IP ranges.
  Future<void> _validateHost(String host) async {
    final normalized = host.toLowerCase().trim();

    if (normalized.isEmpty) {
      throw const ImageSecurityException('Empty hostname.');
    }

    // Direct string matches for localhost / internal identifiers
    if (normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '0.0.0.0' ||
        normalized == '::1' ||
        normalized == '[::1]' ||
        normalized.endsWith('.localhost') ||
        normalized.endsWith('.local') ||
        normalized.endsWith('.internal') ||
        normalized == 'metadata.google.internal' ||
        normalized == '169.254.169.254') {
      throw ImageSecurityException(
          'Access to localhost or internal network host "$host" is blocked.');
    }

    // Perform DNS lookup to inspect resolved IP addresses
    List<InternetAddress> addresses;
    try {
      final customLookup = _customAddressLookup;
      if (customLookup != null) {
        addresses = await customLookup(normalized);
      } else {
        addresses =
            await InternetAddress.lookup(normalized).timeout(requestTimeout);
      }
    } catch (e) {
      throw ImageNetworkException('Failed to resolve host "$host": $e');
    }

    if (addresses.isEmpty) {
      throw ImageNetworkException(
          'Host "$host" could not be resolved to any IP address.');
    }

    for (final addr in addresses) {
      if (isPrivateOrRestrictedAddress(addr)) {
        throw ImageSecurityException(
          'Host "$host" resolves to a private or restricted IP address (${addr.address}).',
        );
      }
    }
  }

  /// Evaluates whether an [InternetAddress] belongs to a private, loopback, link-local,
  /// multicast, or special reserved IP range (SSRF guard).
  static bool isPrivateOrRestrictedAddress(InternetAddress addr) {
    if (addr.isLoopback || addr.isLinkLocal || addr.isMulticast) {
      return true;
    }

    final raw = addr.rawAddress;

    // IPv4 Address checks
    if (addr.type == InternetAddressType.IPv4 || raw.length == 4) {
      final b0 = raw[0];
      final b1 = raw[1];
      final b2 = raw[2];

      // 0.0.0.0/8 (Current network)
      if (b0 == 0) return true;

      // 10.0.0.0/8 (Private network)
      if (b0 == 10) return true;

      // 100.64.0.0/10 (Shared address space / Carrier-grade NAT)
      if (b0 == 100 && (b1 >= 64 && b1 <= 127)) return true;

      // 127.0.0.0/8 (Loopback)
      if (b0 == 127) return true;

      // 169.254.0.0/16 (Link-local)
      if (b0 == 169 && b1 == 254) return true;

      // 172.16.0.0/12 (Private network: 172.16.0.0 - 172.31.255.255)
      if (b0 == 172 && (b1 >= 16 && b1 <= 31)) return true;

      // 192.0.0.0/24 (IETF Protocol Assignments)
      if (b0 == 192 && b1 == 0 && b2 == 0) return true;

      // 192.0.2.0/24 (TEST-NET-1 documentation)
      if (b0 == 192 && b1 == 0 && b2 == 2) return true;

      // 192.168.0.0/16 (Private network)
      if (b0 == 192 && b1 == 168) return true;

      // 198.18.0.0/15 (Benchmarking)
      if (b0 == 198 && (b1 == 18 || b1 == 19)) return true;

      // 198.51.100.0/24 (TEST-NET-2 documentation)
      if (b0 == 198 && b1 == 51 && b2 == 100) return true;

      // 203.0.113.0/24 (TEST-NET-3 documentation)
      if (b0 == 203 && b1 == 0 && b2 == 113) return true;

      // 224.0.0.0/4 (Multicast)
      if (b0 >= 224 && b0 <= 239) return true;

      // 240.0.0.0/4 (Reserved / Future use)
      if (b0 >= 240) return true;

      return false;
    }

    // IPv6 Address checks
    if (addr.type == InternetAddressType.IPv6 || raw.length == 16) {
      // ::1 (Loopback)
      if (addr.isLoopback) return true;

      // fc00::/7 (Unique Local Address - ULA)
      if (raw[0] == 0xfc || raw[0] == 0xfd) return true;

      // fe80::/10 (Link-Local Unicast)
      if (raw[0] == 0xfe && (raw[1] & 0xc0) == 0x80) return true;

      // ff00::/8 (Multicast)
      if (raw[0] == 0xff) return true;

      // 2001:db8::/32 (Documentation)
      if (raw[0] == 0x20 &&
          raw[1] == 0x01 &&
          raw[2] == 0x0d &&
          raw[3] == 0xb8) {
        return true;
      }

      // IPv4-mapped IPv6 addresses (::ffff:x.x.x.x)
      var isMapped = true;
      for (var i = 0; i < 10; i++) {
        if (raw[i] != 0) {
          isMapped = false;
          break;
        }
      }
      if (isMapped && raw[10] == 0xff && raw[11] == 0xff) {
        final ipv4Bytes = Uint8List.fromList(raw.sublist(12, 16));
        final ipv4 = InternetAddress.fromRawAddress(ipv4Bytes);
        return isPrivateOrRestrictedAddress(ipv4);
      }

      return false;
    }

    return false;
  }

  /// Inspects the first bytes of [bytes] to identify standard image magic numbers.
  /// Returns the lowercase file extension or null if not a recognized image.
  static String? _detectImageFormatExtension(Uint8List bytes) {
    if (bytes.length < 8) return null;

    // JPEG / JFIF / EXIF: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'jpg';
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'png';
    }

    // GIF: GIF87a or GIF89a (47 49 46 38 37 61 or 47 49 46 38 39 61)
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) &&
        bytes[5] == 0x61) {
      return 'gif';
    }

    // WebP: RIFF (52 49 46 46) .... WEBP (57 45 42 50)
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }

    // BMP: BM (42 4D)
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return 'bmp';
    }

    // ISO Media / HEIF / HEIC / AVIF: ftypheic, ftypmif1, ftypmsf1, ftypavif
    if (bytes.length >= 12 &&
        bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70) {
      final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
      if (brand == 'heic' ||
          brand == 'heix' ||
          brand == 'hevc' ||
          brand == 'hevx' ||
          brand == 'mif1' ||
          brand == 'msf1') {
        return 'heic';
      }
      if (brand == 'avif' || brand == 'avis') {
        return 'avif';
      }
    }

    return null;
  }
}
