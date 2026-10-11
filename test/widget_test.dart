import 'package:flutter_test/flutter_test.dart';

import 'package:indian_food_tracker/main.dart';

void main() {
  testWidgets('App launches and shows the Today shell', (tester) async {
    await tester.pumpWidget(const IndianFoodTrackerApp());

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Nothing logged yet'), findsOneWidget);
    expect(
      find.text('Your meals for today will appear here.'),
      findsOneWidget,
    );
  });
}