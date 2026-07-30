import 'dart:async';
import 'dart:math' show min;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/device_layout.dart';
import '../../../core/utils/image_quality_analyzer.dart';
import '../../../core/utils/permission_helper.dart';
import '../result/batch_result_provider.dart';
import 'scanner_provider.dart';

// Slow-changing scanner state consumed by the outer Selector.
// Using a Dart-3 record gives structural equality for free, so the Selector
// only schedules a rebuild when any of these fields actually changes —
// not on every 150 ms camera-frame notification.
typedef _ScannerSlowState = ({
  bool cameraInitialized,
  CameraController? cameraController,
  bool torchOn,
  bool batchMode,
  int batchCount,
  bool isAnalysing,
  String? errorMessage,
});

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  bool _showGuidance = true;
  bool? _permissionsGranted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndRequestPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void deactivate() {
    context.read<ScannerProvider>().releaseCamera();
    super.deactivate();
  }

  // The camera plugin requires releasing the controller when the app goes to
  // the background and re-initialising on resume; otherwise the preview is
  // frozen or black when the user returns to the app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    if (state == AppLifecycleState.resumed) {
      if (_permissionsGranted == true) {
        context.read<ScannerProvider>().initCamera();
      } else {
        _checkPermissionsOnResume();
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_permissionsGranted == true) {
        context.read<ScannerProvider>().releaseCamera();
      }
    }
  }

  Future<void> _checkPermissionsOnResume() async {
    final granted = await PermissionHelper.hasScannerPermissions();
    if (granted && mounted) {
      setState(() => _permissionsGranted = true);
      unawaited(context.read<ScannerProvider>().initCamera());
    }
  }

  Future<void> _checkAndRequestPermissions({bool requestIfDenied = true}) async {
    final granted = await PermissionHelper.hasScannerPermissions();
    if (granted) {
      if (mounted) {
        setState(() => _permissionsGranted = true);
        unawaited(context.read<ScannerProvider>().initCamera());
      }
    } else {
      if (mounted) {
        setState(() => _permissionsGranted = false);
      }
      if (requestIfDenied) {
        unawaited(_requestPermissions());
      }
    }
  }

  Future<void> _requestPermissions() async {
    final requested = await PermissionHelper.requestScannerPermissions();
    if (mounted) {
      setState(() => _permissionsGranted = requested);
      if (requested) {
        unawaited(context.read<ScannerProvider>().initCamera());
      }
    }
  }

  Future<void> _onCapture(ScannerProvider provider) async {
    final path = await provider.captureImage();
    if (path == null || !mounted) return;

    if (provider.batchMode) {
      provider.addCapturedToBatch(path);
      setState(() => _showGuidance = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.addedToBatch(provider.batchImagePaths.length)),
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      unawaited(_navigateToAnalysis(path));
    }
  }

  Future<void> _onGallery(ScannerProvider provider) async {
    final path = await provider.pickFromGallery();
    if (path == null || !mounted) return;

    if (provider.batchMode) {
      provider.addCapturedToBatch(path);
      setState(() => _showGuidance = false);
    } else {
      unawaited(_navigateToAnalysis(path));
    }
  }

  Future<void> _onUrlInput(ScannerProvider provider) async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.scanFromUrl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.scanFromUrlDesc,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: context.l10n.imageUrlLabel,
                hintText: 'https://…',
                prefixIcon: const Icon(Icons.link),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(context.l10n.analyse),
          ),
        ],
      ),
    );

    if (url == null || url.isEmpty || !mounted) return;

    final path = await provider.downloadFromUrl(url);
    if (path == null || !mounted) return;

    if (provider.batchMode) {
      provider.addCapturedToBatch(path);
      setState(() => _showGuidance = false);
    } else {
      unawaited(_navigateToAnalysis(path));
    }
  }

  Future<void> _navigateToAnalysis(String path) async {
    // Release the camera while the analysing/result screens are on top so the
    // preview and frame-analysis stream stop draining battery underneath them.
    // It is re-initialised when the user returns to the scanner.
    final provider = context.read<ScannerProvider>();
    await provider.releaseCamera();
    if (!mounted) return;
    await context.push(
      Uri(path: '/analysing', queryParameters: {'imagePath': path}).toString(),
    );
    if (mounted && _permissionsGranted == true) {
      unawaited(provider.initCamera());
    }
  }

  Future<void> _onAnalyseBatch(ScannerProvider provider) async {
    final results = await provider.analyseBatch();
    if (!mounted) return;

    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? context.l10n.batchAnalysisFailed),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    context.read<BatchResultProvider>().calculateResults(results);

    if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage!)),
      );
    }

    unawaited(context.push('/batch_result'));
  }

  void _showBatchExplanation(ScannerProvider provider) {
    unawaited(showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_motion,
                size: 48, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              context.l10n.batchModeTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.batchModeDesc,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  provider.setBatchMode(true);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(context.l10n.turnOnBatchMode),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Use read: callbacks hold a live reference; Selectors below subscribe.
    final provider = context.read<ScannerProvider>();
    final colors = context.colors;

    if (_permissionsGranted == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );
    }

    if (_permissionsGranted == false) {
      return PopScope(
        canPop: Navigator.of(context).canPop(),
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          context.go('/home');
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Navigator.of(context).canPop()
                ? BackButton(
                    color: Colors.white,
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.go('/home'),
                  ),
          ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DeviceLayout.screenPaddingHorizontal,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.camera_enhance_outlined,
                      size: 48, color: colors.primary),
                ),
                const SizedBox(height: 32),
                Text(
                  context.l10n.cameraRequiredTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.cameraRequiredDesc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 15,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: DeviceLayout.primaryButtonHeight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          DeviceLayout.buttonCornerRadius,
                        ),
                      ),
                    ),
                    onPressed: _requestPermissions,
                    child: Text(
                      context.l10n.grantPermissions,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: DeviceLayout.secondaryButtonHeight,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          DeviceLayout.buttonCornerRadius,
                        ),
                      ),
                    ),
                    onPressed: () => context.go('/home'),
                    child: Text(
                      context.l10n.goBack,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

    // SLOW-STATE SELECTOR — only rebuilds on user-driven events (torch toggle,
    // mode change, camera init, error appearance). NOT triggered by the ~150ms
    // camera-frame notifications that update previewQuality.
    return Selector<ScannerProvider, _ScannerSlowState>(
      selector: (_, p) => (
        cameraInitialized: p.cameraInitialized,
        cameraController: p.cameraController,
        torchOn: p.torchOn,
        batchMode: p.batchMode,
        batchCount: p.batchImagePaths.length,
        isAnalysing: p.isAnalysing,
        errorMessage: p.errorMessage,
      ),
      builder: (context, s, _) {
        return PopScope(
          canPop: Navigator.of(context).canPop(),
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            context.go('/home');
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            extendBodyBehindAppBar: true,
            floatingActionButton: s.batchMode && s.batchCount > 0
                ? FloatingActionButton.extended(
                    onPressed: s.isAnalysing
                        ? null
                        : () => _onAnalyseBatch(provider),
                    backgroundColor: colors.primary,
                    icon: s.isAnalysing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.analytics_outlined),
                    label: Text(
                      s.isAnalysing
                          ? context.l10n.analysing
                          : context.l10n.analyseBatch(s.batchCount),
                    ),
                  )
                : null,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: Navigator.of(context).canPop()
                  ? BackButton(
                      color: Colors.white,
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.go('/home'),
                    ),
              title: Text(
                context.l10n.scanCropTitle,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    s.torchOn ? Icons.flashlight_on : Icons.flashlight_off,
                    color: s.torchOn ? Colors.yellow : Colors.white,
                  ),
                  onPressed: () => provider.toggleTorch(),
                ),
                IconButton(
                  icon: Icon(
                    s.batchMode
                        ? Icons.auto_awesome_motion
                        : Icons.auto_awesome_motion_outlined,
                    color: s.batchMode ? colors.primary : Colors.white,
                  ),
                  onPressed: () {
                    if (!s.batchMode) {
                      _showBatchExplanation(provider);
                    } else {
                      provider.setBatchMode(false);
                    }
                  },
                ),
              ],
            ),
            body: Stack(
              fit: StackFit.expand,
              children: [
                if (s.cameraInitialized && s.cameraController != null)
                  CameraPreview(s.cameraController!)
                else
                  Container(
                    color: Colors.black87,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt,
                              color: Colors.white54, size: 64),
                          const SizedBox(height: 12),
                          Builder(
                              builder: (ctx) => Text(
                                  ctx.l10n.initialisingCamera,
                                  style: const TextStyle(
                                      color: Colors.white54))),
                        ],
                      ),
                    ),
                  ),
                _ScanOverlay(showGuidance: _showGuidance),
                // HOT-PATH SELECTOR — only this sub-tree rebuilds every ~150 ms.
                // The outer slow-state Selector shields CameraPreview, AppBar,
                // and all controls from unnecessary frame-analysis rebuilds.
                Selector<ScannerProvider, ScanPreviewQuality?>(
                  selector: (_, p) => p.previewQuality,
                  builder: (context, quality, _) => quality == null
                      ? const SizedBox.shrink()
                      : Positioned(
                          left: 16,
                          right: 16,
                          bottom: 108,
                          child: _QualityHud(quality: quality),
                        ),
                ),
                if (s.errorMessage != null)
                  Positioned(
                    top: 100,
                    left: 24,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        s.errorMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      20,
                      24,
                      // Respect the device's bottom safe-area (home indicator /
                      // gesture bar) so the shutter button is never clipped.
                      MediaQuery.paddingOf(context).bottom + 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ControlButton(
                          icon: Icons.photo_library_outlined,
                          label: context.l10n.gallery,
                          onTap: () => _onGallery(provider),
                        ),
                        Semantics(
                          button: true,
                          enabled: !s.isAnalysing,
                          label: context.l10n.capturePhoto,
                          excludeSemantics: true,
                          child: GestureDetector(
                            onTap: s.isAnalysing
                                ? null
                                : () => _onCapture(provider),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                color: s.isAnalysing
                                    ? Colors.white54
                                    : Colors.white,
                              ),
                              child: s.isAnalysing
                                  ? const CircularProgressIndicator(
                                      color: Colors.black54, strokeWidth: 2)
                                  : Icon(
                                      s.batchMode
                                          ? Icons.add_a_photo
                                          : Icons.camera,
                                      color: Colors.black87,
                                      size: 36,
                                    ),
                            ),
                          ),
                        ),
                        if (s.batchMode && s.batchCount > 0)
                          _ControlButton(
                            icon: Icons.analytics_outlined,
                            label: context.l10n.analyse,
                            enabled: !s.isAnalysing,
                            onTap: () => _onAnalyseBatch(provider),
                          )
                        else
                          _ControlButton(
                            icon: Icons.link,
                            label: context.l10n.urlLabel,
                            onTap: () => _onUrlInput(provider),
                          ),
                      ],
                    ),
                  ),
                ),
                if (s.batchMode && s.batchCount > 0)
                  Positioned(
                    top: kToolbarHeight + 60,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        context.l10n.batchImages(s.batchCount),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Estimated height of the bottom shutter-bar (top-padding + button + safe-area).
// Used by _scanFrame to keep the scan rectangle out of the controls area.
// The actual rendered height varies by safe-area inset; 148 dp is a conservative
// upper bound that covers devices with a 34 dp home indicator.
const double _kControlBarHeight = 148.0;

/// Returns a square scan-frame [Rect] that:
/// - is sized from [size.shortestSide] so it remains square in both portrait
///   and landscape without relying on height fractions;
/// - is centered vertically in the space between [topClearance] and the
///   shutter bar, clamped so it never overlaps either boundary.
Rect _scanFrame(Size size, {double topClearance = 0.0}) {
  final maxSide = size.shortestSide * 0.65;
  final available = size.height - topClearance - _kControlBarHeight;
  // Clamp so the frame fits when available space is tight (landscape).
  final side = min(maxSide, available - 16);
  final top = topClearance + (available - side) / 2;
  return Rect.fromLTWH(
    (size.width - side) / 2,
    top,
    side,
    side,
  );
}

class _ScanOverlay extends StatelessWidget {
  final bool showGuidance;
  const _ScanOverlay({required this.showGuidance});

  @override
  Widget build(BuildContext context) {
    // topClearance = status bar + AppBar so the frame is not hidden behind them.
    final topClearance =
        MediaQuery.paddingOf(context).top + kToolbarHeight;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final frame = _scanFrame(size, topClearance: topClearance);
        // Only show guidance when there is at least 28 dp of room below the
        // frame before the shutter bar — in landscape there usually is not.
        final hasRoomBelow =
            frame.bottom + 28 < size.height - _kControlBarHeight;
        return Stack(
          children: [
            CustomPaint(
              painter: _OverlayPainter(frame: frame),
              size: Size.infinite,
            ),
            if (showGuidance && hasRoomBelow)
              Positioned(
                top: frame.bottom + 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Builder(
                    builder: (ctx) => Text(
                      ctx.l10n.scanGuidance,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect frame;
  const _OverlayPainter({required this.frame});

  @override
  void paint(Canvas canvas, Size size) {
    const cornerLen = 24.0;
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    void drawCorner(Offset o, double dx, double dy) {
      canvas.drawLine(o, o + Offset(dx, 0), strokePaint);
      canvas.drawLine(o, o + Offset(0, dy), strokePaint);
    }

    drawCorner(frame.topLeft, cornerLen, cornerLen);
    drawCorner(frame.topRight, -cornerLen, cornerLen);
    drawCorner(frame.bottomLeft, cornerLen, -cornerLen);
    drawCorner(frame.bottomRight, -cornerLen, -cornerLen);

    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.35);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, frame.top), dimPaint);
    canvas.drawRect(
        Rect.fromLTRB(0, frame.bottom, size.width, size.height), dimPaint);
    canvas.drawRect(
        Rect.fromLTRB(0, frame.top, frame.left, frame.bottom), dimPaint);
    canvas.drawRect(
        Rect.fromLTRB(frame.right, frame.top, size.width, frame.bottom),
        dimPaint);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.frame != frame;
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.white30),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QualityHud extends StatelessWidget {
  final ScanPreviewQuality quality;

  const _QualityHud({required this.quality});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Expanded(
                child: _QualityBadge(
                  label: context.l10n.qualityLighting,
                  band: quality.lighting,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QualityBadge(
                  label: context.l10n.qualityFocus,
                  band: quality.focus,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QualityBadge(
                  label: context.l10n.qualityPlacement,
                  band: quality.placement,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QualityBadge extends StatelessWidget {
  final String label;
  final PreviewQualityBand band;

  const _QualityBadge({
    required this.label,
    required this.band,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (band) {
      PreviewQualityBand.good => const Color(0xFF4CAF50),
      PreviewQualityBand.fair => const Color(0xFFFFC107),
      PreviewQualityBand.poor => const Color(0xFFF44336),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            switch (band) {
              PreviewQualityBand.good => context.l10n.qualityGood,
              PreviewQualityBand.fair => context.l10n.qualityFair,
              PreviewQualityBand.poor => context.l10n.qualityPoor,
            },
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
