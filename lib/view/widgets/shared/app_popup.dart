import 'package:flutter/material.dart';

import '../../../core/theme/app_shell_colors.dart';
import 'modal_header_bar.dart';

/// THE way to show anything that pops up over a screen (dialog, sheet, "add …" form).
///
/// Every popup appears in the MIDDLE of the screen that opened it and grows out of its centre
/// (a soft scale + fade) — never from the bottom edge. With the keyboard open it stays centred in
/// the space that remains above it.
///
/// Use it instead of `showDialog` / `showModalBottomSheet`; the [builder] returns an [AppPopup]
/// (header + body + buttons) or, for a popup that lays out its own body, an [AppPopupFrame]
/// topped with a [ModalHeaderBar].
Future<T?> showAppPopup<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color barrierColor = Colors.black54,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (ctx, _, _) => SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        curve: Curves.decelerate,
        padding: MediaQuery.viewInsetsOf(ctx) + const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        // The keyboard inset is applied above; the popup must not subtract it a second time.
        child: MediaQuery.removeViewInsets(
          context: ctx,
          removeBottom: true,
          child: Center(child: Material(type: MaterialType.transparency, child: Builder(builder: builder))),
        ),
      ),
    ),
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          alignment: Alignment.center,
          scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// The popup's card: rounded surface, shadow, width capped at [maxWidth] (and by the screen), height
/// capped by the space available. Give [height] only for content that needs a fixed height.
class AppPopupFrame extends StatelessWidget {
  const AppPopupFrame({required this.child, this.maxWidth = 440, this.height, super.key});

  final Widget child;
  final double maxWidth;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: maxWidth,
      height: height,
      child: Material(
        color: context.shellColors.surface,
        elevation: 10,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// Standard popup: the shared [ModalHeaderBar] ([title] + [icon]), a scrollable [child] and an
/// optional row of [actions] (buttons) aligned to the end. Replaces `AlertDialog` and the
/// hand-built bottom sheets.
///
/// Set [scrollable] to `false` when [child] already scrolls by itself (a `ListView(shrinkWrap: true)`
/// is fine either way).
class AppPopup extends StatelessWidget {
  const AppPopup({
    required this.title,
    required this.icon,
    required this.child,
    this.actions = const [],
    this.onClose,
    this.onIconTap,
    this.maxWidth = 440,
    this.scrollable = true,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 10, 16, 14),
    super.key,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final List<Widget> actions;
  final VoidCallback? onClose;
  final VoidCallback? onIconTap;
  final double maxWidth;
  final bool scrollable;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    return AppPopupFrame(
      maxWidth: maxWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: ModalHeaderBar(title: title, icon: icon, onClose: onClose, onIconTap: onIconTap),
          ),
          Flexible(
            child: scrollable
                ? SingleChildScrollView(padding: contentPadding, child: child)
                : Padding(padding: contentPadding, child: child),
          ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: actions,
              ),
            ),
        ],
      ),
    );
  }
}
