import 'package:flutter/material.dart';
import '../core/viper_theme.dart';
import '../screens/search_screen.dart';

class ViperSearchSheet extends StatelessWidget {
  const ViperSearchSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.30,
      minChildSize: 0.14,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.14, 0.30, 0.85],
      builder: (BuildContext ctx, ScrollController scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: ViperColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
            boxShadow: [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 32,
                spreadRadius: 0,
                offset: Offset(0, -8),
              ),
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 8,
                spreadRadius: 0,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ViperSheetHandle(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  children: [
                    const _ViperGreeting(),
                    const SizedBox(height: 16),
                    _ViperSearchField(
                      onTap: () => Navigator.of(ctx).push(
                        MaterialPageRoute(
                          builder: (_) => const ViperSearchScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _ViperSavedPlacesSection(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ViperSheetHandle extends StatelessWidget {
  const _ViperSheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 14),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _ViperGreeting extends StatelessWidget {
  const _ViperGreeting();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Para onde, Piloto?',
      style: TextStyle(
        color: ViperColors.black,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    );
  }
}

class _ViperSearchField extends StatelessWidget {
  final VoidCallback onTap;

  const _ViperSearchField({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F6F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: ViperColors.black, size: 20),
            const SizedBox(width: 12),
            const Text(
              'Para onde?',
              style: TextStyle(
                color: Color(0xFF757575),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViperSavedPlacesSection extends StatelessWidget {
  const _ViperSavedPlacesSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LOCAIS SALVOS',
          style: TextStyle(
            color: Color(0xFF9E9E9E),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        const _ViperSavedPlaceItem(
          label: 'Casa',
          sublabel: 'Rua das Acácias, 123',
          icon: Icons.home_outlined,
        ),
        Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
        const _ViperSavedPlaceItem(
          label: 'Trabalho',
          sublabel: 'Av. Paulista, 1000',
          icon: Icons.work_outline,
        ),
      ],
    );
  }
}

class _ViperSavedPlaceItem extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;

  const _ViperSavedPlaceItem({
    required this.label,
    required this.sublabel,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F0F0),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: ViperColors.black, size: 18),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: ViperColors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: const TextStyle(
                    color: Color(0xFF9E9E9E),
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
