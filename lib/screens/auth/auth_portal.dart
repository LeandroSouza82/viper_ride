import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/viper_theme.dart';
import '../../services/auth_service.dart';
import '../driver/driver_home.dart';
import '../passenger/passenger_home.dart';
import 'login_screen.dart';
import 'selection_screen.dart';

/// Roteador declarativo da sessão do Viper Ride.
///
/// Responsabilidades:
///   • Ouvir [onAuthStateChange] e reagir a signedIn/signedOut/initialSession.
///   • Buscar [user_type] no Supabase após login para rotear corretamente.
///   • Retornar o widget de destino diretamente no [build] — sem Navigator.
///
/// Cache de instâncias ([_driverHome], [_passengerHome]):
///   O [MapboxMap] usa um canvas OpenGL nativo. Sempre que seu widget é
///   removido da árvore e recriado, o Android tenta bloquear um novo
///   HardwareCanvas antes do anterior ser liberado, lançando o erro
///   lockHardwareCanvas. Ao cachear as instâncias com [??=], o mapa
///   NUNCA é reconstruído enquanto o usuário está logado.
///
/// Evento tokenRefreshed:
///   Atualiza [_session] sem [setState] — evita rebuilds desnecessários
///   que destruiriam o canvas do mapa.
///
/// Fluxo de logout:
///   O [ViperDriverHome._confirmLogout] captura o navigator, navega para
///   /splash e SÓ ENTÃO chama [ViperAuthService.signOut]. Quando o evento
///   'signedOut' chega aqui, o portal já está fora da árvore e o setState
///   é ignorado pelo guard [if (!mounted)].
class ViperAuthPortal extends StatefulWidget {
  const ViperAuthPortal({super.key});

  @override
  State<ViperAuthPortal> createState() => _ViperAuthPortalState();
}

class _ViperAuthPortalState extends State<ViperAuthPortal> {
  late final StreamSubscription<AuthState> _authSub;

  Session? _session;
  String? _userType;
  bool _initialized = false;
  bool _fetchingUserType = false;

  // Instâncias cacheadas: evita destruição/recriação do MapboxMap a cada rebuild
  Widget? _driverHome;
  Widget? _passengerHome;
  @override
  void initState() {
    super.initState();
    _session = Supabase.instance.client.auth.currentSession;

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;

      if (data.event == AuthChangeEvent.signedOut) {
        // Logout detectado: limpa estado e instâncias cacheadas
        // Garantia: próximo login sempre cria nova instância de DriverHome/PassengerHome
        setState(() {
          _session = null;
          _userType = null;
          _initialized = true;
          _driverHome = null;
          _passengerHome = null;
        });
      } else if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.initialSession) {
        // Novo login: busca user_type para rotear corretamente
        setState(() {
          _session = data.session;
          _initialized = false;
        });
        _fetchUserType();
      } else if (data.session != null) {
        // tokenRefreshed e demais eventos: atualiza sessão SEM rebuild
        // Impede que o MapboxMap seja destruído/recriado desnecessariamente
        _session = data.session;
      }
    });

    if (_session != null) {
      _fetchUserType();
    } else {
      _initialized = true; // sem sessão, nada a buscar
    }
  }

  Future<void> _fetchUserType() async {
    if (_fetchingUserType) return;
    _fetchingUserType = true;
    if (mounted) setState(() => _initialized = false);

    final type = await ViperAuthService.getUserType();

    if (!mounted) return;
    _fetchingUserType = false;
    setState(() {
      _userType = type;
      _initialized = true;
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const _ViperLoadingScaffold();
    }

    if (_session == null) {
      return const ViperLoginScreen();
    }

    if (_userType == null) {
      return ViperUserTypeSelectionScreen(onTypeSelected: _fetchUserType);
    }

    if (_userType == 'driver') {
      _driverHome ??= const ViperDriverHome();
      return _driverHome!;
    }

    _passengerHome ??= const ViperPassengerHome();
    return _passengerHome!;
  }
}

class _ViperLoadingScaffold extends StatelessWidget {
  const _ViperLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: ViperColors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: ViperColors.white, strokeWidth: 2),
            SizedBox(height: 24),
            Text(
              'Sincronizando perfil...',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
