import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';

enum SocialProvider { google, facebook }

/// Solid pill button with provider brand color + label, used side-by-side on the login screen
/// per the reference (Google: white bg; Facebook: Facebook-blue bg).
///
/// Uses the REAL brand marks now, bundled at assets/icons/google_icon.png and
/// assets/icons/facebook_icon.png (declared via the whole-folder `assets/icons/` entry in
/// pubspec.yaml — no separate pubspec change needed when those two files are added). If either
/// file is ever missing/renamed, `errorBuilder` falls back to a generic Material icon rather than
/// crashing the login screen outright — same defensive pattern used across this project for every
/// other bundled image (see app_logo.dart, onboarding_illustration.dart).
class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({required this.provider, required this.onPressed, super.key});

  final SocialProvider provider;
  final VoidCallback? onPressed;

  static const _googleBorder = Color(0xFFDADCE0);
  static const _googleBlue = Color(0xFF4285F4);

  @override
  Widget build(BuildContext context) {
    final isGoogle = provider == SocialProvider.google;
    final background = isGoogle ? Colors.white : const Color(0xFF1877F2);
    final foreground = isGoogle ? Colors.black87 : Colors.white;
    final assetName = isGoogle ? 'assets/icons/google_icon.png' : 'assets/icons/facebook_icon.png';

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        minimumSize: const Size.fromHeight(52),
        shape: StadiumBorder(
          side: isGoogle ? const BorderSide(color: _googleBorder) : BorderSide.none,
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            assetName,
            width: 20,
            height: 20,
            errorBuilder: (context, error, stackTrace) => Icon(
              isGoogle ? Icons.g_mobiledata_rounded : Icons.facebook_rounded,
              size: 22,
              color: isGoogle ? _googleBlue : Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isGoogle ? 'Google' : 'Facebook',
            style: AppTextStyles.bodySecondary(context).copyWith(fontWeight: FontWeight.w600, color: foreground),
          ),
        ],
      ),
    );
  }
}
