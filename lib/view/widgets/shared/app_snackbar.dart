import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Central place for success/failure feedback — every auth action (and later, every data
/// mutation) reports through this instead of ad-hoc SnackBar calls, so the look and behavior of
/// "it worked" / "it failed" is consistent app-wide.
abstract class AppSnackBar {
  static void showSuccess(BuildContext context, String message) => _show(
        context,
        message: message,
        background: AppColors.success,
        icon: Icons.check_circle_outline_rounded,
      );

  static void showError(BuildContext context, String message) => _show(
        context,
        message: message,
        background: AppColors.error,
        icon: Icons.error_outline_rounded,
      );

  static void _show(
    BuildContext context, {
    required String message,
    required Color background,
    required IconData icon,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.bodySecondary(context).copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
