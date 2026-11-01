import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AccountActionIconRow extends StatelessWidget {
  const AccountActionIconRow({
    required this.onReminder,
    required this.onTransfer,
    required this.onMessage,
    required this.onCurrency,
    super.key,
  });

  final VoidCallback onReminder;
  final VoidCallback onTransfer;
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
          // Left to right: currency · messages (claim/remind the account holder) · reminder
          // (payment-date notification) · transfer (move an amount to another account).
          _ActionCircle(icon: Icons.chat_bubble_outline_rounded, onTap: onMessage),
          const SizedBox(width: 7),
          _ActionCircle(icon: Icons.alarm_rounded, onTap: onReminder),
          const SizedBox(width: 7),
          _ActionCircle(icon: Icons.swap_horiz_rounded, onTap: onTransfer),
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
