import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Loads a real illustration asset from `assets/images/`, sized large to match the reference
/// proportions (the image is the dominant element of each slide, not a small icon). Falls back
/// to a tinted icon in a circle if the asset is missing.
///
/// ⚠️ Known asset mismatch: the current PNGs at these paths were exported with a baked-in white
/// background for the earlier light design. Against this navy background they'll show as a light
/// rectangle rather than blending in — that needs the four illustrations re-exported with a
/// transparent background; it isn't something layout code can fix.
class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({
    required this.assetName,
    required this.fallbackIcon,
    super.key,
  });

  final String assetName;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 300,
      child: Image.asset(
        'assets/images/$assetName',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.12), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(fallbackIcon, size: 96, color: AppColors.gold),
        ),
      ),
    );
  }
}
