import 'package:flutter/cupertino.dart';

import 'core/design_system/app_colors.dart';
import 'core/design_system/app_spacing.dart';
import 'core/design_system/app_theme.dart';
import 'core/design_system/app_typography.dart';

void main() {
  runApp(const IndianFoodTrackerApp());
}

/// Root of the application.
/// The theme follows the system light/dark appearance.
class IndianFoodTrackerApp extends StatelessWidget {
  const IndianFoodTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Indian Food Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const TodayShell(),
    );
  }
}

/// Temporary Today screen shell.
/// Contains no nutrition data — real features arrive in later milestones.
class TodayShell extends StatelessWidget {
  const TodayShell({super.key});

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