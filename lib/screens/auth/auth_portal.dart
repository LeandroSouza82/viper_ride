import 'package:flutter/material.dart';
import '../driver/driver_home.dart';

/// Portal de autenticação simplificado: forçamos o modo motorista.
class ViperAuthPortal extends StatelessWidget {
  const ViperAuthPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return const ViperDriverHome();
  }
}
