import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_typography.dart';
import 'today_models.dart';

const Duration _progressAnimation = Duration(milliseconds: 700);

/// Calorie hero: ring, goal summary and (when applicable) a sample-data badge.
/// Exposed to screen readers as ONE clear description.
class CalorieHero extends StatelessWidget {
  const CalorieHero({
    super.key,
    required this.progress,
    required this.isSample,
  });

  final CalorieProgress progress;
  final bool isSample;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: progress.semanticsLabel(isSample: isSample),
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CalorieRing(progress: progress),
            const SizedBox(height: AppSpacing.lg),
            _GoalSummary(progress: progress),
            if (isSample) ...[
              const SizedBox(height: AppSpacing.md),
              const SampleDataBadge(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Circular progress towards the daily calorie goal.
/// Inside: consumed calories (dominant) and "kcal" (quiet).
class CalorieRing extends StatelessWidget {
  const CalorieRing({super.key, required this.progress});

  final CalorieProgress progress;

  static const double _strokeWidth = AppSpacing.sm;
  static const double _minDiameter = 180;
  static const double _maxDiameter = 232;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final trackColor = AppColors.separator.resolveFrom(context);
    final ringColor = AppColors.accent.resolveFrom(context);
    final textPrimary = AppColors.textPrimary.resolveFrom(context);
    final textSecondary = AppColors.textSecondary.resolveFrom(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // ~60% of the content width: prominent, but meals stay reachable.
        final diameter = (constraints.maxWidth * 0.6).clamp(
          _minDiameter,
          _maxDiameter,
        );

        return SizedBox.square(
          dimension: diameter,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress.fraction),
            duration: reduceMotion ? Duration.zero : _progressAnimation,
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => CustomPaint(
              painter: _RingPainter(
                progress: value,
                trackColor: trackColor,
                ringColor: ringColor,
                strokeWidth: _strokeWidth,
              ),
              child: child,
            ),
            child: Padding(
              padding: const EdgeInsets.all(_strokeWidth + AppSpacing.md),
              // Scales down instead of overflowing at very large text sizes.
              // The full values are repeated below the ring, where text scales.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatNumber(progress.consumed),
                      style: AppTypography.numericDisplay.copyWith(
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'kcal',
                      style: AppTypography.numericUnit.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.ringColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color ringColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) {
      return;
    }

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = ringColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start at 12 o'clock.
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Remaining (or over) and daily goal, below the ring.
class _GoalSummary extends StatelessWidget {
  const _GoalSummary({required this.progress});

  final CalorieProgress progress;

  @override
  Widget build(BuildContext context) {
    if (!progress.hasGoal) {
      return Text(
        'No daily goal set',
        textAlign: TextAlign.center,
        style: AppTypography.subheadline.copyWith(
          color: AppColors.textSecondary.resolveFrom(context),
        ),
      );
    }

    // Exceeding the goal is stated neutrally — not shown as an error.
    final isOver = progress.over > 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Stat(
            value: isOver ? progress.over : progress.remaining,
            label: isOver ? 'Over goal' : 'Remaining',
          ),
        ),
        Expanded(
          child: _Stat(value: progress.goal, label: 'Daily goal'),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${formatNumber(value)} kcal',
          textAlign: TextAlign.center,
          style: AppTypography.headline.copyWith(
            color: AppColors.textPrimary.resolveFrom(context),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.footnote.copyWith(
            color: AppColors.textSecondary.resolveFrom(context),
          ),
        ),
      ],
    );
  }
}

/// Visible marker shown while the dashboard uses temporary sample values.
class SampleDataBadge extends StatelessWidget {
  const SampleDataBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary.resolveFrom(context),
        borderRadius: AppRadius.capsuleAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          'Sample data',
          style: AppTypography.footnote.copyWith(
            color: AppColors.textSecondary.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}
