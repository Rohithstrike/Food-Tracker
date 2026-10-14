import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indian_food_tracker/core/design_system/app_colors.dart';
import 'package:indian_food_tracker/core/design_system/app_motion.dart';
import 'package:indian_food_tracker/core/design_system/app_theme.dart';
import 'package:indian_food_tracker/main.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// A foreground/background pairing the app actually uses, with the minimum
/// ratio that pairing must meet.
typedef ContrastPair = (
  String name,
  CupertinoDynamicColor foreground,
  CupertinoDynamicColor background,
  double minimum,
);

const double normalText = 4.5; // WCAG AA, normal-size text
const double nonText = 3.0; // WCAG AA, essential non-text indicators

/// Project floor for disabled labels. WCAG exempts disabled controls; this
/// only keeps them from disappearing entirely.
const double disabledFloor = 2.0;

/// Every token, so the dark-only rule can be checked for all of them.
const List<(String, CupertinoDynamicColor)> allTokens = [
  ('background', AppColors.background),
  ('surface', AppColors.surface),
  ('surfaceElevated', AppColors.surfaceElevated),
  ('surfaceSecondary', AppColors.surfaceSecondary),
  ('separator', AppColors.separator),
  ('track', AppColors.track),
  ('strokeStrong', AppColors.strokeStrong),
  ('textPrimary', AppColors.textPrimary),
  ('textSecondary', AppColors.textSecondary),
  ('textTertiary', AppColors.textTertiary),
  ('textDisabled', AppColors.textDisabled),
  ('accent', AppColors.accent),
  ('onAccent', AppColors.onAccent),
  ('success', AppColors.success),
  ('warning', AppColors.warning),
  ('error', AppColors.error),
  ('protein', AppColors.protein),
  ('carbs', AppColors.carbs),
  ('fat', AppColors.fat),
  ('fibre', AppColors.fibre),
];

List<ContrastPair> intendedPairs() {
  const textSurfaces = <(String, CupertinoDynamicColor)>[
    ('background', AppColors.background),
    ('surface', AppColors.surface),
    ('surfaceElevated', AppColors.surfaceElevated),
  ];
  const allSurfaces = <(String, CupertinoDynamicColor)>[
    ...textSurfaces,
    ('surfaceSecondary', AppColors.surfaceSecondary),
  ];

  final pairs = <ContrastPair>[];

  // Text, accent and essential outlines: allowed on every surface.
  for (final (surfaceName, surface) in allSurfaces) {
    pairs
      ..add((
        'textPrimary on $surfaceName',
        AppColors.textPrimary,
        surface,
        normalText,
      ))
      ..add((
        'textSecondary on $surfaceName',
        AppColors.textSecondary,
        surface,
        normalText,
      ))
      ..add((
        'textTertiary on $surfaceName',
        AppColors.textTertiary,
        surface,
        normalText,
      ))
      ..add(('accent on $surfaceName', AppColors.accent, surface, normalText))
      ..add((
        'strokeStrong on $surfaceName',
        AppColors.strokeStrong,
        surface,
        nonText,
      ))
      ..add((
        'textDisabled on $surfaceName',
        AppColors.textDisabled,
        surface,
        disabledFloor,
      ));
  }

  // Status and nutrition colours: small text allowed on main surfaces only
  // (documented rule: not on surfaceSecondary).
  const coloured = <(String, CupertinoDynamicColor)>[
    ('success', AppColors.success),
    ('warning', AppColors.warning),
    ('error', AppColors.error),
    ('protein', AppColors.protein),
    ('carbs', AppColors.carbs),
    ('fat', AppColors.fat),
    ('fibre', AppColors.fibre),
  ];
  for (final (colourName, colour) in coloured) {
    for (final (surfaceName, surface) in textSurfaces) {
      pairs.add(('$colourName on $surfaceName', colour, surface, normalText));
    }
  }

  // Filled part of the calorie ring and macro bars against their track.
  const indicators = <(String, CupertinoDynamicColor)>[
    ('accent', AppColors.accent),
    ('protein', AppColors.protein),
    ('carbs', AppColors.carbs),
    ('fat', AppColors.fat),
    ('fibre', AppColors.fibre),
  ];
  for (final (name, colour) in indicators) {
    pairs.add(('$name on track', colour, AppColors.track, nonText));
  }

  // Label on the filled accent (primary Add) button.
  pairs.add((
    'onAccent on accent',
    AppColors.onAccent,
    AppColors.accent,
    normalText,
  ));

  // Selected chip: off-white fill with dark text.
  pairs.add((
    'background on textPrimary (selected chip)',
    AppColors.background,
    AppColors.textPrimary,
    normalText,
  ));

  return pairs;
}

List<String> contrastFailures() {
  final failures = <String>[];
  for (final (name, fg, bg, minimum) in intendedPairs()) {
    final ratio = contrastRatio(fg.darkColor, bg.darkColor);
    if (ratio < minimum) {
      failures.add('$name: ${ratio.toStringAsFixed(2)} < $minimum');
    }
  }
  return failures;
}

void main() {
  group('Colour tokens', () {
    test('contrast (WCAG AA) for all intended pairings', () {
      expect(contrastFailures(), isEmpty);
    });

    test('every token is dark only: light and dark values are identical', () {
      for (final (name, token) in allTokens) {
        expect(
          token.color.toARGB32(),
          token.darkColor.toARGB32(),
          reason: name,
        );
      }
    });
  });

  group('Theme appearance', () {
    Future<(Color, Brightness)> resolvedTheme(
      WidgetTester tester,
      CupertinoThemeData theme,
    ) async {
      late Color background;
      late Brightness brightness;
      await tester.pumpWidget(
        CupertinoApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              background = CupertinoTheme.of(context).scaffoldBackgroundColor;
              brightness = CupertinoTheme.brightnessOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      return (background, brightness);
    }

    testWidgets('stays dark when the system is light', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final (colour, brightness) = await resolvedTheme(
        tester,
        AppTheme.build(),
      );
      expect(brightness, Brightness.dark);
      expect(colour.toARGB32(), AppColors.background.darkColor.toARGB32());
    });

    testWidgets('stays dark when the system is dark', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final (colour, brightness) = await resolvedTheme(
        tester,
        AppTheme.build(),
      );
      expect(brightness, Brightness.dark);
      expect(colour.toARGB32(), AppColors.background.darkColor.toARGB32());
    });

    testWidgets('explicit dark overrides a light system', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final (colour, brightness) = await resolvedTheme(
        tester,
        AppTheme.build(brightness: Brightness.dark),
      );
      expect(brightness, Brightness.dark);
      expect(colour.toARGB32(), AppColors.background.darkColor.toARGB32());
    });
  });

  testWidgets('Today greeting uses design-system text colours', (tester) async {
    // A light system must not change the app's colours.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const IndianFoodTrackerApp());

    final greeting = tester.widget<Text>(find.textContaining('Good '));
    final subtitle = tester.widget<Text>(find.text("Let's make today count."));

    expect(
      greeting.style?.color?.toARGB32(),
      AppColors.textPrimary.darkColor.toARGB32(),
    );
    expect(
      subtitle.style?.color?.toARGB32(),
      AppColors.textSecondary.darkColor.toARGB32(),
    );
  });

  group('Motion', () {
    Future<Duration> resolved(WidgetTester tester, Duration base) async {
      late Duration result;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            result = AppMotion.duration(context, base);
            return const SizedBox();
          },
        ),
      );
      return result;
    }

    testWidgets('durations apply when Reduce Motion is off', (tester) async {
      expect(await resolved(tester, AppMotion.emphasis), AppMotion.emphasis);
    });

    testWidgets('durations become zero when Reduce Motion is on', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      for (final base in [
        AppMotion.fast,
        AppMotion.standard,
        AppMotion.emphasis,
      ]) {
        expect(await resolved(tester, base), Duration.zero);
      }
    });
  });
}
