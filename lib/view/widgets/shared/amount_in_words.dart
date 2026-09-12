import 'package:flutter/material.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/arabic_number_words.dart';

class AmountInWords extends StatelessWidget {
  const AmountInWords({required this.amountText, super.key});
  final String amountText;

  @override
  Widget build(BuildContext context) {
    final parsed = double.tryParse(amountText.trim());
    if (parsed == null || parsed <= 0) return const SizedBox.shrink();

    final shell = context.shellColors;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        arabicNumberToWords(parsed),
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 11),
      ),
    );
  }
}
