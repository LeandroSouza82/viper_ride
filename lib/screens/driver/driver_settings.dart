import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../driver/navigation_settings.dart';
import '../../widgets/v_settings_tile.dart';
import 'profile/account_management_screen.dart';

class DriverSettingsScreen extends StatelessWidget {
  const DriverSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Configurações',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          // SEÇÃO: CONTA
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              'Conta',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          VSettingsTile(
            icon: Icons.person_outline,
            title: 'Gerenciar conta da Viper',
            onTap: () => Get.to(() => const AccountManagementScreen()),
          ),
          VSettingsTile(icon: Icons.lock, title: 'Privacidade', onTap: () {}),
          VSettingsTile(
            icon: Icons.edit,
            title: 'Edite o endereço',
            onTap: () {},
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Colors.black12, thickness: 1),
          ),

          // SEÇÃO: GERAL
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              'Geral',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          VSettingsTile(
            icon: Icons.accessibility_new,
            title: 'Acessibilidade',
            onTap: () {},
          ),
          VSettingsTile(icon: Icons.forum, title: 'Comunicação', onTap: () {}),
          VSettingsTile(
            icon: Icons.navigation,
            title: 'Navegação',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NavigationSettingsScreen(),
                ),
              );
            },
          ),
          VSettingsTile(
            icon: Icons.volume_up,
            title: 'Sons e voz',
            onTap: () {},
          ),
          VSettingsTile(
            icon: Icons.language,
            title: 'Idioma do app',
            subtitle: 'português (Brasil)',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // Menu items moved to modular widget VSettingsTile
}
