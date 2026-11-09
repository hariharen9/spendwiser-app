import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/section_caption.dart';
import 'app_module.dart';

class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({super.key, required this.module});

  final AppModule module;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 54, 20, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: module.label, subtitle: module.subtitle),
          AppCard(
            child: Column(
              children: [
                IconTile(icon: module.icon, color: module.tint, size: 52),
                const SizedBox(height: 14),
                Text(
                  '${module.label} is being prepared.',
                  textAlign: TextAlign.center,
                  style: AppTypographyFallback.of(context),
                ),
                const SizedBox(height: 6),
                Text(
                  'This screen is part of the Spendwiser mock.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: c.mu),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

abstract final class AppTypographyFallback {
  static TextStyle of(BuildContext context) =>
      TextStyle(fontSize: 16, color: context.spend.tx);
}
