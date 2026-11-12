import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwiser_app/core/theme/app_theme.dart';
import 'package:spendwiser_app/core/widgets/app_select.dart';
import 'package:spendwiser_app/data/models/app_settings.dart';

void main() {
  testWidgets('AppSelect opens its custom menu and selects an option', (
    tester,
  ) async {
    String? selected = 'alpha';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(const AppSettings()),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return AppSelect<String>(
                    value: selected,
                    options: const [
                      AppSelectOption('alpha', 'Alpha'),
                      AppSelectOption('beta', 'Beta'),
                      AppSelectOption('gamma', 'Gamma'),
                    ],
                    onChanged: (value) => setState(() => selected = value),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Alpha'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);

    await tester.tap(find.text('Beta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(selected, 'beta');
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('AppSelect works inside a modal bottom sheet', (tester) async {
    String? selected = 'alpha';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(const AppSettings()),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => StatefulBuilder(
                      builder: (context, setState) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: AppSelect<String>(
                          value: selected,
                          options: const [
                            AppSelectOption('alpha', 'Alpha'),
                            AppSelectOption('beta', 'Beta'),
                            AppSelectOption('gamma', 'Gamma'),
                          ],
                          onChanged: (value) =>
                              setState(() => selected = value),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alpha'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    expect(find.text('Gamma'), findsOneWidget);

    await tester.tap(find.text('Beta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(selected, 'beta');
    expect(find.text('Beta'), findsOneWidget);
  });
}
