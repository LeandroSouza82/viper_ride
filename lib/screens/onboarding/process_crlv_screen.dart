import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ProcessCrlvScreen extends StatefulWidget {
  final String imagePath;
  const ProcessCrlvScreen({super.key, required this.imagePath});

  @override
  State<ProcessCrlvScreen> createState() => _ProcessCrlvScreenState();
}

class _ProcessCrlvScreenState extends State<ProcessCrlvScreen> {
  String _status = "Analisando documento do veículo...";
  bool _isDone = false;
  bool _isSuccess = false;
  String _finalPlaca = "";
  bool _isMotoDetectada = false;

  @override
  void initState() {
    super.initState();
    _processCrlv();
  }

  Future<void> _processCrlv() async {
    final inputImage = InputImage.fromFilePath(widget.imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      String rawText = recognizedText.text.toUpperCase();

      String extractedPlaca = "Não encontrada";
      String extractedAno = "Não encontrado";

      // 1. REGEX SNIPER PARA PLACA (Padrão Antigo e Mercosul)
      // Busca 3 letras, seguido de um espaço/traço opcional, 1 número, 1 letra ou número, 2 números.
      RegExp placaRegex = RegExp(r'\b[A-Z]{3}[- ]?[0-9][A-Z0-9][0-9]{2}\b');
      var placaMatch = placaRegex.firstMatch(rawText);
      if (placaMatch != null) {
        extractedPlaca = placaMatch
            .group(0)!
            .replaceAll(' ', '')
            .replaceAll('-', '');
      }

      // 2. CAÇADOR DO ANO DE EXERCÍCIO
      List<String> lines = recognizedText.text.split('\n');
      for (int i = 0; i < lines.length; i++) {
        String currentLine = lines[i].trim().toUpperCase();

        // Se a linha tem a palavra EXERCICIO, procura um ano (202X) nela ou na próxima
        if (currentLine.contains('EXERC')) {
          RegExp anoRegex = RegExp(r'202[0-9]');

          // Procura na mesma linha primeiro
          var anoMatch = anoRegex.firstMatch(currentLine);
          if (anoMatch != null) {
            extractedAno = anoMatch.group(0)!;
            break;
          }

          // Se não achou na mesma linha, procura na linha de baixo
          if (i + 1 < lines.length) {
            var nextLineMatch = anoRegex.firstMatch(lines[i + 1].toUpperCase());
            if (nextLineMatch != null) {
              extractedAno = nextLineMatch.group(0)!;
              break;
            }
          }
        }
      }

      // 3. DETECTOR DE MOTO
      bool isMotoDetectada =
          rawText.contains('MOTO') ||
          rawText.contains('MOTOCICLETA') ||
          rawText.contains('MOTONETA');

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      setState(() {
        _isDone = true;
        _isMotoDetectada = isMotoDetectada;
        // REGRA DE OURO DO CRLV: Tem que achar pelo menos o Ano de Exercício
        if (extractedAno != "Não encontrado") {
          _status =
              "CRLV Validado!\n\nPlaca: $extractedPlaca\nExercício: $extractedAno";
          _isSuccess = true;
          _finalPlaca = extractedPlaca;
        } else {
          _status =
              "Leitura incompleta!\nNão foi possível identificar o Ano de Exercício.\nTente focar na parte superior do CRLV.";
          _isSuccess = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = "Erro ao ler CRLV. Tente novamente.";
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
                    onPressed: () => Navigator.pop(
                      context,
                      _isSuccess
                          ? {'placa': _finalPlaca, 'isMoto': _isMotoDetectada}
                          : false,
                    ),
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
