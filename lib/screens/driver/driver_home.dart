import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/device_utils.dart';
import '../../core/viper_theme.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/viper_foreground_service.dart';
import 'widgets/ride_request_alert.dart';

/// Tela principal do motorista.
///
/// Decisões arquiteturais documentadas:
///
/// [_canShowMap] — Controle de montagem do mapa:
///   O Android não alocar o HardwareCanvas instantâneamente. Se o [MapboxMap]
///   for inserido na árvore antes do canvas estar pronto, o sistema lança
///   lockHardwareCanvas em loop. Solvídeo: o mapa só entra na árvore após
///   o primeiro frame ([addPostFrameCallback]) + 300ms de margem de segurança.
///
/// [_positionNotifier] — GPS sem rebuild:
///   [setState] + GPS a 60Hz = o Flutter destrói e recria o Stack inteiro,
///   incluindo o canvas OpenGL do Mapbox. [ValueNotifier] + [ValueListenableBuilder]
///   isolam o painel inferior como único widget que reconstrói. O mapa NÃO
///   segue o GPS automaticamente: um puck manual via [PointAnnotation] salta
///   apenas quando o stream filtrado entrega nova coordenada, e a câmera só
///   recentraliza por ação explícita do usuário.
///
/// [textureView: true + SizedBox.expand] — Isolação do canvas Android:
///   Por padrão o Mapbox usa SurfaceView, que entra em conflito de repintura
///   com overlays de Stack (lockHardwareCanvas / QueueBuffer timeout / OOM).
///   `textureView: true` instrui o Mapbox a usar TextureView — solução
///   oficial para Android ao ter elementos sobrepostos ao mapa.
///   [SizedBox.expand] dá restrições rígidas sem criar camada de composição.
///   O card de corrida (Camada 3) usa [RepaintBoundary] para isolar
///   o Timer.periodic (1Hz) do canvas OpenGL — essa é a barreira correta.
///   A câmera fica livre, transformando o mapa em overview estático para rota,
///   coleta e destino.
///
/// Logout — Ordem crítica de operações:
///   [navigate to /splash] ANTES de [signOut()]. Se [signOut()] vier primeiro,
///   o evento 'signedOut' remove este widget da árvore (mounted=false)
///   antes da navegação executar, e a Splash é pulada.

class ViperDriverHome extends StatefulWidget {
  const ViperDriverHome({super.key});

  @override
  State<ViperDriverHome> createState() => _ViperDriverHomeState();
}

class _ViperDriverHomeState extends State<ViperDriverHome> {
  // REGRA DE OURO: ZERO setState nesta classe. O build() é chamado apenas
  // uma vez (montagem inicial). Todas as atualizações de UI ocorrem dentro
  // dos ValueListenableBuilder / ListenableBuilder das camadas isoladas.
  final _onlineNotifier = ValueNotifier<bool>(false);
  final _canShowMapNotifier = ValueNotifier<bool>(false);
  final _positionNotifier = ValueNotifier<geo.Position?>(null);
  final _rideRequestNotifier = ValueNotifier<RideRequest?>(null);

  ValueNotifier<bool> get _isOnline => _onlineNotifier;
  final _sheetController = DraggableScrollableController();

  StreamSubscription<geo.Position>? _positionSub;
  MapboxMap? _mapController;
  PointAnnotationManager? _driverPuckManager;
  PointAnnotationManager? _routePointManager;
  PolylineAnnotationManager? _routePolylineManager;
  PointAnnotation? _driverPuck;
  Uint8List? _driverPuckImage;
  Uint8List? _pickupMarkerImage;
  Uint8List? _destinationMarkerImage;

  @override
  void initState() {
    super.initState();
    // postFrameCallback: executa somente após o primeiro frame estar pintado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Mantém a tela acesa sempre que o motorista estiver nesta tela.
      // Liberado em dispose() — independente do estado online/offline.
      ViperDeviceUtils.keepScreenOn();
      // Inicia permissão de localização logo após o primeiro frame
      _initLocationPermission().then((_) {
        if (mounted) _checkBatteryOptimization();
      });
      // Ativa o mapa após 300ms — garante HardwareCanvas pronto antes do Mapbox.
      // ValueNotifier em vez de setState: build() NÃO é rechamado.
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _canShowMapNotifier.value = true;
      });
    });
  }

  Future<void> _initLocationPermission() async {
    final status = await ViperLocationService.requestPermission();
    if (!mounted) return;

    if (status == LocationPermissionStatus.granted) {
      final pos = await ViperLocationService.getCurrentPosition();
      if (!mounted || pos == null) return;
      // Atualiza a posição local sem tocar a câmera: o mapa virou overview.
      // O puck nativo continua se movendo; a câmera só centraliza por ação
      // explícita do usuário no botão de alvo.
      _positionNotifier.value = pos;
    } else {
      final msg = status == LocationPermissionStatus.serviceDisabled
          ? 'GPS desativado. Ative a localização nas configurações.'
          : 'Permissão de localização negada. Ative nas configurações do app.';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _checkBatteryOptimization() async {
    if (!mounted) return;
    final isIgnoring =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!mounted || isIgnoring) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.battery_alert, color: Color(0xFFF39C12), size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Otimização de bateria',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Para garantir o rastreio contínuo mesmo com a tela bloqueada, '
          'o Viper Ride precisa funcionar sem restrições de bateria.\n\n'
          'Nas configurações, selecione "Sem restrições" ou "Não otimizar".',
          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Agora não',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF39C12),
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await FlutterForegroundTask.requestIgnoreBatteryOptimization();
            },
            child: const Text(
              'Configurar agora',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    _mapController = controller;
    _driverPuckImage ??= await _buildDriverPuckImage();
    _pickupMarkerImage ??= await _buildRouteMarkerImage(
      icon: Icons.person_pin_circle_rounded,
      color: const Color(0xFF2ECC71),
    );
    _destinationMarkerImage ??= await _buildRouteMarkerImage(
      icon: Icons.location_on_rounded,
      color: const Color(0xFFE53935),
    );

    await controller.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await controller.compass.updateSettings(CompassSettings(enabled: false));
    await controller.logo.updateSettings(LogoSettings(enabled: false));
    await controller.attribution.updateSettings(
      AttributionSettings(enabled: false),
    );
    await controller.location.updateSettings(
      LocationComponentSettings(
        // Puck nativo desligado: o LocationComponent do Mapbox é a origem dos
        // crashes de PlatformView/Surface no Android. A posição agora é nossa.
        enabled: false,
        pulsingEnabled: false,
        showAccuracyRing: false,
        puckBearingEnabled: false,
        locationPuck: LocationPuck(locationPuck2D: DefaultLocationPuck2D()),
      ),
    );

    _driverPuckManager ??= await controller.annotations
        .createPointAnnotationManager();
    _routePointManager ??= await controller.annotations
        .createPointAnnotationManager();
    _routePolylineManager ??= await controller.annotations
        .createPolylineAnnotationManager();

    final pos = _positionNotifier.value;
    if (pos != null) {
      await _updateDriverPuck(pos);
    }

    final request = _rideRequestNotifier.value;
    if (pos != null && request != null) {
      await _drawRouteOverview(request, pos);
    }
  }

  Future<Uint8List> _buildDriverPuckImage() async {
    const size = 64.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
    final outerPaint = Paint()..color = Colors.white;
    final innerPaint = Paint()..color = const Color(0xFF1E88E5);

    canvas.drawCircle(center + const Offset(0, 3), 18, shadowPaint);
    canvas.drawCircle(center, 16, outerPaint);
    canvas.drawCircle(center, 11, innerPaint);

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<Uint8List> _buildRouteMarkerImage({
    required IconData icon,
    required Color color,
  }) async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 72,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
    )..layout();

    final dx = (size - textPainter.width) / 2;
    final dy = (size - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(dx, dy));

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> _updateDriverPuck(geo.Position pos) async {
    final manager = _driverPuckManager;
    final image = _driverPuckImage;
    if (manager == null || image == null) return;

    final geometry = Point(coordinates: Position(pos.longitude, pos.latitude));

    final annotation = _driverPuck;
    if (annotation == null) {
      _driverPuck = await manager.create(
        PointAnnotationOptions(
          geometry: geometry,
          image: image,
          iconAnchor: IconAnchor.CENTER,
          iconSize: 1.8,
        ),
      );
      return;
    }

    annotation.geometry = geometry;
    await manager.update(annotation);
  }

  Future<void> _clearDriverPuck() async {
    final manager = _driverPuckManager;
    if (manager == null) return;
    await manager.deleteAll();
    _driverPuck = null;
  }

  Future<Map<String, dynamic>> _fetchRoute(
    Position driver,
    Position pickup,
    Position destination,
  ) async {
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN']?.trim() ?? '';
    if (token.isEmpty) return {'coordinates': <Map<String, dynamic>>[]};

    final String url =
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '${driver.lng},${driver.lat};'
        '${pickup.lng},${pickup.lat};'
        '${destination.lng},${destination.lat}'
        '?geometries=geojson&access_token=$token';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return {'coordinates': <Map<String, dynamic>>[]};
      }

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>?;
      final coords = geometry?['coordinates'] as List<dynamic>?;
      if (coords == null) return {'coordinates': <Map<String, dynamic>>[]};

      final legs = route['legs'] as List<dynamic>?;
      final leg1 = legs != null && legs.isNotEmpty
          ? legs[0] as Map<String, dynamic>
          : null;
      final leg2 = legs != null && legs.length > 1
          ? legs[1] as Map<String, dynamic>
          : null;

      final double kmToPass = leg1 == null
          ? 0.0
          : ((leg1['distance'] as num?)?.toDouble() ?? 0.0) / 1000.0;
      final int minToPass = leg1 == null
          ? 0
          : (((leg1['duration'] as num?)?.toDouble() ?? 0.0) / 60.0).round();

      final double kmToDest = leg2 == null
          ? 0.0
          : ((leg2['distance'] as num?)?.toDouble() ?? 0.0) / 1000.0;
      final int minToDest = leg2 == null
          ? 0
          : (((leg2['duration'] as num?)?.toDouble() ?? 0.0) / 60.0).round();

      return {
        'coordinates': coords
            .map(
              (c) => {
                'type': 'Point',
                'coordinates': [(c as List<dynamic>)[0], c[1]],
              },
            )
            .toList(),
        'kmToPassenger': kmToPass,
        'minutesToPassenger': minToPass,
        'kmToDestination': kmToDest,
        'minutesToDestination': minToDest,
      };
    }
    return {'coordinates': <Map<String, dynamic>>[]};
  }

  Future<void> _drawRouteOverview(
    RideRequest request,
    geo.Position driverPosition,
  ) async {
    final pointManager = _routePointManager;
    final polylineManager = _routePolylineManager;
    final pickupImage = _pickupMarkerImage;
    final destinationImage = _destinationMarkerImage;
    if (pointManager == null || polylineManager == null) return;
    if (pickupImage == null || destinationImage == null) return;

    await polylineManager.deleteAll();
    await pointManager.deleteAll();

    final routeData = await _fetchRoute(
      Position(driverPosition.longitude, driverPosition.latitude),
      Position(request.pickupLng, request.pickupLat),
      Position(request.destLng, request.destLat),
    );
    final routeCoordinates =
        (routeData['coordinates'] as List<dynamic>? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>();

    if (routeCoordinates.isNotEmpty) {
      await polylineManager.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: routeCoordinates
                .map(
                  (point) => Position(
                    (point['coordinates'] as List<dynamic>)[0] as num,
                    (point['coordinates'] as List<dynamic>)[1] as num,
                  ),
                )
                .map((p) => Position(p.lng.toDouble(), p.lat.toDouble()))
                .toList(),
          ),
          lineColor: const Color(0xFF2196F3).toARGB32(),
          lineWidth: 5.0,
          lineJoin: LineJoin.ROUND,
        ),
      );
    }

    await pointManager.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(request.pickupLng, request.pickupLat),
        ),
        image: pickupImage,
        iconAnchor: IconAnchor.BOTTOM,
        iconSize: 1.1,
        iconOffset: [0.0, -4.0],
      ),
    );

    await pointManager.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(request.destLng, request.destLat),
        ),
        image: destinationImage,
        iconAnchor: IconAnchor.BOTTOM,
        iconSize: 1.15,
        iconOffset: [0.0, -6.0],
      ),
    );
  }

  Future<void> _clearRouteOverview() async {
    await _routePolylineManager?.deleteAll();
    await _routePointManager?.deleteAll();
  }

  void _setCamera(geo.Position pos) {
    final ctrl = _mapController;
    if (ctrl == null) return; // guard: não acessa o mapa após dispose
    ctrl.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(pos.longitude, pos.latitude)),
        zoom: 15.0,
        bearing: 0.0,
        pitch: 45.0,
      ),
    );
  }

  Future<void> _centerOnDriver() async {
    final cached = _positionNotifier.value;
    if (cached != null) {
      _setCamera(cached);
      return;
    }

    final pos = await ViperLocationService.getCurrentPosition();
    if (!mounted || pos == null) return;
    _positionNotifier.value = pos;
    await _updateDriverPuck(pos);
    _setCamera(pos);
  }

  Future<void> _snapBackToDriver() async {
    _rideRequestNotifier.value = null;

    // Respiro curto: deixa o Flutter remover o card antes de pedir novo
    // frame ao PlatformView do Mapbox.
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final cached = _positionNotifier.value;
    if (cached != null) {
      final ctrl = _mapController;
      if (ctrl == null) {
        await _clearRouteOverview();
        return;
      }
      ctrl.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(cached.longitude, cached.latitude),
          ),
          zoom: 16.0,
          bearing: 0.0,
          pitch: 45.0,
          padding: MbxEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
        ),
      );
      await _clearRouteOverview();
      return;
    }

    final pos = await ViperLocationService.getCurrentPosition();
    if (!mounted || pos == null) {
      await _clearRouteOverview();
      return;
    }
    _positionNotifier.value = pos;
    await _updateDriverPuck(pos);

    final ctrl = _mapController;
    if (ctrl == null) {
      await _clearRouteOverview();
      return;
    }
    ctrl.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(pos.longitude, pos.latitude)),
        zoom: 16.0,
        bearing: 0.0,
        pitch: 45.0,
        padding: MbxEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
      ),
    );
    await _clearRouteOverview();
  }

  void _collapseSheet() {
    if (!_sheetController.isAttached) return;
    _sheetController.animateTo(
      0.12,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  /// Encerra todos os serviços ativos sem alterar estado de UI.
  /// Pode ser chamado por _goOffline, _confirmLogout e dispose.
  Future<void> _disposeDriverMode() async {
    _positionSub?.cancel();
    _positionSub = null;
    await _clearDriverPuck();
    await _clearRouteOverview();
    await ViperForegroundService.stop();
    // Wakelock NÃO é liberado aqui: a tela fica acesa enquanto o motorista
    // estiver na tela do mapa, mesmo offline. Liberado apenas em dispose().
    // Remove a linha de localização para sinalizar offline no Supabase
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await Supabase.instance.client
            .from('driver_locations')
            .delete()
            .eq('driver_id', userId);
      } catch (_) {}
    }
  }

  Future<void> _confirmLogout() async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.power_settings_new, color: Colors.redAccent, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sair do Viper Ride',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Deseja realmente sair e ficar offline?\n\n'
          'O rastreio e a notificação serão encerrados.',
          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Sair',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _disposeDriverMode();
    if (!mounted) return;

    // CRÍTICO: captura o navigator e navega ANTES de chamar signOut().
    // Se signOut() vier primeiro, o evento 'signedOut' do stream faz o AuthPortal
    // remover ViperDriverHome da árvore (dispose → mounted=false) e a navegação
    // nunca executa — a Splash é pulada e o Login aparece diretamente.
    final nav = Navigator.of(context);
    nav.pushNamedAndRemoveUntil('/splash', (route) => false);

    // signOut após a navegação: quando o stream 'signedOut' chegar, o AuthPortal
    // já estará fora da árvore (unmounted) e o setState será ignorado corretamente.
    await ViperAuthService.signOut();
  }

  Future<void> _goOnline() async {
    _onlineNotifier.value = true; // sem setState — mapa não é tocado

    // Wakelock já está ativo desde o initState — não precisa reativar aqui.
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    await ViperForegroundService.start(
      supabaseUrl: dotenv.env['SUPABASE_URL'] ?? '',
      supabaseKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      driverId: userId,
    );

    _positionSub = ViperLocationService.positionStream().listen(
      (pos) async {
        // Sem setState: apenas atualiza o ValueNotifier. O mapa não segue o
        // GPS automaticamente — overview estático por definição de negócio.
        _positionNotifier.value = pos;
        await _updateDriverPuck(pos);
      },
      onError: (_) {
        if (mounted) _goOffline();
      },
    );
  }

  Future<void> _goOffline() async {
    await _disposeDriverMode();
    _onlineNotifier.value = false; // sem setState — mapa não é tocado
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    final mapboxMap = _mapController;
    if (mapboxMap != null) {
      final driverPuckManager = _driverPuckManager;
      if (driverPuckManager != null) {
        mapboxMap.annotations.removeAnnotationManager(driverPuckManager);
      }
      final routePointManager = _routePointManager;
      if (routePointManager != null) {
        mapboxMap.annotations.removeAnnotationManager(routePointManager);
      }
      final routePolylineManager = _routePolylineManager;
      if (routePolylineManager != null) {
        mapboxMap.annotations.removeAnnotationManager(routePolylineManager);
      }
    }
    _driverPuckManager = null;
    _routePointManager = null;
    _routePolylineManager = null;
    _driverPuck = null;
    _driverPuckImage = null;
    _pickupMarkerImage = null;
    _destinationMarkerImage = null;
    _onlineNotifier.dispose();
    _canShowMapNotifier.dispose();
    _positionNotifier.dispose();
    _rideRequestNotifier.dispose();
    _sheetController.dispose();
    // Destrói o renderer nativo do Mapbox antes de liberar a tela
    // Evita lockHardwareCanvas quando o widget é removido da árvore
    _mapController?.dispose();
    _mapController = null;
    // Fire-and-forget: garante limpeza dos serviços se descartado externamente
    ViperForegroundService.stop();
    ViperDeviceUtils.releaseScreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Este método é chamado APENAS UMA VEZ (montagem inicial).
    // Após isso, o Flutter jamais recria o Stack ou o MapWidget.
    // Cada camada abaixo tem seu próprio mecanismo de rebuild isolado.
    return Scaffold(
      // FAB de teste: dispara um RideRequestAlert fictício para validar o card
      // em produção. Remover antes do release.
      floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'fab_test_ride',
        backgroundColor: const Color(0xFF2ECC71),
        foregroundColor: Colors.black,
        tooltip: 'Testar alerta de corrida',
        onPressed: () async {
          const request = RideRequest(
            id: '123',
            fare: 18.50,
            minutesToPassenger: 8,
            kmToPassenger: 4.2,
            minutesToDestination: 8,
            kmToDestination: 4.2,
            pickupAddress: 'Passeio Pedra Branca, Palhoça',
            pickupLat: -27.6225,
            pickupLng: -48.6811,
            destinationAddress: 'Shopping ViaCatarina, Palhoça',
            destLat: -27.6441,
            destLng: -48.6657,
            passengerRating: 4.9,
            paymentMethod: ViperPaymentMethod.card,
          );

          _rideRequestNotifier.value = request;

          // Respiro obrigatório: deixa o Flutter montar o overlay antes de
          // pedir cálculo de bounds/render ao Mapbox no PlatformView.
          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;

          var driverPosition = _positionNotifier.value;
          if (driverPosition == null) {
            driverPosition = await ViperLocationService.getCurrentPosition();
            if (!mounted || driverPosition == null) return;
            _positionNotifier.value = driverPosition;
            await _updateDriverPuck(driverPosition);
          }

          final routeData = await _fetchRoute(
            Position(driverPosition.longitude, driverPosition.latitude),
            Position(request.pickupLng, request.pickupLat),
            Position(request.destLng, request.destLat),
          );
          final enrichedRequest = RideRequest(
            id: request.id,
            fare: request.fare,
            minutesToPassenger:
                (routeData['minutesToPassenger'] as int?) ??
                request.minutesToPassenger,
            kmToPassenger:
                (routeData['kmToPassenger'] as double?) ??
                request.kmToPassenger,
            minutesToDestination:
                (routeData['minutesToDestination'] as int?) ??
                request.minutesToDestination,
            kmToDestination:
                (routeData['kmToDestination'] as double?) ??
                request.kmToDestination,
            pickupAddress: request.pickupAddress,
            pickupLat: request.pickupLat,
            pickupLng: request.pickupLng,
            destinationAddress: request.destinationAddress,
            destLat: request.destLat,
            destLng: request.destLng,
            passengerRating: request.passengerRating,
            paymentMethod: request.paymentMethod,
          );

          _rideRequestNotifier.value = enrichedRequest;

          await _drawRouteOverview(enrichedRequest, driverPosition);

          final mapboxMap = _mapController;
          if (mapboxMap == null) return;

          final southwest = Point(
            coordinates: Position(
              enrichedRequest.pickupLng < enrichedRequest.destLng
                  ? enrichedRequest.pickupLng
                  : enrichedRequest.destLng,
              enrichedRequest.pickupLat < enrichedRequest.destLat
                  ? enrichedRequest.pickupLat
                  : enrichedRequest.destLat,
            ),
          );
          final northeast = Point(
            coordinates: Position(
              enrichedRequest.pickupLng > enrichedRequest.destLng
                  ? enrichedRequest.pickupLng
                  : enrichedRequest.destLng,
              enrichedRequest.pickupLat > enrichedRequest.destLat
                  ? enrichedRequest.pickupLat
                  : enrichedRequest.destLat,
            ),
          );
          final padding = MbxEdgeInsets(
            top: 100,
            left: 50,
            bottom: 450,
            right: 50,
          );

          final cameraOptions = await mapboxMap.cameraForCoordinateBounds(
            CoordinateBounds(
              southwest: southwest,
              northeast: northeast,
              infiniteBounds: false,
            ),
            padding,
            0.0,
            0.0,
            null,
            null,
          );
          mapboxMap.setCamera(cameraOptions);
        },
        child: const Icon(Icons.notifications_active_rounded),
      ),
      body: Stack(
        children: [
          // ── Camada 0: Mapa — imutável após montagem ──────────────────────
          // O `child` (SizedBox.expand + MapWidget) é instanciado UMA vez
          // como argumento estático do builder. Quando canShow=false, o
          // Container preto é exibido e o PlatformView ainda NÃO existe.
          // Quando canShow=true (300ms), o child entra na RenderTree e o
          // HardwareCanvas é alocado pelo Android exatamente uma vez.
          // Após esse ponto, _canShowMapNotifier nunca mais muda → este
          // builder NUNCA mais é chamado.
          // SEM RepaintBoundary: em Hybrid Composition força cópia de textura
          // que causa QueueBuffer timeout. SizedBox.expand dá restrições
          // rígidas sem criar camada extra de composição.
          ValueListenableBuilder<bool>(
            valueListenable: _canShowMapNotifier,
            child: SizedBox.expand(
              child: MapWidget(
                // textureView: true — usa TextureView em vez de SurfaceView.
                // Solução oficial Mapbox para Android: elimina o conflito de
                // repintura (lockHardwareCanvas / QueueBuffer timeout) causado
                // por overlays de Stack sobre o PlatformView.
                textureView: true,
                styleUri: 'mapbox://styles/mapbox/dark-v11',
                cameraOptions: CameraOptions(
                  center: Point(coordinates: Position(-46.6333, -23.5505)),
                  zoom: 15.0,
                  bearing: 0.0,
                  pitch: 45.0,
                ),
                onMapCreated: _onMapCreated,
              ),
            ),
            builder: (context, canShow, mapChild) =>
                canShow ? mapChild! : Container(color: Colors.black),
          ),

          // ── Camada 1: Botão de logout — estático, nunca reconstrói ───────
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FloatingIconButton(
                      icon: Icons.my_location_rounded,
                      onTap: _centerOnDriver,
                    ),
                    const SizedBox(height: 10),
                    _FloatingIconButton(
                      icon: Icons.logout,
                      onTap: _confirmLogout,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Camada 2: Controle de disponibilidade ─────────────────────
          // OFFLINE → só o botão pílula branco flutuando a 40 px do fundo.
          // ONLINE  → DraggableScrollableSheet nascendo do rodapé.
          // O ValueListenableBuilder reconstrói APENAS esta camada; o mapa
          // e os botões superiores nunca são tocados.
          ValueListenableBuilder<bool>(
            valueListenable: _isOnline,
            builder: (context, isOnline, _) {
              if (!isOnline) {
                // Estado offline: pílula branca centralizada, 40 px do fundo
                return Positioned(
                  left: 24,
                  right: 24,
                  bottom: 40,
                  child: SafeArea(
                    top: false,
                    child: Center(child: _StartPillButton(onTap: _goOnline)),
                  ),
                );
              }

              // Estado online: sheet arrastável ancorada no rodapé.
              // Positioned.fill dá ao DraggableScrollableSheet a altura total
              // da tela para trabalhar; expand: true faz o sheet ocupar esse
              // espaço e renderizar o conteúdo colado na borda inferior.
              return Positioned.fill(
                child: DraggableScrollableSheet(
                  controller: _sheetController,
                  expand: true,
                  initialChildSize: 0.12,
                  minChildSize: 0.12,
                  maxChildSize: 1.0,
                  snap: true,
                  snapSizes: const [0.12, 0.45, 1.0],
                  builder: (context, scrollController) => _DriverStatusSheet(
                    scrollController: scrollController,
                    onGoOffline: _goOffline,
                  ),
                ),
              );
            },
          ),

          // ── Camada 3: Alerta de corrida — isolado do mapa ────────────────
          // Reconstrói SOMENTE quando _rideRequestNotifier muda (null↔request).
          // O RepaintBoundary isola o RideRequestAlert enquanto está visível:
          // o Timer.periodic interno (1Hz) não propaga invalidações de repaint
          // ao canvas OpenGL do Mapbox — zero frames contínuos no overlay.
          ValueListenableBuilder<RideRequest?>(
            valueListenable: _rideRequestNotifier,
            builder: (context, request, _) {
              if (request == null) return const SizedBox.shrink();
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: 156,
                    left: 16,
                    right: 16,
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: RepaintBoundary(
                      child: RideRequestAlert(
                        request: request,
                        onAccepted: () => _rideRequestNotifier.value = null,
                        onDeclined: _snapBackToDriver,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Widgets Internos ──────────────────────────────────────────────────────────

class _FloatingIconButton extends StatelessWidget {
  const _FloatingIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(icon, color: ViperColors.white, size: 20),
      ),
    );
  }
}

/// Botão pílula branco exibido quando o motorista está offline.
class _StartPillButton extends StatelessWidget {
  const _StartPillButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 6,
        shadowColor: Colors.black38,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
        shape: const StadiumBorder(),
      ),
      onPressed: onTap,
      child: const Text(
        'COMEÇAR',
        style: TextStyle(
          color: Colors.black,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Gaveta inferior exibida SOMENTE quando o motorista está online.
///
/// 12 % (mínimo): drag handle + [⚙] Você está online [≡]
/// 45 % / 100 %: revela o botão vermelho FICAR OFFLINE
class _DriverStatusSheet extends StatelessWidget {
  const _DriverStatusSheet({
    required this.scrollController,
    required this.onGoOffline,
  });

  final ScrollController scrollController;
  final VoidCallback onGoOffline;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag handle ─────────────────────────────────────────────
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF424242),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Linha de status: ícone | texto | ícone ──────────────────
            // Visível no snap mínimo (12 %). Imutável — sem rebuild.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SheetIconButton(icon: Icons.tune_rounded, onTap: () {}),
                  const Text(
                    'Você está online',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _SheetIconButton(
                    icon: Icons.format_list_bulleted_rounded,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            // ── Conteúdo expandido (visível a partir de 45 %) ────────────
            Padding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 24 + bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: onGoOffline,
                      child: const Text(
                        'FICAR OFFLINE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Espaço reservado para ganhos do dia / métricas futuras
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        'Aguardando novas corridas...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF5A5A5A),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botão de ícone circular usado na linha de status da gaveta.
class _SheetIconButton extends StatelessWidget {
  const _SheetIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
