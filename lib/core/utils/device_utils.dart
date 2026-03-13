import 'package:wakelock_plus/wakelock_plus.dart';

/// Utilitário de controle de hardware do dispositivo.
///
/// Política de wakelock no Viper Ride:
///   • Ativado em [ViperDriverHome.initState] — tela acesa sempre que o
///     motorista estiver no mapa, independente do estado online/offline.
///   • Liberado em [ViperDriverHome.dispose] — ao sair da tela (logout,
///     descarte externo do widget).
///   • NÃO é liberado ao ficar offline ([_disposeDriverMode]) pois o
///     motorista permanece na tela do mapa.
class ViperDeviceUtils {
  ViperDeviceUtils._();

  static Future<void> keepScreenOn() => WakelockPlus.enable();
  static Future<void> releaseScreen() => WakelockPlus.disable();
}
