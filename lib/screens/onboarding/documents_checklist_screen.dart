import 'package:flutter/material.dart';
import 'camera_capture_screen.dart'; // IMPORT DA CÂMERA

class DocumentsChecklistScreen extends StatelessWidget {
  const DocumentsChecklistScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
      body: Padding(
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

            _buildDocItem(
              icon: Icons.badge_outlined,
              title: 'CNH (Carteira de Motorista)',
              subtitle: 'Frente e verso com EAR',
              status: 'Pendente',
              onTap: () {
                // CONEXÃO COM A CÂMERA
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CameraCaptureScreen(),
                  ),
                );
              },
            ),
            const Divider(height: 32),
            _buildDocItem(
              icon: Icons.directions_car_filled_outlined,
              title: 'CRLV (Documento do Veículo)',
              subtitle: 'Documento do ano vigente',
              status: 'Pendente',
              onTap: () {
                debugPrint('Abrir captura de CRLV');
              },
            ),
            const Divider(height: 32),
            _buildDocItem(
              icon: Icons.camera_front_outlined,
              title: 'Foto de Perfil',
              subtitle: 'Uma selfie bem iluminada',
              status: 'Pendente',
              onTap: () {
                debugPrint('Abrir selfie');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 32, color: Colors.black),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
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
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.black26),
        ],
      ),
    );
  }
}
