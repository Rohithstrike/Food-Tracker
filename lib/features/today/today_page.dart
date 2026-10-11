import 'package:flutter/cupertino.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_typography.dart';

/// Today tab.
/// Currently the verified empty-state shell; the dashboard (greeting,
/// calorie ring, nutrients, meals) is built in the next batches.
/// Contains no nutrition data.
class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary.resolveFrom(context);
    final textSecondary = AppColors.textSecondary.resolveFrom(context);

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('Today'),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: AppSpacing.pageHorizontal,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.square_list,
                      size: AppIconSize.emptyState,
                      color: textSecondary,
                      semanticLabel: 'Empty meal list',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Nothing logged yet',
                      style: AppTypography.headline.copyWith(
                        color: textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.itemGapTight),
                    Text(
                      'Your meals for today will appear here.',
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
        ],
      ),
    );
  }
}