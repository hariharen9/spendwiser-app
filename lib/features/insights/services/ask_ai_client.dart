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

abstract final class AskAiClient {
  static const _systemPrompt =
      'You are Spendwiser AI, a calm, sharp Indian personal-finance assistant. '
      'Answer concisely using ONLY the structured financial snapshot provided. '
      'Format currency in Indian Rupees (₹ with lakhs/crores or commas as shown). '
      'Cite exact numbers, dates, and merchants from the data. '
      'Never invent transactions or balances. Use short bullet points when helpful.';

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
      'activeSubscriptionsMonthly': rupee(
        snapshot.subscriptions
            .where((s) => s.active)
            .fold<double>(0, (s, sub) => s + sub.price),
      ),
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
    if (provider == AiProvider.none || apiKey.trim().isEmpty) {
      throw const AskAiException('No AI API key configured in Settings.');
    }
    final contextJson = buildContext(snapshot, query: query, now: now);
    final userPrompt =
        'Financial snapshot (JSON):\n$contextJson\n\nUser question: $query';
    return _dispatch(
      provider: provider,
      apiKey: apiKey.trim(),
      model: model.trim().isEmpty ? provider.defaultModel : model.trim(),
      userPrompt: userPrompt,
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
    return _dispatch(
      provider: provider,
      apiKey: apiKey.trim(),
      model: model.trim().isEmpty ? provider.defaultModel : model.trim(),
      userPrompt: 'Reply with exactly: Connected',
    );
  }

  static Future<String> _dispatch({
    required AiProvider provider,
    required String apiKey,
    required String model,
    required String userPrompt,
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
                  {'text': _systemPrompt},
                ],
              },
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': userPrompt},
                  ],
                },
              ],
              'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 500},
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
                {'role': 'system', 'content': _systemPrompt},
                {'role': 'user', 'content': userPrompt},
              ],
              'temperature': 0.2,
              'max_tokens': 500,
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
              'system': _systemPrompt,
              'messages': [
                {'role': 'user', 'content': userPrompt},
              ],
              'max_tokens': 500,
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
