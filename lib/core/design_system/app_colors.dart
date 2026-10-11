import 'package:flutter/cupertino.dart';

/// Indian Food Tracker colour tokens.
///
/// Direction: "Warm paper, quiet ink, one spice".
///
/// Every token is a [CupertinoDynamicColor] with a light and dark value.
/// Screens must use these tokens — never raw hex colours.
///
/// Resolve a token for the current appearance with:
///   AppColors.textPrimary.resolveFrom(context)
/// (Cupertino widgets and the theme resolve them automatically.)
///
/// Contrast ratios below are WCAG 2.x, calculated for each colour against
/// [background], [surface] and [surfaceSecondary]. The lowest value is shown.
/// They are re-checked automatically in test/design_system_test.dart.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------------------

  /// Page background. Warm off-white in light mode; warm near-black in dark.
  static const CupertinoDynamicColor background =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF6F4F1),
    darkColor: Color(0xFF0F0E0D),
  );

  /// Grouped sections and cards sitting on [background].
  static const CupertinoDynamicColor surface =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF1C1B19),
  );

  /// Sheets and floating controls. In dark mode, elevation is shown by a
  /// lighter surface rather than shadows.
  static const CupertinoDynamicColor surfaceElevated =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF282624),
  );

  /// Input fields and pressed fills.
  /// Rule: avoid small coloured text ([success], [carbs]) on this surface
  /// in light mode — it falls below 4.5:1.
  static const CupertinoDynamicColor surfaceSecondary =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFEEEBE6),
    darkColor: Color(0xFF2A2825),
  );

  /// Hairline dividers. Decorative only — never the sole carrier of meaning.
  static const CupertinoDynamicColor separator =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFDDD8D0),
    darkColor: Color(0xFF3A3733),
  );

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  /// Main text. Worst case: 14.60:1 light, 13.05:1 dark.
  static const CupertinoDynamicColor textPrimary =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF1C1A17),
    darkColor: Color(0xFFF4F1EC),
  );

  /// Supporting labels. Worst case: 5.73:1 light, 5.82:1 dark.
  static const CupertinoDynamicColor textSecondary =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF605A53),
    darkColor: Color(0xFFA9A29A),
  );

  /// Placeholders, hints and disabled text ONLY.
  /// Below 4.5:1 (worst case 3.11:1 light, 3.32:1 dark), so never use it
  /// for essential small text.
  static const CupertinoDynamicColor textTertiary =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF8A847C),
    darkColor: Color(0xFF7D776F),
  );

  // ---------------------------------------------------------------------------
  // Accent — cinnamon. Used only for actions and selection.
  // ---------------------------------------------------------------------------

  /// Buttons, links, selected states. Worst case: 5.22:1 light, 6.37:1 dark.
  static const CupertinoDynamicColor accent =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF9A4A26),
    darkColor: Color(0xFFE39A6C),
  );

  /// Text and icons placed ON [accent] (e.g. a filled button label).
  /// 6.21:1 light, 7.53:1 dark.
  static const CupertinoDynamicColor onAccent =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF1C1A17),
  );

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  /// Confirmation. Light: 4.78:1 on background, 4.42:1 on surfaceSecondary
  /// (avoid small text there). Dark worst case: 6.82:1.
  static const CupertinoDynamicColor success =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF2D7A4C),
    darkColor: Color(0xFF6CC28E),
  );

  /// Cautions. Worst case: 4.77:1 light, 7.71:1 dark.
  static const CupertinoDynamicColor warning =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF8F5C00),
    darkColor: Color(0xFFE3B556),
  );

  /// Errors. Worst case: 5.08:1 light, 5.81:1 dark.
  static const CupertinoDynamicColor error =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFB3362B),
    darkColor: Color(0xFFF2837A),
  );

  // ---------------------------------------------------------------------------
  // Nutrition — always shown WITH a text label; colour is never the only cue.
  // ---------------------------------------------------------------------------

  /// Protein — muted slate teal. Worst case: 4.99:1 light, 6.87:1 dark.
  static const CupertinoDynamicColor protein =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF2F6A88),
    darkColor: Color(0xFF86B8D4),
  );

  /// Carbohydrates — turmeric ochre. Light: 4.61:1 on background,
  /// 4.25:1 on surfaceSecondary (avoid small text there). Dark: 7.84:1.
  static const CupertinoDynamicColor carbs =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF8A6A12),
    darkColor: Color(0xFFDDB963),
  );

  /// Fat — soft plum. Worst case: 5.29:1 light, 6.63:1 dark.
  static const CupertinoDynamicColor fat =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF8A4A7A),
    darkColor: Color(0xFFCFA0C4),
  );
}