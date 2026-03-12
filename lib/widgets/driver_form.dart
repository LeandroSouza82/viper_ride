import 'package:flutter/material.dart';
import 'viper_input.dart';

class ViperDriverForm extends StatelessWidget {
  final TextEditingController cnhController;
  final TextEditingController placaController;
  final TextEditingController modeloController;
  final TextEditingController corController;

  const ViperDriverForm({
    super.key,
    required this.cnhController,
    required this.placaController,
    required this.modeloController,
    required this.corController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ViperInput(
          controller: cnhController,
          hint: 'CNH',
          prefixIcon: const Icon(
            Icons.badge_outlined,
            color: Color(0xFFAAAAAA),
          ),
        ),
        const SizedBox(height: 12),
        ViperInput(
          controller: placaController,
          hint: 'Placa do veículo',
          prefixIcon: const Icon(Icons.pin_outlined, color: Color(0xFFAAAAAA)),
        ),
        const SizedBox(height: 12),
        ViperInput(
          controller: modeloController,
          hint: 'Modelo do carro',
          prefixIcon: const Icon(
            Icons.directions_car_outlined,
            color: Color(0xFFAAAAAA),
          ),
        ),
        const SizedBox(height: 12),
        ViperInput(
          controller: corController,
          hint: 'Cor do carro',
          prefixIcon: const Icon(
            Icons.palette_outlined,
            color: Color(0xFFAAAAAA),
          ),
        ),
      ],
    );
  }
}
