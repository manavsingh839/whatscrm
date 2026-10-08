import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

class AudioService {
  static final AudioRecorder _recorder = AudioRecorder();
  static final AudioPlayer _player = AudioPlayer();

  static bool _isRecording = false;
  static bool get isRecording => _isRecording;

  static Future<bool> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: '', // in-memory on web / temporary path
        );
        _isRecording = true;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
      return false;
    }
  }

  static Future<Uint8List?> stopRecording() async {
    try {
      _isRecording = false;
      await _recorder.stop();
      // On web or platforms where stream is supported
      return null;
    } catch (e) {
      debugPrint('Error stopping audio recording: $e');
      return null;
    }
  }

  static Future<void> playAudio(String url) async {
    await _player.stop();
    await _player.play(UrlSource(url));
  }

  static Future<void> pauseAudio() async {
    await _player.pause();
  }

  static Future<void> stopAudio() async {
    await _player.stop();
  }

  static Stream<PlayerState> get onPlayerStateChanged => _player.onPlayerStateChanged;
  static Stream<Duration> get onPositionChanged => _player.onPositionChanged;
  static Stream<Duration> get onDurationChanged => _player.onDurationChanged;
}
