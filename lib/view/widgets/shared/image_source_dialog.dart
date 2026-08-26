import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Lets the user explicitly choose the camera or gallery before image_picker is called.
Future<XFile?> showImageSourceDialog(BuildContext context) => showDialog<XFile?>(
      context: context,
      builder: (_) => const _ImageSourceDialog(),
    );

class _ImageSourceDialog extends StatefulWidget {
  const _ImageSourceDialog();

  @override
  State<_ImageSourceDialog> createState() => _ImageSourceDialogState();
}

class _ImageSourceDialogState extends State<_ImageSourceDialog> {
  ImageSource _source = ImageSource.camera;
  bool _picking = false;

  Future<void> _confirm() async {
    setState(() => _picking = true);
    try {
      final image = await ImagePicker().pickImage(source: _source, imageQuality: 85);
      if (mounted) Navigator.of(context).pop(image);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    return AlertDialog(
      backgroundColor: shell.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
      title: Row(
        children: [
          Expanded(
            child: Text(
              l10n.imageOptionsTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.title(context).copyWith(color: shell.textPrimary),
            ),
          ),
          IconButton(
            onPressed: _picking ? null : () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, color: shell.textSecondary),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        // `RadioListTile.groupValue`/`.onChanged` are deprecated on newer Flutter — the group's
        // shared state now comes from this ancestor `RadioGroup<ImageSource>` instead, with each
        // tile below only specifying its own `value`.
        children: [
          RadioGroup<ImageSource>(
            groupValue: _source,
            // `RadioGroup.onChanged` takes a non-nullable `ValueChanged<ImageSource?>` — it can't
            // be turned off by passing `null` the way a plain `Radio`/`RadioListTile.onChanged`
            // could. The "disabled while picking" behavior is now handled inside the callback
            // instead: while `_picking` is true, a tap simply does nothing.
            onChanged: (value) {
              if (_picking || value == null) return;
              setState(() => _source = value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ImageSource>(
                  value: ImageSource.camera,
                  activeColor: shell.accent,
                  title: Text(
                    l10n.imageSourceCamera,
                    textAlign: TextAlign.end,
                    style: AppTextStyles.body(context).copyWith(color: shell.textPrimary),
                  ),
                ),
                RadioListTile<ImageSource>(
                  value: ImageSource.gallery,
                  activeColor: shell.accent,
                  title: Text(
                    l10n.imageSourceGallery,
                    textAlign: TextAlign.end,
                    style: AppTextStyles.body(context).copyWith(color: shell.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _picking ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _picking ? null : _confirm,
          child: _picking
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.confirm),
        ),
      ],
    );
  }
}
