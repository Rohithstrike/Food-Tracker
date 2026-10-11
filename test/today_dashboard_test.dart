import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indian_food_tracker/core/design_system/app_theme.dart';
import 'package:indian_food_tracker/features/today/greeting_header.dart';
import 'package:indian_food_tracker/features/today/today_models.dart';
import 'package:indian_food_tracker/features/today/today_page.dart';

DateTime Function() fixedClock(int hour, [int minute = 0]) =>
    () => DateTime(2026, 1, 1, hour, minute);

/// Pumps the Today page alone in a tall phone-width view, so every
/// section is built without scrolling.
Future<void> pumpToday(
  WidgetTester tester, {
  DailySummary? summary,
  DateTime Function()? clock,
  double? textScale,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(390, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  if (textScale != null) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  await tester.pumpWidget(
    CupertinoApp(
      theme: AppTheme.build(),
      home: TodayPage(summary: summary, clock: clock ?? fixedClock(9)),
    ),
  );
}

DailySummary sampleWithGoal(int goal) {
  final sample = DailySummary.sample();
  return DailySummary(
    calorieGoal: goal,
    meals: sample.meals,
    nutrients: sample.nutrients,
    isSample: false,
  );
}

void main() {
  group('Greeting', () {
    test('boundaries follow local time', () {
      expect(greetingFor(DateTime(2026, 1, 1, 4, 59)), 'Good evening');
      expect(greetingFor(DateTime(2026, 1, 1, 5)), 'Good morning');
      expect(greetingFor(DateTime(2026, 1, 1, 11, 59)), 'Good morning');
      expect(greetingFor(DateTime(2026, 1, 1, 12)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 1, 1, 16, 59)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 1, 1, 17)), 'Good evening');
      expect(greetingFor(DateTime(2026, 1, 1, 23, 30)), 'Good evening');
    });

    for (final (hour, expected) in [
      (8, 'Good morning'),
      (14, 'Good afternoon'),
      (21, 'Good evening'),
    ]) {
      testWidgets('header shows "$expected" at $hour:00', (tester) async {
        await pumpToday(tester, clock: fixedClock(hour));
        expect(find.text(expected), findsOneWidget);
      });
    }

    testWidgets('updates when the app stays open across a boundary',
        (tester) async {
      var now = DateTime(2026, 1, 1, 11, 59);
      await pumpToday(tester, clock: () => now);
      expect(find.text('Good morning'), findsOneWidget);

      now = DateTime(2026, 1, 1, 12);
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Good afternoon'), findsOneWidget);
    });
  });

  group('Calorie maths', () {
    test('normal day', () {
      const p = CalorieProgress(consumed: 1240, goal: 2000);
      expect(p.remaining, 760);
      expect(p.over, 0);
      expect(p.fraction, closeTo(0.62, 1e-9));
    });

    test('over goal: full ring, neutral overage', () {
      const p = CalorieProgress(consumed: 2120, goal: 2000);
      expect(p.remaining, 0);
      expect(p.over, 120);
      expect(p.fraction, 1.0);
    });

    test('zero goal never divides by zero', () {
      const p = CalorieProgress(consumed: 500, goal: 0);
      expect(p.hasGoal, isFalse);
      expect(p.fraction, 0.0);
      expect(p.remaining, 0);
      expect(p.over, 0);
    });

    test('empty day', () {
      const p = CalorieProgress(consumed: 0, goal: 2000);
      expect(p.fraction, 0.0);
      expect(p.remaining, 2000);
    });

    test('daily total is derived from meals, not stored', () {
      final s = DailySummary.sample();
      final sum = s.meals.values.fold<int>(0, (t, m) => t + m.calories);
      expect(s.caloriesConsumed, sum);
      expect(s.caloriesConsumed, 1240);
      expect(s.isSample, isTrue);
    });

    test('nutrient fraction clamps and handles zero target', () {
      const over = NutrientProgress(
        nutrient: Nutrient.protein,
        consumedGrams: 150,
        targetGrams: 100,
      );
      const noTarget = NutrientProgress(
        nutrient: Nutrient.fibre,
        consumedGrams: 10,
        targetGrams: 0,
      );
      expect(over.fraction, 1.0);
      expect(noTarget.fraction, 0.0);
    });

    test('number formatting', () {
      expect(formatNumber(0), '0');
      expect(formatNumber(999), '999');
      expect(formatNumber(1240), '1,240');
      expect(formatNumber(1000000), '1,000,000');
    });
  });

  group('Meal slots', () {
    test('seven default slots in approved order with unique ids', () {
      expect(defaultMealSlots.map((s) => s.name).toList(), [
        'Pre-workout',
        'Breakfast',
        'Mid-morning',
        'Lunch',
        'Snacks',
        'Dinner',
        'Late meal',
      ]);
      final ids = defaultMealSlots.map((s) => s.id).toSet();
      expect(ids.length, 7);
    });

    test('hidden slots are excluded and order follows position', () {
      const slots = [
        MealSlot(id: 'b', name: 'B', icon: CupertinoIcons.moon, position: 1),
        MealSlot(id: 'a', name: 'A', icon: CupertinoIcons.moon, position: 0),
        MealSlot(
          id: 'c',
          name: 'C',
          icon: CupertinoIcons.moon,
          position: 2,
          isVisible: false,
        ),
      ];
      expect(visibleMealSlots(slots).map((s) => s.id).toList(), ['a', 'b']);
    });
  });

  group('Calorie hero', () {
    testWidgets('screen readers get one clear description', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpToday(tester);

      expect(
        find.bySemanticsLabel(
          'Calories: 1,240 of 2,000 consumed. 760 remaining. Sample data.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('over-goal state is stated neutrally', (tester) async {
      await pumpToday(tester, summary: sampleWithGoal(1120));

      expect(find.text('1,240'), findsOneWidget);
      expect(find.text('120 kcal'), findsOneWidget);
      expect(find.text('Over goal'), findsOneWidget);
      expect(find.text('Sample data'), findsNothing);
    });

    testWidgets('zero goal shows a safe message', (tester) async {
      await pumpToday(tester, summary: sampleWithGoal(0));
      expect(find.text('No daily goal set'), findsOneWidget);
    });

    testWidgets('progress animates by default', (tester) async {
      await pumpToday(tester);
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('no animation when Reduce Motion is on', (tester) async {
      await pumpToday(tester, reduceMotion: true);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('Nutrients', () {
    testWidgets('all four nutrients are labelled', (tester) async {
      await pumpToday(tester);
      for (final label in ['Protein', 'Carbohydrates', 'Fat', 'Fibre']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('two columns at default text size', (tester) async {
      await pumpToday(tester);
      expect(
        tester.getTopLeft(find.text('Carbohydrates')).dy,
        tester.getTopLeft(find.text('Protein')).dy,
      );
    });

    testWidgets('one column at large text size', (tester) async {
      await pumpToday(tester, textScale: 2.0);
      expect(
        tester.getTopLeft(find.text('Carbohydrates')).dy,
        greaterThan(tester.getTopLeft(find.text('Protein')).dy),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Meals', () {
    testWidgets('seven meals render in order', (tester) async {
      await pumpToday(tester);
      var previousY = double.negativeInfinity;
      for (final slot in defaultMealSlots) {
        final y = tester.getTopLeft(find.text(slot.name)).dy;
        expect(y, greaterThan(previousY), reason: slot.name);
        previousY = y;
      }
    });

    testWidgets('empty and sample statuses', (tester) async {
      await pumpToday(tester);
      expect(find.text('Nothing added yet'), findsNWidgets(3));
      expect(find.text('2 items · 380 kcal'), findsOneWidget);
      expect(find.text('1 item · 120 kcal'), findsOneWidget);
    });

    testWidgets('each + opens the flow for its own meal', (tester) async {
      await pumpToday(tester);
      for (final slot in defaultMealSlots) {
        await tester.tap(find.byKey(ValueKey('add-meal-${slot.id}')));
        await tester.pumpAndSettle();
        expect(find.text('Add to ${slot.name}'), findsOneWidget);

        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(find.text('Add to ${slot.name}'), findsNothing);
      }
    });

    testWidgets('+ buttons meet the 44 x 44 touch target', (tester) async {
      await pumpToday(tester);
      final size = tester.getSize(find.byKey(const ValueKey('add-meal-lunch')));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });
}