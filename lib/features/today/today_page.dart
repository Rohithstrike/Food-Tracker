import 'package:flutter/cupertino.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_typography.dart';
import 'calorie_ring.dart';
import 'greeting_header.dart';
import 'meal_section_list.dart';
import 'nutrient_progress_grid.dart';
import 'today_models.dart';

/// Shown while Today uses the built-in default targets.
const String defaultTargetsNote =
    'Default targets. Personal targets arrive with your profile in Settings.';

/// Shown on a day with nothing logged.
const String emptyDayMessage =
    'Nothing logged today yet. Tap + on a meal to add food.';

/// Shown when a logged food has no value for a nutrient shown on Today.
const String incompleteDataNote =
    'Some logged foods have no value for a nutrient. Totals include known '
    'values only.';

/// Today dashboard.
///
/// Displays [summary], built from the day's logged entries. This screen never
/// substitutes sample data: a day with nothing logged is shown as empty.
class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.summary,
    this.mealSlots = defaultMealSlots,
    this.clock,
    this.onOpenSettings,
    this.onAddFood,
    this.hasIncompleteData = false,
    this.showDefaultTargetsNote = false,
  });

  final DailySummary summary;
  final List<MealSlot> mealSlots;
  final DateTime Function()? clock;
  final VoidCallback? onOpenSettings;

  /// Called with the meal whose + button was tapped.
  final ValueChanged<MealSlot>? onAddFood;

  /// True when a logged food is missing a value for a nutrient shown here.
  final bool hasIncompleteData;

  /// True while the targets are defaults rather than personal targets.
  final bool showDefaultTargetsNote;

  @override
  Widget build(BuildContext context) {
    final List<MealSlot> slots = visibleMealSlots(mealSlots);
    final bool isEmptyDay = summary.meals.values.every(
      (MealSummary meal) => meal.isEmpty,
    );

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: <Widget>[
          SliverSafeArea(
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageMargin,
                AppSpacing.md,
                AppSpacing.pageMargin,
                AppSpacing.xxl,
              ),
              sliver: SliverList.list(
                children: <Widget>[
                  GreetingHeader(clock: clock, onSettingsTap: onOpenSettings),
                  const SizedBox(height: AppSpacing.xl),
                  CalorieHero(
                    progress: summary.calories,
                    isSample: summary.isSample,
                  ),
                  if (showDefaultTargetsNote) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    const _Note(
                      defaultTargetsNote,
                      key: ValueKey<String>('today-default-targets'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (hasIncompleteData) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    const _Note(
                      incompleteDataNote,
                      key: ValueKey<String>('today-incomplete-data'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sectionGap),
                  const _SectionHeader('Nutrition'),
                  const SizedBox(height: AppSpacing.sm),
                  NutrientProgressGrid(nutrients: summary.nutrients),
                  const SizedBox(height: AppSpacing.sectionGap),
                  const _SectionHeader("Today's meals"),
                  if (isEmptyDay) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    const _Note(
                      emptyDayMessage,
                      key: ValueKey<String>('today-empty-day'),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  MealSectionList(
                    slots: slots,
                    summaryFor: summary.mealFor,
                    onAdd: (MealSlot slot) => onAddFood?.call(slot),
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

class _Note extends StatelessWidget {
  const _Note(this.text, {super.key, this.textAlign = TextAlign.start});

  final String text;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: AppTypography.footnote.copyWith(
        color: AppColors.textSecondary.resolveFrom(context),
      ),
    );
  }
}
