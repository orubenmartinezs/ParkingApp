import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();

  // Note: These files must exist in assets/sounds/
  static const String _entrySound = 'sounds/entry.mp3';
  static const String _exitSound = 'sounds/exit.mp3';
  static const String _successSound = 'sounds/success.mp3'; // Cash register
  static const String _errorSound = 'sounds/error.mp3';
  static const String _syncStartSound = 'sounds/sync_start.mp3';
  static const String _syncSuccessSound = 'sounds/sync_success.mp3';
  static const String _onlineSound = 'sounds/online.mp3';
  static const String _offlineSound = 'sounds/offline.mp3';

  Future<void> _playSound(String assetPath) async {
    try {
      if (kIsWeb) return; // Simple check, though not building for web

      // Stop previous sound if any (optional, prevents overlapping chaos)
      await _player.stop();

      // Play
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      if (kDebugMode) {
        print('Error playing sound $assetPath: $e');
      }
    }
  }

  Future<void> _vibrate({FeedbackType type = FeedbackType.medium}) async {
    try {
      bool canVibrate = await Vibrate.canVibrate;
      if (canVibrate) {
        Vibrate.feedback(type);
      }
    } catch (e) {
      if (kDebugMode) print('Vibration error: $e');
    }
  }

  // --- Public Methods ---

  Future<void> playEntry() async {
    await _playSound(_entrySound);
    await _vibrate(type: FeedbackType.selection);
  }

  Future<void> playExit() async {
    await _playSound(_exitSound);
    await _vibrate(type: FeedbackType.success);
  }

  Future<void> playPaymentSuccess() async {
    await _playSound(_successSound);
    await _vibrate(type: FeedbackType.success);
  }

  Future<void> playError() async {
    await _playSound(_errorSound);
    await _vibrate(type: FeedbackType.error);
  }

  Future<void> playSyncStart() async {
    // Maybe just a light vibration or subtle sound
    // await _playSound(_syncStartSound);
    await _vibrate(type: FeedbackType.light);
  }

  Future<void> playSyncSuccess() async {
    await _playSound(_syncSuccessSound);
  }

  Future<void> playOnline() async {
    await _playSound(_onlineSound);
    await _vibrate(type: FeedbackType.success);
  }

  Future<void> playOffline() async {
    await _playSound(_offlineSound);
    await _vibrate(type: FeedbackType.warning);
  }
}
