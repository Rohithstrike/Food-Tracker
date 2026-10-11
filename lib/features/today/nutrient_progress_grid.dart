import 'package:flutter/cupertino.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_typography.dart';
import 'today_models.dart';

/// Four nutrients in ONE shared panel.
/// Two columns normally; one column for large text or narrow widths.
class NutrientProgressGrid extends StatelessWidget {
  const NutrientProgressGrid({super.key, required this.nutrients});

  final List<NutrientProgress> nutrients;

  static const double _twoColumnMaxTextScale = 1.25;
  static const double _minTileWidth = 140;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.resolveFrom(context),
        borderRadius: AppRadius.mediumAll,
      ),
      child: Padding(
        padding: AppSpacing.sectionInsets,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
            final tileWidth = (constraints.maxWidth - AppSpacing.md) / 2;
            final twoColumns = textScale <= _twoColumnMaxTextScale &&
                tileWidth >= _minTileWidth;

            final tiles = [
              for (final nutrient in nutrients)
                NutrientProgressTile(progress: nutrient),
            ];

            if (!twoColumns) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: _withGaps(tiles),
              );
            }

            final rows = <Widget>[
              for (var i = 0; i < tiles.length; i += 2)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: tiles[i]),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: i + 1 < tiles.length
                          ? tiles[i + 1]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
            ];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: _withGaps(rows),
            );
          },
        ),
      ),
    );
  }

  static List<Widget> _withGaps(List<Widget> children) => [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          children[i],
        ],
      ];
}

/// One nutrient: colour dot + name, consumed / target, progress bar.
/// Colour is never the only cue — the name is always shown.
class NutrientProgressTile extends StatelessWidget {
  const NutrientProgressTile({super.key, required this.progress});

  final NutrientProgress progress;

  @override
  Widget build(BuildContext context) {
    final nutrientColor = progress.nutrient.color.resolveFrom(context);
    final textPrimary = AppColors.textPrimary.resolveFrom(context);
    final textSecondary = AppColors.textSecondary.resolveFrom(context);

    return Semantics(
      container: true,
      label: progress.semanticsLabel,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: AppSpacing.xs,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: nutrientColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    progress.nutrient.label,
                    style: AppTypography.subheadline.copyWith(
                      color: textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: formatGrams(progress.consumedGrams),
                    style: AppTypography.title.copyWith(color: textPrimary),
                  ),
                  TextSpan(
                    text: progress.hasTarget
                        ? ' / ${formatGrams(progress.targetGrams)} g'
                        : ' g',
                    style: AppTypography.subheadline.copyWith(
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ProgressBar(fraction: progress.fraction, color: nutrientColor),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  static const double _height = 6;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return SizedBox(
      height: _height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.separator.resolveFrom(context),
          borderRadius: AppRadius.capsuleAll,
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: fraction),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: AppRadius.capsuleAll,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}