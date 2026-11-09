import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/app_toggle.dart';
import '../../core/widgets/common.dart';
import '../../data/models/app_settings.dart';
import '../../core/theme/app_colors.dart';

Future<void> showCustomizeHomeSheet(BuildContext context) {
  return showAppSheet<void>(context, (_) => const _CustomizeHomeSheet());
}

class _CustomizeHomeSheet extends ConsumerWidget {
  const _CustomizeHomeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.spend;
    final current = ref.watch(settingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle(
          'Customize Home',
          subtitle: 'Show, hide and reorder widgets.',
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < current.homeWidgets.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: i == current.homeWidgets.length - 1
                        ? null
                        : Border(bottom: BorderSide(color: c.ln)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          current.homeWidgets[i].label,
                          style: AppTypography.sans(size: 14, color: c.tx),
                        ),
                      ),
                      AppPill(
                        label: '↑',
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        onTap: i == 0
                            ? null
                            : () {
                                final list = List<HomeWidget>.of(
                                  current.homeWidgets,
                                );
                                final item = list.removeAt(i);
                                list.insert(i - 1, item);
                                ref
                                    .read(settingsProvider.notifier)
                                    .patch(homeWidgets: list);
                              },
                      ),
                      const SizedBox(width: 6),
                      AppPill(
                        label: '↓',
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        onTap: i == current.homeWidgets.length - 1
                            ? null
                            : () {
                                final list = List<HomeWidget>.of(
                                  current.homeWidgets,
                                );
                                final item = list.removeAt(i);
                                list.insert(i + 1, item);
                                ref
                                    .read(settingsProvider.notifier)
                                    .patch(homeWidgets: list);
                              },
                      ),
                      const SizedBox(width: 10),
                      Builder(
                        builder: (context) {
                          final visible = !current.hiddenWidgets.contains(
                            current.homeWidgets[i],
                          );
                          return AppToggle(
                            value: visible,
                            onChanged: (value) {
                              final hidden = Set<HomeWidget>.of(
                                current.hiddenWidgets,
                              );
                              if (value) {
                                hidden.remove(current.homeWidgets[i]);
                              } else {
                                hidden.add(current.homeWidgets[i]);
                              }
                              ref
                                  .read(settingsProvider.notifier)
                                  .patch(hiddenWidgets: hidden);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
