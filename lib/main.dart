import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/viper_theme.dart';
import 'screens/auth/auth_portal.dart';
import 'screens/splash/splash_screen.dart';
import 'services/map_engine.dart';
import 'services/viper_foreground_service.dart';

/// Ponto de entrada do Viper Ride.
///
/// Fluxos de navegação garantidos:
///   • Logout manual   : Botão Sair → /splash → /login  (reset total)
///   • Fechar/reabrir  : Ícone do app → /splash → /auth_portal → Home direta
///
/// Rotas raiz:
///   /splash      → ViperSplashScreen (verifica sessão, define destino)
///   /login       → ViperAuthPortal   (sem sessão: mostra LoginScreen)
///   /auth_portal → ViperAuthPortal   (com sessão: busca user_type → roteia)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 0. Hardware ─────────────────────────────────────────────────────
  // Trava orientação em retrato antes de qualquer frame ser pintado.
  // Reforço ao android:screenOrientation="portrait" no AndroidManifest.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // ── 1. Carregar .env ──────────────────────────────────────────────────────
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('[ViperRide] ERRO ao carregar .env: $e');
  }

  // ── 2. Validar chaves ─────────────────────────────────────────────────────
  final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim() ?? '';
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    if (supabaseUrl.isEmpty) {
      debugPrint('[ViperRide] FALTANDO: SUPABASE_URL não encontrada no .env');
    }
    if (supabaseKey.isEmpty) {
      debugPrint(
        '[ViperRide] FALTANDO: SUPABASE_ANON_KEY não encontrada no .env',
      );
    }
    debugPrint('[ViperRide] Supabase não será inicializado. Verifique o .env.');
    runApp(const ViperApp());
    return;
  }

  // ── 3. Serviços de plataforma ─────────────────────────────────────────────
  ViperMapEngine.init();
  ViperForegroundService.init();

  // ── 4. Inicializar Supabase ───────────────────────────────────────────────
  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  } catch (e) {
    debugPrint('[ViperRide] Falha ao inicializar Supabase: $e');
  }

  runApp(const ViperApp());
}

class ViperApp extends StatelessWidget {
  const ViperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Viper Ride',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: ViperColors.black,
        colorScheme: const ColorScheme.dark(
          surface: ViperColors.black,
          onSurface: ViperColors.white,
        ),
      ),
      home: const ViperSplashScreen(),
      routes: {
        '/splash': (_) => const ViperSplashScreen(),
        // '/login' → ViperAuthPortal sem sessão mostra LoginScreen diretamente.
        // Rota nomeada separada para clareza do fluxo: Splash → /login → /auth_portal
        '/login': (_) => const ViperAuthPortal(),
        '/auth_portal': (_) => const ViperAuthPortal(),
      },
    );
  }
}
