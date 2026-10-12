import 'package:flutter/cupertino.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Builds the app-wide Cupertino theme from the design-system tokens.
abstract final class AppTheme {
  /// [brightness] null  → follow the system appearance (current behaviour).
  /// [brightness] value → force light or dark (future Settings option).
  static CupertinoThemeData build({Brightness? brightness}) {
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: AppColors.accent,
      primaryContrastingColor: AppColors.onAccent,
      scaffoldBackgroundColor: AppColors.background,
      // Solid for now. A subtle glass treatment arrives in a later milestone.
      barBackgroundColor: AppColors.background,
      textTheme: CupertinoTextThemeData(
        primaryColor: AppColors.accent,
        textStyle: AppTypography.body.copyWith(color: AppColors.textPrimary),
        actionTextStyle: AppTypography.body.copyWith(color: AppColors.accent),
        navTitleTextStyle: AppTypography.headline.copyWith(
          color: AppColors.textPrimary,
        ),
        navLargeTitleTextStyle: AppTypography.largeTitle.copyWith(
          color: AppColors.textPrimary,
        ),
        navActionTextStyle: AppTypography.body.copyWith(
          color: AppColors.accent,
        ),
      ),
    );
  }
}
