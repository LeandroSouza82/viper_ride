import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'camera_capture_screen.dart';
import 'selfie_capture_screen.dart';
import 'process_document_screen.dart';
import 'process_crlv_screen.dart';
import 'process_antecedentes_screen.dart';
import 'vehicle_confirmation_screen.dart';
import '../../services/supabase_service.dart';

class DocumentsChecklistScreen extends StatefulWidget {
  const DocumentsChecklistScreen({super.key});

  @override
  State<DocumentsChecklistScreen> createState() =>
      _DocumentsChecklistScreenState();
}

class _DocumentsChecklistScreenState extends State<DocumentsChecklistScreen> {
  // Memória independente para cada lado da CNH
  bool _isCnhFrenteDone = false;
  bool _isCnhVersoDone = false;
  bool _isSelfieDone = false;
  bool _isCrlvDone = false;
  bool _isAntecedentesDone = false;
  String? _veiculoPlaca;
  bool _isVeiculoMoto = false;
  String? _motoristaCpf;
  String? _motoristaNome;

  Future<void> _showDocumentSourceDialog(bool isFrente) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Como deseja enviar?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.black),
                  title: const Text(
                    'Tirar Foto',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext); // Fecha o menu
                    final cameraResult = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CameraCaptureScreen(isFrente: isFrente),
                      ),
                    );
                    if (!mounted) return;
                    // Se voltar um Map, é a CNH Frente ou um resultado enriquecido
                    if (cameraResult != null && cameraResult is Map) {
                      // Caso o robô tenha retornado os dados do documento
                      if (cameraResult.containsKey('cpf')) {
                        setState(() {
                          _isCnhFrenteDone = true;
                          _motoristaCpf = cameraResult['cpf'];
                          _motoristaNome = cameraResult['nome'];
                        });

                        // MODO TURBO: sobe em background
                        final String? imagePath =
                            cameraResult['imagePath'] as String?;
                        if (imagePath != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Salvando CNH na nuvem...'),
                            ),
                          );
                          SupabaseService.uploadDocumento(
                            imagePath,
                            'cnh_frente',
                          ).then((url) {
                            if (url != null) {
                              SupabaseService.saveMotoristaProgress({
                                'cpf': _motoristaCpf,
                                'nome': _motoristaNome,
                                'cnh_frente_url': url,
                              });
                            }
                          });
                        }
                      } else if (cameraResult['success'] == true) {
                        setState(() {
                          if (isFrente) {
                            _isCnhFrenteDone = true;
                          } else {
                            _isCnhVersoDone = true;
                          }
                        });

                        // MODO TURBO: sobe em background (verso)
                        final String? imagePath =
                            cameraResult['imagePath'] as String?;
                        if (imagePath != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Salvando CNH na nuvem...'),
                            ),
                          );
                          SupabaseService.uploadDocumento(
                            imagePath,
                            isFrente ? 'cnh_frente' : 'cnh_verso',
                          ).then((url) {
                            if (url != null) {
                              SupabaseService.saveMotoristaProgress({
                                'cpf': _motoristaCpf,
                                'nome': _motoristaNome,
                                isFrente ? 'cnh_frente_url' : 'cnh_verso_url':
                                    url,
                              });
                            }
                          });
                        }
                      }
                    } else if (cameraResult == true) {
                      setState(() {
                        if (isFrente) {
                          _isCnhFrenteDone = true;
                        } else {
                          _isCnhVersoDone = true;
                        }
                      });
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.black),
                  title: const Text(
                    'Escolher da Galeria (CNH Digital)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext); // Fecha o menu
                    final picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );

                    if (image != null && mounted) {
                      // MÁGICA: Pula a câmera e manda a imagem da galeria direto pro Robô OCR!
                      final processResult = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProcessDocumentScreen(
                            imagePath: image.path,
                            isFrente: isFrente,
                          ),
                        ),
                      );
                      if (!mounted) return;
                      // Se voltar um Map, é a CNH Frente!
                      if (processResult != null && processResult is Map) {
                        // Frente
                        setState(() {
                          _isCnhFrenteDone = true;
                          _motoristaCpf = processResult['cpf'];
                          _motoristaNome = processResult['nome'];
                        });

                        // MODO TURBO: sobe em background usando o image.path local
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Salvando CNH na nuvem...'),
                          ),
                        );
                        SupabaseService.uploadDocumento(
                          image.path,
                          'cnh_frente',
                        ).then((url) {
                          if (url != null) {
                            SupabaseService.saveMotoristaProgress({
                              'cpf': _motoristaCpf,
                              'nome': _motoristaNome,
                              'cnh_frente_url': url,
                            });
                          }
                        });
                      } else if (processResult == true) {
                        setState(() {
                          if (isFrente) {
                            _isCnhFrenteDone = true;
                          } else {
                            _isCnhVersoDone = true;
                          }
                        });

                        // MODO TURBO: verso - sobe a imagem
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Salvando CNH na nuvem...'),
                          ),
                        );
                        SupabaseService.uploadDocumento(
                          image.path,
                          isFrente ? 'cnh_frente' : 'cnh_verso',
                        ).then((url) {
                          if (url != null) {
                            SupabaseService.saveMotoristaProgress({
                              'cpf': _motoristaCpf,
                              'nome': _motoristaNome,
                              isFrente ? 'cnh_frente_url' : 'cnh_verso_url':
                                  url,
                            });
                          }
                        });
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCrlvSourceDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Como deseja enviar o CRLV?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.black),
                  title: const Text(
                    'Tirar Foto',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.camera,
                    );
                    if (image != null && mounted) {
                      final processResult = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ProcessCrlvScreen(imagePath: image.path),
                        ),
                      );
                      if (processResult != null &&
                          processResult is Map &&
                          mounted) {
                        setState(() {
                          _isCrlvDone = true;
                          _veiculoPlaca = processResult['placa'];
                          _isVeiculoMoto = processResult['isMoto'] ?? false;
                        });

                        // MODO TURBO: sobe CRLV
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Salvando CRLV na nuvem...'),
                          ),
                        );
                        SupabaseService.uploadDocumento(
                          image.path,
                          'crlv',
                        ).then((url) {
                          if (url != null) {
                            SupabaseService.saveMotoristaProgress({
                              'cpf': _motoristaCpf,
                              'nome': _motoristaNome,
                              'crlv_url': url,
                              'placa': _veiculoPlaca,
                            });
                          }
                        });
                      } else if (processResult == true && mounted) {
                        setState(() {
                          _isCrlvDone = true;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Salvando CRLV na nuvem...'),
                          ),
                        );
                        SupabaseService.uploadDocumento(
                          image.path,
                          'crlv',
                        ).then((url) {
                          if (url != null) {
                            SupabaseService.saveMotoristaProgress({
                              'cpf': _motoristaCpf,
                              'nome': _motoristaNome,
                              'crlv_url': url,
                            });
                          }
                        });
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.black),
                  title: const Text(
                    'Escolher da Galeria (CRLV Digital)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null && mounted) {
                      final processResult = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ProcessCrlvScreen(imagePath: image.path),
                        ),
                      );
                      if (processResult != null &&
                          processResult is Map &&
                          mounted) {
                        setState(() {
                          _isCrlvDone = true;
                          _veiculoPlaca = processResult['placa'];
                          _isVeiculoMoto = processResult['isMoto'] ?? false;
                        });

                        // MODO TURBO: sobe CRLV
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Salvando CRLV na nuvem...'),
                          ),
                        );
                        SupabaseService.uploadDocumento(
                          image.path,
                          'crlv',
                        ).then((url) {
                          if (url != null) {
                            SupabaseService.saveMotoristaProgress({
                              'cpf': _motoristaCpf,
                              'nome': _motoristaNome,
                              'crlv_url': url,
                              'placa': _veiculoPlaca,
                            });
                          }
                        });
                      } else if (processResult == true && mounted) {
                        setState(() {
                          _isCrlvDone = true;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Salvando CRLV na nuvem...'),
                          ),
                        );
                        SupabaseService.uploadDocumento(
                          image.path,
                          'crlv',
                        ).then((url) {
                          if (url != null) {
                            SupabaseService.saveMotoristaProgress({
                              'cpf': _motoristaCpf,
                              'nome': _motoristaNome,
                              'crlv_url': url,
                            });
                          }
                        });
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAntecedentesSourceDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Antecedentes Criminais',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),

                // BOTÃO 1: Emitir no site da PF
                ListTile(
                  leading: const Icon(
                    Icons.open_in_browser,
                    color: Colors.blue,
                  ),
                  title: const Text(
                    'Emitir Certidão Online',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  subtitle: const Text('Abre o site da Polícia Federal'),
                  onTap: () async {
                    Navigator.pop(sheetContext); // Fecha o menu
                    final Uri url = Uri.parse(
                      'https://servicos.pf.gov.br/epol-sinic-publico/',
                    );
                    if (!await launchUrl(
                      url,
                      mode: LaunchMode.externalApplication,
                    )) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Não foi possível abrir o site. Tente novamente.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
                const Divider(),

                // BOTÃO 2: Enviar o PDF/Foto que ele já baixou
                ListTile(
                  leading: const Icon(Icons.file_upload, color: Colors.black),
                  title: const Text(
                    'Já tenho o documento',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  subtitle: const Text('Enviar PDF ou Imagem da Galeria'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final picker = ImagePicker();
                    // Permite pegar da galeria (fotos)
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null && mounted) {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProcessAntecedentesScreen(
                            imagePath: image.path,
                            expectedCpf: _motoristaCpf!,
                            expectedNome: _motoristaNome!,
                          ),
                        ),
                      );
                      if (result == true && mounted) {
                        setState(() => _isAntecedentesDone = true);

                        // MODO TURBO: sobe antecedentes
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Salvando certidão na nuvem...'),
                          ),
                        );
                        SupabaseService.uploadDocumento(
                          image.path,
                          'antecedentes',
                        ).then((url) {
                          if (url != null) {
                            SupabaseService.saveMotoristaProgress({
                              'cpf': _motoristaCpf,
                              'nome': _motoristaNome,
                              'antecedentes_url': url,
                            });
                          }
                        });
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    bool canSubmit =
        _isCnhFrenteDone &&
        _isCnhVersoDone &&
        _isSelfieDone &&
        _isCrlvDone &&
        _isAntecedentesDone;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Enviar documentos',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Falta pouco!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Precisamos de algumas fotos para validar seu cadastro na Viper.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 32),

            // 1. CNH FRENTE (Sempre liberado)
            _buildDocItem(
              icon: Icons.badge_outlined,
              title: 'CNH - Frente',
              subtitle: _isCnhFrenteDone
                  ? 'Nome e CPF confirmados'
                  : 'Lado da foto',
              status: _isCnhFrenteDone ? 'Concluído' : 'Pendente',
              isDone: _isCnhFrenteDone,
              onTap: () => _showDocumentSourceDialog(true),
            ),
            const Divider(height: 24),

            // 2. CNH VERSO (Só libera se Frente estiver OK)
            _buildDocItem(
              icon: Icons.credit_card_outlined,
              title: 'CNH - Verso',
              subtitle: _isCnhVersoDone ? 'EAR validado' : 'Verso contendo EAR',
              status: _isCnhVersoDone ? 'Concluído' : 'Pendente',
              isDone: _isCnhVersoDone,
              isEnabled: _isCnhFrenteDone,
              onTap: () {
                if (!_isCnhFrenteDone) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Por favor, conclua a Frente da CNH primeiro.',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                _showDocumentSourceDialog(false);
              },
            ),
            const Divider(height: 24),

            // 3. CRLV (Só libera se CNH Verso estiver OK)
            _buildDocItem(
              icon: Icons.directions_car_filled_outlined,
              title: 'CRLV (Veículo)',
              subtitle: _isCrlvDone
                  ? 'Exercício validado'
                  : 'Documento vigente',
              status: _isCrlvDone ? 'Concluído' : 'Pendente',
              isDone: _isCrlvDone,
              isEnabled: _isCnhVersoDone,
              onTap: () {
                if (!_isCnhVersoDone) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Por favor, conclua a CNH antes de enviar o documento do veículo.',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                _showCrlvSourceDialog();
              },
            ),
            const Divider(height: 24),

            // 4. SELFIE (Só libera se CRLV estiver OK)
            _buildDocItem(
              icon: Icons.camera_front_outlined,
              title: 'Foto de Perfil',
              subtitle: _isSelfieDone
                  ? 'Rosto validado'
                  : 'Selfie bem iluminada',
              status: _isSelfieDone ? 'Concluído' : 'Pendente',
              isDone: _isSelfieDone,
              isEnabled: _isCrlvDone,
              onTap: () async {
                if (!_isCrlvDone) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Por favor, conclua o documento do veículo primeiro.',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SelfieCaptureScreen(),
                  ),
                );
                if (!mounted) return;
                if (result != null) {
                  if (result is Map && result['imagePath'] != null) {
                    setState(() => _isSelfieDone = true);

                    // MODO TURBO: sobe selfie
                    final String imagePath = result['imagePath'] as String;
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Salvando selfie na nuvem...'),
                      ),
                    );
                    SupabaseService.uploadDocumento(imagePath, 'selfie').then((
                      url,
                    ) {
                      if (url != null) {
                        SupabaseService.saveMotoristaProgress({
                          'cpf': _motoristaCpf,
                          'nome': _motoristaNome,
                          'selfie_url': url,
                        });
                      }
                    });
                  } else if (result == true) {
                    setState(() => _isSelfieDone = true);
                  }
                }
              },
            ),
            const Divider(height: 24),

            // 5. ANTECEDENTES (Só libera se Selfie estiver OK e CPF existir)
            _buildDocItem(
              icon: Icons.gavel_outlined,
              title: 'Antecedentes Criminais',
              subtitle: _isAntecedentesDone
                  ? 'Nada Consta validado'
                  : 'Certidão da Polícia Federal',
              status: _isAntecedentesDone ? 'Concluído' : 'Pendente',
              isDone: _isAntecedentesDone,
              isEnabled: _isSelfieDone,
              onTap: () {
                if (!_isSelfieDone) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Por favor, tire sua foto de perfil primeiro.',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (_motoristaCpf == null || _motoristaNome == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Erro: Dados da CNH não encontrados.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                _showAntecedentesSourceDialog();
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      // COLAR SUBSTITUINDO A PARTIR DO bottomNavigationBar:
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: canSubmit
                  ? () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VehicleConfirmationScreen(
                            placaInicial: _veiculoPlaca ?? "",
                            isMotoInicial: _isVeiculoMoto,
                          ),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Enviar para Análise',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    ); // Fecha o Scaffold
  } // Fecha o método build

  Widget _buildDocItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
    required bool isDone,
    bool isEnabled = true,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        child: Row(
          children: [
            Icon(icon, size: 32, color: isDone ? Colors.green : Colors.black),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDone ? Colors.green : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDone ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: isDone ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ), // <--- AQUI ESTAVA FALTANDO O FECHAMENTO DO INKWELL!
    );
  }
} // Fecha a classe _DocumentsChecklistScreenState
