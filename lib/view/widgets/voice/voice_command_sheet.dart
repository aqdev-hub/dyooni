import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/currencies.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/voice_palette.dart';
import '../../../data/models/account.dart';
import '../../../data/models/general_settings.dart';
import '../../../logic/accounts/accounts_provider.dart';
import '../../../logic/settings/direction_labels.dart';
import '../../../logic/settings/general_settings_provider.dart';
import '../../../logic/voice/voice_provider.dart';

/// Statuses rendered as "the mic circle + a headline/subtitle pair" (reference states 1–4, plus
/// the Bluetooth handshake steps until their own dedicated treatment lands). Every other status
/// swaps the circle out for a dedicated icon composition (processing/clarification/confirmation/
/// saving/success/error) — never both at once, matching the reference exactly.
bool _isMicFamily(VoiceStatus status) => const {
      VoiceStatus.idle,
      VoiceStatus.preparing,
      VoiceStatus.listening,
      VoiceStatus.paused,
      VoiceStatus.bluetoothConnecting,
      VoiceStatus.bluetoothConnected,
      VoiceStatus.bluetoothWaitingWakeWord,
      VoiceStatus.bluetoothWakeWordDetected,
      VoiceStatus.bluetoothListeningCommand,
    }.contains(status);

/// Resolves what tapping the mic circle should do for the CURRENT status — exhaustive over every
/// [VoiceStatus] so an in-between state (e.g. mid Bluetooth handshake) can never fall through to
/// the wrong action. Idle dispatches by entry mode (see VoiceController.setEntryMode); listening
/// states stop-and-analyze; every other status (preparing/processing/saving/paused/the Bluetooth
/// handshake steps/etc.) ignores taps — paused resumes via its own dedicated button, not the
/// circle, matching the reference (the circle shows a static pause glyph there, not a tappable
/// affordance).
VoidCallback? _resolveMicTap(VoiceState state, VoiceController controller) {
  return switch (state.status) {
    VoiceStatus.idle => state.bluetoothMode ? controller.startBluetoothMode : controller.startShortPress,
    VoiceStatus.listening || VoiceStatus.bluetoothListeningCommand => controller.stopAndAnalyze,
    _ => null,
  };
}

/// Whether the recognizer is actively engaged right now — used to disable the recognition
/// language toggle mid-session (switching languages mid-sentence wouldn't apply until the next
/// recording anyway, which would be confusing to allow).
bool _recognizerBusy(VoiceStatus status) => const {
      VoiceStatus.preparing,
      VoiceStatus.listening,
      VoiceStatus.paused,
      VoiceStatus.confirmationListening,
      VoiceStatus.saving,
      VoiceStatus.bluetoothConnecting,
      VoiceStatus.bluetoothConnected,
      VoiceStatus.bluetoothWaitingWakeWord,
      VoiceStatus.bluetoothWakeWordDetected,
      VoiceStatus.bluetoothListeningCommand,
    }.contains(status);

/// Maps an error status + code to the right localized message. `errorCode` is checked first (not
/// just the status) because both VoiceStatus.error and VoiceStatus.bluetoothDisconnected can now
/// carry any of these codes — see VoiceController._onSpeechError.
String _voiceErrorMessage(AppLocalizations l10n, String? code) => switch (code) {
      'connection' => l10n.voiceBluetoothDisconnected,
      'permission' => l10n.voiceNoSpeechPermission,
      'network' => l10n.voiceNetworkError,
      _ => l10n.voiceRecognitionError,
    };

class VoiceCommandSheet extends ConsumerWidget {
  const VoiceCommandSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(voiceProvider);
    final controller = ref.read(voiceProvider.notifier);
    final settings = ref.watch(generalSettingsProvider).value;
    final creditLabel = resolveCreditLabel(l10n, settings);
    final debitLabel = resolveDebitLabel(l10n, settings);
    final status = state.status;
    final isRecording = status == VoiceStatus.listening || status == VoiceStatus.bluetoothListeningCommand;

    final Widget content;
    if (isRecording) {
      content = _ListeningView(state: state, controller: controller);
    } else if (_isMicFamily(status)) {
      content = _IdleView(state: state, controller: controller);
    } else if (status == VoiceStatus.processing) {
      content = _ThinkingView(
        icon: const _AssetIcon(asset: 'assets/icons/voice_brain.png', fallback: Icons.psychology_rounded, size: 135),
        title: l10n.voiceProcessing,
        subtitle: l10n.voiceProcessingSubtitle,
        step: state.processingStep,
      );
    } else if (status == VoiceStatus.saving) {
      content = _ThinkingView(
        icon: const _AssetIcon(asset: 'assets/icons/voice_saving.png', fallback: Icons.cloud_upload_rounded, size: 120),
        title: l10n.voiceSavingHint,
        subtitle: l10n.voiceProcessingSubtitle,
      );
    } else if (status == VoiceStatus.needsClarification) {
      content = _ClarificationView(state: state, controller: controller, creditLabel: creditLabel, debitLabel: debitLabel);
    } else if (status == VoiceStatus.awaitingConfirmation || status == VoiceStatus.confirmationListening) {
      content = _ConfirmationView(state: state, controller: controller, creditLabel: creditLabel, debitLabel: debitLabel);
    } else if (status == VoiceStatus.success) {
      content = Padding(padding: const EdgeInsets.fromLTRB(20, 28, 20, 20), child: _SuccessCard(state: state, controller: controller));
    } else {
      content = Padding(padding: const EdgeInsets.fromLTRB(20, 28, 20, 20), child: _ErrorCard(state: state, controller: controller));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        content,
        const Spacer(),
        if (isRecording) const _TipBox() else const SizedBox(height: 8),
      ],
    );
  }
}

/// The person's own PNG from `assets/icons/`; if the file is missing the closest Flutter icon is
/// drawn instead so the screen never breaks. [width]/[height] are the box the image is fitted
/// into (aspect ratio preserved, nothing cropped).
class _AssetIcon extends StatelessWidget {
  const _AssetIcon({required this.asset, required this.fallback, double? size, double? width, double? height})
      : width = width ?? size,
        height = height ?? size;
  final String asset;
  final IconData fallback;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final palette = context.voicePalette;
    final box = (height ?? width ?? 100);
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: BoxFit.contain,
      // The box is intentionally larger than the visible glyph (see callers), so the Flutter
      // fallback icon is drawn smaller than the box.
      errorBuilder: (_, __, ___) => Icon(fallback, size: box * 0.42, color: palette.gold),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.voicePalette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.headline(context).copyWith(color: palette.textPrimary, fontSize: 24, height: 1.3),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(context).copyWith(color: palette.textSecondary, fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Stage 1 — idle ─────────────────────────────

class _IdleView extends StatelessWidget {
  const _IdleView({required this.state, required this.controller});
  final VoiceState state;
  final VoiceController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.voicePalette;
    final status = state.status;
    final isIdle = status == VoiceStatus.idle;
    final (String title, String subtitle) = switch (status) {
      VoiceStatus.idle => (l10n.voiceStartListening, l10n.voiceIdleSubtitle),
      VoiceStatus.preparing => (l10n.voicePreparing, l10n.voiceIdleSubtitle),
      VoiceStatus.paused => (l10n.voicePausedTitle, l10n.voicePausedHint),
      VoiceStatus.bluetoothConnecting => (l10n.voiceBluetoothConnecting, l10n.voiceIdleSubtitle),
      VoiceStatus.bluetoothConnected => (l10n.voiceBluetoothConnected, l10n.voiceIdleSubtitle),
      VoiceStatus.bluetoothWaitingWakeWord => (l10n.voiceBluetoothWaitingWakeWord, l10n.voiceIdleSubtitle),
      VoiceStatus.bluetoothWakeWordDetected => (l10n.voiceBluetoothWakeWordDetected, l10n.voiceIdleSubtitle),
      _ => (l10n.voiceStartListening, l10n.voiceIdleSubtitle),
    };
    final isPaused = status == VoiceStatus.paused;
    final isBusy = status != VoiceStatus.idle && !isPaused;

    return Column(
      children: [
        const SizedBox(height: 30),
        const _IdleDecoration(),
        const SizedBox(height: 26),
        _Headline(title: title, subtitle: subtitle),
        const SizedBox(height: 11),
        GestureDetector(
          onTap: _resolveMicTap(state, controller),
          child: _BigMic(icon: isPaused ? Icons.play_arrow_rounded : Icons.mic_rounded, busy: isBusy),
        ),
        const SizedBox(height: 18),
        if (isIdle || status == VoiceStatus.preparing)
          Text(
            l10n.voiceLongPressHint,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(context).copyWith(color: palette.textSecondary, fontSize: 14),
          ),
        const SizedBox(height: 10),
        _RecordingTimer(state: state),
        const SizedBox(height: 12),
        _PillRow(state: state, controller: controller),
        if (state.draft != null || isPaused || isBusy) ...[
          const SizedBox(height: 12),
          _CancelPill(controller: controller),
        ],
        if (state.transcript.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _TranscriptCard(text: state.transcript)),
        ],
      ],
    );
  }
}

/// Reference top flourish: a flat gold microphone flanked by two small gold level-bar groups.
class _IdleDecoration extends StatelessWidget {
  const _IdleDecoration();

  @override
  Widget build(BuildContext context) {
    final palette = context.voicePalette;
    Widget bars(List<double> heights) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final h in heights)
              Container(
                width: 3,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(color: palette.gold, borderRadius: BorderRadius.circular(2)),
              ),
          ],
        );
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          bars(const [10, 20, 30, 20, 10]),
          const SizedBox(width: 12),
          Icon(Icons.mic_rounded, size: 56, color: palette.gold),
          const SizedBox(width: 12),
          bars(const [10, 20, 30, 20, 10]),
        ],
      ),
    );
  }
}

/// The big navy microphone: soft gold halo (215) → thin gold ring (191) → navy disc (168).
class _BigMic extends StatelessWidget {
  const _BigMic({required this.icon, required this.busy});
  final IconData icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.voicePalette;
    return SizedBox(
      width: 215,
      height: 215,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 215,
            height: 215,
            decoration: BoxDecoration(shape: BoxShape.circle, color: palette.goldGlow.withValues(alpha: 0.55)),
          ),
          Container(
            width: 191,
            height: 191,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.goldGlow.withValues(alpha: 0.35),
              border: Border.all(color: palette.gold, width: 2),
            ),
          ),
          Container(
            width: 168,
            height: 168,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [palette.micTop, palette.micBottom]),
              boxShadow: [BoxShadow(color: palette.micBottom.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            alignment: Alignment.center,
            child: busy
                ? const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                : Icon(icon, size: 84, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Stage 2 — listening ─────────────────────────────

class _ListeningView extends StatelessWidget {
  const _ListeningView({required this.state, required this.controller});
  final VoiceState state;
  final VoiceController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.voicePalette;
    final resumed = state.elapsedBeforePause > Duration.zero;
    return Column(
      children: [
        const SizedBox(height: 20),
        const _EarBadge(),
        const SizedBox(height: 16),
        _Headline(
          title: l10n.voiceListening,
          subtitle: resumed ? l10n.voiceContinueSpeakingHint : l10n.voiceListeningSubtitle,
        ),
        const SizedBox(height: 14),
        const _Waveform(),
        const SizedBox(height: 14),
        GestureDetector(onTap: controller.stopAndAnalyze, child: const _StopButton()),
        const SizedBox(height: 8),
        Text(
          l10n.voiceStopLabel,
          style: AppTextStyles.title(context).copyWith(color: palette.stopRed, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        _RecordingTimer(state: state),
        const SizedBox(height: 8),
        _PillRow(state: state, controller: controller),
        const SizedBox(height: 14),
        _CancelPill(controller: controller),
        if (state.transcript.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _TranscriptCard(text: state.transcript)),
        ],
        const SizedBox(height: 14),
      ],
    );
  }
}

/// The listening illustration: the person's own PNG (navy disc, gold ear, sound arcs on both
/// sides) — replaces the earlier version that was assembled from a Container, an image and a
/// CustomPaint. One image means one asset to restyle and no layout maths to maintain.
class _EarBadge extends StatelessWidget {
  const _EarBadge();

  @override
  Widget build(BuildContext context) {
    return const _AssetIcon(asset: 'assets/icons/voice_ear.png', fallback: Icons.hearing_rounded, width: 200, height: 104);
  }
}

/// Decorative level bars under the headline (fixed heights — the recorder exposes no live
/// amplitude stream, and animating fake levels would misrepresent what the microphone hears).
class _Waveform extends StatelessWidget {
  const _Waveform();

  static final List<double> _heights = List<double>.generate(43, (i) {
    final x = (i - 21) / 21;
    final envelope = 1 - x.abs();
    const jitter = [1.0, 0.45, 0.8, 0.35, 0.95, 0.55, 0.7];
    return 4 + 38 * envelope * envelope * jitter[i % jitter.length];
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.voicePalette;
    return SizedBox(
      width: 290,
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final h in _heights)
            Container(
              width: 3,
              height: h,
              decoration: BoxDecoration(color: palette.gold, borderRadius: BorderRadius.circular(2)),
            ),
        ],
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton();

  @override
  Widget build(BuildContext context) {
    final palette = context.voicePalette;
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(shape: BoxShape.circle, color: palette.stopGlow.withValues(alpha: 0.45)),
      alignment: Alignment.center,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [palette.stopRed.withValues(alpha: 0.85), palette.stopRed]),
          boxShadow: [BoxShadow(color: palette.stopRed.withValues(alpha: 0.35), blurRadius: 12, spreadRadius: 1)],
        ),
        alignment: Alignment.center,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)),
        ),
      ),
    );
  }
}

class _TipBox extends StatelessWidget {
  const _TipBox();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.voicePalette;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      // No fixed height any more: the text wraps to 3 lines on narrow phones and was being
      // cut off. The box now grows to fit, and sits 18 above the bottom bar.
      constraints: const BoxConstraints(minHeight: 58),
      decoration: BoxDecoration(
        color: palette.tipBackground,
        border: Border.all(color: palette.tipBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.voiceTipText,
              style: AppTextStyles.body(context).copyWith(color: palette.textSecondary, fontSize: 12.5, height: 1.6),
            ),
          ),
          Container(width: 1, height: 38, color: palette.tipBorder, margin: const EdgeInsets.symmetric(horizontal: 12)),
          const SizedBox(
            width: 56,
            height: 44,
            child: OverflowBox(
              maxWidth: 60,
              maxHeight: 60,
              child: _AssetIcon(asset: 'assets/icons/voice_tip_bulb.png', fallback: Icons.lightbulb_rounded, size: 58),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Shared controls ─────────────────────────────

/// mm:ss display (reference: bold navy digits + outlined clock). Ticks only while recording and
/// freezes at the reached value when paused (see VoiceController.pauseRecording).
class _RecordingTimer extends StatefulWidget {
  const _RecordingTimer({required this.state});
  final VoiceState state;

  @override
  State<_RecordingTimer> createState() => _RecordingTimerState();
}

class _RecordingTimerState extends State<_RecordingTimer> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _RecordingTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  bool get _isRunning => widget.state.status == VoiceStatus.listening || widget.state.status == VoiceStatus.bluetoothListeningCommand;

  void _syncTicker() {
    if (_isRunning && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!_isRunning && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.voicePalette;
    final startedAt = widget.state.recordingStartedAt;
    final liveElapsed = _isRunning && startedAt != null ? DateTime.now().difference(startedAt) : Duration.zero;
    final total = widget.state.elapsedBeforePause + liveElapsed;
    final minutes = total.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = total.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule_outlined, size: 20, color: palette.textPrimary),
        const SizedBox(width: 6),
        Text(
          '$minutes:$seconds',
          textDirection: TextDirection.ltr,
          style: AppTextStyles.title(context).copyWith(color: palette.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _PillRow extends StatelessWidget {
  const _PillRow({required this.state, required this.controller});
  final VoiceState state;
  final VoiceController controller;

  @override
  Widget build(BuildContext context) {
    final busy = _recognizerBusy(state.status);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(child: _RecognitionLanguagePill(disabled: busy)),
          const SizedBox(width: 8),
          Expanded(child: _RecognitionProviderPill(disabled: busy)),
          const SizedBox(width: 8),
          Expanded(child: _PausePill(state: state, controller: controller)),
        ],
      ),
    );
  }
}

/// White rounded pill with a light-gold border (reference toolbar buttons).
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.onTap, this.iconAfterLabel = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool iconAfterLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.voicePalette;
    final iconWidget = Icon(icon, size: icon == Icons.pause_rounded ? 18 : 20, color: palette.textPrimary);
    final text = Flexible(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.button(context).copyWith(color: palette.textPrimary, fontSize: 14),
      ),
    );
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: palette.pillBorder, width: 1.2),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: iconAfterLabel
                  ? [text, const SizedBox(width: 6), iconWidget]
                  : [iconWidget, const SizedBox(width: 6), text],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecognitionLanguagePill extends ConsumerWidget {
  const _RecognitionLanguagePill({required this.disabled});
  final bool disabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = ref.watch(voiceRecognitionLanguageProvider) == 'ar';
    return _Pill(
      icon: Icons.language_rounded,
      label: isArabic ? l10n.voiceLanguageArabic : l10n.voiceLanguageEnglish,
      onTap: disabled ? null : () => ref.read(voiceRecognitionLanguageProvider.notifier).state = isArabic ? 'en' : 'ar',
    );
  }
}

/// Provider selection (local / cloud) is persisted in general settings and disabled during a
/// live utterance so one command can never be split across two recognizers.
class _RecognitionProviderPill extends ConsumerWidget {
  const _RecognitionProviderPill({required this.disabled});
  final bool disabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.voicePalette;
    final current = ref.watch(generalSettingsProvider).value?.voiceRecognitionMode ?? VoiceRecognitionMode.local;
    return PopupMenuButton<VoiceRecognitionMode>(
      enabled: !disabled,
      color: palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tooltip: l10n.voiceRecognitionModeTitle,
      onSelected: (mode) => ref.read(voiceProvider.notifier).setRecognitionMode(mode),
      itemBuilder: (_) => [
        PopupMenuItem(value: VoiceRecognitionMode.local, child: Text(l10n.voiceRecognitionModeLocal, style: TextStyle(color: palette.textPrimary))),
        PopupMenuItem(value: VoiceRecognitionMode.cloud, child: Text(l10n.voiceRecognitionModeCloud, style: TextStyle(color: palette.textPrimary))),
      ],
      child: IgnorePointer(
        child: _Pill(
          icon: current == VoiceRecognitionMode.local ? Icons.phone_android_rounded : Icons.cloud_rounded,
          label: current == VoiceRecognitionMode.local ? l10n.voiceRecognitionModeLocal : l10n.voiceRecognitionModeCloud,
          onTap: () {},
        ),
      ),
    );
  }
}

class _PausePill extends StatelessWidget {
  const _PausePill({required this.state, required this.controller});
  final VoiceState state;
  final VoiceController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRecording = state.status == VoiceStatus.listening || state.status == VoiceStatus.bluetoothListeningCommand;
    final isPaused = state.status == VoiceStatus.paused;
    return _Pill(
      icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
      label: isPaused ? l10n.voiceResumeAction : l10n.voicePauseAction,
      onTap: isRecording ? controller.pauseRecording : (isPaused ? controller.resumeRecording : null),
      iconAfterLabel: true,
    );
  }
}

/// Red-outlined "إلغاء" pill, aligned to the start edge (reference stage 2).
class _CancelPill extends StatelessWidget {
  const _CancelPill({required this.controller});
  final VoiceController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.voicePalette;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16),
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: palette.stopRed, width: 1.2),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(17),
              onTap: controller.cancel,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cancel_outlined, size: 18, color: palette.stopRed),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context)!.cancel,
                      style: AppTextStyles.button(context).copyWith(color: palette.stopRed, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.voicePalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border.all(color: palette.tipBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.voiceTranscriptLabel, style: AppTextStyles.bodySecondary(context).copyWith(color: palette.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(text, style: AppTextStyles.body(context).copyWith(color: palette.textPrimary)),
        ],
      ),
    );
  }
}

// ───────────────────────────── Stage 3 — processing ─────────────────────────────

class _ThinkingView extends StatelessWidget {
  const _ThinkingView({required this.icon, required this.title, required this.subtitle, this.step});
  final Widget icon;
  final String title;
  final String subtitle;

  /// Real progress (see VoiceState.processingStep); `null` hides the step list.
  final int? step;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.voicePalette;
    Widget ring(double size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: palette.goldSoft, width: 1.6)),
        );
    return Column(
      children: [
        const SizedBox(height: 16),
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [ring(160), ring(124), icon],
          ),
        ),
        const SizedBox(height: 24),
        _Headline(title: title, subtitle: subtitle),
        if (step != null) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 27),
            child: Column(
              children: [
                _StepRow(label: l10n.voiceStepAnalyze, state: _stepState(0, step!)),
                const SizedBox(height: 6),
                _StepRow(label: l10n.voiceStepExtract, state: _stepState(1, step!)),
                const SizedBox(height: 6),
                _StepRow(label: l10n.voiceStepValidate, state: _stepState(2, step!)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static _StepState _stepState(int index, int current) =>
      index < current ? _StepState.done : (index == current ? _StepState.active : _StepState.pending);
}

enum _StepState { done, active, pending }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state});
  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.voicePalette;
    final Widget indicator = switch (state) {
      _StepState.done => Container(
          width: 27,
          height: 27,
          decoration: BoxDecoration(shape: BoxShape.circle, color: palette.success),
          child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
        ),
      _StepState.active => SizedBox(
          width: 27,
          height: 27,
          child: CircularProgressIndicator(strokeWidth: 4, color: palette.textPrimary, backgroundColor: palette.tipBorder),
        ),
      _StepState.pending => Container(
          width: 27,
          height: 27,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: palette.tipBorder, width: 3)),
        ),
    };
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          indicator,
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body(context).copyWith(color: palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Stage 4 — clarification ─────────────────────────────

class _ClarificationView extends StatelessWidget {
  const _ClarificationView({required this.state, required this.controller, required this.creditLabel, required this.debitLabel});
  final VoiceState state;
  final VoiceController controller;
  final String creditLabel;
  final String debitLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.voicePalette;
    final code = state.errorCode;
    final (String question, String hint) = switch (code) {
      'direction' => (l10n.voiceQuestionDirection, l10n.voiceQuestionDirectionHint),
      'amount' => state.draft?.amountUncertain == true
          ? (l10n.voiceQuestionAmountUncertain, l10n.voiceQuestionAmountUncertainHint)
          : (l10n.voiceQuestionAmount, l10n.voiceQuestionAmountHint),
      'accountName' => (l10n.voiceQuestionAccountName, l10n.voiceQuestionAccountNameHint),
      'sameAccount' => (
          l10n.voiceQuestionSameAccount,
          l10n.voiceQuestionSameAccountHint(state.suggestedAccount?.name ?? ''),
        ),
      'currency' => (l10n.voiceQuestionCurrency, l10n.voiceQuestionCurrencyHint),
      'noSpeech' => (l10n.voiceQuestionNoSpeech, l10n.voiceQuestionNoSpeechHint),
      _ => (l10n.voiceQuestionAccount, l10n.voiceQuestionAccountHint),
    };

    final List<Widget> actions;
    if (code == 'direction') {
      actions = [
        _ChoiceButton(label: debitLabel, primary: true, onTap: () => controller.selectDirection(AccountDirection.debit)),
        const SizedBox(height: 13),
        _ChoiceButton(label: creditLabel, primary: false, onTap: () => controller.selectDirection(AccountDirection.credit)),
      ];
    } else if (code == 'sameAccount') {
      actions = [
        _ChoiceButton(label: l10n.voiceYes, primary: true, onTap: () => controller.answerSameAccount(same: true)),
        const SizedBox(height: 13),
        _ChoiceButton(label: l10n.voiceNo, primary: false, onTap: () => controller.answerSameAccount(same: false)),
      ];
    } else {
      actions = [
        if (code == 'account') ...[
          _AccountChoices(onSelected: controller.selectAccount),
          const SizedBox(height: 10),
        ],
        _ChoiceButton(label: l10n.voiceRetry, primary: false, icon: Icons.refresh_rounded, onTap: controller.retry),
      ];
    }

    return Column(
      children: [
        const _ClarifyBadge(),
        const SizedBox(height: 10),
        _Headline(title: l10n.voiceClarifyTitle, subtitle: l10n.voiceClarifySubtitle),
        const SizedBox(height: 22),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 23),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          constraints: const BoxConstraints(minHeight: 87),
          decoration: BoxDecoration(
            color: palette.questionBackground,
            border: Border.all(color: palette.questionBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question,
                      style: AppTextStyles.headline(context).copyWith(color: palette.textPrimary, fontSize: 18, height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hint,
                      style: AppTextStyles.body(context).copyWith(color: palette.textSecondary, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.mic_rounded, size: 40, color: palette.textPrimary),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 38),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: actions),
        ),
        if (code != 'noSpeech' && state.transcript.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 23), child: _TranscriptCard(text: state.transcript)),
        ],
        const SizedBox(height: 14),
      ],
    );
  }
}

/// The clarification illustration: the person's own PNG (gold "?" medal with rays).
class _ClarifyBadge extends StatelessWidget {
  const _ClarifyBadge();

  @override
  Widget build(BuildContext context) {
    return const _AssetIcon(asset: 'assets/icons/voice_clarify.png', fallback: Icons.help_outline_rounded, width: 190, height: 140);
  }
}

/// Pill button: gold gradient (primary) or white with a gold outline, with a mic glyph (the
/// answer can also be spoken) unless [icon] says otherwise.
class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({required this.label, required this.primary, required this.onTap, this.icon = Icons.mic_rounded});
  final String label;
  final bool primary;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.voicePalette;
    final foreground = primary ? palette.onGold : palette.textPrimary;
    return Container(
      height: primary ? 48 : 44,
      decoration: BoxDecoration(
        gradient: primary ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [palette.goldButtonTop, palette.goldButtonBottom]) : null,
        color: primary ? null : palette.card,
        borderRadius: BorderRadius.circular(24),
        border: primary ? null : Border.all(color: palette.gold, width: 2),
        boxShadow: primary ? [BoxShadow(color: palette.goldButtonBottom.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))] : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: primary ? 28 : 24, color: foreground),
              const SizedBox(width: 14),
              Text(
                label,
                style: AppTextStyles.button(context).copyWith(color: foreground, fontSize: primary ? 18 : 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountChoices extends ConsumerWidget {
  const _AccountChoices({required this.onSelected});
  final ValueChanged<Account> onSelected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    if (accounts.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 4, alignment: WrapAlignment.center, children: [
      for (final account in accounts)
        ActionChip(
          label: Text(account.name, style: TextStyle(color: context.shellColors.textPrimary)),
          backgroundColor: context.shellColors.surface,
          side: BorderSide(color: context.shellColors.border),
          onPressed: () => onSelected(account),
        ),
    ]);
  }
}

// ───────────────────────────── Stage 5 — confirmation ─────────────────────────────

String _groupThousands(double amount) {
  final isWhole = amount == amount.roundToDouble();
  final text = isWhole ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  final parts = text.split('.');
  final grouped = parts.first.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
}

class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView({required this.state, required this.controller, required this.creditLabel, required this.debitLabel});
  final VoiceState state;
  final VoiceController controller;
  final String creditLabel;
  final String debitLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.voicePalette;
    final draft = state.draft!;
    // Safe by construction: this view only renders in awaitingConfirmation/confirmationListening,
    // which the controller never reaches while the direction or amount is still missing.
    final direction = draft.direction! == AccountDirection.credit ? creditLabel : debitLabel;
    final isListening = state.status == VoiceStatus.confirmationListening;
    final matched = state.account;
    final accountName = matched?.name ?? draft.accountName!;
    final currency = currencies.firstWhere((c) => c.code == draft.currency, orElse: () => currencies.first).label(l10n);
    final date = '${draft.date.year}-${draft.date.month.toString().padLeft(2, '0')}-${draft.date.day.toString().padLeft(2, '0')}';
    final statusLine = isListening
        ? l10n.voiceConfirmationListening
        : (state.errorCode == 'confirmation' ? l10n.voiceConfirmationNotUnderstood : null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(21, 24, 21, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(17, 14, 17, 10),
            decoration: BoxDecoration(
              color: palette.summaryBackground,
              border: Border.all(color: palette.summaryBorder, width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 30, color: palette.goldButtonBottom),
                    const SizedBox(width: 10),
                    Text(l10n.voiceSummaryTitle, style: AppTextStyles.body(context).copyWith(color: palette.textPrimary, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                _SummaryRow(label: l10n.voiceNameLabel, value: accountName),
                if (matched == null)
                  Text(
                    l10n.voiceAccountWillBeCreated,
                    style: AppTextStyles.bodySecondary(context).copyWith(color: palette.textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                _SummaryRow(label: l10n.amountLabel, value: '${_groupThousands(draft.amount!)} $currency'),
                _SummaryRow(label: l10n.voiceDirectionLabel, value: direction),
                _SummaryRow(label: l10n.detailsLabel, value: draft.details ?? '—'),
                _SummaryRow(label: l10n.dateLabel, value: date),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            l10n.voiceConfirmQuestion,
            textAlign: TextAlign.center,
            style: AppTextStyles.headline(context).copyWith(color: palette.textPrimary, fontSize: 22, height: 1.3),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 78,
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _EditButton(onTap: controller.startEdit),
                ),
                const SizedBox(width: 22),
                Expanded(
                  flex: 5,
                  child: _SaveButton(onTap: controller.confirmByTap),
                ),
              ],
            ),
          ),
          if (statusLine != null) ...[
            const SizedBox(height: 10),
            Text(
              statusLine,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(context).copyWith(color: palette.goldButtonBottom, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            l10n.voiceYouCanSay,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(context).copyWith(color: palette.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.voiceYouCanSayExamples,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(context).copyWith(color: palette.textSecondary, fontSize: 13),
          ),
          if (!isListening && state.errorCode == 'permission')
            Center(
              child: IconButton(
                onPressed: controller.startVoiceConfirmation,
                icon: Icon(Icons.mic_rounded, color: palette.goldButtonBottom),
                tooltip: l10n.voiceConfirmationHint,
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.voicePalette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 92,
            child: Text('$label:', style: AppTextStyles.body(context).copyWith(color: palette.textPrimary, fontSize: 16)),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.headline(context).copyWith(color: palette.textPrimary, fontSize: 20, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.voicePalette;
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.gold, width: 1.5),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_rounded, size: 26, color: palette.textPrimary),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)!.voiceEdit,
                style: AppTextStyles.button(context).copyWith(color: palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.voicePalette;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [palette.goldDeepTop, palette.goldDeepBottom]),
        boxShadow: [BoxShadow(color: palette.goldDeepBottom.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mic_rounded, size: 34, color: palette.onGold),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.voiceConfirmYes, style: AppTextStyles.button(context).copyWith(color: palette.onGold, fontSize: 20, fontWeight: FontWeight.w700, height: 1.2)),
                  Text(l10n.voiceConfirmSave, style: AppTextStyles.button(context).copyWith(color: palette.onGold, fontSize: 17, fontWeight: FontWeight.w700, height: 1.2)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reference state 10 — green checkmark, then the SHORT-PRESS-ONLY "start another recording"
/// action. Bluetooth mode deliberately keeps its own different framing here (continuing to
/// listen for the wake word is genuinely correct for hands-free use) — see
/// VoiceController.startAnother's doc comment for why the two modes diverge on purpose.
class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.state, required this.controller});
  final VoiceState state;
  final VoiceController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    return Column(
      children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 56),
        const SizedBox(height: 10),
        Text(l10n.voiceSaved, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        if (state.bluetoothMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Text(l10n.voiceBluetoothWaitingWakeWord, textAlign: TextAlign.center, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textPrimary)),
          )
        else
          FilledButton.icon(
            onPressed: controller.startAnother,
            icon: const Icon(Icons.mic_rounded, size: 18),
            label: Text(l10n.voiceRecordAnother),
          ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.state, required this.controller});
  final VoiceState state;
  final VoiceController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Text(_voiceErrorMessage(l10n, state.errorCode), textAlign: TextAlign.center, style: AppTextStyles.bodySecondary(context).copyWith(color: AppColors.error)),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: controller.retry, icon: const Icon(Icons.refresh_rounded), label: Text(l10n.voiceBluetoothRetry)),
      ],
    );
  }
}
