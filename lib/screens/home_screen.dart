import 'package:flutter/material.dart';
import '../services/viper_foreground_service.dart';
import '../services/viper_wakelock_service.dart';
import '../widgets/map_display.dart';
import '../widgets/search_sheet.dart';

class ViperHomeScreen extends StatefulWidget {
  const ViperHomeScreen({super.key});

  @override
  State<ViperHomeScreen> createState() => _ViperHomeScreenState();
}

class _ViperHomeScreenState extends State<ViperHomeScreen> {
  @override
  void initState() {
    super.initState();
    ViperForegroundService.start();
    ViperWakelockService.enable();
  }

  @override
  void dispose() {
    ViperForegroundService.stop();
    ViperWakelockService.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: ViperMapDisplay()),
          ViperSearchSheet(),
        ],
      ),
    );
  }
}
