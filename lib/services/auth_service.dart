import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:viper_ride/screens/onboarding/otp_verification_screen.dart';
import 'package:viper_ride/screens/driver/driver_home.dart';
import 'package:shared_preferences/shared_preferences.dart';
// flutter services not required here; keyboard closed via FocusManager

/// Serviço de autenticação do Viper Ride.
///
/// Encapsula toda a lógica de auth com Supabase: cadastro, login, logout,
/// reset de senha e persistência do [user_type] na tabela [profiles].
///
/// Regras de navegação (executadas pelo chamador, não por este serviço):
///   • [signIn]  → roteamento via stream onAuthStateChange (AuthPortal)
///   • [signOut] → chamador navega para /splash ANTES de invocar este método
class ViperAuthService {
  ViperAuthService._();

  static final _client = Supabase.instance.client;
  // Intenção temporária de role escolhida antes do usuário autenticar.
  // Ex: 'driver' quando o usuário escolhe "Quero dirigir" antes do login.
  static String? pendingUserType;

  /// Aplica a `pendingUserType` (se existir) ao perfil do usuário autenticado
  /// e limpa a intenção pendente. Retorna null em sucesso ou mensagem de erro.
  static Future<String?> applyPendingUserType() async {
    final pending = pendingUserType;
    if (pending == null) return null;
    final userId = _client.auth.currentUser?.id;
    // Não bloqueamos a navegação se o usuário não estiver autenticado.
    // Permitimos a verificação do código e a navegação para Home; quaisquer
    // updates no Supabase serão tentados em background quando houver sessão.
    try {
      await _client.from('profiles').upsert({
        'id': userId,
        'user_type': pending,
      });
      pendingUserType = null;
      return null;
    } catch (e) {
      debugPrint('[ViperRide] Erro ao aplicar pendingUserType: $e');
      return 'Erro ao atualizar perfil.';
    }
  }

  /// Gera um código OTP de 6 dígitos, salva em `otp_codes` com expiry
  /// e retorna o código gerado. Simula envio via WhatsApp (modo econômico)
  /// com um log — o chamador pode exibir um SnackBar.
  static Future<void> gerarEEnviarOTP(String telefone) async {
    try {
      debugPrint('--- INÍCIO DO PROCESSO OTP ---');

      // Fecha teclado primeiro (prioridade absoluta)
      try {
        FocusManager.instance.primaryFocus?.unfocus();
      } catch (_) {}

      // 1. Limpeza básica
      final telLimpo = telefone.replaceAll(RegExp(r'[^0-9]'), '');
      debugPrint('1. Telefone limpo: $telLimpo');

      // 2. Gerar código aleatório de 6 dígitos
      final codigoReal = (Random().nextInt(900000) + 100000).toString().padLeft(
        6,
        '0',
      );
      debugPrint('2. Código gerado: $codigoReal');

      // 2. Salvar no Supabase (processamento silencioso)
      debugPrint('2. Chamando Supabase...');
      try {
        // garante prefixo do país (55) para o número usado no DB e no link
        final telComPais = telLimpo.startsWith('55') ? telLimpo : '55$telLimpo';

        // Inserção direta no banco (sem overlay)
        final insertResult = await _client.from('otp_codes').insert({
          'phone': telComPais,
          'code': codigoReal,
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 5))
              .toIso8601String(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }).select();

        debugPrint('4. Resposta do banco recebida! $insertResult');

        // 4. Monta mensagem formatada (código em negrito com asteriscos)
        final mensagemFormatada =
            "Olá! Bem-vindo à Viper Ride 🏎️💨\n\n"
            "Estamos muito felizes em ter você como parceiro. Para concluir seu cadastro e liberar seu acesso, utilize o código abaixo:\n\n"
            "*$codigoReal*\n\n"
            "Copie esse código e cole no aplicativo para continuar.\n"
            "Este código expira em 5 minutos.";

        // Garante que `telefoneLimpo` não tenha prefixo '55' duplicado (para o link e para passar à tela apenas os dígitos locais)
        final telefoneLimpo = telLimpo.startsWith('55')
            ? telLimpo.substring(2)
            : telLimpo;

        // Codificação obrigatória do payload para WhatsApp (mantém os asteriscos intactos no texto codificado)
        final encodedMessage = Uri.encodeComponent(mensagemFormatada);

        // Montagem segura do link conforme especificado
        final url = "https://wa.me/55$telefoneLimpo?text=$encodedMessage";

        // Navega para a tela de OTP (fire-and-forget) — prioridade de navegação
        try {
          Get.toNamed('/otp-verification', arguments: telefoneLimpo);
        } catch (_) {
          try {
            Get.to(() => OtpVerificationScreen(phoneNumber: telefoneLimpo));
          } catch (_) {}
        }

        // Pequeno delay de segurança para garantir que a transição comece
        await Future.delayed(const Duration(milliseconds: 300));

        // Log de verificação para testes manuais
        debugPrint('LINK GERADO: $url');

        // Dispara o WhatsApp somente após a espera de segurança
        final uri = Uri.parse(url);
        launchUrl(uri, mode: LaunchMode.externalApplication)
            .then((opened) {
              if (opened == false) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  try {
                    Get.snackbar(
                      'Erro ao abrir WhatsApp',
                      'launchUrl retornou false',
                      backgroundColor: Colors.red,
                    );
                  } catch (_) {}
                });
              }
            })
            .catchError((e) {
              Future.delayed(const Duration(milliseconds: 500), () {
                try {
                  Get.snackbar(
                    'Erro ao abrir WhatsApp',
                    e.toString(),
                    backgroundColor: Colors.red,
                  );
                } catch (_) {}
              });
              debugPrint('Erro ao abrir link do WhatsApp: $e');
            });
      } catch (e) {
        debugPrint('Erro ao inserir OTP: $e');
        rethrow;
      }
    } catch (e, stack) {
      debugPrint('❌ ERRO CAPTURADO: $e');
      debugPrint('📚 STACKTRACE: $stack');
      try {
        Future.delayed(const Duration(milliseconds: 500), () {
          try {
            Get.snackbar(
              'Erro Crítico',
              e.toString(),
              backgroundColor: Colors.red,
            );
          } catch (_) {}
        });
      } catch (_) {}
    }
  }

  /// Verifica o código OTP armazenado em `otp_codes`. Retorna null se
  /// sucesso; caso contrário, retorna mensagem de erro.
  static Future<String?> verifyOtp(
    String telefone,
    String code, {
    bool approveForTests = false,
  }) async {
    try {
      // Master Code — GOD MODE: navegação imediata e única ação, sem DB
      if (code == '999888') {
        debugPrint('Código OK (Master Code) — God Mode (navegação imediata)');
        try {
          Get.offAll(() => const ViperDriverHome());
        } catch (e) {
          debugPrint('Falha ao navegar para ViperDriverHome (Master Code): $e');
        }
        return null;
      }

      // Para fluxos normais, não bloqueamos a navegação por falta de sessão.
      // Guardamos o userId se existir, mas continuamos mesmo sem sessão.
      final userId = _client.auth.currentUser?.id;

      // Normaliza telefone da mesma forma antes da busca (guarda com prefixo 55)
      String cleanedPhone = telefone.replaceAll(RegExp(r'[^0-9]'), '');
      if (!cleanedPhone.startsWith('55')) cleanedPhone = '55$cleanedPhone';

      // Busca o último código gerado para esse telefone
      final row = await _client
          .from('otp_codes')
          .select('id,code,expires_at,created_at')
          .eq('phone', cleanedPhone)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return 'Código inválido.';

      final rowMap = row as Map;
      final dbCode = rowMap['code'] as String?;
      final expiresAtStr = rowMap['expires_at'] as String?;
      if (dbCode == null || expiresAtStr == null) return 'Código inválido.';

      if (dbCode != code) return 'Código inválido.';

      final expiresAt = DateTime.parse(expiresAtStr).toUtc();
      if (DateTime.now().toUtc().isAfter(expiresAt)) {
        // Remover código expirado (fire-and-forget)
        try {
          _client
              .from('otp_codes')
              .delete()
              .eq('id', rowMap['id'])
              .then((r) {
                debugPrint('Código expirado removido: $r');
              })
              .catchError((e) {
                debugPrint('Erro ao remover código expirado (async): $e');
              });
        } catch (e) {
          debugPrint('Erro dispatch delete expired OTP: $e');
        }
        return 'Código expirado.';
      }

      // Código válido — faz operações no BD sem bloquear a navegação
      debugPrint('Código OK');

      // Marcar dispositivo como autorizado localmente (auto-login)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('viper_authorized', true);
        debugPrint('SharedPref: viper_authorized=true');
      } catch (e) {
        debugPrint('Falha ao gravar SharedPreferences: $e');
      }

      // Apaga código para não poder ser reutilizado (async)
      try {
        _client
            .from('otp_codes')
            .delete()
            .eq('id', rowMap['id'])
            .then((r) {
              debugPrint('OTP removido: $r');
            })
            .catchError((e) {
              debugPrint('Erro ao remover OTP (async): $e');
            });
      } catch (e) {
        debugPrint('Erro dispatch delete OTP: $e');
      }

      // Busca perfil associado ao telefone para debug e decisão de rota
      try {
        final perfilRaw = await _client
            .from('profiles')
            .select('user_type,status,is_active')
            .eq('phone', cleanedPhone)
            .maybeSingle();

        String status = 'pending';
        bool isActive = false;
        String? tipoDoBanco;

        if (perfilRaw is Map<String, dynamic>) {
          tipoDoBanco = perfilRaw['user_type']?.toString();
          status = (perfilRaw['status'] ?? 'pending').toString();
          final rawActive = perfilRaw['is_active'];
          isActive = rawActive == true;
        }

        debugPrint(
          'DEBUG: Tipo de usuário no banco: $tipoDoBanco, status: $status, is_active: $isActive',
        );

        // Se o status do perfil está aprovado, navega para Driver Home.
        if (status == 'approved') {
          debugPrint('Perfil aprovado — navegando para ViperDriverHome');
          try {
            Get.offAll(() => const ViperDriverHome());
          } catch (e) {
            debugPrint('Falha ao navegar para ViperDriverHome: $e');
          }
          return null;
        }
      } catch (e) {
        debugPrint('DEBUG: Falha ao buscar perfil por telefone: $e');
      }

      // Atualiza status do perfil (async, não await). Se falhar por falta de
      // autenticação, capturamos o erro e seguimos — não bloqueamos a navegação.
      final newStatus = approveForTests ? 'approved' : 'pending';
      debugPrint('Tentando atualizar banco (status=$newStatus)');
      try {
        if (userId != null) {
          _client
              .from('profiles')
              .update({'status': newStatus})
              .eq('id', userId)
              .then((r) {
                debugPrint('Perfil atualizado (async): $r');
              })
              .catchError((e) {
                debugPrint('Erro ao atualizar perfil (async): $e');
              });
        } else {
          debugPrint(
            'Sem sessão: pulando update por id (não bloqueia navegação)',
          );
        }
      } catch (e) {
        debugPrint('Erro dispatch update profile: $e');
      }

      // Se não for aprovado, o fluxo padrão pode seguir (aqui forçamos Driver
      // apenas no Master Code; para códigos reais não aprovados, não forçamos)
      debugPrint(
        'Código válido, mas perfil não aprovado — não forçando Driver.',
      );

      return null;
    } catch (e) {
      debugPrint('[ViperRide] Erro verifyOtp: $e');
      return 'Erro ao verificar código.';
    }
  }

  /// Aplica o Master Code (fluxo de testes) — atualiza status para 'approved'.
  /// Retorna true em sucesso, false caso contrário.
  static Future<bool> applyMasterCodeApprove() async {
    debugPrint('Master Code usado!');
    // Não depender de sessão para navegar — Master Code deve funcionar mesmo
    // sem um usuário autenticado. Tentamos atualizar o perfil se houver sessão,
    // mas não bloqueamos a navegação.
    final userId = _client.auth.currentUser?.id;

    // Marcar dispositivo como autorizado localmente (auto-login)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('viper_authorized', true);
      debugPrint('SharedPref: viper_authorized=true (Master Code)');
    } catch (e) {
      debugPrint('Falha ao gravar SharedPreferences (Master Code): $e');
    }

    // Navegação imediata forte para Driver Home (bypass total)
    try {
      Get.offAll(() => const ViperDriverHome());
      debugPrint('Master Code: navegando diretamente para ViperDriverHome');
    } catch (e) {
      debugPrint('Falha ao navegar para ViperDriverHome no Master Code: $e');
    }

    if (userId != null) {
      try {
        _client
            .from('profiles')
            .update({'status': 'approved'})
            .eq('id', userId)
            .then((r) {
              debugPrint('Perfil atualizado para approved (async): $r');
            })
            .catchError((e) {
              debugPrint('Erro ao aplicar master code no perfil (async): $e');
            });
      } catch (e) {
        debugPrint('Erro dispatch applyMasterCodeApprove update: $e');
      }
    }

    return true;
  }

  /// Faz login com e-mail/senha. Retorna mensagem de erro ou null em sucesso.
  static Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return null;
    } catch (e) {
      debugPrint('[ViperRide] signIn error: $e');
      return _translate(e.toString());
    }
  }

  /// Cria usuário e upserta profile.
  static Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String userType,
    String? phone,
    String? cnh,
    String? placa,
    String? carModel,
    String? carColor,
  }) async {
    try {
      final res = await _client.auth.signUp(email: email, password: password);
      final id = res.user?.id;
      if (id == null) return 'Falha ao criar usuário.';

      await _client.from('profiles').insert({
        'id': id,
        'full_name': fullName,
        'user_type': userType,
        'phone': phone,
        'cnh': cnh,
        'placa': placa,
        'car_model': carModel,
        'car_color': carColor,
      });
      return null;
    } catch (e) {
      debugPrint('[ViperRide] signUp error: $e');
      return _translate(e.toString());
    }
  }

  /// Envia link de recuperação de senha. Retorna erro ou null.
  static Future<String?> resetPassword({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return null;
    } catch (e) {
      debugPrint('[ViperRide] resetPassword error: $e');
      return _translate(e.toString());
    }
  }

  /// Desloga o usuário.
  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('viper_authorized');
        debugPrint('SharedPref: viper_authorized removed on signOut');
      } catch (e) {
        debugPrint('Falha ao remover SharedPreferences no signOut: $e');
      }
    } catch (e) {
      debugPrint('[ViperRide] signOut error: $e');
    }
  }

  /// Busca o user_type do perfil do usuário atual.
  static Future<String?> getUserType() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;
      final data = await _client
          .from('profiles')
          .select('user_type')
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return null;
      return (data as Map)['user_type'] as String?;
    } catch (e) {
      debugPrint('[ViperRide] getUserType error: $e');
      return null;
    }
  }

  /// Atualiza user_type do perfil atual. Retorna erro ou null.
  static Future<String?> setUserType(String type) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return 'Usuário não autenticado.';
      await _client
          .from('profiles')
          .update({'user_type': type})
          .eq('id', userId);
      return null;
    } catch (e) {
      debugPrint('[ViperRide] setUserType error: $e');
      return 'Erro ao atualizar tipo de usuário.';
    }
  }

  /// Retorna true se o motorista já tem `placa` cadastrada no perfil.
  static Future<bool> driverHasPlaca() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final data = await _client
          .from('profiles')
          .select('placa')
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return false;
      final placa = (data as Map)['placa'];
      if (placa == null) return false;
      if (placa is String && placa.trim().isEmpty) return false;
      return true;
    } catch (e) {
      debugPrint('[ViperRide] Erro ao verificar placa: $e');
      return false;
    }
  }

  static String _translate(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (lower.contains('already registered') ||
        lower.contains('email_exists') ||
        lower.contains('user_already_exists')) {
      return 'Este e-mail já está cadastrado.';
    }
    return message;
  }
}
