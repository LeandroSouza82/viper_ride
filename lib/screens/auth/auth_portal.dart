import 'package:flutter/material.dart';
import '../../core/viper_theme.dart';
import '../../services/auth_service.dart';
import '../driver/driver_home.dart';
import '../passenger/passenger_home.dart';

class ViperAuthPortal extends StatefulWidget {
  const ViperAuthPortal({super.key});

  @override
  State<ViperAuthPortal> createState() => _ViperAuthPortalState();
}

class _ViperAuthPortalState extends State<ViperAuthPortal> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final userType = await ViperAuthService.getUserType();
    if (!mounted) return;
    final destination = userType == 'driver'
        ? const ViperDriverHome()
        : const ViperPassengerHome();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: ViperColors.white,
      body: Center(
        child: CircularProgressIndicator(
          color: ViperColors.black,
          strokeWidth: 2,
        ),
      ),
    );
  }
}
