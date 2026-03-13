import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/viper_theme.dart';

/// Tela de boas-vindas e ponto de decisão de fluxo do Viper Ride.
///
/// Exibe a animação do logo por 2 segundos e em seguida decide o destino:
///
///   Sessão ativa (fechar/reabrir app):
///     → /auth_portal → AuthPortal busca user_type → Home direta
///     Texto "Sincronizando perfil..." aparece para feedback ao usuário.
///
///   Sem sessão (primeiro acesso ou após logout):
///     → /login → AuthPortal já sem sessão mostra LoginScreen imediatamente.
///     Nenhum texto de sync é exibido (sem sessão, sem o que sincronizar).
///
/// Não há logout automático aqui. O único ponto de logout é o botão 'Sair'
/// em [ViperDriverHome._confirmLogout].

class ViperSplashScreen extends StatefulWidget {
  const ViperSplashScreen({super.key});

  @override
  State<ViperSplashScreen> createState() => _ViperSplashScreenState();
}

class _ViperSplashScreenState extends State<ViperSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _viperSlide;
  late final Animation<Offset> _rideSlide;
  late final Animation<double> _syncFade;

  // Verificado de forma síncrona: condiciona texto e rota de destino
  late final bool _hasSession;

  @override
  void initState() {
    super.initState();

    // Leitura síncrona: não bloqueia, pois currentSession é cache local
    _hasSession = Supabase.instance.client.auth.currentSession != null;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _viperSlide = Tween<Offset>(begin: const Offset(-1.5, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    _rideSlide = Tween<Offset>(begin: const Offset(1.5, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    // Texto de sync aparece suavemente depois que o logo parou
    _syncFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // 2 segundos: tempo para o logo animar e o Supabase confirmar sessão
    Future.delayed(const Duration(seconds: 2), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    // Sem sessão → vai direto para Login (portal mostra LoginScreen)
    // Com sessão → portal verifica user_type e roteia para Home/Seleção
    // Em ambos os casos o destino é o portal, mas a rota sinaliza a intenção
    final route = _hasSession ? '/auth_portal' : '/login';
    Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViperColors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRect(
              child: SlideTransition(
                position: _viperSlide,
                child: const Text(
                  'Viper',
                  style: TextStyle(
                    color: ViperColors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            ClipRect(
              child: SlideTransition(
                position: _rideSlide,
                child: const Text(
                  'Ride',
                  style: TextStyle(
                    color: ViperColors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),
            // Exibe "Sincronizando" apenas quando há sessão a sincronizar
            if (_hasSession)
              FadeTransition(
                opacity: _syncFade,
                child: const Text(
                  'Sincronizando perfil...',
                  style: TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
