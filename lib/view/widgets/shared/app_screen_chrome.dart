import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/voice_palette.dart';

/// The look of the voice screen, shared by every screen: the soft blue body gradient with the two
/// waves along the bottom, the navy header with a centred gold title, and (see MainBottomNav) the
/// navy bottom bar. Keeping it here means a colour change is made once ([VoicePalette]), not per
/// screen.

/// Two soft translucent waves along the bottom of the body.
class AppWavesPainter extends CustomPainter {
  const AppWavesPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    void wave(double baseline, double amplitude, double phase, double alpha) {
      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width; x += 4) {
        final y = size.height - baseline + amplitude * math.sin((x / size.width) * 2 * math.pi + phase);
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: alpha));
    }

    wave(size.height * 0.16, 14, 0.4, 0.55);
    wave(size.height * 0.10, 10, 2.1, 0.45);
  }

  @override
  bool shouldRepaint(covariant AppWavesPainter oldDelegate) => oldDelegate.color != color;
}

/// The body background: vertical gradient + waves. Fills all the space it is given.
class AppBody extends StatelessWidget {
  const AppBody({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.voicePalette;
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.bodyTop, palette.bodyBottom],
          ),
        ),
        child: CustomPaint(painter: AppWavesPainter(color: palette.wave), child: child),
      ),
    );
  }
}

/// A [Scaffold] whose body sits on the shared [AppBody] background. Same arguments as the ones the
/// app's screens use on Scaffold.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.body,
    this.drawer,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
    super.key,
  });

  final Widget body;
  final Widget? drawer;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.voicePalette.bodyTop,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: AppBody(child: body),
    );
  }
}

/// Navy header with a centred gold [title], used by every inner screen. [onBack] defaults to
/// popping the route; pass [leading]/[trailing] for anything else (the slots keep the title centred).
class AppHeaderBar extends StatelessWidget {
  const AppHeaderBar({required this.title, this.onBack, this.leading, this.trailing, super.key});

  final String title;
  final VoidCallback? onBack;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    final palette = context.voicePalette;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [shell.headerTop, shell.headerBottom],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          leading ??
              IconButton(
                icon: Icon(Icons.arrow_forward_ios_rounded, color: palette.headerGold, size: 20),
                onPressed: onBack ?? () => context.pop(),
              ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headline(context).copyWith(color: palette.headerGold, fontSize: 21, height: 1.3),
            ),
          ),
          trailing ?? const SizedBox(width: 48),
        ],
      ),
    );
  }
}
