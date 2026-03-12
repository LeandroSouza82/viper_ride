import 'package:flutter/material.dart';
import '../../core/viper_theme.dart';
import '../../services/auth_service.dart';

class ViperDriverHome extends StatelessWidget {
  const ViperDriverHome({super.key});

  Future<void> _signOut(BuildContext context) async {
    await ViperAuthService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViperColors.white,
      appBar: AppBar(
        backgroundColor: ViperColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Viper · Motorista',
          style: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF111111)),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: const SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_car, size: 72, color: Color(0xFF111111)),
              SizedBox(height: 20),
              Text(
                'Pronto para rodar?',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Toque em "Ficar Online" para receber corridas.',
                style: TextStyle(color: Color(0xFF777777), fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(28, 0, 28, 32),
        child: _GoOnlineButton(),
      ),
    );
  }
}

class _GoOnlineButton extends StatefulWidget {
  const _GoOnlineButton();

  @override
  State<_GoOnlineButton> createState() => _GoOnlineButtonState();
}

class _GoOnlineButtonState extends State<_GoOnlineButton> {
  bool _online = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: () => setState(() => _online = !_online),
        style: ElevatedButton.styleFrom(
          backgroundColor: _online
              ? const Color(0xFF2ECC71)
              : ViperColors.black,
          foregroundColor: ViperColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: Text(
          _online ? 'Online — Aguardando corrida' : 'Ficar Online',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
