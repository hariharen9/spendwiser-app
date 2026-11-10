import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/segmented_control.dart';
import '../../data/models/app_settings.dart';

class OnboardingOverlay extends ConsumerStatefulWidget {
  const OnboardingOverlay({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends ConsumerState<OnboardingOverlay> {
  int _step = 0;
  bool _finishing = false;
  late final TextEditingController _name;
  late Color _accent;
  late AppThemeMode _theme;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _name = TextEditingController(text: settings.userName);
    _accent = settings.accent;
    _theme = settings.theme;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _dismiss() {
    final settings = ref.read(settingsProvider);
    ref
        .read(settingsProvider.notifier)
        .update(settings.copyWith(onboardingSeen: true));
    widget.onDone();
  }

  Future<void> _finish({required bool loadDemo}) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    if (loadDemo) {
      ref.read(toastProvider.notifier).show('Loading demo data…');
      await ref.read(financeRepositoryProvider).loadDemoData();
    }
    if (!mounted) return;
    final settings = ref.read(settingsProvider);
    ref
        .read(settingsProvider.notifier)
        .update(
          settings.copyWith(
            userName: _name.text.trim().isEmpty
                ? settings.userName
                : _name.text.trim(),
            accent: _accent,
            theme: _theme,
            onboardingSeen: true,
          ),
        );
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Positioned.fill(
      child: Material(
        color: c.bg,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.bg,
            gradient: RadialGradient(
              center: const Alignment(0, -1),
              radius: 1.15,
              colors: [Color.lerp(c.bg, _accent, 0.30)!, c.bg],
              stops: const [0, 0.7],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 34),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppPill(
                      label: '✕',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      onTap: _dismiss,
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: _step == 0
                          ? _first(context)
                          : _step == 1
                          ? _second(context)
                          : _third(context),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: i == _step
                                ? c.tx
                                : c.tx.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _first(BuildContext context) {
    final c = context.spend;
    return Column(
      key: const ValueKey(0),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Spendwiser',
          textAlign: TextAlign.center,
          style: AppTypography.serif(size: 64, color: c.tx, height: 1),
        ),
        const SizedBox(height: 14),
        Text(
          'Your money, spent wiser.',
          textAlign: TextAlign.center,
          style: AppTypography.serif(size: 28, color: _accent),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 270,
          child: Text(
            'Track, plan and understand every rupee. Everything syncs to your Spendwiser account.',
            textAlign: TextAlign.center,
            style: AppTypography.sans(size: 14, color: c.mu),
          ),
        ),
        const SizedBox(height: 36),
        AppButton(
          label: 'Get started',
          primary: true,
          centered: true,
          margin: EdgeInsets.zero,
          onTap: () => setState(() => _step = 1),
        ),
      ],
    );
  }

  Widget _second(BuildContext context) {
    final c = context.spend;
    return Column(
      key: const ValueKey(1),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Make it yours',
          textAlign: TextAlign.left,
          style: AppTypography.serif(size: 34, color: c.tx),
        ),
        const SizedBox(height: 16),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.c1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.ln),
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: _name,
            textAlignVertical: TextAlignVertical.center,
            style: AppTypography.sans(size: 15, color: c.tx),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              hintText: 'What should we call you?',
              hintStyle: AppTypography.sans(size: 15, color: c.mu),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text('Accent', style: AppTypography.sans(size: 12, color: c.mu)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final accent in AppColors.accents)
              GestureDetector(
                onTap: () {
                  setState(() => _accent = accent);
                  ref.read(settingsProvider.notifier).patch(accent: accent);
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, AppColors.accentSecondary(accent)],
                    ),
                    shape: BoxShape.circle,
                    border: _accent == accent
                        ? Border.all(color: c.tx, width: 2)
                        : Border.all(color: c.ln),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SegmentedControl<AppThemeMode>(
          options: const [
            SegmentedOption(AppThemeMode.dark, 'Dark'),
            SegmentedOption(AppThemeMode.light, 'Light'),
          ],
          selected: _theme,
          onChanged: (value) {
            setState(() => _theme = value);
            ref.read(settingsProvider.notifier).patch(theme: value);
          },
        ),
        AppButton(
          label: 'Continue',
          primary: true,
          centered: true,
          margin: const EdgeInsets.only(top: 20),
          onTap: () => setState(() => _step = 2),
        ),
      ],
    );
  }

  Widget _third(BuildContext context) {
    final c = context.spend;
    return Column(
      key: const ValueKey(2),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'How do you want to start?',
          style: AppTypography.serif(size: 34, color: c.tx),
        ),
        Text(
          'Load six months of sample activity, or begin with your own data. '
          'You can load or clear demo data later in Settings.',
          style: AppTypography.sans(size: 14, color: c.mu),
        ),
        const SizedBox(height: 18),
        AppCard(
          onTap: _finishing ? null : () => _finish(loadDemo: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore with demo data',
                style: AppTypography.sans(
                  size: 15,
                  color: c.tx,
                  weight: FontWeight.w500,
                ),
              ),
              Text(
                'Sample accounts, cards, budgets, goals and six months of transactions',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
            ],
          ),
        ),
        AppCard(
          onTap: _finishing ? null : () => _finish(loadDemo: false),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start with my own data',
                style: AppTypography.sans(
                  size: 15,
                  color: c.tx,
                  weight: FontWeight.w500,
                ),
              ),
              Text(
                'Your existing Spendwiser account is left as it is',
                style: AppTypography.sans(size: 12, color: c.mu),
              ),
            ],
          ),
        ),
        if (_finishing)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Preparing your account…',
              textAlign: TextAlign.center,
              style: AppTypography.sans(size: 12, color: c.mu),
            ),
          ),
      ],
    );
  }
}
