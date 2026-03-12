import 'package:flutter/material.dart';
import '../../core/viper_theme.dart';
import '../../services/auth_service.dart';

class ViperPassengerHome extends StatelessWidget {
  const ViperPassengerHome({super.key});

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
          'Viper Ride',
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Container(
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 16),
                    Icon(Icons.search, color: Color(0xFF777777)),
                    SizedBox(width: 12),
                    Text(
                      'Para onde você vai?',
                      style: TextStyle(color: Color(0xFF777777), fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Recentes',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _RecentItem(
                icon: Icons.home_outlined,
                label: 'Casa',
                sublabel: 'Adicionar endereço',
                onTap: () {},
              ),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              _RecentItem(
                icon: Icons.work_outline,
                label: 'Trabalho',
                sublabel: 'Adicionar endereço',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  const _RecentItem({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F0F0),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF111111), size: 20),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
