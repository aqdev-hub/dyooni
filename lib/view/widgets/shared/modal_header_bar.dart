import 'package:flutter/material.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ModalHeaderBar extends StatelessWidget {
  const ModalHeaderBar({required this.title, required this.onClose, super.key});
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(color: context.shellColors.headerBottom, borderRadius: BorderRadius.circular(7)),
      child: Row(
        children: [
          IconButton(
            icon: Image.asset('assets/icons/modal_back_arrow.png', width: 28, height: 22, fit: BoxFit.contain),
            onPressed: onClose,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.button(context).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(shape: BoxShape.circle, color: context.shellColors.accent),
            child: Icon(Icons.keyboard_outlined, size: 18, color: context.shellColors.headerBottom),
          ),
        ],
      ),
    );
  }
}
