import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indian_food_tracker/app/app_shell.dart';
import 'package:indian_food_tracker/app/floating_tab_bar.dart';
import 'package:indian_food_tracker/core/design_system/app_theme.dart';
import 'package:indian_food_tracker/data/log/log_store.dart';
import 'package:indian_food_tracker/domain/log/log_entry.dart';
import 'package:indian_food_tracker/features/log/day_log_controller.dart';
import 'package:indian_food_tracker/features/today/today_models.dart';
import 'package:indian_food_tracker/features/today/today_page.dart';

// All foods come from the SAMPLE provider: placeholder values, not real
// nutrition data. 1 idli = 56 kcal; 1 cup rice = 208 kcal; 5 g oil = 45 kcal.

const String todaySubtitle = "Let's make today count.";

DateTime lunchTime() => DateTime(2026, 10, 12, 13);

Future<DayLogController> pumpApp(
  WidgetTester tester, {
  DateTime Function() clock = lunchTime,
}) async {
  tester.view.physicalSize = const Size(390, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  int next = 0;
  final DayLogController controller = DayLogController(
    store: InMemoryLogStore(),
    clock: clock,
    idGenerator: () => 'entry-${++next}',
  );
  await tester.pumpWidget(
    CupertinoApp(
      theme: AppTheme.build(),
      home: AppShell(controller: controller, clock: clock),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Finder tabItem(String label) => find.descendant(
  of: find.byType(FloatingTabBar),
  matching: find.text(label),
);

Future<void> tapKey(WidgetTester tester, String key) async {
  final Finder finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Searches for [query] and opens the detail sheet for [foodId].
Future<void> openFood(WidgetTester tester, String query, String foodId) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('food-search-field')),
    query,
  );
  await tester.pumpAndSettle();
  await tapKey(tester, 'food-result-$foodId');
}

/// Lets the confirmation banner time out, so no timer is left running.
Future<void> waitForBannerToClose(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

String mealStatus(int items, int kcal) =>
    '${items == 1 ? '1 item' : '$items items'} \u00B7 $kcal kcal';

void main() {
  testWidgets('a new day is genuinely empty, with no sample data', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final DayLogController c = await pumpApp(tester);

    expect(c.log.isEmpty, isTrue);
    expect(find.text('Nothing added yet'), findsNWidgets(7));
    expect(find.text(emptyDayMessage), findsOneWidget);
    expect(find.text(defaultTargetsNote), findsOneWidget);
    expect(find.text(incompleteDataNote), findsNothing);
    expect(find.text('Sample data'), findsNothing);
    expect(
      find.bySemanticsLabel('Calories: 0 of 2,000 consumed. 2,000 remaining.'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('+ on Lunch opens Search for Lunch and logs to Lunch', (
    WidgetTester tester,
  ) async {
    final DayLogController c = await pumpApp(tester);

    await tapKey(tester, 'add-meal-lunch');
    expect(find.text('Add food'), findsWidgets);
    await openFood(tester, 'idli', 'sample:idli');
    expect(find.text('Add to Lunch'), findsOneWidget);

    await tapKey(tester, 'detail-add');

    expect(find.text(todaySubtitle), findsOneWidget);
    expect(c.log.entriesFor('lunch').length, 1);
    expect(find.text(mealStatus(1, 56)), findsOneWidget);
    expect(find.text('Nothing added yet'), findsNWidgets(6));
    expect(find.text(emptyDayMessage), findsNothing);
    expect(find.text('Added Idli to Lunch'), findsOneWidget);

    await waitForBannerToClose(tester);
    expect(find.text('Added Idli to Lunch'), findsNothing);
  });

  testWidgets('Search tab: meal defaults by time and can be changed', (
    WidgetTester tester,
  ) async {
    final DayLogController c = await pumpApp(tester);

    await tester.tap(tabItem('Search'));
    await tester.pumpAndSettle();
    await openFood(tester, 'idli', 'sample:idli');
    expect(find.text('Add to Lunch'), findsOneWidget);

    await tapKey(tester, 'meal-dinner');
    expect(find.text('Add to Dinner'), findsOneWidget);
    await tapKey(tester, 'detail-add');

    expect(c.log.entriesFor('dinner').length, 1);
    expect(c.log.entriesFor('lunch'), isEmpty);
    expect(
      find.byKey(const ValueKey<String>('food-search-field')),
      findsOneWidget,
    );
    expect(find.text('Added Idli to Dinner'), findsOneWidget);

    await tester.tap(tabItem('Today'));
    await tester.pumpAndSettle();
    expect(find.text(mealStatus(1, 56)), findsOneWidget);

    await waitForBannerToClose(tester);
  });

  testWidgets('Search tab default meal follows the clock', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, clock: () => DateTime(2026, 10, 12, 20));
    await tester.tap(tabItem('Search'));
    await tester.pumpAndSettle();
    await openFood(tester, 'idli', 'sample:idli');
    expect(find.text('Add to Dinner'), findsOneWidget);
    await tapKey(tester, 'detail-done');
  });

  testWidgets('totals combine, and Undo restores the previous totals', (
    WidgetTester tester,
  ) async {
    final DayLogController c = await pumpApp(tester);

    await tapKey(tester, 'add-meal-lunch');
    await openFood(tester, 'idli', 'sample:idli');
    await tapKey(tester, 'detail-add');
    expect(find.text(mealStatus(1, 56)), findsOneWidget);

    await tapKey(tester, 'add-meal-lunch');
    await openFood(tester, 'rice', 'sample:rice_white_cooked');
    await tapKey(tester, 'detail-add');
    expect(find.text(mealStatus(2, 264)), findsOneWidget);
    expect(find.text('Added White rice, cooked to Lunch'), findsOneWidget);

    await tapKey(tester, 'log-feedback-undo');

    expect(find.text(mealStatus(1, 56)), findsOneWidget);
    expect(
      c.log.entries.map((LogEntry e) => e.base.foodName).toList(),
      <String>['Idli'],
    );
    expect(find.text('Added White rice, cooked to Lunch'), findsNothing);
  });

  testWidgets('added oil flows into Today as part of the entry', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final DayLogController c = await pumpApp(tester);

    await tapKey(tester, 'add-meal-breakfast');
    await openFood(tester, 'idli', 'sample:idli');
    await tapKey(tester, 'oil-normal');
    expect(find.text('Add to Breakfast'), findsOneWidget);
    await tapKey(tester, 'detail-add');

    expect(find.text(mealStatus(1, 101)), findsOneWidget);
    expect(c.log.entries.single.isEstimate, isTrue);
    expect(
      find.bySemanticsLabel(
        'Calories: 101 of 2,000 consumed. 1,899 remaining. Sample data.',
      ),
      findsOneWidget,
    );
    handle.dispose();
    await waitForBannerToClose(tester);
  });

  testWidgets('Add button and meal chips meet the 44 x 44 touch target', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tapKey(tester, 'add-meal-lunch');
    await openFood(tester, 'idli', 'sample:idli');

    for (final String key in <String>['detail-add', 'meal-lunch']) {
      final Size size = tester.getSize(find.byKey(ValueKey<String>(key)));
      expect(size.width, greaterThanOrEqualTo(44), reason: key);
      expect(size.height, greaterThanOrEqualTo(44), reason: key);
    }
    await tapKey(tester, 'detail-done');
  });

  testWidgets('the incomplete-data note appears only when flagged', (
    WidgetTester tester,
  ) async {
    Future<void> pumpToday({required bool incomplete}) async {
      await tester.pumpWidget(
        CupertinoApp(
          theme: AppTheme.build(),
          home: TodayPage(
            summary: const DailySummary(
              calorieGoal: 2000,
              meals: <String, MealSummary>{},
              nutrients: <NutrientProgress>[],
              isSample: false,
            ),
            hasIncompleteData: incomplete,
            clock: lunchTime,
          ),
        ),
      );
      await tester.pump();
    }

    await pumpToday(incomplete: true);
    expect(find.text(incompleteDataNote), findsOneWidget);
    await pumpToday(incomplete: false);
    expect(find.text(incompleteDataNote), findsNothing);
  });
}
