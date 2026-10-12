import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indian_food_tracker/app/floating_tab_bar.dart';
import 'package:indian_food_tracker/core/design_system/app_colors.dart';
import 'package:indian_food_tracker/features/today/today_page.dart';
import 'package:indian_food_tracker/main.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Worst-case contrast for tab labels on the translucent bar, assuming the
/// most contrasting content in the app is directly behind it.
List<String> glassContrastFailures({required bool dark}) {
  Color pick(CupertinoDynamicColor c) => dark ? c.darkColor : c.color;

  final glass = pick(AppColors.surfaceElevated)
      .withValues(alpha: FloatingTabBarMetrics.glassOpacity);
  final behindOptions = <String, Color>{
    'background': pick(AppColors.background),
    'textPrimary': pick(AppColors.textPrimary),
    'accent': pick(AppColors.accent),
  };
  final labels = <String, Color>{
    'textSecondary': pick(AppColors.textSecondary),
    'accent': pick(AppColors.accent),
  };

  final failures = <String>[];
  for (final behind in behindOptions.entries) {
    final effective = Color.alphaBlend(glass, behind.value);
    for (final label in labels.entries) {
      final ratio = contrastRatio(label.value, effective);
      if (ratio < 4.5) {
        failures.add(
          '${label.key} over ${behind.key}: ${ratio.toStringAsFixed(2)}',
        );
      }
    }
  }
  return failures;
}

Future<void> pumpApp(
  WidgetTester tester, {
  Size size = const Size(375, 667), // iPhone SE points.
  double bottomSafeArea = 0,
  bool highContrast = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = FakeViewPadding(bottom: bottomSafeArea);
  tester.view.viewPadding = FakeViewPadding(bottom: bottomSafeArea);
  addTearDown(tester.view.reset);

  if (highContrast) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(highContrast: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  await tester.pumpWidget(const IndianFoodTrackerApp());
  await tester.pumpAndSettle();
}

Finder barDescendant(Finder matching) =>
    find.descendant(of: find.byType(FloatingTabBar), matching: matching);

/// Scrolls the Today dashboard to its very end, then checks the last meal
/// row and its add button sit fully above the floating bar.
Future<void> expectLastMealClearsBar(WidgetTester tester) async {
  await tester.drag(
    find.descendant(
      of: find.byType(TodayPage),
      matching: find.byType(CustomScrollView),
    ),
    const Offset(0, -5000),
  );
  await tester.pumpAndSettle();

  final barTop = tester.getRect(find.byType(FloatingTabBar)).top;
  final lateMeal = tester.getRect(find.text('Late meal'));
  final addButton = tester.getRect(
    find.byKey(const ValueKey('add-meal-late_meal')),
  );

  expect(lateMeal.bottom, lessThanOrEqualTo(barTop));
  expect(addButton.bottom, lessThanOrEqualTo(barTop));
}

void main() {
  group('Glass contrast (worst case content behind the bar)', () {
    test('light mode', () {
      expect(glassContrastFailures(dark: false), isEmpty);
    });

    test('dark mode', () {
      expect(glassContrastFailures(dark: true), isEmpty);
    });
  });

  testWidgets('every tab meets the 44 x 44 touch target', (tester) async {
    await pumpApp(tester);
    for (final id in ['today', 'search', 'progress', 'settings']) {
      final size = tester.getSize(find.byKey(ValueKey('tab-$id')));
      expect(size.width, greaterThanOrEqualTo(44), reason: id);
      expect(size.height, greaterThanOrEqualTo(44), reason: id);
    }
  });

  testWidgets('screen readers get tab buttons with selected state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);

    expect(
      tester.getSemantics(find.byKey(const ValueKey('tab-today'))),
      containsSemantics(
        label: 'Today',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('tab-search'))),
      containsSemantics(label: 'Search', isButton: true, isSelected: false),
    );
    handle.dispose();
  });

  testWidgets('uses a blurred glass surface by default', (tester) async {
    await pumpApp(tester);
    expect(barDescendant(find.byType(BackdropFilter)), findsOneWidget);
  });

  testWidgets('falls back to a solid surface when contrast is increased', (
    tester,
  ) async {
    await pumpApp(tester, highContrast: true);

    expect(barDescendant(find.byType(BackdropFilter)), findsNothing);
    final surface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('floating-tab-bar-surface')),
    );
    expect(
      (surface.decoration as BoxDecoration).color!.toARGB32(),
      AppColors.surfaceElevated.color.toARGB32(),
    );
  });

  testWidgets('iPhone SE: last meal row clears the bar', (tester) async {
    await pumpApp(tester);

    final bar = tester.getRect(find.byType(FloatingTabBar));
    expect(bar.bottom, closeTo(667 - 16, 0.5)); // 16 pt above the edge.

    await expectLastMealClearsBar(tester);
  });

  testWidgets('home-indicator iPhone: bar sits above the safe area', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(393, 852), bottomSafeArea: 34);

    final bar = tester.getRect(find.byType(FloatingTabBar));
    expect(bar.bottom, closeTo(852 - 34, 0.5));

    await expectLastMealClearsBar(tester);
  });
}
