import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Plain equal-size dots — active dot is gold per explicit direction, inactive dots are dim.
class PageIndicator extends StatelessWidget {
  const PageIndicator({required this.count, required this.currentIndex, super.key});

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActive = i == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsetsDirectional.only(end: 8),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.indicatorActive : AppColors.indicatorInactive,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
