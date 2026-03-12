import 'package:flutter/material.dart';

class ViperInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType keyboardType;
  final Widget? prefixIcon;

  const ViperInput({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFF111111), fontSize: 15),
      cursorColor: const Color(0xFF111111),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 15),
        prefixIcon: prefixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF111111), width: 1.5),
        ),
      ),
    );
  }
}
