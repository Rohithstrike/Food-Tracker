// Small reusable controls for food details and logging:
 // selectable chips, a quantity stepper and information tags.
 //
 // All colours, sizes and radii come from the design system. Every control
 // meets the 44 x 44 touch target and grows with the user's text size.

import 'package:flutter/cupertino.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_typography.dart';

/// A pill-shaped choice. Selected chips use the accent colour; the label is
/// always shown, so selection is never shown by colour alone (screen
/// readers also get the selected state).
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color background = selected
        ? AppColors.accent.resolveFrom(context)
        : AppColors.surfaceSecondary.resolveFrom(context);
    final Color foreground = selected
        ? AppColors.onAccent.resolveFrom(context)
        : AppColors.textPrimary.resolveFrom(context);

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget,
            minWidth: AppSpacing.minTouchTarget,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: AppRadius.capsuleAll,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Align(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  label,
                  style: AppTypography.subheadline.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Minus / value / plus. Pass null for a callback to disable that button.
/// Keys: the keyPrefix followed by "-minus", "-value" or "-plus".
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.keyPrefix,
    required this.valueText,
    required this.onDecrease,
    required this.onIncrease,
    required this.decreaseLabel,
    required this.increaseLabel,
    this.detail,
  });

  final String keyPrefix;
  final String valueText;
  final String? detail;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final String decreaseLabel;
  final String increaseLabel;

  @override
  Widget build(BuildContext context) {
    final String? detailText = detail;
    return Row(
      children: <Widget>[
        _StepButton(
          key: ValueKey<String>('$keyPrefix-minus'),
          icon: CupertinoIcons.minus,
          semanticLabel: decreaseLabel,
          onPressed: onDecrease,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                valueText,
                key: ValueKey<String>('$keyPrefix-value'),
                textAlign: TextAlign.center,
                style: AppTypography.headline.copyWith(
                  color: AppColors.textPrimary.resolveFrom(context),
                ),
              ),
              if (detailText != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  detailText,
                  textAlign: TextAlign.center,
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.textSecondary.resolveFrom(context),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _StepButton(
          key: ValueKey<String>('$keyPrefix-plus'),
          icon: CupertinoIcons.plus,
          semanticLabel: increaseLabel,
          onPressed: onIncrease,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: SizedBox.square(
        dimension: AppSpacing.minTouchTarget,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled
                ? AppColors.accent.resolveFrom(context)
                : AppColors.surfaceSecondary.resolveFrom(context),
          ),
          child: Icon(
            icon,
            size: AppIconSize.inline,
            semanticLabel: semanticLabel,
            color: enabled
                ? AppColors.onAccent.resolveFrom(context)
                : AppColors.textTertiary.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}

/// A small, quiet label such as "Sample data" or "Estimate".
class InfoTag extends StatelessWidget {
  const InfoTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary.resolveFrom(context),
        borderRadius: AppRadius.capsuleAll,
        border: Border.all(
          color: AppColors.separator.resolveFrom(context),
          width: 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          label,
          style: AppTypography.footnote.copyWith(
            color: AppColors.textSecondary.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}

/// Section heading inside sheets and pages.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        title,
        style: AppTypography.subheadline.copyWith(
          color: AppColors.textSecondary.resolveFrom(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}