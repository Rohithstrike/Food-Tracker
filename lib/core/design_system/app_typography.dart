import 'package:flutter/cupertino.dart';

/// Indian Food Tracker typography.
///
/// Styles here are deliberately COLOURLESS. Apply colour where the style is
/// used, from AppColors, resolved for the current appearance:
///
///   AppTypography.body.copyWith(
///     color: AppColors.textPrimary.resolveFrom(context),
///   )
///
/// Sizes follow the iOS default text-size scale. Flutter applies the user's
/// text-scaling setting on top of these sizes automatically — never wrap
/// text in fixed-height containers.
///
/// Font families match those used by Flutter's own Cupertino defaults:
/// on iOS they resolve to the system font; in Chrome a fallback font is used.
abstract final class AppTypography {
  static const String _textFamily = 'CupertinoSystemText';
  static const String _displayFamily = 'CupertinoSystemDisplay';

  /// Page titles, e.g. "Today".
  static const TextStyle largeTitle = TextStyle(
    fontFamily: _displayFamily,
    fontSize: 34,
    fontWeight: FontWeight.w700,
  );

  /// Section headers on key screens.
  static const TextStyle title = TextStyle(
    fontFamily: _displayFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
  );

  /// List-row titles and emphasised short text.
  static const TextStyle headline = TextStyle(
    fontFamily: _textFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
  );

  /// Default reading text.
  static const TextStyle body = TextStyle(
    fontFamily: _textFamily,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.41,
  );

  /// Secondary information.
  static const TextStyle subheadline = TextStyle(
    fontFamily: _textFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
  );

  /// Metadata.
  static const TextStyle footnote = TextStyle(
    fontFamily: _textFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  /// Smallest labels. Use sparingly.
  static const TextStyle caption = TextStyle(
    fontFamily: _textFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  /// Hero nutrition number (e.g. daily calories).
  /// Tabular figures keep digits the same width, so values don't shift
  /// sideways when they change.
  static const TextStyle numericDisplay = TextStyle(
    fontFamily: _displayFamily,
    fontSize: 48,
    fontWeight: FontWeight.w600,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /// Unit shown beside a hero number (e.g. "kcal").
  /// Pair with AppColors.textSecondary so the number dominates.
  static const TextStyle numericUnit = TextStyle(
    fontFamily: _textFamily,
    fontSize: 17,
    fontWeight: FontWeight.w500,
  );
}

/// Icon sizes. Icons are sized like type, so they live beside typography.
abstract final class AppIconSize {
  /// Inline with body text.
  static const double inline = 17;

  /// Standard toolbar / row icons.
  static const double standard = 22;

  /// Large illustrative icon in empty states.
  static const double emptyState = 48;
}