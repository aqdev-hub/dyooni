import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Dark rounded input field with a subtle border, matching the reference auth screens.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.hint,
    this.controller,
    this.leadingIcon,
    this.trailingIcon,
    this.onTrailingTap,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.errorText,
    super.key,
  });

  final String hint;
  final TextEditingController? controller;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: AppTextStyles.body(context).copyWith(color: AppColors.textPrimary),
      cursorColor: AppColors.gold,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body(context).copyWith(color: AppColors.textSecondary),
        errorText: errorText,
        errorStyle: AppTextStyles.bodySecondary(context).copyWith(color: AppColors.error, fontSize: 12),
        filled: true,
        fillColor: AppColors.surface,
        prefixIcon: leadingIcon != null ? Icon(leadingIcon, size: 20, color: AppColors.textSecondary) : null,
        suffixIcon: trailingIcon != null
            ? IconButton(
                icon: Icon(trailingIcon, size: 20, color: AppColors.textSecondary),
                onPressed: onTrailingTap,
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }
}
