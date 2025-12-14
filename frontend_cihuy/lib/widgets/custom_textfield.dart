import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    const Color primaryTeal = Color(0xFF00796B);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // warna background field & border disesuaikan
    final Color fillColor =
        isDark ? const Color(0xFF233632) : Colors.white; // hijau gelap agak terang
    final Color enabledBorderColor =
        isDark ? Colors.white24 : Colors.grey.shade400;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      cursorColor: primaryTeal, // cursor hijau

      // <<< WARNA TEKS INPUT >>>
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
      ),

      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : Colors.grey,
        ),

        filled: true,
        fillColor: fillColor,

        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: primaryTeal) // icon hijau
            : null,
        suffixIcon: suffixIcon,

        // border saat TIDAK fokus
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
            color: enabledBorderColor,
            width: 1.4,
          ),
        ),

        // border saat fokus
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(30)),
          borderSide: BorderSide(
            color: primaryTeal,
            width: 2,
          ),
        ),

        // border kalau error
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(30)),
          borderSide: BorderSide(
            color: Colors.red,
            width: 1.4,
          ),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(30)),
          borderSide: BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
      ),
    );
  }
}