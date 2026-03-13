import 'package:geolocator/geolocator.dart';

/// Serviço de localização do Viper Ride.
///
/// Encapsula [Geolocator]: permissões, posição pontual e stream contínuo.
///
/// Nota: permissão [LocationPermission.always] (Android 10+) requer UI
/// específica do sistema — não há API programática para concedi-la.
/// O motorista deve conceder manualmente nas configurações do app.

enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class ViperLocationService {
  static const _minMovementMeters = 5.0;

  ViperLocationService._();

  static Future<LocationPermissionStatus> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermissionStatus.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionStatus.deniedForever;
    }
    if (permission == LocationPermission.denied) {
      return LocationPermissionStatus.denied;
    }

    return LocationPermissionStatus.granted;
  }

  static Future<Position?> getCurrentPosition() async {
    final status = await requestPermission();
    if (status != LocationPermissionStatus.granted) return null;
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  static Stream<Position> positionStream() {
    Position? lastEmitted;

    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        // Só emite quando houver deslocamento real do veículo.
        // 5m elimina microvariações do sensor e reduz churn no mapa.
        distanceFilter: 5,
      ),
    ).where((pos) {
      final previous = lastEmitted;
      if (previous == null) {
        lastEmitted = pos;
        return true;
      }

      final movedMeters = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (movedMeters < _minMovementMeters) return false;

      lastEmitted = pos;
      return true;
    });
  }
}
