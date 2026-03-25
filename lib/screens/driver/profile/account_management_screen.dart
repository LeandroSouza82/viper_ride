import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/account_controller.dart';
// supabase not used directly here; controller handles auth

class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AccountController());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Gerenciar conta',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final vehicleTypeLabel =
            controller.vehicleType.value.toLowerCase().contains('moto')
            ? 'Moto'
            : controller.vehicleType.value.toLowerCase().contains('carro')
            ? 'Carro'
            : (controller.vehicleType.value.isNotEmpty
                  ? controller.vehicleType.value
                  : '-');

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Perfil card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.grey.shade200,
                    child: Text(
                      controller.fullName.value.isNotEmpty
                          ? controller.fullName.value[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 28, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.fullName.value.isNotEmpty
                              ? controller.fullName.value
                              : 'Não preenchido',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          controller.email.value.isNotEmpty
                              ? controller.email.value
                              : '-',
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Lista de informações
            ListTile(
              leading: const Icon(Icons.person, color: Colors.black),
              title: const Text('Nome', style: TextStyle(color: Colors.black)),
              subtitle: Text(
                controller.fullName.value.isNotEmpty
                    ? controller.fullName.value
                    : '-',
              ),
            ),

            ListTile(
              leading: const Icon(Icons.email, color: Colors.black),
              title: const Text(
                'E-mail',
                style: TextStyle(color: Colors.black),
              ),
              subtitle: Text(
                controller.email.value.isNotEmpty
                    ? controller.email.value
                    : '-',
              ),
            ),

            ListTile(
              leading: const Icon(Icons.phone, color: Colors.black),
              title: const Text(
                'Telefone',
                style: TextStyle(color: Colors.black),
              ),
              subtitle: Text(
                controller.phone.value.isNotEmpty
                    ? controller.phone.value
                    : '-',
              ),
            ),

            ListTile(
              leading:
                  controller.vehicleType.value.toLowerCase().contains('carro')
                  ? const Icon(Icons.directions_car, color: Colors.black)
                  : const Icon(Icons.motorcycle, color: Colors.black),
              title: const Text(
                'Modelo do Veículo',
                style: TextStyle(color: Colors.black),
              ),
              subtitle: Text(
                controller.vehicleModel.value.isNotEmpty
                    ? controller.vehicleModel.value
                    : '-',
              ),
            ),

            ListTile(
              leading: const Icon(
                Icons.confirmation_number,
                color: Colors.black,
              ),
              title: const Text('Placa', style: TextStyle(color: Colors.black)),
              subtitle: Text(
                controller.vehiclePlate.value.isNotEmpty
                    ? controller.vehiclePlate.value
                    : '-',
              ),
            ),

            ListTile(
              leading: const Icon(Icons.category, color: Colors.black),
              title: const Text(
                'Tipo de Veículo',
                style: TextStyle(color: Colors.black),
              ),
              subtitle: Text(vehicleTypeLabel),
            ),

            const SizedBox(height: 24),

            // Botão de sair no final
            InkWell(
              onTap: () async {
                final confirm = await Get.defaultDialog<bool>(
                  title: 'Sair?',
                  middleText:
                      'Deseja realmente sair? Você precisará validar o código via WhatsApp para entrar novamente ou com outra conta.',
                  textCancel: 'Cancelar',
                  textConfirm: 'Sair',
                  onConfirm: () => Get.back(result: true),
                );
                if (confirm == true) {
                  await controller.logout();
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'Sair da Conta',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
