import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../settings/data/models/alert_tone.dart';

abstract interface class AlertAudioController {
  Future<void> playLoop(AlertTone tone, {required double volume});

  Future<void> setVolume(double volume);

  Future<void> stop();
}

/// Reproduz somente os sons empacotados no FaceTrack. O canal de notificação
/// do sistema permanece silencioso para que seleção, volume e looping sejam
/// controlados integralmente pelo aplicativo.
class AlertAudioService implements AlertAudioController {
  AlertAudioService._();

  static final AlertAudioService instance = AlertAudioService._();

  static const MethodChannel _androidChannel = MethodChannel('facetrack/audio');
  final AudioPlayer _player = AudioPlayer(playerId: 'facetrack_alert_loop');

  bool get _usesAndroidNativePlayer =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> playLoop(AlertTone tone, {required double volume}) async {
    final normalizedVolume = volume.clamp(0.0, 1.0).toDouble();
    if (_usesAndroidNativePlayer) {
      await _androidChannel.invokeMethod<void>('playLoop', {
        'tone': tone.storageValue,
        'volume': normalizedVolume,
      });
      return;
    }
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(normalizedVolume);
    await _player.play(AssetSource(tone.assetPath));
  }

  @override
  Future<void> setVolume(double volume) {
    final normalizedVolume = volume.clamp(0.0, 1.0).toDouble();
    if (_usesAndroidNativePlayer) {
      return _androidChannel.invokeMethod<void>('setVolume', {
        'volume': normalizedVolume,
      });
    }
    return _player.setVolume(normalizedVolume);
  }

  @override
  Future<void> stop() {
    if (_usesAndroidNativePlayer) {
      return _androidChannel.invokeMethod<void>('stop');
    }
    return _player.stop();
  }
}
