import 'dart:async';

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
import '../../widgets/shared/app_screen_chrome.dart';
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

  /// The bottom bar behaves like tabs: "الرئيسية" always lands on Home. It used to pop ONE screen,
  /// so after Home → التقارير → صوتي it went back to التقارير instead of Home (and needed a second
  /// tap). `go` replaces the whole stack with Home.
  void _goHome(BuildContext context) => context.go('/home');

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
                  painter: AppWavesPainter(color: palette.wave),
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
              // Long press on the voice tab = Bluetooth-headset mode (only when nothing is recording).
              onVoiceLongPress: () {
                if (ref.read(voiceProvider).status == VoiceStatus.idle) {
                  unawaited(ref.read(voiceProvider.notifier).startBluetoothMode());
                }
              },
              // Tab-like: replace this screen instead of stacking another one on top of it.
              onReports: () => context.pushReplacement('/reports'),
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
      if (!mounted) return;
      final controller = ref.read(voiceProvider.notifier);
      controller.setEntryMode(bluetoothMode: widget.bluetoothMode);
      // Long-pressing the voice button on Home means "Bluetooth headset mode": connect now instead
      // of making the person tap the record button a second time.
      if (widget.bluetoothMode) unawaited(controller.startBluetoothMode());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
