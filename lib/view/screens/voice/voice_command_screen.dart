import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../logic/voice/voice_provider.dart';
import '../../widgets/voice/voice_command_sheet.dart';

/// A real full-page recording experience. It owns the recording lifecycle so
/// the recognizer never starts behind an unopened modal sheet.
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    return Scaffold(
      backgroundColor: shell.background,
      appBar: AppBar(
        backgroundColor: shell.headerBottom,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(l10n.voiceScreenTitle, style: AppTextStyles.title(context).copyWith(color: Colors.white)),
        leading: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded)),
      ),
      body: const Center(child: SingleChildScrollView(child: VoiceCommandSheet())),
    );
  }
}
