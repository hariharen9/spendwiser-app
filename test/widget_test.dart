import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwiser_app/app.dart';

void main() {
  testWidgets('Home renders the Spendwiser shell', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: SpendwiserApp()));
    await tester.pump(const Duration(seconds: 7));

    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text('TOTAL NET WORTH'), findsOneWidget);
    expect(find.text('Safe to spend today'), findsOneWidget);
    expect(find.text('Customize Home'), findsOneWidget);
  });
}
