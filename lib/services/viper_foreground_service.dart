import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Serviço de foreground para rastreio de localização do motorista.
///
/// Executa em um isolate separado (via [flutter_foreground_task]), garantindo
/// operação contínua mesmo com a tela bloqueada ou o app em background.
///
/// Ciclo de vida:
///   [init]  → chamado em [main] antes de [runApp] para configurar opções Android.
///   [start] → salva credenciais via [saveData], inicia [ViperTaskHandler].
///   [stop]  → encerra o serviço e a notificação persistente.
///
/// [ViperTaskHandler.onRepeatEvent] (a cada 5s):
///   Obtém posição GPS e faz upsert em [driver_locations] no Supabase.
///   Credenciais são lidas via [getData] — cross-isolate safe.

@pragma('vm:entry-point')
void startViperServiceCallback() {
  FlutterForegroundTask.setTaskHandler(ViperTaskHandler());
}

class ViperForegroundService {
  ViperForegroundService._();

  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'viper_driver_service',
        channelName: 'Viper Ride - Motorista',
        channelDescription: 'Localização ativa para corridas',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> start({
    required String supabaseUrl,
    required String supabaseKey,
    required String driverId,
  }) async {
    await FlutterForegroundTask.saveData(key: 'sp_url', value: supabaseUrl);
    await FlutterForegroundTask.saveData(key: 'sp_key', value: supabaseKey);
    await FlutterForegroundTask.saveData(key: 'driver_id', value: driverId);

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Viper Ride - Modo Motorista',
      notificationText: 'Você está online e disponível para corridas',
      callback: startViperServiceCallback,
    );
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }
}

class ViperTaskHandler extends TaskHandler {
  SupabaseClient? _supabase;
  String? _driverId;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final url = await FlutterForegroundTask.getData<String>(key: 'sp_url');
    final key = await FlutterForegroundTask.getData<String>(key: 'sp_key');
    _driverId = await FlutterForegroundTask.getData<String>(key: 'driver_id');

    if (url != null && url.isNotEmpty && key != null && key.isNotEmpty) {
      try {
        await Supabase.initialize(url: url, anonKey: key);
      } catch (_) {
        // Já inicializado — reusa instância existente
      }
      _supabase = Supabase.instance.client;
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _updateDriverLocation();
  }

  Future<void> _updateDriverLocation() async {
    if (_supabase == null || _driverId == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 4));

      await _supabase!.from('driver_locations').upsert({
        'driver_id': _driverId,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _supabase = null;
    _driverId = null;
  }
}
