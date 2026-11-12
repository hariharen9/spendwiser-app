import 'dart:convert';
import 'dart:io';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/finance_snapshot.dart';
import '../../../data/services/finance_calculator.dart';

class AskAiException implements Exception {
  const AskAiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AiChatMessage {
  const AiChatMessage({required this.role, required this.text});

  /// `'user'` or `'assistant'`
  final String role;
  final String text;
}

enum AiActionType { logTx, addBudget, addGoal }

class AiActionProposal {
  const AiActionProposal({
    required this.type,
    required this.title,
    required this.amount,
    this.category = 'Miscellaneous',
    this.isIncome = false,
    this.note = '',
  });

  final AiActionType type;
  final String title;
  final double amount;
  final String category;
  final bool isIncome;
  final String note;
}

class AiChatReply {
  const AiChatReply({required this.text, this.action});

  final String text;
  final AiActionProposal? action;
}

class AiParsedTransaction {
  const AiParsedTransaction({
    required this.merchant,
    required this.amount,
    required this.category,
    required this.isIncome,
    required this.note,
  });

  final String merchant;
  final double amount;
  final String category;
  final bool isIncome;
  final String note;
}

abstract final class AskAiClient {
  static const _systemPrompt =
      'You are Spendwiser AI, a calm, sharp Indian personal-finance copilot. '
      'Answer concisely using ONLY the structured financial snapshot provided. '
      'Format currency in Indian Rupees (₹ with lakhs/crores or commas). '
      'Cite exact numbers, dates, and merchants from the data. Never invent transactions or balances. '
      'When the user asks to log/add a transaction, create a budget, or create a goal, respond briefly AND include a single JSON block at the very end in this exact format:\n'
      '```action\n'
      '{"action":"log_tx","merchant":"Chai","amount":40,"category":"Food","isIncome":false,"note":""}\n'
      '```\n'
      'Allowed actions: "log_tx" (merchant, amount, category, isIncome, note), '
      '"add_budget" (category, amount), "add_goal" (title, amount).';

  /// Builds a compact, privacy-conscious financial briefing from the snapshot.
  static String buildContext(
    FinanceSnapshot snapshot, {
    required String query,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final thisMonth = DateTime(n.year, n.month, 1);
    final lastMonth = DateTime(n.year, n.month - 1, 1);
    final thisFlow = snapshot.flow(thisMonth);
    final lastFlow = snapshot.flow(lastMonth);
    final runway = FinanceCalculator.cashRunway(snapshot, now: n);
    final safe = FinanceCalculator.safeToSpend(snapshot, now: n);

    final catThis = _topCategories(snapshot, thisMonth);
    final catLast = _topCategories(snapshot, lastMonth);
    final topMerchants = FinanceCalculator.topMerchants(
      snapshot,
      thisMonth,
      limit: 8,
    );

    final tokens = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toSet();
    final relevantTx = snapshot.transactions
        .where((t) {
          if (tokens.isEmpty) return true;
          final hay = '${t.merchant} ${t.category} ${t.note} ${t.tags.join(' ')}'
              .toLowerCase();
          return tokens.any(hay.contains);
        })
        .take(25)
        .map(
          (t) =>
              '${isoDate(t.date)} | ${t.merchant} | ${t.category} | ${rupee(t.amount)}',
        )
        .toList();

    Map<String, dynamic>? payoffSummary;
    if (snapshot.loans.isNotEmpty) {
      final avalanche = FinanceCalculator.simulatePayoff(
        snapshot,
        5000,
        PayoffStrategy.avalanche,
      );
      final snowball = FinanceCalculator.simulatePayoff(
        snapshot,
        5000,
        PayoffStrategy.snowball,
      );
      payoffSummary = {
        'avalancheWithExtra5k':
            '${avalanche.months} months, interest ${rupee(avalanche.interest)}',
        'snowballWithExtra5k':
            '${snowball.months} months, interest ${rupee(snowball.interest)}',
      };
    }

    final payload = {
      'asOf': isoDate(n),
      'netWorth': rupee(snapshot.netWorth),
      'liquidCash': rupee(snapshot.liquidAssets),
      'accounts': [
        for (final a in snapshot.accounts) '${a.name}: ${rupee(a.balance)}',
      ],
      'cashRunway': {
        'lowestBalance': rupee(runway.lowestBalance),
        'lowestDate': isoDate(runway.lowestDate),
        'typicalDailySpend': rupee(runway.dailySpend),
        'upcomingBillsTotal': rupee(runway.totalBills),
        'payday': runway.payday == null ? null : isoDate(runway.payday!),
        'expectedIncome': rupee(runway.expectedIncome),
        'isShortfall': runway.isShortfall,
      },
      'safeToSpendPerDay': rupee(safe.perDay),
      'thisMonth': {
        'income': rupee(thisFlow.income),
        'expense': rupee(thisFlow.expense),
        'topCategories': catThis,
        'topMerchants': [
          for (final m in topMerchants) '${m.key}: ${rupee(m.value)}',
        ],
      },
      'lastMonth': {
        'income': rupee(lastFlow.income),
        'expense': rupee(lastFlow.expense),
        'topCategories': catLast,
      },
      'cards': [
        for (final c in snapshot.cards)
          '${c.name}: outstanding ${rupee(c.outstanding)} / limit ${rupee(c.limit)}'
          '${c.due == null ? '' : ', due ${isoDate(c.due!.dueDate)} (${rupee(c.due!.amount)})'}',
      ],
      'loans': [
        for (final l in snapshot.loans)
          '${l.name}: outstanding ${rupee(l.outstanding)}, EMI ${rupee(l.emi)}/mo @ ${l.rate}%',
      ],
      'debtPayoffPlanner': ?payoffSummary,
      'budgets': [
        for (final b in snapshot.budgets)
          '${b.category}: spent ${rupee(b.spent)} / ${rupee(b.limit)}',
      ],
      'goals': [
        for (final g in snapshot.goals)
          '${g.name}: saved ${rupee(g.saved)} / ${rupee(g.target)}',
      ],
      'subscriptions': [
        for (final s in snapshot.subscriptions.where((s) => s.active))
          '${s.name}: ${rupee(s.price)}/mo (${s.category})',
      ],
      'recurring': [
        for (final r in snapshot.recurring.where((r) => r.active && !r.isIncome))
          '${r.name}: ${rupee(r.amount.abs())} (${r.frequency.name})',
      ],
      'splitGroups': [
        for (final g in snapshot.groups)
          '${g.name}: net ${rupee(g.yourBalance)}',
      ],
      'matchingTransactions': relevantTx,
    };
    return jsonEncode(payload);
  }

  static List<String> _topCategories(FinanceSnapshot snapshot, DateTime month) {
    final map = <String, double>{};
    for (final t in snapshot.inMonth(month)) {
      if (t.amount < 0 && t.category != 'Transfer') {
        map[t.category] = (map[t.category] ?? 0) - t.amount;
      }
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in sorted.take(8)) '${e.key}: ${rupee(e.value)}'];
  }

  static Future<String> ask({
    required AiProvider provider,
    required String apiKey,
    required String model,
    required String query,
    required FinanceSnapshot snapshot,
    DateTime? now,
  }) async {
    final reply = await askChat(
      provider: provider,
      apiKey: apiKey,
      model: model,
      history: [AiChatMessage(role: 'user', text: query)],
      snapshot: snapshot,
      now: now,
    );
    return reply.text;
  }

  static Future<AiChatReply> askChat({
    required AiProvider provider,
    required String apiKey,
    required String model,
    required List<AiChatMessage> history,
    required FinanceSnapshot snapshot,
    DateTime? now,
  }) async {
    if (provider == AiProvider.none || apiKey.trim().isEmpty) {
      throw const AskAiException('No AI API key configured in Settings.');
    }
    final latestQuery = history.lastWhere(
      (m) => m.role == 'user',
      orElse: () => const AiChatMessage(role: 'user', text: ''),
    ).text;
    final contextJson = buildContext(snapshot, query: latestQuery, now: now);
    final messages = <AiChatMessage>[
      AiChatMessage(
        role: 'user',
        text: 'Financial snapshot (JSON):\n$contextJson',
      ),
      const AiChatMessage(
        role: 'assistant',
        text: 'Ready. Ask me anything about your finances.',
      ),
      ...history,
    ];
    final raw = await _dispatchMessages(
      provider: provider,
      apiKey: apiKey.trim(),
      model: model.trim().isEmpty ? provider.defaultModel : model.trim(),
      systemPrompt: _systemPrompt,
      messages: messages,
      maxTokens: 650,
    );
    return _extractAction(raw);
  }

  static Future<String> generateNarrative({
    required AiProvider provider,
    required String apiKey,
    required String model,
    required String prompt,
  }) async {
    if (provider == AiProvider.none || apiKey.trim().isEmpty) {
      throw const AskAiException('No AI API key configured in Settings.');
    }
    return _dispatchMessages(
      provider: provider,
      apiKey: apiKey.trim(),
      model: model.trim().isEmpty ? provider.defaultModel : model.trim(),
      systemPrompt:
          'You are Spendwiser AI. Reply with exactly 3 concise Markdown bullets '
          '(using `- **Label:** ...`) in Indian Rupees (₹). Be specific and practical.',
      messages: [AiChatMessage(role: 'user', text: prompt)],
      maxTokens: 350,
    );
  }

  static Future<String> auditSubscriptions({
    required AiProvider provider,
    required String apiKey,
    required String model,
    required FinanceSnapshot snapshot,
  }) async {
    final contextJson = buildContext(
      snapshot,
      query: 'subscriptions recurring',
    );
    return _dispatchMessages(
      provider: provider,
      apiKey: apiKey.trim(),
      model: model.trim().isEmpty ? provider.defaultModel : model.trim(),
      systemPrompt:
          'You are Spendwiser AI. Audit the user’s subscriptions and recurring charges. '
          'Identify overlapping, creeping, or low-value charges, calculate total annual cost in ₹, '
          'and suggest 2–3 concrete cuts with estimated yearly ₹ savings. Keep it concise in Markdown bullets.',
      messages: [
        AiChatMessage(
          role: 'user',
          text: 'Financial snapshot (JSON):\n$contextJson\n\nAudit my subscriptions & recurring leaks.',
        ),
      ],
      maxTokens: 450,
    );
  }

  static Future<AiParsedTransaction> parseTransactionWithAi({
    required AiProvider provider,
    required String apiKey,
    required String model,
    required String rawInput,
    required List<String> categories,
  }) async {
    if (provider == AiProvider.none || apiKey.trim().isEmpty) {
      throw const AskAiException('No AI API key configured in Settings.');
    }
    final raw = await _dispatchMessages(
      provider: provider,
      apiKey: apiKey.trim(),
      model: model.trim().isEmpty ? provider.defaultModel : model.trim(),
      systemPrompt:
          'Extract transaction details from messy voice/receipt/SMS text. '
          'Return ONLY valid JSON with keys: merchant (string), amount (positive number), '
          'category (must be one of: ${categories.join(', ')}), isIncome (boolean), note (short string).',
      messages: [AiChatMessage(role: 'user', text: rawInput)],
      maxTokens: 200,
    );
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
    if (jsonMatch == null) {
      throw const AskAiException('Could not parse AI transaction output.');
    }
    final map = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
    final cat = (map['category'] ?? 'Miscellaneous').toString();
    return AiParsedTransaction(
      merchant: (map['merchant'] ?? '').toString().trim(),
      amount: (map['amount'] as num? ?? 0).toDouble().abs(),
      category: categories.contains(cat) ? cat : 'Miscellaneous',
      isIncome: map['isIncome'] == true,
      note: (map['note'] ?? '').toString().trim(),
    );
  }

  static Future<String> testConnection({
    required AiProvider provider,
    required String apiKey,
    required String model,
  }) async {
    if (provider == AiProvider.none || apiKey.trim().isEmpty) {
      throw const AskAiException('Enter an API key first.');
    }
    return _dispatchMessages(
      provider: provider,
      apiKey: apiKey.trim(),
      model: model.trim().isEmpty ? provider.defaultModel : model.trim(),
      systemPrompt: _systemPrompt,
      messages: const [
        AiChatMessage(role: 'user', text: 'Reply with exactly: Connected'),
      ],
      maxTokens: 32,
    );
  }

  static AiChatReply parseReply(String raw) => _extractAction(raw);

  static AiChatReply _extractAction(String raw) {
    final actionMatch = RegExp(
      r'```action\s*(\{[\s\S]*?\})\s*```',
    ).firstMatch(raw);
    if (actionMatch == null) return AiChatReply(text: raw.trim());

    final cleanText = raw.replaceRange(actionMatch.start, actionMatch.end, '').trim();
    try {
      final map = jsonDecode(actionMatch.group(1)!) as Map<String, dynamic>;
      final kind = (map['action'] ?? '').toString();
      final amount = (map['amount'] as num? ?? 0).toDouble().abs();
      if (amount <= 0) return AiChatReply(text: cleanText);
      if (kind == 'log_tx') {
        return AiChatReply(
          text: cleanText,
          action: AiActionProposal(
            type: AiActionType.logTx,
            title: (map['merchant'] ?? 'Expense').toString(),
            amount: amount,
            category: (map['category'] ?? 'Miscellaneous').toString(),
            isIncome: map['isIncome'] == true,
            note: (map['note'] ?? '').toString(),
          ),
        );
      }
      if (kind == 'add_budget') {
        final cat = (map['category'] ?? 'Miscellaneous').toString();
        return AiChatReply(
          text: cleanText,
          action: AiActionProposal(
            type: AiActionType.addBudget,
            title: '$cat budget',
            amount: amount,
            category: cat,
          ),
        );
      }
      if (kind == 'add_goal') {
        return AiChatReply(
          text: cleanText,
          action: AiActionProposal(
            type: AiActionType.addGoal,
            title: (map['title'] ?? 'Savings Goal').toString(),
            amount: amount,
          ),
        );
      }
    } catch (_) {}
    return AiChatReply(text: cleanText);
  }

  static Future<String> _dispatchMessages({
    required AiProvider provider,
    required String apiKey,
    required String model,
    required String systemPrompt,
    required List<AiChatMessage> messages,
    int maxTokens = 500,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      switch (provider) {
        case AiProvider.none:
          throw const AskAiException('AI provider is off.');
        case AiProvider.gemini:
          final uri = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/'
            '${Uri.encodeComponent(model)}:generateContent?key=${Uri.encodeQueryComponent(apiKey)}',
          );
          final req = await client.postUrl(uri);
          req.headers.contentType = ContentType.json;
          req.write(
            jsonEncode({
              'systemInstruction': {
                'parts': [
                  {'text': systemPrompt},
                ],
              },
              'contents': [
                for (final m in messages)
                  {
                    'role': m.role == 'assistant' ? 'model' : 'user',
                    'parts': [
                      {'text': m.text},
                    ],
                  },
              ],
              'generationConfig': {
                'temperature': 0.2,
                'maxOutputTokens': maxTokens,
              },
            }),
          );
          final res = await req.close().timeout(const Duration(seconds: 25));
          final body = await res.transform(utf8.decoder).join();
          if (res.statusCode >= 400) {
            throw AskAiException(_friendlyError(res.statusCode, body));
          }
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          final candidates = decoded['candidates'] as List?;
          String? text;
          if (candidates != null && candidates.isNotEmpty) {
            final contentMap = (candidates.first as Map)['content'] as Map?;
            final parts = contentMap?['parts'] as List?;
            text = parts
                ?.map((p) => (p as Map)['text'] ?? '')
                .join('\n')
                .trim();
          }
          if (text == null || text.isEmpty) {
            throw const AskAiException('Empty response from Gemini.');
          }
          return text;

        case AiProvider.openrouter:
          final uri = Uri.parse(
            'https://openrouter.ai/api/v1/chat/completions',
          );
          final req = await client.postUrl(uri);
          req.headers.contentType = ContentType.json;
          req.headers.set('Authorization', 'Bearer $apiKey');
          req.headers.set('HTTP-Referer', 'https://hariharen.space');
          req.headers.set('X-Title', 'SpendWiser');
          req.write(
            jsonEncode({
              'model': model,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                for (final m in messages)
                  {'role': m.role, 'content': m.text},
              ],
              'temperature': 0.2,
              'max_tokens': maxTokens,
            }),
          );
          final res = await req.close().timeout(const Duration(seconds: 25));
          final body = await res.transform(utf8.decoder).join();
          if (res.statusCode >= 400) {
            throw AskAiException(_friendlyError(res.statusCode, body));
          }
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          final choices = decoded['choices'] as List?;
          String? content;
          if (choices != null && choices.isNotEmpty) {
            final messageMap = (choices.first as Map)['message'] as Map?;
            content = messageMap?['content']?.toString().trim();
          }
          if (content == null || content.isEmpty) {
            throw const AskAiException('Empty response from OpenRouter.');
          }
          return content;

        case AiProvider.claude:
          final uri = Uri.parse('https://api.anthropic.com/v1/messages');
          final req = await client.postUrl(uri);
          req.headers.contentType = ContentType.json;
          req.headers.set('x-api-key', apiKey);
          req.headers.set('anthropic-version', '2023-06-01');
          req.write(
            jsonEncode({
              'model': model,
              'system': systemPrompt,
              'messages': [
                for (final m in messages)
                  {'role': m.role, 'content': m.text},
              ],
              'max_tokens': maxTokens,
              'temperature': 0.2,
            }),
          );
          final res = await req.close().timeout(const Duration(seconds: 25));
          final body = await res.transform(utf8.decoder).join();
          if (res.statusCode >= 400) {
            throw AskAiException(_friendlyError(res.statusCode, body));
          }
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          final content = decoded['content'] as List?;
          final text = content
              ?.whereType<Map>()
              .where((b) => b['type'] == 'text')
              .map((b) => b['text'] ?? '')
              .join('\n')
              .trim();
          if (text == null || text.isEmpty) {
            throw const AskAiException('Empty response from Claude.');
          }
          return text;
      }
    } on AskAiException {
      rethrow;
    } on SocketException {
      throw const AskAiException('No internet connection.');
    } catch (e) {
      throw AskAiException('AI request failed: $e');
    } finally {
      client.close(force: true);
    }
  }

  static String _friendlyError(int code, String body) {
    if (code == 401 || code == 403) {
      return 'Invalid or unauthorized API key ($code).';
    }
    if (code == 429) {
      return 'Rate limit or quota reached (429). Try again shortly.';
    }
    try {
      final map = jsonDecode(body) as Map<String, dynamic>;
      final err = map['error'];
      if (err is Map && err['message'] != null) {
        return '${err['message']} ($code)';
      }
    } catch (_) {}
    return 'Provider error ($code).';
  }
}
