import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';

enum SocialProvider { google, facebook }

/// Solid pill button with provider brand color + label, used side-by-side on the login screen
/// per the reference (Google: white bg; Facebook: Facebook-blue bg).
///
/// NOTE: brand marks (Google "G", Facebook "f") are trademarked assets — using a plain colored
/// letter / generic Material icon as placeholders, not the official SVG marks. Swap for those
/// before release, per each provider's brand guidelines. This batch only fixes the Google mark
/// looking visibly broken (it was `Icons.g_mobiledata_rounded` — a signal-strength icon, not a
/// "G", rendered in an unset/ambient color that came out dark instead of Google's blue) and adds
/// the subtle gray border real "Sign in with Google" buttons use on a white background so the
/// pill doesn't look like a flat, borderless card.
class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({required this.provider, required this.onPressed, super.key});

  final SocialProvider provider;
  final VoidCallback? onPressed;

  static const _googleBlue = Color(0xFF4285F4);
  static const _googleBorder = Color(0xFFDADCE0);

  @override
  Widget build(BuildContext context) {
    final isGoogle = provider == SocialProvider.google;
    final background = isGoogle ? Colors.white : const Color(0xFF1877F2);
    final foreground = isGoogle ? Colors.black87 : Colors.white;

    final Widget mark = isGoogle
        ? const Text(
            'G',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _googleBlue, height: 1),
          )
        : const Icon(Icons.facebook_rounded, size: 22, color: Colors.white);

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
          mark,
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
