import 'package:flutter/material.dart';

class NavigationSettingsScreen extends StatefulWidget {
  const NavigationSettingsScreen({super.key});

  @override
  State<NavigationSettingsScreen> createState() =>
      _NavigationSettingsScreenState();
}

class _NavigationSettingsScreenState extends State<NavigationSettingsScreen> {
  String _selectedNav = 'Google Maps';

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
          'Navegação',
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              'App de navegação principal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
          _buildNavOption('Navegação no App (Viper)', Icons.map),
          _buildNavOption('Google Maps', Icons.pin_drop),
          _buildNavOption('Waze', Icons.navigation),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Text(
              'O app selecionado será aberto automaticamente quando você iniciar uma viagem.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavOption(String title, IconData icon) {
    final bool isSelected = _selectedNav == title;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Icon(icon, color: Colors.black, size: 28),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.blue, size: 28)
          : null,
      onTap: () {
        setState(() {
          _selectedNav = title;
        });
      },
    );
  }
}
