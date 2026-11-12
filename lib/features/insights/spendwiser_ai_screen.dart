import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/app_pill.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/section_caption.dart';
import 'services/ask_ai_client.dart';
import 'widgets/ai_action_card.dart';
import 'widgets/formatted_ai_response.dart';

class _AiTurn {
  const _AiTurn({required this.role, required this.text, this.action});

  final String role;
  final String text;
  final AiActionProposal? action;
}

/// Dedicated SpendWiser AI workspace unlocked when a BYOK AI key is configured.
class SpendWiserAiScreen extends ConsumerStatefulWidget {
  const SpendWiserAiScreen({super.key});

  @override
  ConsumerState<SpendWiserAiScreen> createState() => _SpendWiserAiScreenState();
}

class _SpendWiserAiScreenState extends ConsumerState<SpendWiserAiScreen> {
  final _input = TextEditingController();
  final _turns = <_AiTurn>[];
  bool _loading = false;
  String? _error;

  static const _starterPrompts = <String>[
    'Can I afford a ₹45,000 trip next week?',
    'Should I prepay my loan or build savings?',
    'Audit my subscriptions & recurring leaks',
    'Where can I cut ₹5,000 this month?',
    'Log chai 40',
  ];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _loading) return;
    final settings = ref.read(settingsProvider);
    if (!settings.hasAiKey) return;
    final snapshot = ref.read(financeSnapshotProvider);

    _input.clear();
    setState(() {
      _turns.add(_AiTurn(role: 'user', text: q));
      _loading = true;
      _error = null;
    });
    FocusScope.of(context).unfocus();

    try {
      final history = [
        for (final t in _turns) AiChatMessage(role: t.role, text: t.text),
      ];
      final reply = await AskAiClient.askChat(
        provider: settings.aiProvider,
        apiKey: settings.aiApiKey,
        model: settings.effectiveAiModel,
        history: history,
        snapshot: snapshot,
      );
      if (!mounted) return;
      setState(() {
        _turns.add(
          _AiTurn(role: 'assistant', text: reply.text, action: reply.action),
        );
        _loading = false;
      });
    } on AskAiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final settings = ref.watch(settingsProvider);

    return ScreenScroll(
      children: [
        PageHeader(
          title: 'SpendWiser AI',
          subtitle: settings.hasAiKey
              ? '${settings.aiProvider.label} · ${settings.effectiveAiModel}'
              : 'Configure an API key in Settings',
          trailing: _turns.isNotEmpty
              ? AppPill(
                  label: 'New chat',
                  onTap: () => setState(() {
                    _turns.clear();
                    _error = null;
                  }),
                )
              : null,
        ),
        if (!settings.hasAiKey)
          AppCard(
            child: Text(
              'Add your Gemini, OpenRouter, or Claude API key in Settings → Ask Spendwiser AI to unlock your personal financial copilot.',
              style: AppTypography.sans(size: 13, color: c.mu, height: 1.5),
            ),
          )
        else ...[
          Container(
            height: 52,
            padding: const EdgeInsets.only(left: 16, right: 6),
            decoration: BoxDecoration(
              color: c.c1,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.ln),
            ),
            alignment: Alignment.center,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    textAlignVertical: TextAlignVertical.center,
                    style: AppTypography.sans(size: 14, color: c.tx),
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: _turns.isEmpty
                          ? 'Ask about affordability, loans, leaks, or log…'
                          : 'Ask a follow-up…',
                      hintStyle: AppTypography.sans(size: 13, color: c.mu),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _send(_input.text),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.ac,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: SpendIcon('arrowRight', size: 18, color: c.aci),
                  ),
                ),
              ],
            ),
          ),
          if (_turns.isEmpty) ...[
            const SectionCaption(
              'Try asking',
              margin: EdgeInsets.only(top: 18, bottom: 10),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final prompt in _starterPrompts)
                  AppPill(label: prompt, onTap: () => _send(prompt)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          for (final turn in _turns)
            if (turn.role == 'user')
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10, left: 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: c.ac.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.ac.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    turn.text,
                    style: AppTypography.sans(size: 13, color: c.tx),
                  ),
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.c1,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: c.ln),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FormattedAiResponse(text: turn.text),
                    if (turn.action != null)
                      AiActionCard(proposal: turn.action!),
                  ],
                ),
              ),
          if (_loading)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.c1,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.ac.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.ac,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Thinking…',
                    style: AppTypography.sans(size: 13, color: c.tx),
                  ),
                ],
              ),
            ),
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.co.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.co.withValues(alpha: 0.35)),
              ),
              child: Text(
                _error!,
                style: AppTypography.sans(size: 12, color: c.co),
              ),
            ),
        ],
      ],
    );
  }
}

