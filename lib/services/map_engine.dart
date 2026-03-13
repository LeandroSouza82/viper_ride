import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class ViperMapEngine {
  ViperMapEngine._();

  static void init() {
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN']?.trim() ?? '';
    if (token.isEmpty) {
      debugPrint(
        '[ViperRide] MAPBOX_ACCESS_TOKEN ausente no .env — mapa não funcionará.',
      );
      return;
    }
    debugPrint('[ViperRide] Mapbox token: ${token.substring(0, 10)}...');
    MapboxOptions.setAccessToken(token);
  }
}
