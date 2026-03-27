import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../controllers/mapbox_theme_controller.dart';

class MapDisplay extends StatefulWidget {
  const MapDisplay({super.key});

  @override
  State<MapDisplay> createState() => _MapDisplayState();
}

class _MapDisplayState extends State<MapDisplay> {
  MapboxMap? _mapController;
  bool _routeCreated = false;
  List<List<double>> _routePoints = [];

  // Token lido de variáveis de ambiente (arquivo .env)
  final String _accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

  bool get _isNoite {
    final int hora = DateTime.now().hour;
    return hora >= 18 || hora < 6;
  }

  @override
  Widget build(BuildContext context) {
    // Usa estilo conforme horário via controlador central
    final String styleUri = MapboxThemeController.styleFromTime();

    return MapWidget(
      key: const ValueKey('vup_map_fixed'),
      textureView: true,
      styleUri: styleUri,
      cameraOptions: CameraOptions(zoom: 13.5),
      onMapCreated: (controller) async {
        _mapController = controller;
        await _onStyleLoaded();
      },
    );
  }

  Future<void> _onStyleLoaded() async {
    if (_mapController == null) return;
    if (_routeCreated) return; // garante execução única
    if (!mounted) return;

    // Aplica dimmer diurno (fundo preto com 25% opacidade)
    if (!_isNoite) {
      try {
        // garantir que não existam duplicatas
        try {
          await _mapController!.style.removeStyleLayer('viper-day-dimmer');
        } catch (_) {}
        await _mapController!.style.addLayer(
          BackgroundLayer(
            id: 'viper-day-dimmer',
            backgroundColor: Colors.black.toARGB32(),
            backgroundOpacity: 0.25,
          ),
        );
      } catch (_) {}
    }

    // Buscar rota e criar source/layers apenas se ainda não criada
    await _fetchRouteAndCreateLayers();
    // _routeCreated será marcado em _fetchRouteAndCreateLayers no início
  }

  Future<void> _fetchRouteAndCreateLayers() async {
    if (_mapController == null) return;
    if (_routeCreated) return; // segurança adicional
    if (!mounted) return;

    // marcar imediatamente para prevenir reentradas concorrentes
    _routeCreated = true;

    // Coordenadas obrigatórias [lng, lat]
    final origin = [-48.6750, -27.6200];
    final destination = [-48.6650, -27.6530];

    final url =
        'https://api.mapbox.com/directions/v5/mapbox/driving/${origin[0]},${origin[1]};${destination[0]},${destination[1]}?geometries=geojson&overview=full&access_token=$_accessToken';

    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) return;
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final coords = (data['routes'][0]['geometry']['coordinates'] as List)
          .map<List<double>>((c) => [c[0] as double, c[1] as double])
          .toList();
      if (coords.isEmpty) return;
      _routePoints = coords;

      final style = _mapController!.style;

      // Limpar source/layers anteriores se existirem
      try {
        await style.removeStyleLayer('route-line');
      } catch (_) {}
      try {
        await style.removeStyleLayer('route-border');
      } catch (_) {}
      try {
        await style.removeStyleSource('route-source');
      } catch (_) {}

      // Montar GeoJSON
      final geojson = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {'type': 'LineString', 'coordinates': _routePoints},
          },
        ],
      };

      // Cores conforme regra 18h/6h (DIA: topo azul, borda preta) — inteiros ARGB
      final int topo = _isNoite ? 0xFFFFFFFF : 0xFF007AFF;
      final int borda = _isNoite ? 0xFF007AFF : 0xFF000000;

      // Adicionar source
      await style.addSource(
        GeoJsonSource(id: 'route-source', data: json.encode(geojson)),
      );

      // Adicionar camada de borda (por baixo) — tentar posicionar acima das labels
      final borderLayer = LineLayer(
        id: 'route-border',
        sourceId: 'route-source',
        lineColor: borda,
        lineWidth: 8.0,
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      );
      try {
        await style.addLayerAt(borderLayer, LayerPosition(above: 'road-label'));
      } catch (_) {
        try {
          await style.addLayerAt(borderLayer, LayerPosition(at: 999));
        } catch (_) {
          await style.addLayer(borderLayer);
        }
      }

      // Adicionar camada da rota por cima — posicionar acima das labels
      final routeLayer = LineLayer(
        id: 'route-line',
        sourceId: 'route-source',
        lineColor: topo,
        lineWidth: 4.0,
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      );
      try {
        await style.addLayerAt(routeLayer, LayerPosition(above: 'road-label'));
      } catch (_) {
        try {
          await style.addLayerAt(routeLayer, LayerPosition(at: 999));
        } catch (_) {
          await style.addLayer(routeLayer);
        }
      }

      // Centraliza câmera na rota
      final midLng = (_routePoints.first[0] + _routePoints.last[0]) / 2;
      final midLat = (_routePoints.first[1] + _routePoints.last[1]) / 2;
      try {
        await _mapController!.setCamera(
          CameraOptions(
            center: Point(coordinates: Position(midLng, midLat)),
            zoom: 13.5,
          ),
        );
      } catch (_) {
        // fallback silencioso
      }
    } catch (e) {
      // não propagar erro para UI
    }
  }
}
