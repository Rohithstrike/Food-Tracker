import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indian_food_tracker/core/design_system/app_theme.dart';
import 'package:indian_food_tracker/data/food/food_provider.dart';
import 'package:indian_food_tracker/data/food/food_repository.dart';
import 'package:indian_food_tracker/data/food/sample_food_provider.dart';
import 'package:indian_food_tracker/data/log/log_store.dart';
import 'package:indian_food_tracker/features/log/day_log_controller.dart';
import 'package:indian_food_tracker/features/search/food_labels.dart';
import 'package:indian_food_tracker/features/search/food_search_page.dart';

// All foods come from the SAMPLE provider: placeholder values, not real
// nutrition data. Idli sample: 140 kcal per 100 g, 1 idli = 40 g.
// Sunflower oil sample: 900 kcal per 100 g.
// Household servings step by 0.5; grams step by 10.

Future<void> pumpSearch(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double? textScale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  if (textScale != null) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final FoodRepository repository = FoodRepository(const <FoodProvider>[
    SampleFoodProvider(),
  ]);
  DateTime clock() => DateTime(2026, 10, 12, 13);
  final DayLogController controller = DayLogController(
    store: InMemoryLogStore(),
    clock: clock,
  );
  await tester.pumpWidget(
    CupertinoApp(
      theme: AppTheme.build(),
      home: FoodSearchPage(
        repository: repository,
        controller: controller,
        clock: clock,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> search(WidgetTester tester, String query) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('food-search-field')),
    query,
  );
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final Finder finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openIdli(WidgetTester tester) async {
  await search(tester, 'idli');
  await tapKey(tester, 'food-result-sample:idli');
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey<String>(key))).data ?? '';

void main() {
  group('Search page', () {
    testWidgets('an empty search shows a hint and the sample notice', (
      WidgetTester tester,
    ) async {
      await pumpSearch(tester);
      expect(find.text(searchHint), findsOneWidget);
      expect(find.text(sampleDataNotice), findsOneWidget);
    });

    testWidgets('regional names find foods; no match is explained', (
      WidgetTester tester,
    ) async {
      await pumpSearch(tester);
      await search(tester, 'idly');
      expect(
        find.byKey(const ValueKey<String>('food-result-sample:idli')),
        findsOneWidget,
      );

      await search(tester, 'zzzz');
      expect(find.text('No foods match "zzzz"'), findsOneWidget);
    });

    testWidgets('results are labelled as sample data', (
      WidgetTester tester,
    ) async {
      await pumpSearch(tester);
      await search(tester, 'idli');
      expect(
        find.text('Ready to eat \u00B7 140 kcal per 100 g \u00B7 Sample'),
        findsOneWidget,
      );
    });
  });

  group('Food detail', () {
    testWidgets('starts at one serving and recalculates live', (
      WidgetTester tester,
    ) async {
      await pumpSearch(tester);
      await openIdli(tester);
      expect(textOf(tester, 'detail-qty-value'), '1 idli');
      expect(textOf(tester, 'detail-kcal'), '56');

      // Household servings step by half a serving.
      await tapKey(tester, 'detail-qty-plus');
      expect(textOf(tester, 'detail-qty-value'), '1.5 idlis');
      expect(textOf(tester, 'detail-kcal'), '84');

      await tapKey(tester, 'detail-qty-plus');
      expect(textOf(tester, 'detail-qty-value'), '2 idlis');
      expect(textOf(tester, 'detail-kcal'), '112');

      await tapKey(tester, 'detail-qty-minus');
      await tapKey(tester, 'detail-qty-minus');
      expect(textOf(tester, 'detail-qty-value'), '1 idli');
      await tapKey(tester, 'detail-qty-minus');
      expect(textOf(tester, 'detail-qty-value'), '0.5 idlis');
      expect(textOf(tester, 'detail-kcal'), '28');
    });

    testWidgets('switching to grams starts at 100 g', (
      WidgetTester tester,
    ) async {
      await pumpSearch(tester);
      await openIdli(tester);
      await tapKey(tester, 'serving-g');
      expect(textOf(tester, 'detail-qty-value'), '100 g');
      expect(textOf(tester, 'detail-kcal'), '140');
    });

    testWidgets('an oil preset adds an estimated amount', (
      WidgetTester tester,
    ) async {
      await pumpSearch(tester);
      await openIdli(tester);
      await tapKey(tester, 'oil-normal');
      expect(textOf(tester, 'detail-oil-value'), '5 g oil');
      // 56 kcal idli + 45 kcal oil.
      expect(textOf(tester, 'detail-kcal'), '101');
      expect(find.text('Estimate'), findsOneWidget);
      expect(
        find.textContaining('Added oil (5 g) is an estimate'),
        findsOneWidget,
      );
    });

    testWidgets('the oil amount is editable', (WidgetTester tester) async {
      await pumpSearch(tester);
      await openIdli(tester);
      await tapKey(tester, 'oil-normal');
      await tapKey(tester, 'detail-oil-plus');
      expect(textOf(tester, 'detail-oil-value'), '5.5 g oil');
      // 56 + 49.5 = 105.5 kcal, shown rounded half up.
      expect(textOf(tester, 'detail-kcal'), '106');
      expect(find.textContaining('Added oil (5.5 g)'), findsOneWidget);
    });

    testWidgets('unknown nutrients are shown as not available', (
      WidgetTester tester,
    ) async {
      await pumpSearch(tester);
      await openIdli(tester);
      // Idli sample sugar is unknown.
      expect(find.text('Not available'), findsWidgets);
      expect(find.text('Sample data'), findsOneWidget);
    });

    testWidgets('oil itself is not offered extra oil', (
      WidgetTester tester,
    ) async {
      await pumpSearch(tester);
      await search(tester, 'sunflower');
      await tapKey(tester, 'food-result-sample:sunflower_oil');
      expect(find.byKey(const ValueKey<String>('detail-kcal')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('oil-none')), findsNothing);
    });

    testWidgets('Done closes the sheet', (WidgetTester tester) async {
      await pumpSearch(tester);
      await openIdli(tester);
      await tapKey(tester, 'detail-done');
      expect(find.byKey(const ValueKey<String>('detail-kcal')), findsNothing);
    });

    testWidgets('small iPhone at 2x text renders without overflow', (
      WidgetTester tester,
    ) async {
      await pumpSearch(tester, size: const Size(375, 667), textScale: 2.0);
      await openIdli(tester);
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'oil-high');
      expect(tester.takeException(), isNull);
      expect(textOf(tester, 'detail-kcal'), '146');
    });
  });
}
