import 'dart:io';
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

  late final Future<void> _initFuture;

  TtsManager._internal() {
    _initFuture = _init();
  }

  Future<void> _init() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> speak(String text, {String languageCode = "en"}) async {
    await _initFuture;

    final cacheKey = "${text.hashCode}_$languageCode";

    // Check Cache [Priority 5]
    if (_speechCache.containsKey(cacheKey)) {
      AppLogger.d('TTS cache hit: $text');
      await _audioPlayer.play(DeviceFileSource(_speechCache[cacheKey]!.path));
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
    await _tts.setLanguage(locale);
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    await _audioPlayer.stop();
  }

  void dispose() {
    _tts.stop();
    _audioPlayer.dispose();
  }
}
