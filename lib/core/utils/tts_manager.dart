import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../data/remote/ghana_nlp_service.dart';
import 'app_logger.dart';

class TtsManager {
  static final TtsManager _instance = TtsManager._internal();
  factory TtsManager() => _instance;

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final GhanaNlpService _ghanaNlp = GhanaNlpService();

  // Speech Cache
  final Map<String, File> _speechCache = {};

  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  bool get isPlaying => isPlayingNotifier.value;

  late final Future<void> _initFuture;

  TtsManager._internal() {
    _initFuture = _init();
  }

  Future<void> _init() async {
    _tts.setStartHandler(() {
      isPlayingNotifier.value = true;
    });
    _tts.setCompletionHandler(() {
      isPlayingNotifier.value = false;
    });
    _tts.setErrorHandler((msg) {
      isPlayingNotifier.value = false;
    });
    _tts.setCancelHandler(() {
      isPlayingNotifier.value = false;
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      isPlayingNotifier.value = (state == PlayerState.playing);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      isPlayingNotifier.value = false;
    });

    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (e) {
      AppLogger.w('TTS init failed: $e');
    }
  }

  Future<void> speak(String text, {String languageCode = "en"}) async {
    await stop();
    await _initFuture;
    isPlayingNotifier.value = true;

    final cacheKey = "${text.hashCode}_$languageCode";

    // Check Cache [Priority 5]
    if (_speechCache.containsKey(cacheKey)) {
      AppLogger.d('TTS cache hit: $text');
      try {
        await _audioPlayer.play(DeviceFileSource(_speechCache[cacheKey]!.path));
      } catch (e) {
        AppLogger.w('AudioPlayer play cache hit failed: $e');
        isPlayingNotifier.value = false;
      }
      return;
    }

    String locale;
    bool useKhaya = false;

    switch (languageCode) {
      case "tw":
      case "ee":
      case "dag":
        useKhaya = true;
        locale = "en-GB";
        break;
      case "fr":
        locale = "fr-FR";
        break;
      case "ha":
        locale = "ha-NE";
        break;
      default:
        locale = "en-US";
    }

    if (useKhaya) {
      try {
        final audioFile =
            await _ghanaNlp.synthesize(text, language: languageCode);
        if (audioFile != null) {
          _speechCache[cacheKey] = audioFile; // Save to cache
          await _audioPlayer.play(DeviceFileSource(audioFile.path));
          return;
        }
      } catch (e) {
        AppLogger.w(
            'Ghana NLP synthesis failed, falling back to local TTS: $e');
        // Fall back to native TTS below
      }
    }

    // Fallback [Priority 3]
    try {
      await _tts.setLanguage(locale);
      await _tts.speak(text);
    } catch (e) {
      AppLogger.w('TTS speak fallback failed: $e');
      isPlayingNotifier.value = false;
    }
  }

  Future<void> stop() async {
    isPlayingNotifier.value = false;
    try {
      await _tts.stop();
    } catch (e) {
      AppLogger.w('TTS stop failed: $e');
    }
    try {
      await _audioPlayer.stop();
    } catch (e) {
      AppLogger.w('AudioPlayer stop failed: $e');
    }
  }

  void dispose() {
    stop();
    try {
      _tts.stop();
      _audioPlayer.dispose();
    } catch (_) {}
  }
}
