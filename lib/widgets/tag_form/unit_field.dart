import 'package:flutter/material.dart';

class UnitField extends StatelessWidget {
  const UnitField({
    required this.controller,
    required this.unit,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String unit;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: '0',
        suffixText: unit,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}
