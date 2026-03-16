import 'package:flutter/material.dart';
import 'navigation_settings.dart';

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
          _buildMenuItem(Icons.person, 'Gerenciar conta da Viper'),
          _buildMenuItem(Icons.lock, 'Privacidade'),
          _buildMenuItem(Icons.edit, 'Edite o endereço'),

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
          _buildMenuItem(Icons.accessibility_new, 'Acessibilidade'),
          _buildMenuItem(Icons.forum, 'Comunicação'),
          _buildMenuItem(
            Icons.navigation,
            'Navegação',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NavigationSettingsScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(Icons.volume_up, 'Sons e voz'),
          _buildMenuItem(
            Icons.language,
            'Idioma do app',
            subtitle: 'português (Brasil)',
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: Colors.black, size: 28),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: Colors.black54))
          : null,
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.black38,
        size: 28,
      ),
      onTap: onTap,
    );
  }
}
