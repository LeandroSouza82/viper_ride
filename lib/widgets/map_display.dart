import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../controllers/mapbox_theme_controller.dart';

/// DOCUMENTAÇÃO: RESOLUÇÃO DE lockHardwareCanvas NO ANDROID
///
/// Problema Raiz: O Mapbox usa SurfaceView por padrão, que entra em conflito com o Impeller
/// (engine Vulkan do Flutter) no Android 11+. Isso causa um loop infinito de requisições
/// de frame → "D/Surface: lockHardwareCanvas" repetido 100+ vezes/segundo.
///
/// Soluções Implementadas Nesta Classe:
///
/// 1. TextureView em vez de SurfaceView:
///    MapWidget(textureView: true, ...) instrui o Mapbox a usar TextureView que é
///    compatível com Impeller. Solução RECOMENDADA.
///
/// 2. Árvore de Widgets IMUTÁVEL após First Build:
///    - MapWidget tem ValueKey("vup_map_stable") para evitar reconstrução
///    - RepaintBoundary isola o canvas do Mapbox de rebuilds superiores
///    - Conditional rendering (if/else) REMOVIDO da árvore — causa remontagem
///    - Animações usam AnimatedOpacity (não conditional if)
///
/// 3. LineLayer via Style API em vez de PolylineAnnotationManager:
///    AnnotationManagers criam views nativas que competem com o pipeline de renderização
///    do Flutter. Style layers (GeoJsonSource + LineLayer) são renderizados inteiramente
///    dentro do motor GL do Mapbox — zero operações extras de canvas.
///
/// 4. Se ainda ver "D/Surface: lockHardwareCanvas" em logcat:
///    a) Desativar Impeller (último recurso):
///       flutter run --no-enable-impeller
///    b) Verificar se há AnimatedContainer/AnimatedCrossFade na mesma Stack
///       (Devem estar em RepaintBoundary separado)
///
/// Verificação: Após implementar, execute:
///   adb logcat -s "Surface|lockHardwareCanvas" -E "VUP_LOG"
/// Esperado: lockHardwareCanvas aparece APENAS 1-2 vezes durante init, depois silêncio.
/// Inaceitável: lockHardwareCanvas repetido infinitamente (100+x/s).

class MapDisplayController {
  _MapDisplayState? _state;

  Future<void> showTripRoute(
    List<double> pickupCoords,
    List<double> destinationCoords, {
    List<double>? originCoords,
    String? tripId,
  }) async {
    return _state?.showTripRoute(
          pickupCoords,
          destinationCoords,
          originCoords: originCoords,
          tripId: tripId,
        ) ??
        Future.value();
  }

  Future<void> clearTripRoute() async {
    return _state?.clearTripRoute() ?? Future.value();
  }

  bool get isReady => _state?._mapboxMap != null;
}

class MapDisplay extends StatefulWidget {
  final MapDisplayController? controller;
  const MapDisplay({super.key, this.controller});

  @override
  State<MapDisplay> createState() => _MapDisplayState();
}

class _MapDisplayState extends State<MapDisplay> {
  MapboxMap? _mapboxMap;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _cachedStyleUri = MapboxThemeController.styleFromTime();
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    super.dispose();
  }

  // Circle annotations manager para marcadores confiáveis (leve, não causa lockHardwareCanvas)
  CircleAnnotationManager? _circleManager;
  final List<CircleAnnotation> _circleAnnotations = [];

  // IDs fixos para source/layers de rota via Style API
  // Style layers são renderizados DENTRO do GL engine — zero canvas overhead
  static const _routeSourceId = 'vup_route_source';
  static const _routeBorderId = 'vup_route_border';
  static const _routeMainId = 'vup_route_main';

  // Controles de renderização para evitar loops infinitos
  bool _hasFocussed = false; // Evita focar câmera em loop
  bool _isDrawingRoute = false; // Mutex: impede draws concorrentes no canvas
  String?
  _lastDrawnRouteId; // Cache do último tripId desenhado para evitar redesenho

  // Cachear styleUri para evitar rebuild do MapWidget
  late String _cachedStyleUri;
  int _lastHourCheck = -1; // Track última hora verificada para mudar tema

  final String _accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

  // Regra de horário fixa 18h/6h
  bool get _isNoite {
    final int hora = DateTime.now().hour;
    return hora >= 18 || hora < 6;
  }

  @override
  Widget build(BuildContext context) {
    // Verifica se mudou de hora (dia/noite) apenas a cada build (não a cada frame)
    final currentHour = DateTime.now().hour;
    if (currentHour != _lastHourCheck) {
      _cachedStyleUri = MapboxThemeController.styleFromTime();
      _lastHourCheck = currentHour;
      debugPrint(
        'VUP_LOG: Tema atualizado para hora=$currentHour - styleUri mudou',
      );
    }

    final String styleUri = _cachedStyleUri;

    return Stack(
      children: [
        // CRÍTICO: RepaintBoundary + ValueKey garante que MapWidget NUNCA é reconstruído
        // após a primeira montagem, mesmo que build() seja chamado múltiplas vezes
        Positioned.fill(
          child: RepaintBoundary(
            child: MapWidget(
              key: const ValueKey("vup_map_stable"),
              textureView:
                  true, // TextureView em vez de SurfaceView para evitar Impeller conflicts
              styleUri: styleUri,
              cameraOptions: CameraOptions(zoom: 13.0),
              gestureRecognizers:
                  const {}, // Fix Xiaomi: impede conflito de gestos
              onMapCreated: (controller) async {
                _mapboxMap = controller;
                try {
                  _mapboxMap?.compass.updateSettings(
                    CompassSettings(enabled: false),
                  );
                } catch (e) {
                  debugPrint('VUP_LOG: Erro ao desativar bússola: $e');
                }
                await _setupMapOnce();
              },
            ),
          ),
        ),
        // CRÍTICO: Overlay de sombra (dia) SEMPRE na árvore, mas opacity = 0 quando noite
        // Isso evita remontagem dinâmica que causa lockHardwareCanvas
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _isNoite ? 0.0 : 0.15,
              duration: const Duration(milliseconds: 500), // Transição suave
              child: Container(color: Colors.black),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _setupMapOnce() async {
    if (_initialized || _mapboxMap == null) return;
    _initialized = true;

    try {
      // CONFIGURAÇÃO: Seta de Navegação
      // DefaultLocationPuck2D() com GPS habilitado mostra uma seta que gira automaticamente
      await _mapboxMap?.location.updateSettings(
        LocationComponentSettings(
          locationPuck: LocationPuck(locationPuck2D: DefaultLocationPuck2D()),
          enabled: true,
          pulsingEnabled: false,
          puckBearingEnabled: true,
        ),
      );
      debugPrint(
        'VUP_LOG: LocationComponent inicializado com seta de navegação',
      );
    } catch (e) {
      debugPrint('VUP_LOG: falha ao ativar LocationComponent: $e');
    }

    // Cria APENAS o CircleAnnotationManager (leve, não causa lockHardwareCanvas)
    // PolylineAnnotationManagers foram REMOVIDOS — substituídos por Style layers
    try {
      _circleManager = await _mapboxMap!.annotations
          .createCircleAnnotationManager();
      debugPrint('VUP_LOG: CircleAnnotationManager criado');
    } catch (e) {
      debugPrint('VUP_LOG: Não foi possível criar CircleAnnotationManager: $e');
    }

    await _resetCameraToCurrentLocation();
  }

  /// Adiciona marcadores de pickup (círculo verde) e destination (círculo vermelho)
  Future<void> _addRouteMarkers(
    List<double> pickupCoords,
    List<double> destinationCoords,
  ) async {
    if (_circleManager == null) {
      debugPrint('VUP_LOG: CircleAnnotationManager não foi inicializado');
      return;
    }

    try {
      // Limpa marcadores de círculo anteriores
      await _circleManager!.deleteAll();
      _circleAnnotations.clear();

      // Passageiro: círculo verde
      final pickupCircle = await _circleManager!.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(pickupCoords[0], pickupCoords[1]),
          ),
          circleColor: Colors.green.toARGB32(),
          circleRadius: 8.0,
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 2.0,
        ),
      );
      _circleAnnotations.add(pickupCircle);

      // Destino: círculo vermelho
      final destCircle = await _circleManager!.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(destinationCoords[0], destinationCoords[1]),
          ),
          circleColor: Colors.red.toARGB32(),
          circleRadius: 9.0,
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 2.0,
        ),
      );
      _circleAnnotations.add(destCircle);

      debugPrint('VUP_LOG: Circle markers (pickup + destination) adicionados');
    } catch (e) {
      debugPrint('VUP_LOG: Erro ao adicionar circle markers: $e');
    }
  }

  /// Limpa TUDO: style layers de rota + circle annotations.
  /// Style layers são removidos via removeStyleLayer/removeStyleSource —
  /// sem AnnotationManager overhead.
  Future<void> _cleanupAnnotations() async {
    final map = _mapboxMap;
    if (map == null) return;

    try {
      // 1. Remove line layers (ordem: layers primeiro, source depois)
      try {
        await map.style.removeStyleLayer(_routeMainId);
      } catch (_) {} // ignora se não existe
      try {
        await map.style.removeStyleLayer(_routeBorderId);
      } catch (_) {}
      try {
        await map.style.removeStyleSource(_routeSourceId);
      } catch (_) {}

      // 2. Limpa circle annotations (leves, sem impacto no canvas)
      if (_circleManager != null) {
        await _circleManager!.deleteAll();
        _circleAnnotations.clear();
      }

      debugPrint('VUP_LOG: Anotações e style layers limpos');
    } catch (e) {
      debugPrint('VUP_LOG: Erro ao limpar anotações: $e');
    }
  }

  /// Busca rota de 3 pontos via Mapbox Directions API
  /// origin -> pickup -> destination
  Future<List<List<double>>> _fetchThreePointRoute(
    List<double> originCoords,
    List<double> pickupCoords,
    List<double> destinationCoords,
  ) async {
    final coords =
        '${originCoords[0]},${originCoords[1]};${pickupCoords[0]},${pickupCoords[1]};${destinationCoords[0]},${destinationCoords[1]}';
    final url =
        'https://api.mapbox.com/directions/v5/mapbox/driving/$coords?geometries=geojson&access_token=$_accessToken';

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => http.Response('timeout', 408),
          );

      if (response.statusCode != 200) {
        debugPrint(
          'VUP_LOG: Mapbox Directions statusCode ${response.statusCode}',
        );
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>?;
      final routes = data?['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return [];

      final geometry =
          (routes.first as Map<String, dynamic>)['geometry']
              as Map<String, dynamic>?;
      final coordsList = geometry?['coordinates'] as List<dynamic>?;
      if (coordsList == null) return [];

      return coordsList
          .whereType<List<dynamic>>()
          .map<List<double>>(
            (raw) => [(raw[0] as num).toDouble(), (raw[1] as num).toDouble()],
          )
          .toList();
    } catch (e) {
      debugPrint('VUP_LOG: Erro ao buscar rota no Mapbox: $e');
      return [];
    }
  }

  /// Desenha a rota usando GeoJsonSource + LineLayer (Style API).
  /// ZERO AnnotationManagers — roda inteiramente dentro do motor GL do Mapbox.
  /// Isso elimina o lockHardwareCanvas causado por PolylineAnnotationManager.
  Future<void> _renderRoutePolylines(List<List<double>> coordinates) async {
    final map = _mapboxMap;
    if (map == null) {
      debugPrint('VUP_LOG: Mapa não inicializado para desenhar polilinha');
      return;
    }

    if (coordinates.isEmpty) {
      debugPrint('VUP_LOG: Nenhuma posição para desenhar');
      return;
    }

    try {
      // Monta GeoJSON inline da rota
      final geoJson = json.encode({
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': coordinates, // já no formato [[lng, lat], ...]
        },
        'properties': {},
      });

      // Adiciona source GeoJSON (ou atualiza se já existir)
      bool sourceExists = false;
      try {
        sourceExists = await map.style.styleSourceExists(_routeSourceId);
      } catch (_) {}

      if (sourceExists) {
        // Atualiza dados sem recriar source
        await map.style.setStyleSourceProperty(_routeSourceId, 'data', geoJson);
        debugPrint('VUP_LOG: GeoJSON source atualizada');
      } else {
        // Cria source nova
        await map.style.addSource(
          GeoJsonSource(id: _routeSourceId, data: geoJson),
        );
        debugPrint('VUP_LOG: GeoJSON source criada');

        // Adiciona layer de borda (casing) — espessura 8, cor dinâmica dia/noite
        await map.style.addLayer(
          LineLayer(
            id: _routeBorderId,
            sourceId: _routeSourceId,
            lineWidth: 8.0,
            lineColor: _isNoite
                ? const Color(0xFF007AFF).toARGB32()
                : Colors.white.toARGB32(),
            lineCap: LineCap.ROUND,
            lineJoin: LineJoin.ROUND,
          ),
        );
        debugPrint('VUP_LOG: LineLayer borda (casing) adicionada');

        // Adiciona layer principal — azul sólido, espessura 5
        await map.style.addLayer(
          LineLayer(
            id: _routeMainId,
            sourceId: _routeSourceId,
            lineWidth: 5.0,
            lineColor: Colors.blue.toARGB32(),
            lineCap: LineCap.ROUND,
            lineJoin: LineJoin.ROUND,
          ),
        );
        debugPrint('VUP_LOG: LineLayer principal azul adicionada (width: 5.0)');
      }
    } catch (e) {
      debugPrint('VUP_LOG: Erro ao desenhar polilinhas via Style API: $e');
    }
  }

  /// Ajusta câmera para enquadrar toda a rota (motorista -> pickup -> destination)
  /// Calcula bounds entre os 3 pontos e deixa o bounds decidir o zoom.
  Future<void> _focusCameraOnRoute(
    List<double> originCoords,
    List<List<double>> routeCoords,
    List<double> pickupCoords,
    List<double> destinationCoords,
  ) async {
    if (_hasFocussed) {
      debugPrint('VUP_LOG: Foco de câmera já realizado, skipping');
      return;
    }

    if (_mapboxMap == null) {
      debugPrint('VUP_LOG: Não é possível focar câmera: mapa nulo');
      return;
    }

    try {
      _hasFocussed = true;

      // Cria lista com os 3 pontos: [Motorista, Embarque, Destino]
      final List<List<double>> threePoints = [
        originCoords,
        pickupCoords,
        destinationCoords,
      ];

      // Calcula bounds exatos usando math.min / math.max APENAS entre os 3 pontos
      double minLat = threePoints[0][1];
      double maxLat = threePoints[0][1];
      double minLng = threePoints[0][0];
      double maxLng = threePoints[0][0];

      for (final p in threePoints) {
        minLng = math.min(minLng, p[0]);
        maxLng = math.max(maxLng, p[0]);
        minLat = math.min(minLat, p[1]);
        maxLat = math.max(maxLat, p[1]);
      }

      debugPrint('VUP_LOG: Bounds SW=($minLat,$minLng) NE=($maxLat,$maxLng)');

      // Padding obrigatório: top:100, left:80, right:80, bottom:400
      const double padTop = 100.0;
      const double padLeft = 80.0;
      const double padRight = 80.0;
      const double padBottom = 400.0;

      // Cria LatLngBounds e usa coordinateBoundsForCamera implícito via center+zoom Mercator
      final centerLng = (minLng + maxLng) / 2.0;
      final centerLat = (minLat + maxLat) / 2.0;

      // Cálculo Mercator sem zoom fixo — o bounds decide
      final size = MediaQuery.of(context).size;
      final usableWidth = math.max(50.0, size.width - padLeft - padRight);
      final usableHeight = math.max(50.0, size.height - padTop - padBottom);

      double latRad(double lat) =>
          math.log(math.tan(math.pi / 4 + lat * math.pi / 360));

      final double latFraction = (latRad(maxLat) - latRad(minLat)) / math.pi;
      final double lngFraction = (maxLng - minLng) / 360.0;

      const double tileSize = 256.0;
      double latZoom = double.infinity;
      double lngZoom = double.infinity;

      if (latFraction > 0) {
        latZoom = math.log(usableHeight / tileSize / latFraction) / math.log(2);
      }
      if (lngFraction > 0) {
        lngZoom = math.log(usableWidth / tileSize / lngFraction) / math.log(2);
      }

      double boundsZoom = math.min(latZoom, lngZoom);
      if (!boundsZoom.isFinite) boundsZoom = 14.0;
      boundsZoom = boundsZoom.clamp(3.0, 20.0);

      debugPrint('VUP_LOG: Zoom calculado pelo bounds: $boundsZoom');

      // Anima câmera com easeTo — zoom derivado dos bounds, NÃO hardcoded
      await _mapboxMap!.easeTo(
        CameraOptions(
          center: Point(coordinates: Position(centerLng, centerLat)),
          zoom: boundsZoom,
          bearing: 0,
          pitch: 0,
          padding: MbxEdgeInsets(
            top: padTop,
            left: padLeft,
            bottom: padBottom,
            right: padRight,
          ),
        ),
        MapAnimationOptions(duration: 800),
      );

      debugPrint(
        'VUP_LOG: Câmera animada com sucesso (zoom:$boundsZoom pad T:$padTop L:$padLeft R:$padRight B:$padBottom)',
      );
    } catch (e) {
      debugPrint('VUP_LOG: Erro ao focar câmera na rota: $e');
      // Fallback: centraliza no ponto médio da rota
      if (routeCoords.isNotEmpty) {
        try {
          final midPoint = routeCoords[routeCoords.length ~/ 2];
          await _mapboxMap?.setCamera(
            CameraOptions(
              center: Point(coordinates: Position(midPoint[0], midPoint[1])),
            ),
          );
          debugPrint('VUP_LOG: Fallback câmera - ponto médio da rota usado');
        } catch (fallbackErr) {
          debugPrint('VUP_LOG: Fallback câmera também falhou: $fallbackErr');
        }
      }
    }
  }

  Future<void> _resetCameraToCurrentLocation() async {
    try {
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );
      await _mapboxMap?.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: 15.0,
        ),
      );
    } catch (e) {
      debugPrint('VUP_LOG: Não conseguiu centralizar no motorista: $e');
    }
  }

  Future<void> showTripRoute(
    List<double> pickupCoords,
    List<double> destinationCoords, {
    List<double>? originCoords,
    String? tripId,
  }) async {
    debugPrint(
      'VUP_LOG: showTripRoute chamado - pickup: $pickupCoords, destination: $destinationCoords, tripId: $tripId',
    );

    // PASSO 0: Guards defensivos — tripId + mutex + cache de redesenho
    if (tripId != null && _lastDrawnRouteId == tripId) {
      debugPrint(
        'VUP_LOG: showTripRoute skipped - mesma corrida já desenhada (tripId: $tripId)',
      );
      return;
    }

    if (_isDrawingRoute) {
      debugPrint('VUP_LOG: showTripRoute BLOQUEADO - draw já em andamento');
      return;
    }

    if (_isDrawingRoute) {
      debugPrint('VUP_LOG: showTripRoute BLOQUEADO - draw já em andamento');
      return;
    }

    if (_mapboxMap == null) {
      debugPrint('VUP_LOG: showTripRoute chamado antes do mapa estar pronto.');
      return;
    }

    // Valida coordenadas NaN/Infinity antes de qualquer operação no canvas
    for (final coord in [...pickupCoords, ...destinationCoords]) {
      if (coord.isNaN || coord.isInfinite) {
        debugPrint(
          'VUP_LOG: ERRO - Coordenada NaN/Infinity detectada, abortando para evitar loop.',
        );
        return;
      }
    }

    _hasFocussed = false;
    _isDrawingRoute = true; // LOCK — nenhum outro draw entra até o finally

    // Cache do tripId atual para evitar redesenho futuro
    _lastDrawnRouteId = tripId;

    try {
      // PASSO 1: Limpeza Inicial — remove TUDO do mapa antes de desenhar
      debugPrint('VUP_LOG: PASSO 1 - Limpeza inicial');
      await _cleanupAnnotations();
      debugPrint('VUP_LOG: Anotações anteriores removidas');

      // PASSO 2: Resolver origem (GPS do motorista)
      debugPrint('VUP_LOG: PASSO 2 - Resolvendo origem');
      List<double> originCoordsLocal;
      if (originCoords != null && originCoords.length >= 2) {
        originCoordsLocal = originCoords;
        debugPrint('VUP_LOG: Origin fornecida: $originCoordsLocal');
      } else {
        late geo.Position currentPos;
        try {
          currentPos = await geo.Geolocator.getCurrentPosition(
            locationSettings: const geo.LocationSettings(
              accuracy: geo.LocationAccuracy.high,
            ),
          );
          debugPrint(
            'VUP_LOG: GPS obtido - lat: ${currentPos.latitude}, lng: ${currentPos.longitude}',
          );
        } catch (gpsError) {
          debugPrint('VUP_LOG: Erro ao obter GPS: $gpsError');
          final lastPos = await geo.Geolocator.getLastKnownPosition();
          if (lastPos == null) {
            debugPrint(
              'VUP_LOG: Nenhuma posição conhecida disponível. Abortando.',
            );
            return;
          }
          currentPos = lastPos;
          debugPrint('VUP_LOG: Usando última posição conhecida');
        }
        originCoordsLocal = [currentPos.longitude, currentPos.latitude];
        debugPrint('VUP_LOG: Origin resolvida: $originCoordsLocal');
      }

      // PASSO 3: Rota de 3 pontos (Motorista -> Embarque -> Destino)
      debugPrint('VUP_LOG: PASSO 3 - Buscando rota de 3 pontos');
      final routeCoords = await _fetchThreePointRoute(
        originCoordsLocal,
        pickupCoords,
        destinationCoords,
      );

      if (routeCoords.isEmpty) {
        debugPrint('VUP_LOG: Rota vazia retornada pela API. Abortando.');
        return;
      }
      debugPrint('VUP_LOG: Rota obtida com ${routeCoords.length} pontos');

      // PASSO 4: Desenho da polilinha via Style API (GeoJsonSource + LineLayer)
      debugPrint('VUP_LOG: PASSO 4 - Desenhando polilinha via Style API');
      await _renderRoutePolylines(routeCoords);

      // PASSO 5: Marcadores nativos (CircleAnnotation verde + vermelho)
      debugPrint('VUP_LOG: PASSO 5 - Adicionando marcadores');
      await _addRouteMarkers(pickupCoords, destinationCoords);

      // PASSO 6: Câmera animada com bounds dos 3 pontos
      debugPrint('VUP_LOG: PASSO 6 - Ajustando câmera');
      await _focusCameraOnRoute(
        originCoordsLocal,
        routeCoords,
        pickupCoords,
        destinationCoords,
      );
      debugPrint('VUP_LOG: showTripRoute COMPLETO');
    } catch (e) {
      debugPrint('VUP_LOG: Erro FATAL em showTripRoute: $e');
    } finally {
      _isDrawingRoute = false; // UNLOCK — sempre libera, mesmo em erro
    }
  }

  /// Limpa toda a rota e volta para a posição do motorista
  Future<void> clearTripRoute() async {
    debugPrint('VUP_LOG: clearTripRoute chamado');
    await _cleanupAnnotations();
    debugPrint('VUP_LOG: Anotações limpas');

    // Reset das flags de controle para próxima corrida
    _hasFocussed = false;
    _lastDrawnRouteId = null; // Reset do cache de redesenho
    debugPrint('VUP_LOG: Flags de controle resetadas');

    await _resetCameraToCurrentLocation();
    debugPrint('VUP_LOG: Câmera resetada para posição do motorista');
  }
}
