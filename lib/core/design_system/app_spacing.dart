import 'package:flutter/widgets.dart';

/// Indian Food Tracker spacing scale and layout rules.
///
/// Screens should prefer the semantic layout tokens (e.g. [pageMargin],
/// [sectionGap]) and fall back to the raw scale only when no semantic
/// token fits. Never type raw spacing numbers in screens.
///
/// Values are logical pixels.
abstract final class AppSpacing {
  // ---------------------------------------------------------------------------
  // Raw scale (approved: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64)
  // ---------------------------------------------------------------------------

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
  static const double giant = 64;

  // ---------------------------------------------------------------------------
  // Semantic layout tokens — always taken from the raw scale above.
  // ---------------------------------------------------------------------------

  /// Left/right margin for page content.
  static const double pageMargin = lg; // 20

  /// Padding inside a grouped section or card.
  static const double sectionPadding = md; // 16

  /// Gap between two separate sections on a page.
  static const double sectionGap = xxl; // 32

  /// Gap between closely related items (e.g. a label and its value).
  static const double itemGapTight = xs; // 8

  /// Gap between related items within a section.
  static const double itemGap = sm; // 12

  /// Minimum width and height for anything tappable (Apple guideline).
  /// Use as a minimum constraint only — never as a fixed content height.
  static const double minTouchTarget = 44;

  // ---------------------------------------------------------------------------
  // Ready-made insets
  // ---------------------------------------------------------------------------

  /// Horizontal page margins only.
  static const EdgeInsets pageHorizontal =
      EdgeInsets.symmetric(horizontal: pageMargin);

  /// Padding inside a grouped section or card.
  static const EdgeInsets sectionInsets = EdgeInsets.all(sectionPadding);
}

/// Indian Food Tracker corner radii.
///
/// Only these four radii are allowed, to keep shapes consistent.
abstract final class AppRadius {
  /// Inputs and small controls.
  static const double small = 10;

  /// Grouped sections and cards.
  static const double medium = 14;

  /// Sheets and floating bars.
  static const double large = 22;

  /// Fully rounded pills and the future floating navigation.
  /// 999 fully rounds any control shorter than ~2000 px.
  static const double capsule = 999;

  static const BorderRadius smallAll = BorderRadius.all(Radius.circular(small));
  static const BorderRadius mediumAll =
      BorderRadius.all(Radius.circular(medium));
  static const BorderRadius largeAll = BorderRadius.all(Radius.circular(large));
  static const BorderRadius capsuleAll =
      BorderRadius.all(Radius.circular(capsule));
}