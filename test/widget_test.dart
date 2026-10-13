import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indian_food_tracker/app/floating_tab_bar.dart';
import 'package:indian_food_tracker/core/design_system/app_colors.dart';
import 'package:indian_food_tracker/features/search/food_labels.dart';
import 'package:indian_food_tracker/main.dart';

const todaySubtitle = "Let's make today count.";

/// Finds a label inside the tab bar only (page titles share the same words).
Finder tabItem(String label) => find.descendant(
  of: find.byType(FloatingTabBar),
  matching: find.text(label),
);

int currentTabIndex(WidgetTester tester) =>
    tester.widget<FloatingTabBar>(find.byType(FloatingTabBar)).currentIndex;

/// Text that identifies each non-Today tab's page.
const tabPageTexts = <String, String>{
  'Search': searchHint,
  'Progress': 'Progress tracking arrives in a later milestone.',
  'Settings': 'Settings arrive in a later milestone.',
};

void main() {
  testWidgets('App launches on the Today dashboard', (tester) async {
    await tester.pumpWidget(const IndianFoodTrackerApp());

    expect(tabItem('Today'), findsOneWidget);
    expect(find.text(todaySubtitle), findsOneWidget);
  });

  testWidgets('Tab bar shows four destinations, Today selected', (
    tester,
  ) async {
    await tester.pumpWidget(const IndianFoodTrackerApp());

    for (final label in ['Today', 'Search', 'Progress', 'Settings']) {
      expect(tabItem(label), findsOneWidget);
    }
    expect(currentTabIndex(tester), 0);
  });

  testWidgets('Each tab opens its own page and Today can be reopened', (
    tester,
  ) async {
    await tester.pumpWidget(const IndianFoodTrackerApp());

    var expectedIndex = 1;
    for (final entry in tabPageTexts.entries) {
      await tester.tap(tabItem(entry.key));
      await tester.pumpAndSettle();

      expect(find.text(entry.value), findsOneWidget);
      expect(find.text(todaySubtitle), findsNothing);
      expect(currentTabIndex(tester), expectedIndex);
      expectedIndex++;
    }

    await tester.tap(tabItem('Today'));
    await tester.pumpAndSettle();

    expect(find.text(todaySubtitle), findsOneWidget);
    expect(currentTabIndex(tester), 0);
  });

  testWidgets('Settings shortcut on Today opens the Settings tab', (
    tester,
  ) async {
    await tester.pumpWidget(const IndianFoodTrackerApp());

    await tester.tap(find.byKey(const ValueKey('today-settings-shortcut')));
    await tester.pumpAndSettle();

    expect(currentTabIndex(tester), 3);
    expect(find.text('Settings arrive in a later milestone.'), findsOneWidget);
  });

  testWidgets('Tab bar uses design-system colours in dark mode', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const IndianFoodTrackerApp());

    final surface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('floating-tab-bar-surface')),
    );
    final fill = (surface.decoration as BoxDecoration).color!;
    expect(
      fill.toARGB32(),
      AppColors.surfaceElevated.darkColor
          .withValues(alpha: FloatingTabBarMetrics.glassOpacity)
          .toARGB32(),
    );

    final selected = tester.widget<Text>(tabItem('Today'));
    final unselected = tester.widget<Text>(tabItem('Search'));
    expect(
      selected.style?.color?.toARGB32(),
      AppColors.accent.darkColor.toARGB32(),
    );
    expect(
      unselected.style?.color?.toARGB32(),
      AppColors.textSecondary.darkColor.toARGB32(),
    );
  });

  testWidgets('Every tab renders without overflow: small iPhone, 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667); // iPhone SE points.
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const IndianFoodTrackerApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (final label in ['Search', 'Progress', 'Settings', 'Today']) {
      await tester.tap(tabItem(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Overflow on $label');
    }
  });
}
