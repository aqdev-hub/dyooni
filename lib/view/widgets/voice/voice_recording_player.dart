import 'package:flutter/material.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/voice/voice_audio_player.dart';
import '../../../data/models/transaction.dart';
import '../shared/app_snackbar.dart';

/// A deliberately compact addition to a transaction row; it does not alter the
/// existing account-details layout when no voice recording is present.
class VoiceRecordingPlayer extends StatefulWidget {
  const VoiceRecordingPlayer({required this.recording, super.key});
  final VoiceRecording recording;

  @override
  State<VoiceRecordingPlayer> createState() => _VoiceRecordingPlayerState();
}

class _VoiceRecordingPlayerState extends State<VoiceRecordingPlayer> {
  late final VoiceAudioPlayer _player;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player = VoiceAudioPlayer();
    _player.playerStateStream.listen((state) {
      if (mounted) setState(() => _playing = state.playing);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      await _player.toggle(widget.recording.path);
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, AppLocalizations.of(context)!.voiceAudioUnavailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final seconds = (widget.recording.durationMs / 1000).ceil();
    return Tooltip(
      message: l10n.voiceRecordingDuration(seconds),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 26, height: 26),
        onPressed: _toggle,
        icon: Icon(_playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, size: 23, color: shell.accent),
      ),
    );
  }
}
