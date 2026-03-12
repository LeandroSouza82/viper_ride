import 'package:flutter/material.dart';
import '../../core/viper_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/viper_input.dart';
import '../../widgets/driver_form.dart';

class ViperRegisterScreen extends StatefulWidget {
  const ViperRegisterScreen({super.key});

  @override
  State<ViperRegisterScreen> createState() => _ViperRegisterScreenState();
}

class _ViperRegisterScreenState extends State<ViperRegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cnhController = TextEditingController();
  final _placaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _corController = TextEditingController();
  String _userType = 'rider';
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _cnhController.dispose();
    _placaController.dispose();
    _modeloController.dispose();
    _corController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('Preencha todos os campos obrigatórios.');
      return;
    }
    if (_userType == 'driver') {
      if (_cnhController.text.trim().isEmpty ||
          _placaController.text.trim().isEmpty ||
          _modeloController.text.trim().isEmpty ||
          _corController.text.trim().isEmpty) {
        _showError('Preencha todos os dados do veículo.');
        return;
      }
    }
    setState(() => _loading = true);
    final error = await ViperAuthService.signUp(
      email: email,
      password: password,
      fullName: name,
      userType: _userType,
      phone: phone.isEmpty ? null : phone,
      cnh: _userType == 'driver' ? _cnhController.text.trim() : null,
      placa: _userType == 'driver' ? _placaController.text.trim() : null,
      carModel: _userType == 'driver' ? _modeloController.text.trim() : null,
      carColor: _userType == 'driver' ? _corController.text.trim() : null,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      _showError(error);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViperColors.white,
      appBar: AppBar(
        backgroundColor: ViperColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111111)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Criar conta',
          style: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ViperInput(
                controller: _nameController,
                hint: 'Nome completo',
                prefixIcon: const Icon(
                  Icons.person_outline,
                  color: Color(0xFFAAAAAA),
                ),
              ),
              const SizedBox(height: 12),
              ViperInput(
                controller: _phoneController,
                hint: 'Telefone (WhatsApp)',
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(
                  Icons.phone_outlined,
                  color: Color(0xFFAAAAAA),
                ),
              ),
              const SizedBox(height: 12),
              ViperInput(
                controller: _emailController,
                hint: 'E-mail',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: Color(0xFFAAAAAA),
                ),
              ),
              const SizedBox(height: 12),
              ViperInput(
                controller: _passwordController,
                hint: 'Senha',
                obscure: true,
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFFAAAAAA),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Você é:',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              _UserTypeSelector(
                selected: _userType,
                onChanged: (t) => setState(() => _userType = t),
              ),
              if (_userType == 'driver') ...[
                const SizedBox(height: 28),
                const Text(
                  'Dados do veículo',
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                ViperDriverForm(
                  cnhController: _cnhController,
                  placaController: _placaController,
                  modeloController: _modeloController,
                  corController: _corController,
                ),
              ],
              const SizedBox(height: 36),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ViperColors.black,
                    foregroundColor: ViperColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ViperColors.white,
                          ),
                        )
                      : const Text(
                          'Criar conta',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserTypeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _UserTypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TypeChip(
          label: 'Passageiro',
          icon: Icons.person_outline,
          active: selected == 'rider',
          onTap: () => onChanged('rider'),
        ),
        const SizedBox(width: 10),
        _TypeChip(
          label: 'Motorista',
          icon: Icons.directions_car_outlined,
          active: selected == 'driver',
          onTap: () => onChanged('driver'),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? ViperColors.black : ViperColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? ViperColors.black : const Color(0xFFE0E0E0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? ViperColors.white : const Color(0xFF777777),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? ViperColors.white : const Color(0xFF777777),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
