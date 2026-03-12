import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../core/viper_theme.dart';
import '../services/geo_service.dart';

class ViperMapDisplay extends StatefulWidget {
  const ViperMapDisplay({super.key});

  @override
  State<ViperMapDisplay> createState() => _ViperMapDisplayState();
}

class _ViperMapDisplayState extends State<ViperMapDisplay> {
  MapboxMap? _mapController;
  List<_VehicleOverlay> _vehicles = [];

  static const double _defaultLat = -23.5505;
  static const double _defaultLng = -46.6333;

  void _onMapCreated(MapboxMap controller) {
    _mapController = controller;
    _centerOnUser();
  }

  Future<void> _centerOnUser() async {
    final geo.Position? pos = await ViperGeoService.getCurrentPosition();
    if (pos == null || _mapController == null || !mounted) return;
    await _mapController!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(pos.longitude, pos.latitude)),
        zoom: 15.0,
      ),
      MapAnimationOptions(duration: 1200),
    );
    await _refreshVehicles(pos.latitude, pos.longitude);
  }

  Future<void> _refreshVehicles(double lat, double lng) async {
    if (_mapController == null || !mounted) return;
    final rawCoords = [
      Position(lng + 0.0022, lat + 0.0011),
      Position(lng - 0.0015, lat - 0.0020),
      Position(lng + 0.0008, lat - 0.0030),
    ];
    final result = <_VehicleOverlay>[];
    for (final coord in rawCoords) {
      final sc = await _mapController!.pixelForCoordinate(
        Point(coordinates: coord),
      );
      result.add(_VehicleOverlay(x: sc.x, y: sc.y));
    }
    if (mounted) setState(() => _vehicles = result);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          // Camada base: mapa Mapbox (rotas e polylines renderizadas pelo SDK)
          MapWidget(
            styleUri: MapboxStyles.DARK,
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(_defaultLng, _defaultLat)),
              zoom: 13.0,
            ),
            onMapCreated: _onMapCreated,
          ),
          // Camada superior: ícones de veículos sempre acima das polylines
          ..._vehicles.map(
            (v) => Positioned(
              left: v.x - 18,
              top: v.y - 18,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ViperColors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_car,
                  color: ViperColors.black,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleOverlay {
  final double x;
  final double y;

  const _VehicleOverlay({required this.x, required this.y});
}
