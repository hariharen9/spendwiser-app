import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwiser_app/core/theme/app_theme.dart';
import 'package:spendwiser_app/core/widgets/brand_splash.dart';
import 'package:spendwiser_app/data/models/app_settings.dart';

void main() {
  testWidgets('BrandSplash lays out at a narrow phone size', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(const AppSettings()),
        home: const BrandSplash(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Spendwiser'), findsOneWidget);
    expect(find.text('SPEND WISER'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
