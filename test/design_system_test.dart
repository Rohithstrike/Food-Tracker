import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indian_food_tracker/core/design_system/app_colors.dart';
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
const double largeOrHint = 3.0; // WCAG AA, large text / placeholders

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

  // Primary/secondary text and accent: allowed on every surface.
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
      ..add(('accent on $surfaceName', AppColors.accent, surface, normalText))
      ..add((
        'textTertiary on $surfaceName',
        AppColors.textTertiary,
        surface,
        largeOrHint,
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

  // Label on a filled accent button.
  pairs.add((
    'onAccent on accent',
    AppColors.onAccent,
    AppColors.accent,
    normalText,
  ));

  return pairs;
}

List<String> contrastFailures({required bool dark}) {
  final failures = <String>[];
  for (final (name, fg, bg, minimum) in intendedPairs()) {
    final ratio = dark
        ? contrastRatio(fg.darkColor, bg.darkColor)
        : contrastRatio(fg.color, bg.color);
    if (ratio < minimum) {
      failures.add('$name: ${ratio.toStringAsFixed(2)} < $minimum');
    }
  }
  return failures;
}

void main() {
  group('Contrast (WCAG AA) for intended colour pairings', () {
    test('light mode', () {
      expect(contrastFailures(dark: false), isEmpty);
    });

    test('dark mode', () {
      expect(contrastFailures(dark: true), isEmpty);
    });
  });

  group('Theme appearance', () {
    Future<Color> scaffoldColour(
      WidgetTester tester,
      CupertinoThemeData theme,
    ) async {
      late Color captured;
      await tester.pumpWidget(
        CupertinoApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              captured = CupertinoTheme.of(context).scaffoldBackgroundColor;
              return const SizedBox();
            },
          ),
        ),
      );
      return captured;
    }

    testWidgets('follows system light appearance', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final colour = await scaffoldColour(tester, AppTheme.build());
      expect(colour.toARGB32(), AppColors.background.color.toARGB32());
    });

    testWidgets('follows system dark appearance', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final colour = await scaffoldColour(tester, AppTheme.build());
      expect(colour.toARGB32(), AppColors.background.darkColor.toARGB32());
    });

    testWidgets('explicit dark overrides a light system', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final colour = await scaffoldColour(
        tester,
        AppTheme.build(brightness: Brightness.dark),
      );
      expect(colour.toARGB32(), AppColors.background.darkColor.toARGB32());
    });
  });

  testWidgets('Today greeting uses design-system text colours in dark mode', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
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
}
