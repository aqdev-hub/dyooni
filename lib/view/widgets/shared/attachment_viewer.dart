import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';

/// Opens the attached photo large, on a dark scrim: pinch or double-tap to zoom, drag to pan.
/// A tap OUTSIDE the picture, the close button, or the system back button returns to where the
/// person was. The colours here are fixed (dark scrim, white controls) on purpose — they must
/// stay readable whatever theme the app is in.
Future<void> showAttachmentViewer(BuildContext context, String path) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: AppLocalizations.of(context)!.attachmentViewerClose,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => _AttachmentViewer(path: path),
    transitionBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
  );
}

class _AttachmentViewer extends StatefulWidget {
  const _AttachmentViewer({required this.path});
  final String path;

  @override
  State<_AttachmentViewer> createState() => _AttachmentViewerState();
}

class _AttachmentViewerState extends State<_AttachmentViewer> {
  final _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final zoomedIn = _controller.value.getMaxScaleOnAxis() > 1.05;
    _controller.value = zoomedIn ? Matrix4.identity() : (Matrix4.identity()..scale(2.6));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final file = File(widget.path);
    final mediaSize = MediaQuery.sizeOf(context);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Behind the picture: any tap that does not land on it closes the viewer.
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => Navigator.of(context).maybePop()),
          ),
          Center(
            child: GestureDetector(
              onDoubleTap: _toggleZoom,
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: 1,
                maxScale: 6,
                clipBehavior: Clip.none,
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  width: mediaSize.width,
                  height: mediaSize.height * 0.86,
                  errorBuilder: (context, error, stackTrace) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 56),
                        const SizedBox(height: 10),
                        Text(l10n.attachmentUnavailable, style: const TextStyle(color: Colors.white, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
                  tooltip: l10n.attachmentViewerClose,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
