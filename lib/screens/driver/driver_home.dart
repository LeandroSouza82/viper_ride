import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
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
import '../../services/trip_request_service.dart';
import '../../services/audio_service.dart';
import '../../controllers/mapbox_theme_controller.dart';
import 'widgets/ride_request_alert.dart';
import '../../widgets/trip_request_sheet.dart';
import 'driver_settings.dart';
import 'profile/complete_profile_screen.dart';
import '../../controllers/account_controller.dart';

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

  final _sheetController = DraggableScrollableController();
  final _sheetExtentNotifier = ValueNotifier<double>(0.12);
  bool _isEarningsExpanded = false;
  bool _isEarningsVisible = true;
  final double _dailyEarnings = 154.20;
  final int _tripsCompleted = 8;
  final int _points = 120;

  // Simula o array de veículos aprovados vindo do Supabase
  final List<String> _veiculosCadastrados = ['moto', 'carro'];
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _vehicleType;

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
      // Carrega o tipo do veículo do perfil para bloquear preferências
      _loadVehicleType();
      // Verifica se o perfil está completo e, se não, redireciona para completar
      // Checagem separada para evitar import circular — usamos Get.find if exists
      Future.microtask(() async {
        try {
          late AccountController ac;
          try {
            ac = Get.find<AccountController>();
          } catch (_) {
            ac = Get.put(AccountController());
          }
          final incomplete = await ac.checkProfileCompleteness();
          if (!mounted) return;
          if (incomplete) {
            try {
              Get.offAll(() => const CompleteProfileScreen());
            } catch (_) {}
          }
        } catch (_) {}
      });
    });
  }

  Future<void> _loadVehicleType() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final res = await Supabase.instance.client
          .from('profiles')
          .select('vehicle_type')
          .eq('id', userId)
          .maybeSingle();
      if (res == null) return;
      final v = (res as Map<String, dynamic>?)?['vehicle_type'] as String?;
      if (v != null && mounted) {
        setState(() {
          _vehicleType = v.toLowerCase();
        });
        debugPrint(
          'DEBUG VIPER: Tipo de veículo carregado do banco: $_vehicleType',
        );
      }
      // também imprime caso venha nulo
      if (v == null) {
        debugPrint('DEBUG VIPER: Tipo de veículo carregado do banco: null');
      }
    } catch (_) {
      // ignore errors silently — não bloqueia UI
    }
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
    TripRequestService.instance.stopListening();
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
    TripRequestService.instance.startListening(driverId: userId);
    try {
      AudioService.instance.playOnlineSound();
    } catch (_) {}

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

  void _showPreferencesSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        // Estado local do modal: não afeta o State principal.
        var isEntregasActive = false;
        var isMotoActive = false;
        var isCarroActive = true;
        var aceitarDinheiro = true;
        var avaliacaoAtiva = false;
        var notaMinima = 4.5;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollController) => Column(
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0, top: 8.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.black,
                            size: 28,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Preferências',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Conteúdo scrollável ─────────────────────────────────
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        // Banner informativo
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Filtrar viagens com base nas preferências',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF7B6000),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Título da seção
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Opções',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                showDialog<void>(
                                  context: context,
                                  builder: (BuildContext dialogContext) {
                                    return AlertDialog(
                                      backgroundColor: Colors.white,
                                      surfaceTintColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: const Text(
                                        'Como funciona?',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      content: const SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '📦 Viper Entregas',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Transporte de pacotes e delivery. Fature com agilidade.',
                                              style: TextStyle(
                                                color: Colors.black87,
                                              ),
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              '🏍️ Viper Moto',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Transporte rápido. Fuja do trânsito com taxa mínima justa.',
                                              style: TextStyle(
                                                color: Colors.black87,
                                              ),
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              '🚗 Viper Carros',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Conforto e lucro com nossa taxa fixa de 18%.',
                                              style: TextStyle(
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(dialogContext).pop(),
                                          child: const Text(
                                            'Entendi',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black,
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text(
                                'Saiba mais',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Grid de opções
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.1,
                          children: [
                            // CARD 1: Viper Entregas (Padrão para todos)
                            _buildPreferenceCard(
                              title: 'Viper Entregas',
                              icon: Icons.inventory,
                              isActive: isEntregasActive,
                              onChanged: (val) => setModalState(
                                () => isEntregasActive = val ?? false,
                              ),
                            ),

                            // CARD 2: Moto (Renderiza se tiver 'moto' na lista)
                            if (_veiculosCadastrados.contains('moto'))
                              _buildPreferenceCard(
                                title: 'Viper Moto',
                                icon: Icons.motorcycle,
                                isActive: isMotoActive,
                                isLocked: _vehicleType == 'carro',
                                onChanged: (val) => setModalState(() {
                                  isMotoActive = val ?? false;
                                  if (isMotoActive) isCarroActive = false;
                                }),
                              ),

                            // CARD 3: Carro (Renderiza se tiver 'carro' na lista)
                            if (_veiculosCadastrados.contains('carro'))
                              _buildPreferenceCard(
                                title: 'Viper Carros',
                                icon: Icons.directions_car,
                                isActive: isCarroActive,
                                // Forçar bloqueio visual para teste
                                isLocked: true,
                                onChanged: (val) => setModalState(() {
                                  isCarroActive = val ?? false;
                                  if (isCarroActive) isMotoActive = false;
                                }),
                              ),

                            // CARD 4: Preenchimento visual (para não deixar buraco no layout)
                            if (_veiculosCadastrados.length == 2)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Divisor
                        Divider(color: Colors.grey.shade300, thickness: 1),

                        // Header Filtros
                        const Padding(
                          padding: EdgeInsets.only(top: 12, bottom: 4),
                          child: Text(
                            'Filtros da viagem',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),

                        // Toggle Dinheiro
                        SwitchListTile(
                          activeThumbColor: Colors.black,
                          secondary: const Icon(
                            Icons.money,
                            color: Colors.black,
                          ),
                          title: const Text(
                            'Aceitar dinheiro',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          value: aceitarDinheiro,
                          onChanged: (val) =>
                              setModalState(() => aceitarDinheiro = val),
                        ),

                        // Toggle Avaliação + Slider dinâmico
                        Column(
                          children: [
                            SwitchListTile(
                              activeThumbColor: Colors.black,
                              secondary: const Icon(
                                Icons.people,
                                color: Colors.black,
                              ),
                              title: const Text(
                                'Avaliação do usuário',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              subtitle: const Text(
                                'Defina uma avaliação mínima de usuário para solicitações.',
                                style: TextStyle(color: Colors.black87),
                              ),
                              value: avaliacaoAtiva,
                              onChanged: (val) =>
                                  setModalState(() => avaliacaoAtiva = val),
                            ),
                            if (avaliacaoAtiva)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Nota mínima exigida: ${notaMinima.toStringAsFixed(1)} ⭐️',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    Slider(
                                      activeColor: Colors.black,
                                      inactiveColor: Colors.grey.shade300,
                                      value: notaMinima,
                                      min: 3.0,
                                      max: 5.0,
                                      divisions: 20,
                                      label: notaMinima.toStringAsFixed(1),
                                      onChanged: (val) =>
                                          setModalState(() => notaMinima = val),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Botão Redefinir
                        Center(
                          child: ElevatedButton(
                            onPressed: () => setModalState(() {
                              isEntregasActive = false;
                              isMotoActive = false;
                              isCarroActive = true;
                              aceitarDinheiro = true;
                              avaliacaoAtiva = false;
                              notaMinima = 4.5;
                            }),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 14,
                              ),
                              shape: const StadiumBorder(),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Redefinir',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPreferenceCard({
    required String title,
    required IconData icon,
    required bool isActive,
    bool isLocked = false,
    required ValueChanged<bool?> onChanged,
  }) {
    return Opacity(
      opacity: isLocked ? 0.3 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Top-right: checkbox when allowed, lock icon when blocked
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: isLocked
                    ? const Icon(
                        Icons.lock_outline,
                        size: 20,
                        color: Colors.black54,
                      )
                    : Checkbox(
                        value: isActive,
                        activeColor: Colors.black,
                        checkColor: Colors.white,
                        side: const BorderSide(color: Colors.black, width: 2),
                        onChanged: isLocked ? null : onChanged,
                      ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 36, color: Colors.black),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isLocked) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Indisponível para este veículo',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _goOffline() async {
    await _disposeDriverMode();
    _onlineNotifier.value = false; // sem setState — mapa não é tocado
    _collapseSheet();
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
    _sheetExtentNotifier.dispose();
    _sheetController.dispose();
    _pageController.dispose();
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
    final int horaAtual = DateTime.now().hour;
    final bool isNoite = horaAtual >= 18 || horaAtual < 6;

    SystemChrome.setSystemUIOverlayStyle(
      isNoite ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
    return Scaffold(
      // FAB de teste: dispara um RideRequestAlert fictício para validar o card
      // em produção. Remover antes do release.
      floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'fab_test_ride',
        backgroundColor: const Color(0xFF2ECC71),
        foregroundColor: Colors.black,
        tooltip: 'Testar alerta de corrida',
        onPressed: () {
          TripRequestService.instance.requestNotifier.value = {
            'price': 18.50,
            'eta': '15 min',
            'distance_to_pickup': '7.3 km',
            'trip_distance': '4.8 km',
            'pickup_address': 'Passeio Pedra Branca, Palhoça',
            'destination_address': 'Shopping ViaCatarina, Palhoça',
            'rating': 4.9,
            'payment_method': 'Cartão',
          };
          AudioService.instance.playRequestSound();
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
                styleUri: MapboxThemeController.styleFromTime(),
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

          // ── Pílula / Carrossel de Ganhos ────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: !_isEarningsExpanded
                  // ESTADO 1: PÍLULA RECOLHIDA
                  ? GestureDetector(
                      key: const ValueKey('collapsed'),
                      onTap: () => setState(() => _isEarningsExpanded = true),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.black, width: 1.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            _isEarningsVisible
                                ? 'R\$ ${_dailyEarnings.toStringAsFixed(2).replaceAll('.', ',')}'
                                : 'R\$ •••••',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 1),
                                  blurRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  // ESTADO 2: CARROSSEL EXPANDIDO
                  : GestureDetector(
                      key: const ValueKey('expanded'),
                      onTap: () => setState(() => _isEarningsExpanded = false),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 220,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 10,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: PageView(
                              controller: _pageController,
                              onPageChanged: (int page) =>
                                  setState(() => _currentPage = page),
                              children: [
                                // CARD 1: RESUMO
                                Stack(
                                  children: [
                                    Positioned(
                                      top: 4,
                                      left: 4,
                                      child: IconButton(
                                        icon: Icon(
                                          _isEarningsVisible
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                          color: Colors.black,
                                        ),
                                        onPressed: () => setState(
                                          () => _isEarningsVisible =
                                              !_isEarningsVisible,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                          child: Text(
                                            _isEarningsVisible
                                                ? 'R\$ ${_dailyEarnings.toStringAsFixed(2).replaceAll('.', ',')}'
                                                : 'R\$ •••••',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.greenAccent,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'HOJE',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          '$_tripsCompleted viagem concluída',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.diamond,
                                              color: Colors.blue,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$_points pontos',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () {},
                                          child: const Text(
                                            'VER RESUMO SEMANAL',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                // CARD 2: MISSÕES
                                const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.emoji_events,
                                        size: 48,
                                        color: Colors.orange,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Sem missão no momento',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Fique online para receber novas missões.',
                                        style: TextStyle(color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),

                                // CARD 3: ÚTIMA CORRIDA
                                const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 48,
                                        color: Colors.green,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Última Viagem',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      Text(
                                        'R\$ 15,50',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Hoje, 14:30 • Viper Moto',
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Indicadores
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (index) {
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentPage == index
                                      ? Colors.white
                                      : Colors.white54,
                                  border: Border.all(
                                    color: Colors.black26,
                                    width: 1,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // ── Camada 2: Gaveta arrastável — sempre presente (Online e Offline) ──
          // O DraggableScrollableSheet está sempre na árvore (snaps [0.12, 0.45, 1.0]).
          // O botão COMEÇAR / barra de status vive DENTRO da gaveta, como primeiro
          // item da coluna scrollável. Isso faz o botão "subir junto com a barra
          // preta" ao arrastar — sem nenhum widget flutuante fora da gaveta.
          // NotificationListener captura DraggableScrollableNotification
          // e atualiza _sheetExtentNotifier sem tocar no mapa ou no estado.
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              _sheetExtentNotifier.value = notification.extent;
              return false; // permite que a notificação continue subindo
            },
            child: Positioned.fill(
              child: DraggableScrollableSheet(
                controller: _sheetController,
                expand: true,
                initialChildSize: 0.12,
                minChildSize: 0.12,
                maxChildSize: 1.0,
                snap: true,
                snapSizes: const [0.12, 0.45, 1.0],
                builder: (context, scrollController) => _UnifiedDriverSheet(
                  scrollController: scrollController,
                  onlineNotifier: _onlineNotifier,
                  onGoOffline: _goOffline,
                  onShowPreferences: () {
                    // Forçar valor de teste antes de abrir o modal (debug)
                    String testeVehicleType = 'moto';
                    _vehicleType = testeVehicleType;
                    debugPrint(
                      'DEBUG VIPER: Forçando testeVehicleType = $testeVehicleType',
                    );
                    _showPreferencesSheet(context);
                  },
                ),
              ),
            ),
          ),

          // ── Camada 2b: Botão COMEÇAR — acompanha a gaveta em tempo real ──
          // ValueListenableBuilder duplo: extent (posição contínua da gaveta)
          // e online (aparece/desaparece). O botão sobe colado à borda superior
          // da gaveta e desvanece suavemente ao passar de 0.45.
          ValueListenableBuilder<double>(
            valueListenable: _sheetExtentNotifier,
            builder: (context, extent, _) {
              final screenH = MediaQuery.of(context).size.height;
              final currentBottom = (extent * screenH) + 10.0;
              final opacity = extent > 0.45 ? 0.0 : 1.0;
              return ValueListenableBuilder<bool>(
                valueListenable: _onlineNotifier,
                builder: (context, isOnline, _) {
                  // Se existe uma requisição de corrida ativa, escondemos o botão COMEÇAR
                  return ValueListenableBuilder<Map<String, dynamic>?>(
                    valueListenable:
                        TripRequestService.instance.requestNotifier,
                    builder: (context, trip, child) {
                      if (trip != null) return const SizedBox.shrink();
                      if (isOnline) return const SizedBox.shrink();
                      return Positioned(
                        left: 0,
                        right: 0,
                        bottom: currentBottom,
                        child: IgnorePointer(
                          ignoring: opacity == 0.0,
                          child: AnimatedOpacity(
                            opacity: opacity,
                            duration: const Duration(milliseconds: 200),
                            child: Center(
                              child: _StartPillButton(onTap: _goOnline),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
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

          // TripRequestSheet: exibe a BottomSheet fixa quando há uma requisição
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: TripRequestService.instance.requestNotifier,
            builder: (context, trip, _) {
              if (trip == null) return const SizedBox.shrink();
              return Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: TripRequestSheet(trip: trip),
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
        shape: const StadiumBorder(
          side: BorderSide(color: Colors.black, width: 2.0),
        ),
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

/// Gaveta unificada — presente em modo Online e Offline.
///
/// 0.12 (mínimo) : header fixo [⚙ | pílula + status | ☰].
/// 0.45 / 1.0    : botão FICAR OFFLINE (vermelho se online, cinza se offline)
///                 + placeholder de métricas.
class _UnifiedDriverSheet extends StatelessWidget {
  const _UnifiedDriverSheet({
    required this.scrollController,
    required this.onlineNotifier,
    required this.onGoOffline,
    required this.onShowPreferences,
  });

  final ScrollController scrollController;
  final ValueNotifier<bool> onlineNotifier;
  final VoidCallback onGoOffline;
  final VoidCallback onShowPreferences;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        color: const Color(0xFF121212),
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: scrollController,
              physics: const ClampingScrollPhysics(),
              child: ValueListenableBuilder<bool>(
                valueListenable: onlineNotifier,
                builder: (context, isOnline, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header fixo: [⚙] | pílula + status | [☰] ────────────────
                    // Os ícones nas pontas são sempre visíveis (online e offline).
                    // O texto central só aparece quando online.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.settings_rounded,
                              color: Colors.white,
                            ),
                            onPressed: onShowPreferences,
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF424242),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              if (isOnline) ...[
                                const SizedBox(height: 10),
                                const Text(
                                  'Você está online',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.menu_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const DriverSettingsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Espaçador dinâmico: empurra o conteúdo para o "subsolo"
                    // da gaveta quando ela estiver totalmente expandida.
                    SizedBox(height: MediaQuery.of(context).size.height * 0.75),

                    // ── Conteúdo expandido (visível a partir de ~0.45) ──────────
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 28, 20, 40 + bottomPad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Espaço de segurança antes do botão
                          const SizedBox(height: 20),

                          // FICAR OFFLINE: vermelho+habilitado (online) ou cinza+desabilitado (offline)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isOnline
                                    ? Colors.red
                                    : const Color(0xFF424242),
                                foregroundColor: Colors.white,
                                disabledForegroundColor: Colors.white
                                    .withValues(alpha: 0.5),
                                disabledBackgroundColor: const Color(
                                  0xFF424242,
                                ),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: const StadiumBorder(),
                              ),
                              onPressed: isOnline
                                  ? () async {
                                      try {
                                        await AudioService.instance
                                            .playOfflineSound();
                                        await Future.delayed(
                                          const Duration(milliseconds: 1200),
                                        );
                                      } catch (_) {}
                                      onGoOffline();
                                    }
                                  : null,
                              child: const Text(
                                'FICAR OFFLINE',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
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
            ),
            // ── Barra de radar (online only) ─────────────────────────────────
            // Colada no topo absoluto da gaveta, height 3 px.
            // ClipRRect pai garante que ela siga a curva das bordas arredondadas.
            ValueListenableBuilder<bool>(
              valueListenable: onlineNotifier,
              builder: (context, isOnline, _) {
                if (!isOnline) return const SizedBox.shrink();
                return Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 3.0,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFF2ECC71),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Fim dos widgets internos ────────────────────────────────────────────────────
