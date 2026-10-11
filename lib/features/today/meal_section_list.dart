import 'package:flutter/cupertino.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_typography.dart';
import 'today_models.dart';

const double _badgeSize = AppSpacing.xxl; // 32

/// All visible meal slots in ONE grouped surface with inset hairlines.
/// Rows are built from data, so configurable slots need no layout changes.
class MealSectionList extends StatelessWidget {
  const MealSectionList({
    super.key,
    required this.slots,
    required this.summaryFor,
    required this.onAdd,
  });

  final List<MealSlot> slots;
  final MealSummary Function(String slotId) summaryFor;
  final ValueChanged<MealSlot> onAdd;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.mediumAll,
      child: ColoredBox(
        color: AppColors.surface.resolveFrom(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < slots.length; i++) ...[
              if (i > 0) const _InsetSeparator(),
              MealRow(
                slot: slots[i],
                summary: summaryFor(slots[i].id),
                onAdd: () => onAdd(slots[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Icon · name + status · add button.
/// No fixed height: grows with text size; minimum keeps rhythm consistent.
class MealRow extends StatelessWidget {
  const MealRow({
    super.key,
    required this.slot,
    required this.summary,
    required this.onAdd,
  });

  final MealSlot slot;
  final MealSummary summary;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary.resolveFrom(context);
    final textSecondary = AppColors.textSecondary.resolveFrom(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpacing.giant),
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.sectionPadding,
          right: AppSpacing.xs,
          top: AppSpacing.xs,
          bottom: AppSpacing.xs,
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: _badgeSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary.resolveFrom(context),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    slot.icon,
                    size: AppIconSize.inline,
                    color: textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    slot.name,
                    style: AppTypography.headline.copyWith(color: textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    summary.statusText,
                    style: AppTypography.subheadline.copyWith(
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            CupertinoButton(
              key: ValueKey('add-meal-${slot.id}'),
              padding: EdgeInsets.zero,
              onPressed: onAdd,
              child: SizedBox.square(
                dimension: _badgeSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.accent.resolveFrom(context),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      CupertinoIcons.add,
                      size: AppIconSize.inline,
                      color: AppColors.onAccent.resolveFrom(context),
                      semanticLabel: 'Add food to ${slot.name}',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hairline aligned with the meal name, not the screen edge (iOS style).
class _InsetSeparator extends StatelessWidget {
  const _InsetSeparator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.sectionPadding + _badgeSize + AppSpacing.sm,
      ),
      child: SizedBox(
        height: 1 / MediaQuery.devicePixelRatioOf(context),
        width: double.infinity,
        child: ColoredBox(color: AppColors.separator.resolveFrom(context)),
      ),
    );
  }
}
