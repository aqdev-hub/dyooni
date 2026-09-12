import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AccountActionIconRow extends StatelessWidget {
  const AccountActionIconRow({
    required this.onAddAction,
    required this.onShare,
    required this.onMessage,
    required this.onCurrency,
    super.key,
  });

  final VoidCallback onAddAction;
  final VoidCallback onShare;
  final VoidCallback onMessage;
  final VoidCallback onCurrency;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _ActionCircle(icon: Icons.attach_money_rounded, onTap: onCurrency),
          const SizedBox(width: 7),
          // The gold "+" is the one REAL action here — it opens Add Transaction. The other
          // three are honest placeholders (see account_details_screen.dart) — per your note,
          // these are meant to open their own popups later; that behavior isn't built yet.
          _ActionCircle(icon: Icons.chat_bubble_outline_rounded, onTap: onMessage),
          const SizedBox(width: 7),
          _ActionCircle(icon: Icons.alarm_rounded, onTap: onAddAction),
          const SizedBox(width: 7),
          _ActionCircle(icon: Icons.swap_horiz_rounded, onTap: onShare),
        ],
      ),
      ),
    );
  }
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.backgroundTop,
          border: Border.all(color: AppColors.gold, width: 1.2),
        ),
        child: Icon(icon, size: 20, color: AppColors.gold),
      ),
    );
  }
}
