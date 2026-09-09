import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../logic/voice/voice_provider.dart';
import '../../widgets/home/app_drawer.dart';
import '../../widgets/shared/main_bottom_nav.dart';
import '../../widgets/voice/vosk_model_download_sheet.dart';
import '../../widgets/voice/voice_command_sheet.dart';

/// A real full-page recording experience, sharing the same header/drawer/bottom-nav chrome as
/// Home (see the reference design) rather than a modal pushed on top of it. It owns the
/// recording lifecycle so the recognizer never starts behind an unopened sheet.
///
/// CHANGED: [VoiceCommandSheet] is now wrapped in [VoskModelGate] — the offline Arabic speech
/// model must finish downloading/loading before the mic UI is usable at all. On every run after
/// the first successful download this gate is invisible (resolves instantly from local cache).
class VoiceCommandScreen extends ConsumerStatefulWidget {
  const VoiceCommandScreen({required this.bluetoothMode, super.key});
  final bool bluetoothMode;

  @override
  ConsumerState<VoiceCommandScreen> createState() => _VoiceCommandScreenState();
}

class _VoiceCommandScreenState extends ConsumerState<VoiceCommandScreen> {
  @override
  void initState() {
    super.initState();
    // Deliberately does NOT start listening or Bluetooth discovery here — see
    // VoiceController.setEntryMode's doc comment for why the idle state must be what's shown
    // first in both entry modes, and VoiceCommandSheet for where the actual start happens (a tap
    // on the mic circle).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceProvider.notifier).setEntryMode(bluetoothMode: widget.bluetoothMode);
    });
  }

  @override
  void dispose() {
    unawaited(ref.read(voiceProvider.notifier).cancel());
    super.dispose();
  }

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

    return Scaffold(
      backgroundColor: shell.background,
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
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(Icons.menu_rounded, color: shell.accent, size: 21),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      l10n.voiceScreenTitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.title(context).copyWith(color: shell.accent, fontSize: 17),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.info_outline_rounded, color: shell.accent, size: 20),
                    onPressed: () => _showInfo(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: VoskModelGate(child: const VoiceCommandSheet()),
              ),
            ),
            MainBottomNav(
              activeTab: MainNavTab.voice,
              onHome: () => _goHome(context),
              onVoice: () {},
              onReports: () => context.push('/reports'),
            ),
          ],
        ),
      ),
    );
  }
}
