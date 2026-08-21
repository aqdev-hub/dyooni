import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../widgets/shared/app_snackbar.dart';

/// Hand-drawn signature pad. Matches the reference's structure (prompt label → white signing
/// box → Cancel / Retry / Save row) but every color and font here comes from Dyooni's own
/// navy+gold identity, never the reference's colors, per explicit direction.
///
/// Drawing is a plain `CustomPainter` fed by raw pan points — no signature-pad package needed.
/// On save, the canvas is captured to a PNG via `RenderRepaintBoundary` and written to the app's
/// own documents directory (using `path_provider`, already a project dependency for report
/// export) — then the saved file path is popped back to whoever pushed this route.
class SignatureCaptureScreen extends StatefulWidget {
  const SignatureCaptureScreen({super.key});

  @override
  State<SignatureCaptureScreen> createState() => _SignatureCaptureScreenState();
}

class _SignatureCaptureScreenState extends State<SignatureCaptureScreen> {
  final List<Offset?> _points = [];
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isSaving = false;

  void _addPoint(Offset localPosition) {
    setState(() => _points.add(localPosition));
  }

  void _endStroke() {
    setState(() => _points.add(null));
  }

  void _clear() {
    setState(() => _points.clear());
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (_points.every((p) => p == null)) {
      AppSnackBar.showError(context, l10n.signatureEmptyMessage);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/dyooni_signature_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      context.pop(file.path);
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(context, l10n.unexpectedError);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;

    return Scaffold(
      backgroundColor: shell.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [shell.headerTop, shell.headerBottom],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      l10n.signatureScreenTitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.title(context).copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      l10n.signaturePromptLabel,
                      style: AppTextStyles.title(context).copyWith(color: shell.textPrimary, fontSize: 17),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: shell.accent, width: 3),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: RepaintBoundary(
                            key: _boundaryKey,
                            child: GestureDetector(
                              onPanUpdate: (details) => _addPoint(details.localPosition),
                              onPanEnd: (_) => _endStroke(),
                              child: CustomPaint(
                                painter: _SignaturePainter(_points),
                                size: Size.infinite,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // RTL row: first child renders at the visual right (matches the
                        // reference, where "Save" sits on the right and "Cancel" on the left).
                        Expanded(
                          child: _ActionButton(
                            label: l10n.saveButton,
                            onTap: _isSaving ? null : _save,
                            filled: true,
                            isLoading: _isSaving,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _ActionButton(label: l10n.signatureRetryLabel, onTap: _clear)),
                        const SizedBox(width: 10),
                        Expanded(child: _ActionButton(label: l10n.cancel, onTap: () => context.pop())),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.points);
  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.4;
    for (var i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  // Always true: `points` is mutated in place (the same List instance), so a reference
  // comparison here would never detect the change and the stroke would stop updating live.
  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap, this.filled = false, this.isLoading = false});
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    if (filled) {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.backgroundTop,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
              )
            : Text(label, style: AppTextStyles.button(context).copyWith(color: Colors.white, fontSize: 14)),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: shell.accent,
        side: BorderSide(color: shell.accent),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: AppTextStyles.button(context).copyWith(fontSize: 14, color: shell.accent)),
    );
  }
}
