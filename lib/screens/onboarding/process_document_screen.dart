import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ProcessDocumentScreen extends StatefulWidget {
  final String imagePath;
  final bool isFrente; // Sabe qual lado está lendo
  const ProcessDocumentScreen({
    super.key,
    required this.imagePath,
    required this.isFrente,
  });

  @override
  State<ProcessDocumentScreen> createState() => _ProcessDocumentScreenState();
}

class _ProcessDocumentScreenState extends State<ProcessDocumentScreen> {
  String _status = "Analisando documento...";
  bool _isDone = false;
  bool _isSuccess = false; // Controla se a leitura foi aprovada
  String _finalCpf = "";
  String _finalNome = "";

  @override
  void initState() {
    super.initState();
    _processImage();
  }

  Future<void> _processImage() async {
    final inputImage = InputImage.fromFilePath(widget.imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      String rawText = recognizedText.text.toUpperCase();

      String extractedCpf = "Não encontrado";
      String extractedName = "Não encontrado";
      bool hasEAR = false;

      // 1. DETECTOR DE EAR
      if (rawText.contains('EAR') ||
          rawText.contains('EXERCE ATIVIDADE REMUNERADA')) {
        hasEAR = true;
      }

      // 2. CPF SNIPER
      RegExp cpfRegex = RegExp(r'\b\d{3}[.,\s]\d{3}[.,\s]\d{3}[-\s]\d{2}\b');
      var cpfMatch = cpfRegex.firstMatch(rawText);
      if (cpfMatch != null) {
        String cleanCpf = cpfMatch.group(0)!.replaceAll(RegExp(r'[^\d]'), '');
        if (cleanCpf.length == 11) {
          extractedCpf =
              '${cleanCpf.substring(0, 3)}.${cleanCpf.substring(3, 6)}.${cleanCpf.substring(6, 9)}-${cleanCpf.substring(9)}';
        }
      }

      // 3. CAÇADOR DE NOME
      List<String> lines = recognizedText.text.split('\n');
      for (int i = 0; i < lines.length; i++) {
        String currentLine = lines[i].trim().toUpperCase();
        if (currentLine.contains('NOME') || currentLine.startsWith('NOM')) {
          for (int j = i + 1; j <= i + 3 && j < lines.length; j++) {
            String possibleName = lines[j].trim().toUpperCase();
            if (possibleName.length > 5 &&
                !RegExp(r'\d').hasMatch(possibleName) &&
                possibleName.contains(' ')) {
              if (!possibleName.contains('MINISTERIO') &&
                  !possibleName.contains('REPUBLICA') &&
                  !possibleName.contains('VALIDADE')) {
                extractedName = possibleName;
                break;
              }
            }
          }
          if (extractedName != "Não encontrado") break;
        }
      }

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      setState(() {
        _isDone = true;
        if (widget.isFrente) {
          // REGRA DE OURO DA FRENTE: Tem que ter Nome E CPF!
          if (extractedName != "Não encontrado" &&
              extractedCpf != "Não encontrado") {
            _status =
                "Leitura concluída!\n\nNome: $extractedName\nCPF: $extractedCpf";
            _finalCpf = extractedCpf; // SALVA O CPF
            _finalNome = extractedName; // SALVA O NOME
            _isSuccess = true;
          } else {
            _status =
                "Leitura incompleta!\nNão foi possível ler o Nome e o CPF juntos.\nEvite reflexos e tente novamente.";
            _isSuccess = false; // Bloqueia o avanço
          }
        } else {
          // REGRA DO VERSO
          if (hasEAR) {
            _status = "EAR CONFIRMADO ✅\nVerso validado com sucesso!";
          } else {
            _status = "IMAGEM CAPTURADA ✅\nVerso salvo para análise.";
          }
          _isSuccess = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = "Erro ao ler documento. Tente novamente.";
        _isDone = true;
        _isSuccess = false;
      });
    } finally {
      textRecognizer.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isDone)
                const CircularProgressIndicator(color: Colors.black),
              if (_isDone)
                Icon(
                  _isSuccess ? Icons.check_circle : Icons.error_outline,
                  color: _isSuccess ? Colors.green : Colors.red,
                  size: 80,
                ),
              const SizedBox(height: 24),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (_isDone) ...[
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_isSuccess && widget.isFrente) {
                        Navigator.pop(context, {
                          'cpf': _finalCpf,
                          'nome': _finalNome,
                        });
                      } else {
                        Navigator.pop(context, _isSuccess);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSuccess ? Colors.black : Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _isSuccess ? 'Continuar' : 'Tentar Novamente',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
