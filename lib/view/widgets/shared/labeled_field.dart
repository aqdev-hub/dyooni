import 'package:flutter/material.dart';
import '../../../core/theme/app_shell_colors.dart';

/// Bordered container with a leading icon, wrapping a form control (TextFormField, dropdown, date
/// picker trigger...). Shared by Add Account and Add Transaction so their field styling can never
/// drift apart.
class LabeledField extends StatefulWidget {
  const LabeledField({required this.icon, required this.child, this.onIconTap, super.key});
  final IconData icon;
  final Widget child;
  final Future<void> Function()? onIconTap;

  @override
  State<LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<LabeledField> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: shell.surface, borderRadius: BorderRadius.circular(5), border: Border.all(color: shell.border)),
            child: widget.child,
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: () async {
            setState(() => _active = true);
            if (widget.onIconTap != null) {
              await widget.onIconTap!();
            }
            if (mounted) setState(() => _active = false);
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _active ? shell.accent : shell.headerBottom),
            child: Icon(widget.icon, size: 18, color: _active ? shell.headerBottom : shell.accent),
          ),
        ),
      ],
    );
  }
}
