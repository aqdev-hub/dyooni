import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'labeled_field.dart';

/// Wraps [LabeledField] with an optional error message shown ABOVE it. [LabeledField]'s own box
/// never changes size whether or not an error is showing — the error lives in a separate Text
/// widget entirely, so it can never push/overflow the input the way relying on
/// `TextFormField.validator`'s built-in (below-the-field) error rendering did.
class ValidatedField extends StatelessWidget {
  const ValidatedField({
    required this.icon,
    required this.child,
    this.errorText,
    this.onIconTap,
    super.key,
  });

  final IconData icon;
  final Widget child;
  final String? errorText;
  final Future<void> Function()? onIconTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              errorText!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary(context).copyWith(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        LabeledField(icon: icon, onIconTap: onIconTap, child: child),
      ],
    );
  }
}
