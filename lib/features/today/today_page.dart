import 'package:flutter/cupertino.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_typography.dart';
import 'calorie_ring.dart';
import 'greeting_header.dart';
import 'meal_section_list.dart';
import 'nutrient_progress_grid.dart';
import 'today_models.dart';

/// Today dashboard.
///
/// Displays [summary] (currently clearly labelled SAMPLE data). When food
/// logging is implemented, a real summary built from saved entries is passed
/// in and this screen does not change.
class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    this.summary,
    this.mealSlots = defaultMealSlots,
    this.clock,
    this.onOpenSettings,
  });

  final DailySummary? summary;
  final List<MealSlot> mealSlots;
  final DateTime Function()? clock;
  final VoidCallback? onOpenSettings;

  void _showAddFood(BuildContext context, MealSlot slot) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text('Add to ${slot.name}'),
        content: const Text(
          'Food search and logging arrive in a later milestone. '
          'This meal will be pre-selected.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = summary ?? DailySummary.sample();
    final slots = visibleMealSlots(mealSlots);

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          SliverSafeArea(
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageMargin,
                AppSpacing.md,
                AppSpacing.pageMargin,
                AppSpacing.xxl,
              ),
              sliver: SliverList.list(
                children: [
                  GreetingHeader(clock: clock, onSettingsTap: onOpenSettings),
                  const SizedBox(height: AppSpacing.xl),
                  CalorieHero(progress: data.calories, isSample: data.isSample),
                  const SizedBox(height: AppSpacing.sectionGap),
                  const _SectionHeader('Nutrition'),
                  const SizedBox(height: AppSpacing.sm),
                  NutrientProgressGrid(nutrients: data.nutrients),
                  const SizedBox(height: AppSpacing.sectionGap),
                  const _SectionHeader("Today's meals"),
                  const SizedBox(height: AppSpacing.sm),
                  MealSectionList(
                    slots: slots,
                    summaryFor: data.mealFor,
                    onAdd: (slot) => _showAddFood(context, slot),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        title,
        style: AppTypography.title.copyWith(
          color: AppColors.textPrimary.resolveFrom(context),
        ),
      ),
    );
  }
}
