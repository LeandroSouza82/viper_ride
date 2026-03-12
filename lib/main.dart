import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/viper_theme.dart';
import 'screens/auth/auth_portal.dart';
import 'screens/auth/login_screen.dart';
import 'services/map_engine.dart';
import 'services/viper_foreground_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  ViperMapEngine.init();
  ViperForegroundService.init();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
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
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = snapshot.hasData
              ? snapshot.data!.session
              : Supabase.instance.client.auth.currentSession;
          if (session != null) return const ViperAuthPortal();
          return const ViperLoginScreen();
        },
      ),
    );
  }
}
