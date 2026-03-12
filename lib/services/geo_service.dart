import 'package:geolocator/geolocator.dart';

class ViperGeoService {
  ViperGeoService._();

  static Future<Position?> getCurrentPosition() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  static Stream<Position> get positionStream => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  );
}
