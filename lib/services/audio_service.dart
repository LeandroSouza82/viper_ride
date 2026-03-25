import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Serviço singleton para tocar sons do app.
class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  // Player principal para efeitos curtos (online/offline)
  final AudioPlayer _player = AudioPlayer();
  // Player dedicado para o som de chamada (loop), para não conflitar
  // com reproduções pontuais no mesmo `AudioPlayer`.
  final AudioPlayer _requestPlayer = AudioPlayer();

  Future<void> playOnlineSound() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(AssetSource('sounds/comecar.mp3'));
    } catch (e) {
      debugPrint('ERRO DE ÁUDIO: $e');
    }
  }

  Future<void> playOfflineSound() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(AssetSource('sounds/sair.mp3'));
    } catch (e) {
      debugPrint('ERRO DE ÁUDIO: $e');
    }
  }

  Future<void> playRequestSound() async {
    try {
      await _requestPlayer.setReleaseMode(ReleaseMode.loop);
      await _requestPlayer.play(AssetSource('sounds/chamada.mp3'));
    } catch (e) {
      debugPrint('ERRO DE ÁUDIO: $e');
    }
  }

  Future<void> stopSound() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      await _requestPlayer.stop();
      await _requestPlayer.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      debugPrint('ERRO DE ÁUDIO: $e');
    }
  }
}
