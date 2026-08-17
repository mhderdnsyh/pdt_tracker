import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';

class AlarmService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  AlarmService() {
    _init();
  }

  void _init() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
    });
  }

  /// Triggers the alarm sound at maximum volume.
  Future<void> triggerAlarm() async {
    try {
      // Set device volume to max
      await PerfectVolumeControl.setVolume(1.0);
      
      // Loop alarm sound
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('audio/alarm.mp3'));
      _isPlaying = true;
    } catch (e) {
      debugPrint('Error triggering alarm: $e');
    }
  }

  /// Stops the alarm audio.
  Future<void> stopAlarm() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
    } catch (e) {
      debugPrint('Error stopping alarm: $e');
    }
  }


  void dispose() {
    _audioPlayer.dispose();
  }
}
