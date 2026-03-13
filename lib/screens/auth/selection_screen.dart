import 'package:flutter/material.dart';
import '../../core/viper_theme.dart';
import '../../services/auth_service.dart';

class ViperUserTypeSelectionScreen extends StatefulWidget {
  const ViperUserTypeSelectionScreen({super.key, required this.onTypeSelected});

  /// Chamado pelo AuthPortal para rebuscar o user_type após salvar.
  final VoidCallback onTypeSelected;

  @override
  State<ViperUserTypeSelectionScreen> createState() =>
      _ViperUserTypeSelectionScreenState();
}

class _ViperUserTypeSelectionScreenState
    extends State<ViperUserTypeSelectionScreen> {
  bool _loading = false;

  Future<void> _select(String userType) async {
    if (_loading) return;
    setState(() => _loading = true);

    final error = await ViperAuthService.setUserType(userType);

    if (!mounted) return;

    if (error != null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Notifica o AuthPortal para rebuscar user_type e atualizar a rota
    widget.onTypeSelected();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViperColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Text(
                'Como você quer\nusa o Viper?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ViperColors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 56),
              _BigButton(
                label: 'TRABALHAR COMO\nMOTORISTA',
                icon: Icons.directions_car,
                enabled: !_loading,
                onTap: () => _select('driver'),
              ),
              const SizedBox(height: 20),
              _BigButton(
                label: 'USAR APP COMO\nPASSAGEIRO',
                icon: Icons.person,
                enabled: !_loading,
                onTap: () => _select('rider'),
              ),
              const Spacer(),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(
                    color: ViperColors.white,
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        decoration: BoxDecoration(
          color: ViperColors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: ViperColors.black, size: 32),
            const SizedBox(width: 20),
            Text(
              label,
              style: const TextStyle(
                color: ViperColors.black,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
