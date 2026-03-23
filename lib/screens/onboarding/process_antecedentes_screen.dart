import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ProcessAntecedentesScreen extends StatefulWidget {
  final String imagePath;
  final String expectedCpf;
  final String expectedNome;

  const ProcessAntecedentesScreen({
    super.key,
    required this.imagePath,
    required this.expectedCpf,
    required this.expectedNome,
  });

  @override
  State<ProcessAntecedentesScreen> createState() =>
      _ProcessAntecedentesScreenState();
}

class _ProcessAntecedentesScreenState extends State<ProcessAntecedentesScreen> {
  String _status = "Auditando Antecedentes Criminais...";
  bool _isDone = false;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _processAntecedentes();
  }

  Future<void> _processAntecedentes() async {
    final inputImage = InputImage.fromFilePath(widget.imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      // Remove acentos para evitar erros do OCR (ex: NÃO vira NAO)
      String rawText = recognizedText.text
          .toUpperCase()
          .replaceAll('Ã', 'A')
          .replaceAll('Õ', 'O')
          .replaceAll('Á', 'A')
          .replaceAll('É', 'E');

      // Busca todas as variações possíveis de aprovação
      bool hasNadaConsta =
          rawText.contains('NADA CONSTA') ||
          rawText.contains('NAO CONSTA') ||
          rawText.contains('NENHUM REGISTRO');

      // Limpa o CPF esperado (da CNH) para comparar só os números
      String cleanExpectedCpf = widget.expectedCpf.replaceAll(
        RegExp(r'[^\d]'),
        '',
      );

      // Procura CPFs no documento de antecedentes
      RegExp cpfRegex = RegExp(r'\d{3}[.,\s]?\d{3}[.,\s]?\d{3}[-\s]?\d{2}');
      Iterable<RegExpMatch> matches = cpfRegex.allMatches(rawText);

      bool cpfMatchFound = false;
      for (var match in matches) {
        String foundCpf = match.group(0)!.replaceAll(RegExp(r'[^\d]'), '');
        if (foundCpf == cleanExpectedCpf) {
          cpfMatchFound = true;
          break;
        }
      }

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      setState(() {
        _isDone = true;
        if (!hasNadaConsta) {
          _status =
              "Atenção!\nNão encontramos a expressão 'NADA CONSTA' no documento.\nEnvie uma certidão válida.";
          _isSuccess = false;
        } else if (!cpfMatchFound) {
          _status =
              "Fraude Detectada!\nO CPF desta certidão NÃO BATE com o da sua CNH.\nEnvie o SEU documento.";
          _isSuccess = false;
        } else {
          // MÁGICA: CPF exato + Nada Consta = Aprovado! Sem travas com nome.
          _status =
              "Antecedentes Aprovados!\nNADA CONSTA verificado para o CPF:\n${widget.expectedCpf}";
          _isSuccess = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = "Erro na leitura. Tente novamente.";
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
                  _isSuccess ? Icons.verified_user : Icons.gavel,
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
                    onPressed: () => Navigator.pop(context, _isSuccess),
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
