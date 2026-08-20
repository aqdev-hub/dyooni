import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Loads the real brand mark from `assets/icons/app_logo.png` (confirmed present). Falls back to
/// a gold-ringed letter mark only if that file is ever missing/renamed, so this never breaks a
/// screen outright.
class AppLogo extends StatelessWidget {
  const AppLogo({this.size = 108, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/app_logo.png',
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(color: AppColors.gold, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          'د',
          style: TextStyle(
            color: AppColors.gold,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
