import 'package:flutter/cupertino.dart';

/// Indian Food Tracker colour tokens.
///
/// Direction: "Ink & Saffron". A neutral near-black foundation, one warm
/// accent used sparingly, and a matched family of macro colours.
///
/// DARK ONLY. Every token is still a [CupertinoDynamicColor], but its light
/// and dark values are identical, so `resolveFrom(context)` returns the same
/// colour whatever the system appearance. This keeps every existing call
/// site working unchanged.
///
/// Screens must use these tokens, never raw hex colours.
///
/// Contrast ratios below are WCAG 2.x. "Worst" is the lowest value across
/// [background], [surface], [surfaceElevated] and [surfaceSecondary] unless
/// stated otherwise. They are re-checked in test/design_system_test.dart.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Surfaces: depth comes from four neutral steps, not shadows or tints.
  // ---------------------------------------------------------------------------

  /// App background (canvas). Near-black, OLED-friendly, but not pure black
  /// so the surfaces above it remain distinguishable.
  static const CupertinoDynamicColor background =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF07080A),
        darkColor: Color(0xFF07080A),
      );

  /// Grouped cards and list rows sitting on [background].
  static const CupertinoDynamicColor surface =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF131418),
        darkColor: Color(0xFF131418),
      );

  /// Sheets, the tab bar, the feedback banner and the search field.
  static const CupertinoDynamicColor surfaceElevated =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF1D1F24),
        darkColor: Color(0xFF1D1F24),
      );

  /// Unselected chips, stepper buttons and pressed rows.
  /// Rule: no small status or macro-coloured text on this surface.
  static const CupertinoDynamicColor surfaceSecondary =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF27292F),
        darkColor: Color(0xFF27292F),
      );

  /// Hairlines inside grouped lists. Decorative only, never the sole
  /// carrier of meaning.
  static const CupertinoDynamicColor separator =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF2E3036),
        darkColor: Color(0xFF2E3036),
      );

  /// Unfilled part of rings and progress bars. Decorative: the filled part
  /// carries the meaning and meets 3:1 against this track.
  static const CupertinoDynamicColor track =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF2A2C32),
        darkColor: Color(0xFF2A2C32),
      );

  /// Essential outlines such as focus indicators. Worst: 3.25:1.
  static const CupertinoDynamicColor strokeStrong =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF74777F),
        darkColor: Color(0xFF74777F),
      );

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  /// Titles, values and body text. Worst: 13.09:1.
  static const CupertinoDynamicColor textPrimary =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFF2F3F5),
        darkColor: Color(0xFFF2F3F5),
      );

  /// Labels, units and supporting text. Worst: 5.56:1.
  static const CupertinoDynamicColor textSecondary =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF9DA0A9),
        darkColor: Color(0xFF9DA0A9),
      );

  /// Hints, placeholders and empty-state text. Worst: 4.62:1, so it now
  /// meets the normal-text requirement on every surface.
  static const CupertinoDynamicColor textTertiary =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF8E919A),
        darkColor: Color(0xFF8E919A),
      );

  /// Labels of DISABLED controls only. 2.35:1 to 3.24:1. WCAG does not
  /// require contrast for disabled controls; never use for other text.
  static const CupertinoDynamicColor textDisabled =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF5E616A),
        darkColor: Color(0xFF5E616A),
      );

  // ---------------------------------------------------------------------------
  // Accent: saffron. Reserved for the calorie ring, the primary Add button
  // and the selected tab.
  // ---------------------------------------------------------------------------

  /// Worst: 8.27:1 on surfaces; 7.94:1 against [track].
  static const CupertinoDynamicColor accent =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFFFB547),
        darkColor: Color(0xFFFFB547),
      );

  /// Text and icons placed ON [accent]. 10.75:1.
  static const CupertinoDynamicColor onAccent =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF101114),
        darkColor: Color(0xFF101114),
      );

  // ---------------------------------------------------------------------------
  // Status: always paired with a label or icon.
  // ---------------------------------------------------------------------------

  /// Confirmation. Worst: 7.82:1.
  static const CupertinoDynamicColor success =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF4CD68A),
        darkColor: Color(0xFF4CD68A),
      );

  /// Cautions. Worst: 7.13:1. Close in hue to [accent], so always labelled.
  static const CupertinoDynamicColor warning =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFFF9F45),
        darkColor: Color(0xFFFF9F45),
      );

  /// Errors. Worst: 5.24:1.
  static const CupertinoDynamicColor error =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFFF6B6B),
        darkColor: Color(0xFFFF6B6B),
      );

  // ---------------------------------------------------------------------------
  // Nutrition: one family with matched brightness. Always shown WITH a text
  // label; colour is never the only cue.
  // ---------------------------------------------------------------------------

  /// Protein: blue. Worst: 6.19:1; 5.95:1 against [track].
  static const CupertinoDynamicColor protein =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF7FA8FF),
        darkColor: Color(0xFF7FA8FF),
      );

  /// Carbohydrates: teal (not yellow, so it never competes with saffron).
  /// Worst: 7.73:1; 7.42:1 against [track].
  static const CupertinoDynamicColor carbs =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF5CCFC3),
        darkColor: Color(0xFF5CCFC3),
      );

  /// Fat: pink. Worst: 6.46:1; 6.20:1 against [track].
  static const CupertinoDynamicColor fat = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF28DBE),
    darkColor: Color(0xFFF28DBE),
  );

  /// Fibre: green. Worst: 8.52:1; 8.18:1 against [track].
  static const CupertinoDynamicColor fibre =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF9FD66B),
        darkColor: Color(0xFF9FD66B),
      );
}
