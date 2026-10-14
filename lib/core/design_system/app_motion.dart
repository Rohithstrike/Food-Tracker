import 'package:flutter/widgets.dart';

/// Indian Food Tracker motion tokens.
///
/// Motion only communicates a real change of state. No springs, bounce,
/// parallax or continuous animation, and nothing ever delays an action.
///
/// When the system's Reduce Motion setting is on, every duration becomes
/// zero: use [AppMotion.duration] rather than the raw constants.
abstract final class AppMotion {
  /// Pressed highlights and chip selection.
  static const Duration fast = Duration(milliseconds: 120);

  /// Banner in and out, notes appearing.
  static const Duration standard = Duration(milliseconds: 240);

  /// Calorie ring and macro bars, only when their value changes.
  static const Duration emphasis = Duration(milliseconds: 500);

  static const Curve fastCurve = Curves.easeOut;
  static const Curve standardCurve = Curves.easeInOut;
  static const Curve emphasisCurve = Curves.easeOutCubic;

  /// True when the user has asked the system to reduce motion.
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// [base], or zero when Reduce Motion is on.
  static Duration duration(BuildContext context, Duration base) =>
      reduceMotion(context) ? Duration.zero : base;
}
