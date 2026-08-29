import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';

/// Shown under the details field once a transaction has a picked photo attached — a small
/// thumbnail with three actions matching the reference: pencil = replace the photo (re-opens the
/// camera/gallery picker), circular arrow = rotate it 90° in place, trash = remove the attachment
/// entirely. This same attachment is what gets embedded into the PDF statement report and noted
/// in the CSV export when present (see pdf_report_service.dart / csv_report_service.dart).
class AttachmentPreview extends StatelessWidget {
  const AttachmentPreview({
    required this.path,
    required this.onEdit,
    required this.onRotate,
    required this.onDelete,
    this.isBusy = false,
    super.key,
  });

  final String path;
  final VoidCallback onEdit;
  final VoidCallback onRotate;
  final VoidCallback onDelete;

  /// True while a rotate (or other background edit) is in progress — disables the three action
  /// buttons and shows a small spinner over the thumbnail instead of leaving the button looking
  /// like it did nothing while the work happens on a background isolate.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final file = File(path);
    // A rotated/replaced attachment keeps the exact same PATH, so Flutter's image cache would
    // otherwise keep showing the stale bytes after a rotate — keying on the file's own
    // modification time forces a fresh decode whenever the attachment actually changes.
    final cacheBustingKey = ValueKey(file.existsSync() ? file.lastModifiedSync().microsecondsSinceEpoch : path);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionIcon(icon: Icons.edit_rounded, tooltip: l10n.edit, onTap: isBusy ? null : onEdit),
              const SizedBox(height: 6),
              _ActionIcon(icon: Icons.rotate_right_rounded, tooltip: l10n.attachmentRotateAction, onTap: isBusy ? null : onRotate),
              const SizedBox(height: 6),
              _ActionIcon(icon: Icons.delete_outline_rounded, tooltip: l10n.delete, onTap: isBusy ? null : onDelete, color: Colors.red),
            ],
          ),
          const SizedBox(width: 10),
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  file,
                  key: cacheBustingKey,
                  width: 110,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 110,
                    height: 140,
                    color: shell.surface,
                    alignment: Alignment.center,
                    child: Icon(Icons.broken_image_outlined, color: shell.textSecondary),
                  ),
                ),
              ),
              if (isBusy)
                Container(
                  width: 110,
                  height: 140,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(8)),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, required this.tooltip, required this.onTap, this.color});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    final disabled = onTap == null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(shape: BoxShape.circle, color: shell.headerBottom.withValues(alpha: disabled ? 0.5 : 1)),
          child: Icon(icon, size: 17, color: (color ?? shell.accent).withValues(alpha: disabled ? 0.5 : 1)),
        ),
      ),
    );
  }
}
