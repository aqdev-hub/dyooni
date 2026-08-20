import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class FeatureIconItem {
  const FeatureIconItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// The trio of "icon above small label" items reused across onboarding slides. Each item is
/// wrapped in `Expanded` with wrapping, center-aligned text — fixes the horizontal overflow that
/// showed up on real narrow devices with longer Arabic labels.
class FeatureIconRow extends StatelessWidget {
  const FeatureIconRow({required this.items, super.key});

  final List<FeatureIconItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.6),
                        width: 1.4,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(item.icon, size: 19, color: AppColors.gold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySecondary(context).copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
