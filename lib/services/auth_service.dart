import 'package:supabase_flutter/supabase_flutter.dart';

class ViperAuthService {
  ViperAuthService._();

  static final _client = Supabase.instance.client;

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
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      final userId = response.user?.id;
      if (userId == null) return 'Não foi possível criar a conta.';
      final profileData = <String, dynamic>{
        'id': userId,
        'full_name': fullName,
        'user_type': userType,
      };
      if (phone != null && phone.isNotEmpty) profileData['phone'] = phone;
      if (userType == 'driver') {
        if (cnh != null && cnh.isNotEmpty) profileData['cnh'] = cnh;
        if (placa != null && placa.isNotEmpty) profileData['placa'] = placa;
        if (carModel != null && carModel.isNotEmpty) {
          profileData['car_model'] = carModel;
        }
        if (carColor != null && carColor.isNotEmpty) {
          profileData['car_color'] = carColor;
        }
      }
      await _client.from('profiles').insert(profileData);
      return null;
    } on AuthException catch (e) {
      return _translate(e.message);
    } catch (_) {
      return 'Erro inesperado. Tente novamente.';
    }
  }

  static Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return _translate(e.message);
    } catch (_) {
      return 'Erro inesperado. Tente novamente.';
    }
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  static Future<String?> resetPassword({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return null;
    } on AuthException catch (e) {
      return _translate(e.message);
    } catch (_) {
      return 'Erro inesperado. Tente novamente.';
    }
  }

  static Future<String?> getUserType() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final data = await _client
          .from('profiles')
          .select('user_type')
          .eq('id', userId)
          .single();
      return data['user_type'] as String?;
    } catch (_) {
      return null;
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
