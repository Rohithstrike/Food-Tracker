import 'package:flutter/cupertino.dart';

import '../core/design_system/app_colors.dart';
import '../core/design_system/app_spacing.dart';
import '../core/design_system/app_typography.dart';

/// Honest placeholder for destinations that are not built yet.
/// Contains no interactive controls, so nothing pretends to work.
/// Delete each usage when its real page is implemented.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary.resolveFrom(context);
    final textSecondary = AppColors.textSecondary.resolveFrom(context);

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(largeTitle: Text(title)),
          // Keeps the message centred in the area above the floating bar.
          SliverSafeArea(
            top: false,
            sliver: SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: AppSpacing.pageHorizontal,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: AppIconSize.emptyState,
                        color: textSecondary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Coming in a later milestone',
                        style: AppTypography.headline.copyWith(
                          color: textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.itemGapTight),
                      Text(
                        message,
                        style: AppTypography.subheadline.copyWith(
                          color: textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
