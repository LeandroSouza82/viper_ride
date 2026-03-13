import 'package:flutter/material.dart';
import '../../core/viper_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/viper_input.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class ViperLoginScreen extends StatefulWidget {
  const ViperLoginScreen({super.key});

  @override
  State<ViperLoginScreen> createState() => _ViperLoginScreenState();
}

class _ViperLoginScreenState extends State<ViperLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showError('Preencha todos os campos.');
      return;
    }
    setState(() => _loading = true);
    final error = await ViperAuthService.signIn(
      email: email,
      password: password,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      _showError(error);
      return;
    }
    // O onAuthStateChange no AuthPortal detecta a nova sessão automaticamente.
    // Nenhuma navegação manual necessária aqui.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViperColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Bem-vindo de volta',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Entre na sua conta para continuar.',
                style: TextStyle(color: Color(0xFF777777), fontSize: 15),
              ),
              const SizedBox(height: 40),
              ViperInput(
                controller: _emailController,
                hint: 'E-mail',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: Color(0xFFAAAAAA),
                ),
              ),
              const SizedBox(height: 14),
              ViperInput(
                controller: _passwordController,
                hint: 'Senha',
                obscure: true,
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFFAAAAAA),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ViperForgotPasswordScreen(),
                    ),
                  ),
                  child: const Text(
                    'Esqueci a senha',
                    style: TextStyle(color: Color(0xFF555555), fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signIn,
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
                          'Entrar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Não tem uma conta?  ',
                    style: TextStyle(color: Color(0xFF777777), fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ViperRegisterScreen(),
                      ),
                    ),
                    child: const Text(
                      'Criar conta',
                      style: TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
