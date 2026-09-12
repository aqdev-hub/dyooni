import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ChatTurn {
  const ChatTurn({required this.text, required this.fromAssistant});
  final String text;
  final bool fromAssistant;
}

/// Slide-3 illustration: a short Q&A conversation inside a rounded card, ending with a success
/// confirmation row. Static/decorative here — the real dialogue-confirmation flow ships in
/// Phase 3 (voice).
class OnboardingChatPreview extends StatelessWidget {
  const OnboardingChatPreview({
    required this.turns,
    required this.successLabel,
    super.key,
  });

  final List<ChatTurn> turns;
  final String successLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final turn in turns) ...[
            Align(
              alignment: turn.fromAssistant
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                constraints: const BoxConstraints(maxWidth: 220),
                decoration: BoxDecoration(
                  color: turn.fromAssistant
                      ? AppColors.gold
                      : AppColors.backgroundBottom,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  turn.text,
                  style: AppTextStyles.bodySecondary(context).copyWith(
                    color: turn.fromAssistant
                        ? AppColors.backgroundTop
                        : AppColors.textPrimary,
                    fontWeight:
                        turn.fromAssistant ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                child: const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                successLabel,
                style: AppTextStyles.bodySecondary(context).copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
