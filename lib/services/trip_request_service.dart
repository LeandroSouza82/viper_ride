// lib/services/trip_request_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'audio_service.dart';

class TripRequestService {
  TripRequestService._();

  static final TripRequestService instance = TripRequestService._();

  final ValueNotifier<Map<String, dynamic>?> requestNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);

  /// Versão reativa do payload para uso com `Obx` onde desejado.
  final Rxn<Map<String, dynamic>> requestRx = Rxn<Map<String, dynamic>>();

  StreamSubscription<dynamic>? _internalSub;

  /// Inicia a escuta em `trips` para o `driverId`.
  /// Não altera UI — apenas publica novos payloads em `requestNotifier`.
  Future<void> startListening({required String driverId}) async {
    if (driverId.isEmpty) return;
    // Evita múltiplas assinaturas para o mesmo driver
    if (_internalSub != null) return;

    final client = Supabase.instance.client;

    // Usa o stream Realtime exposto pelo client.from(...).stream()
    // Filtra por driver_id; o stream emite o conjunto de registros afetados.
    _internalSub = client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .listen((dynamic payload) {
          try {
            // Payload costuma ser List<Map<String, dynamic>> representando rows
            if (payload is List) {
              for (final item in payload) {
                if (item is Map<String, dynamic>) {
                  final status =
                      (item['status'] as String?)?.toLowerCase() ?? '';
                  if (status == 'pending' || status == 'aguardando') {
                    final payload = Map<String, dynamic>.from(item);
                    requestNotifier.value = payload;
                    requestRx.value = payload;
                    // Toca som de nova requisição
                    try {
                      AudioService.instance.playRequestSound();
                    } catch (_) {}
                    return;
                  }
                }
              }
            } else if (payload is Map<String, dynamic>) {
              final status =
                  (payload['status'] as String?)?.toLowerCase() ?? '';
              if (status == 'pending' || status == 'aguardando') {
                final p = Map<String, dynamic>.from(payload);
                requestNotifier.value = p;
                requestRx.value = p;
                try {
                  AudioService.instance.playRequestSound();
                } catch (_) {}
              }
            }
          } catch (_) {}
        });
  }

  /// Para a escuta e limpa o notifier.
  Future<void> stopListening() async {
    try {
      await _internalSub?.cancel();
      _internalSub = null;
    } catch (_) {}
    requestNotifier.value = null;
    requestRx.value = null;
    try {
      AudioService.instance.stopSound();
    } catch (_) {}
  }

  /// Limpa a requisição atual sem parar a escuta.
  void clearRequest() {
    requestNotifier.value = null;
    requestRx.value = null;
    try {
      AudioService.instance.stopSound();
    } catch (_) {}
  }

  /// Remove recursos definitivamente.
  Future<void> dispose() async {
    await stopListening();
    await _internalSub?.cancel();
    _internalSub = null;
  }

  // _extractRecord removed: using stream payload parsing instead.
}
