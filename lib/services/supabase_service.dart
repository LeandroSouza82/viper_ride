import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class SupabaseService {
  static final _supabase = Supabase.instance.client;

  // 1. Comprime a foto e faz o upload para o Bucket
  static Future<String?> uploadDocumento(
    String imagePath,
    String docType,
  ) async {
    try {
      // Pega a pasta temporária do celular para não lotar a memória do usuário
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // MÁGICA: Espreme a imagem original
      final XFile? compressedFile =
          await FlutterImageCompress.compressAndGetFile(
            imagePath,
            targetPath,
            quality: 50, // Corta o peso pela metade (sem perder leitura)
            minWidth: 1024, // Limita o tamanho máximo da imagem
            minHeight: 1024,
          );

      if (compressedFile == null) {
        debugPrint('Erro: Falha ao comprimir imagem.');
        return null;
      }

      final fileToUpload = File(compressedFile.path);
      final userId =
          _supabase.auth.currentUser?.id ??
          'temp_user_${DateTime.now().millisecondsSinceEpoch}';
      final fileName = '${userId}_$docType.jpg';

      // Sobe a foto compactada para a pasta 'documentos'
      await _supabase.storage
          .from('documentos')
          .upload(
            fileName,
            fileToUpload,
            fileOptions: const FileOptions(upsert: true),
          );

      // Pega a URL pública
      return _supabase.storage.from('documentos').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Erro ao fazer upload compactado ($docType): $e');
      return null;
    }
  }

  // 2. Salva os dados na tabela 'profiles' e retorna o erro se falhar
  static Future<String?> saveMotoristaProgress(
    Map<String, dynamic> data,
  ) async {
    try {
      if (data['id'] == null) {
        return 'Erro: ID do usuário está nulo.';
      }
      await _supabase.from('profiles').upsert(data, onConflict: 'id');
      return null; // Null significa Sucesso!
    } catch (e) {
      debugPrint('Erro Supabase: $e');
      return e.toString(); // Retorna o texto do erro para a tela
    }
  }

  static String? getCurrentUserId() {
    // Retorna o ID oficial que já existe no banco da Viper (forçado para testes)
    return 'ffb763a2-3565-49d8-98a6-b786e844829d';
  }

  // 3. Busca o progresso atual
  static Future<Map<String, dynamic>?> getMotoristaProgress(String cpf) async {
    try {
      final data = await _supabase
          .from('motoristas')
          .select()
          .eq('cpf', cpf)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('Erro ao buscar progresso: $e');
      return null;
    }
  }
}
