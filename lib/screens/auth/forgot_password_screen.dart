import 'package:flutter/material.dart';
import '../../core/viper_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/viper_input.dart';

class ViperForgotPasswordScreen extends StatefulWidget {
  const ViperForgotPasswordScreen({super.key});

  @override
  State<ViperForgotPasswordScreen> createState() =>
      _ViperForgotPasswordScreenState();
}

class _ViperForgotPasswordScreenState extends State<ViperForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe seu e-mail.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    final error = await ViperAuthService.resetPassword(email: email);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() => _sent = true);
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: _sent
              ? _SentConfirmation(onBack: () => Navigator.of(context).pop())
              : _ResetForm(
                  emailController: _emailController,
                  loading: _loading,
                  onSend: _sendReset,
                ),
        ),
      ),
    );
  }
}

class _ResetForm extends StatelessWidget {
  final TextEditingController emailController;
  final bool loading;
  final VoidCallback onSend;

  const _ResetForm({
    required this.emailController,
    required this.loading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Esqueceu a senha?',
          style: TextStyle(
            color: Color(0xFF111111),
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Informe seu e-mail e enviaremos um link para redefinir sua senha.',
          style: TextStyle(color: Color(0xFF777777), fontSize: 15),
        ),
        const SizedBox(height: 36),
        ViperInput(
          controller: emailController,
          hint: 'E-mail',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(
            Icons.email_outlined,
            color: Color(0xFFAAAAAA),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: loading ? null : onSend,
            style: ElevatedButton.styleFrom(
              backgroundColor: ViperColors.black,
              foregroundColor: ViperColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ViperColors.white,
                    ),
                  )
                : const Text(
                    'Enviar link',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }
}

class _SentConfirmation extends StatelessWidget {
  final VoidCallback onBack;

  const _SentConfirmation({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        const Icon(
          Icons.mark_email_read_outlined,
          size: 64,
          color: Color(0xFF111111),
        ),
        const SizedBox(height: 24),
        const Text(
          'Link enviado!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF111111),
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Verifique sua caixa de entrada e siga as instruções para redefinir sua senha.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF777777), fontSize: 15),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: onBack,
            style: ElevatedButton.styleFrom(
              backgroundColor: ViperColors.black,
              foregroundColor: ViperColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Voltar ao login',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
