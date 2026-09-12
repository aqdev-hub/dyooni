import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_shell_colors.dart';

/// Label + tappable colored ring, used to pick "له"/"عليه" on both Add Account and Add
/// Transaction. Shared so the two forms' direction picker can never visually drift apart.
class DirectionChoice extends StatelessWidget {
  const DirectionChoice({required this.label, required this.color, required this.selected, required this.onTap, super.key});
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Text(label, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary)),
            const SizedBox(width: 6),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.6),
                color: selected ? color : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
