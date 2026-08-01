import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_logger.dart';
import '../../data/remote/ghana_nlp_service.dart';

/// A dictation button component that records audio from the microphone and
/// transcribes it using [GhanaNlpService.transcribe].
///
/// Gated to Twi (`tw`) as specified by GhanaNLP ASR API capabilities.
class VoiceDictationButton extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onTranscribed;

  const VoiceDictationButton({
    super.key,
    required this.controller,
    this.onTranscribed,
  });

  @override
  State<VoiceDictationButton> createState() => _VoiceDictationButtonState();
}

class _VoiceDictationButtonState extends State<VoiceDictationButton> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final GhanaNlpService _ghanaNlp = GhanaNlpService();

  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _recordingPath;

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _toggleDictation() async {
    final currentLang = Localizations.localeOf(context).languageCode;
    if (currentLang != 'tw') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice dictation currently supports Twi (tw). Switch language in Settings.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_isRecording) {
      await _stopRecordingAndTranscribe();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required for dictation.')),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/dictation_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordingPath = path;
      });
    } catch (e) {
      AppLogger.e('VoiceDictationButton start recording error: $e');
    }
  }

  Future<void> _stopRecordingAndTranscribe() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
      });

      final filePath = path ?? _recordingPath;
      if (filePath != null && File(filePath).existsSync()) {
        final audioFile = File(filePath);
        final transcribed = await _ghanaNlp.transcribe(audioFile, language: 'tw');

        if (mounted && transcribed != null && transcribed.isNotEmpty) {
          final currentText = widget.controller.text;
          final newText = currentText.isEmpty
              ? transcribed
              : '$currentText $transcribed';

          widget.controller.text = newText;
          widget.controller.selection = TextSelection.fromPosition(
            TextPosition(offset: newText.length),
          );
          widget.onTranscribed?.call();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Transcribed (Twi): "$transcribed"'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.e('VoiceDictationButton transcription error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transcription failed: ${e.toString().replaceAll('Exception:', '').trim()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currentLang = Localizations.localeOf(context).languageCode;
    final isTwi = currentLang == 'tw';

    if (_isTranscribing) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colors.primary,
        ),
      );
    }

    if (_isRecording) {
      return IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.stop, color: Colors.white, size: 18),
        ),
        tooltip: 'Stop Dictation (Recording Twi...)',
        onPressed: _toggleDictation,
      );
    }

    return IconButton(
      icon: Icon(
        Icons.mic,
        color: isTwi ? colors.primary : colors.muted.withValues(alpha: 0.6),
      ),
      tooltip: isTwi
          ? 'Voice Dictation (Twi)'
          : 'Voice Dictation (Twi only — tap for details)',
      onPressed: _toggleDictation,
    );
  }
}
