import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwiser_app/core/state/providers.dart';
import 'package:spendwiser_app/core/theme/app_colors.dart';
import 'package:spendwiser_app/core/theme/app_theme.dart';
import 'package:spendwiser_app/core/theme/app_typography.dart';
import 'package:spendwiser_app/data/models/app_settings.dart';
import 'package:spendwiser_app/features/shell/app_shell.dart';

void main() {
  testWidgets('Home renders the Spendwiser shell', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.build(const AppSettings()),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 7));

    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text('TOTAL NET WORTH'), findsOneWidget);
    expect(find.text('Safe to spend today'), findsOneWidget);
    expect(find.text('Customize Home'), findsOneWidget);
  });

  test('Font mode changes update AppTypography styles dynamically', () {
    AppTypography.fontMode = AppFontMode.dmSans;
    expect(AppTypography.activeSansFamily, 'DMSans');
    expect(AppTypography.activeSerifFamily, 'InstrumentSerif');

    AppTypography.fontMode = AppFontMode.serif;
    expect(AppTypography.activeSansFamily, 'InstrumentSerif');
    expect(AppTypography.activeSerifFamily, 'InstrumentSerif');

    AppTypography.fontMode = AppFontMode.mono;
    expect(AppTypography.activeSansFamily, 'monospace');
    expect(AppTypography.activeSerifFamily, 'monospace');
  });

  test('SettingsNotifier allows adding, editing and deleting categories', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(settingsProvider.notifier);
    expect(container.read(settingsProvider).categories.containsKey('Groceries'), false);

    // Add category
    const customColor = Color(0xFF34D399);
    notifier.addCategory('Groceries', customColor);
    expect(container.read(settingsProvider).categories['Groceries'], customColor);
    expect(AppColors.category('Groceries'), customColor);
    expect(AppColors.categoryList.contains('Groceries'), true);

    // Edit category
    const updatedColor = Color(0xFFFB7185);
    notifier.editCategory('Groceries', 'Supermarket', updatedColor);
    expect(container.read(settingsProvider).categories.containsKey('Groceries'), false);
    expect(container.read(settingsProvider).categories['Supermarket'], updatedColor);
    expect(AppColors.category('Supermarket'), updatedColor);

    // Delete category
    notifier.deleteCategory('Supermarket');
    expect(container.read(settingsProvider).categories.containsKey('Supermarket'), false);
    expect(AppColors.categoryList.contains('Supermarket'), false);

    // Reorder categories
    final beforeKeys = container.read(settingsProvider).categories.keys.toList();
    final first = beforeKeys[0];
    final second = beforeKeys[1];
    notifier.reorderCategories(0, 2);
    final afterKeys = container.read(settingsProvider).categories.keys.toList();
    expect(afterKeys[0], second);
    expect(afterKeys[1], first);
  });

  test('ITransactionRepository allows adding, renaming and deleting tags', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repo = container.read(transactionRepositoryProvider);
    final financeRepo = container.read(financeRepositoryProvider);

    expect(financeRepo.current.tags.contains('Vacation'), false);

    await repo.addTag('Vacation');
    expect(financeRepo.current.tags.contains('Vacation'), true);

    await repo.renameTag('Vacation', 'Holiday');
    expect(financeRepo.current.tags.contains('Vacation'), false);
    expect(financeRepo.current.tags.contains('Holiday'), true);

    await repo.deleteTag('Holiday');
    expect(financeRepo.current.tags.contains('Holiday'), false);
  });
}
