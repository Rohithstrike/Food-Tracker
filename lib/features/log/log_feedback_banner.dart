// Brief confirmation shown after food is added, with Undo.

import 'package:flutter/cupertino.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_typography.dart';

class LogFeedbackBanner extends StatelessWidget {
  const LogFeedbackBanner({
    super.key,
    required this.message,
    required this.onUndo,
  });

  final String message;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        key: const ValueKey<String>('log-feedback-banner'),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated.resolveFrom(context),
          borderRadius: AppRadius.largeAll,
          border: Border.all(
            color: AppColors.separator.resolveFrom(context),
            width: 0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.xxs,
            top: AppSpacing.xxs,
            bottom: AppSpacing.xxs,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                CupertinoIcons.check_mark_circled_solid,
                size: AppIconSize.standard,
                color: AppColors.success.resolveFrom(context),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.subheadline.copyWith(
                    color: AppColors.textPrimary.resolveFrom(context),
                  ),
                ),
              ),
              CupertinoButton(
                key: const ValueKey<String>('log-feedback-undo'),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                onPressed: onUndo,
                child: Text(
                  'Undo',
                  style: AppTypography.headline.copyWith(
                    color: AppColors.accent.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
