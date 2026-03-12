import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class ViperMapEngine {
  ViperMapEngine._();

  static void init() {
    MapboxOptions.setAccessToken(dotenv.env['MAPBOX_ACCESS_TOKEN']!);
  }
}
