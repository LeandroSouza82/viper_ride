import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountController extends GetxController {
  final fullName = ''.obs;
  final email = ''.obs;
  final phone = ''.obs;
  final vehicleModel = ''.obs;
  final vehiclePlate = ''.obs;
  final vehicleType = ''.obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> logout() async {
    isLoading.value = true;
    try {
      await Supabase.instance.client.auth.signOut();
      Get.offAllNamed('/login');
    } catch (e) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!isClosed) {
          Get.snackbar(
            'Erro',
            'Falha ao sair',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      });
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadProfile() async {
    isLoading.value = true;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        isLoading.value = false;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!isClosed) {
            Get.snackbar(
              'Perfil',
              'Usuário não autenticado',
              snackPosition: SnackPosition.BOTTOM,
            );
          }
        });
        return;
      }

      final res = await Supabase.instance.client
          .from('profiles')
          .select(
            'full_name,email,phone,vehicle_model,vehicle_plate,vehicle_type',
          )
          .eq('id', userId)
          .maybeSingle();

      if (res == null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!isClosed) {
            Get.snackbar(
              'Perfil',
              'Perfil não encontrado',
              snackPosition: SnackPosition.BOTTOM,
            );
          }
        });
      } else {
        final Map<String, dynamic> p = Map<String, dynamic>.from(res);
        fullName.value = p['full_name']?.toString() ?? '';
        email.value = p['email']?.toString() ?? '';
        phone.value = p['phone']?.toString() ?? '';
        vehicleModel.value = p['vehicle_model']?.toString() ?? '';
        vehiclePlate.value = p['vehicle_plate']?.toString() ?? '';
        vehicleType.value = p['vehicle_type']?.toString() ?? '';
      }
    } catch (e) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!isClosed) {
          Get.snackbar(
            'Erro',
            'Falha ao carregar perfil',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      });
    } finally {
      // pequeno delay para garantir visibilidade do estado de loading
      await Future.delayed(const Duration(seconds: 1));
      isLoading.value = false;
      update();
    }
  }

  /// Verifica se o perfil possui campos obrigatórios preenchidos.
  /// Retorna `true` se o perfil estiver incompleto (nome ou email vazios).
  Future<bool> checkProfileCompleteness() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return false;

      final res = await Supabase.instance.client
          .from('profiles')
          .select('full_name,email')
          .eq('id', userId)
          .maybeSingle();

      if (res == null) return true;
      final Map<String, dynamic> p = Map<String, dynamic>.from(res);
      final full = p['full_name']?.toString() ?? '';
      final mail = p['email']?.toString() ?? '';
      return full.trim().isEmpty || mail.trim().isEmpty;
    } catch (e) {
      // Em caso de erro, não bloqueamos a navegação; consideramos incompleto
      return true;
    }
  }

  /// Atualiza os campos obrigatórios do perfil (nome, email, cpf/document_cpf).
  /// Retorna true se a atualização foi bem-sucedida.
  Future<bool> updateCompleteProfile(
    String name,
    String mail,
    String cpf,
  ) async {
    isLoading.value = true;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!isClosed) {
            Get.snackbar(
              'Erro',
              'Usuário não autenticado',
              snackPosition: SnackPosition.BOTTOM,
            );
          }
        });
        return false;
      }

      final updates = {
        'full_name': name.trim(),
        'email': mail.trim(),
        // coluna criada: document_cpf
        'document_cpf': cpf.trim(),
      };

      await Supabase.instance.client
          .from('profiles')
          .update(updates)
          .eq('id', userId);

      // Atualiza estado local
      fullName.value = name.trim();
      email.value = mail.trim();

      // Navega para home após sucesso
      try {
        Get.offAllNamed('/home');
      } catch (_) {}

      return true;
    } catch (e) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!isClosed) {
          Get.snackbar(
            'Erro',
            'Falha ao salvar perfil',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      });
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
