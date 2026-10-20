import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/voice_palette.dart';
import '../../../logic/voice/voice_provider.dart';
import '../../../logic/settings/general_settings_provider.dart';
import '../../../data/models/general_settings.dart';
import '../../widgets/home/app_drawer.dart';
import '../../widgets/shared/main_bottom_nav.dart';
import '../../widgets/voice/voice_command_sheet.dart';
import '../../widgets/voice/whisper_model_gate.dart';

/// A real full-page recording experience, sharing the same header/drawer/bottom-nav chrome as
/// Home (see the reference design) rather than a modal pushed on top of it. It owns the
/// recording lifecycle so the recognizer never starts behind an unopened sheet.
///
/// In local mode [VoiceCommandSheet] is wrapped in [WhisperModelGate] — a Whisper speech model
/// must be on the device before the mic UI is usable. On every run after the first download the
/// gate is invisible (it resolves instantly from the files already on disk).
class VoiceCommandScreen extends ConsumerStatefulWidget {
  const VoiceCommandScreen({required this.bluetoothMode, super.key});
  final bool bluetoothMode;

  @override
  ConsumerState<VoiceCommandScreen> createState() => _VoiceCommandScreenState();
}

class _VoiceCommandScreenState extends ConsumerState<VoiceCommandScreen> {
  // No dispose() override on purpose: using `ref` while a ConsumerStatefulWidget unmounts throws
  // "Cannot use ref after the widget was disposed" (seen in the v5 device log). The controller is
  // an autoDispose provider whose own dispose() cancels the recording and frees the engine, so
  // leaving the screen is already handled there.

  void _goHome(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _showInfo(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: shell.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(l10n.voiceInfoTitle, style: AppTextStyles.title(dialogContext).copyWith(color: shell.textPrimary)),
        content: Text(l10n.voiceInfoBody, style: AppTextStyles.body(dialogContext).copyWith(color: shell.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.confirm, style: TextStyle(color: shell.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final palette = context.voicePalette;
    final isConfirming = ref.watch(voiceIsConfirmingProvider);

    return Scaffold(
      backgroundColor: palette.bodyTop,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [shell.headerTop, shell.headerBottom],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(Icons.menu_rounded, color: palette.headerGold, size: 30),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      isConfirming ? l10n.voiceConfirmTitle : l10n.voiceScreenTitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headline(context).copyWith(color: palette.headerGold, fontSize: 21, height: 1.3),
                    ),
                  ),
                  if (isConfirming)
                    // Reference stage 5: a left-pointing arrow in the info slot. `textDirection:
                    // ltr` pins the glyph to "←" in both languages; it cancels the pending entry.
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: palette.headerGold, size: 30, textDirection: TextDirection.ltr),
                      onPressed: () => unawaited(ref.read(voiceProvider.notifier).cancel()),
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.info_outline_rounded, color: palette.headerGold, size: 27),
                      onPressed: () => _showInfo(context),
                    ),
                ],
              ),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [palette.bodyTop, palette.bodyBottom]),
                ),
                child: CustomPaint(
                  painter: _WavesPainter(color: palette.wave),
                  child: ref.watch(generalSettingsProvider).when(
                        loading: () => Center(child: CircularProgressIndicator(color: shell.accent)),
                        error: (_, __) => _scrollable(WhisperModelGate(child: _sheet())),
                        data: (settings) => settings.voiceRecognitionMode == VoiceRecognitionMode.cloud
                            ? _scrollable(_sheet())
                            : _scrollable(WhisperModelGate(child: _sheet())),
                      ),
                ),
              ),
            ),
            MainBottomNav(
              activeTab: MainNavTab.voice,
              prominent: true,
              onHome: () => _goHome(context),
              onVoice: () {},
              onReports: () => context.push('/reports'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheet() => _EntryModeInit(bluetoothMode: widget.bluetoothMode, child: const VoiceCommandSheet());

  /// Gives the sheet at least the full body height (so its `Spacer` can pin the tip box to the
  /// bottom, as in the reference) while still scrolling on short screens.
  Widget _scrollable(Widget child) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(child: child),
          ),
        ),
      );
}

/// Two soft translucent waves along the bottom of the body (reference background flourish).
class _WavesPainter extends CustomPainter {
  const _WavesPainter({required this.color});
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
  bool shouldRepaint(covariant _WavesPainter oldDelegate) => oldDelegate.color != color;
}

/// Sets the entry mode once, from INSIDE the model gate — i.e. only once the recognizer's model is
/// available.
class _EntryModeInit extends ConsumerStatefulWidget {
  const _EntryModeInit({required this.bluetoothMode, required this.child});
  final bool bluetoothMode;
  final Widget child;

  @override
  ConsumerState<_EntryModeInit> createState() => _EntryModeInitState();
}

class _EntryModeInitState extends ConsumerState<_EntryModeInit> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(voiceProvider.notifier).setEntryMode(bluetoothMode: widget.bluetoothMode);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
