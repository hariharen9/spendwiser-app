import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/state/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/category_aliases.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/common.dart';
import '../services/capture_parser.dart';

void showVoiceCaptureSheet(BuildContext context) {
  showAppSheet(context, (_) => const VoiceCaptureSheet());
}

class VoiceCaptureSheet extends ConsumerStatefulWidget {
  const VoiceCaptureSheet({super.key});

  @override
  ConsumerState<VoiceCaptureSheet> createState() => _VoiceCaptureSheetState();
}

class _VoiceCaptureSheetState extends ConsumerState<VoiceCaptureSheet>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  late final AnimationController _pulseController;

  bool _speechEnabled = false;
  bool _isListening = false;
  String _words = '';
  String _status = 'Initializing microphone…';
  ParsedCapture? _parsed;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _initSpeech();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'listening') {
            setState(() {
              _isListening = true;
              _status = 'Listening… speak naturally';
            });
          } else if (status == 'notListening' || status == 'done') {
            setState(() {
              _isListening = false;
              if (_words.isEmpty) {
                _status = 'Tap microphone to speak';
              }
            });
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _status = 'Tap microphone to speak or pick a sample';
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _speechEnabled = available;
        _status = available
            ? 'Listening… speak naturally'
            : 'Speech service unavailable, try a sample below';
      });

      if (available) {
        _startListening();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _speechEnabled = false;
        _status = 'Microphone ready. Pick or say a phrase';
      });
    }
  }

  Future<void> _startListening() async {
    if (!_speechEnabled) return;
    setState(() {
      _isListening = true;
      _status = 'Listening…';
    });

    await _speech.listen(
      onResult: _onSpeechResult,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (!mounted) return;
    setState(() => _isListening = false);
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      _words = result.recognizedWords;
      _parsed = CaptureParser.parse(_words);
    });
  }

  void _applySample(String sample) {
    setState(() {
      _words = sample;
      _parsed = CaptureParser.parse(sample);
      _status = 'Phrase recognized';
    });
  }

  Future<void> _confirmAndLog() async {
    final parsed = _parsed;
    if (parsed == null) return;

    final snapshot = ref.read(financeSnapshotProvider);
    final defaultAccountId =
        ref.read(userProfileRepositoryProvider)?.defaultAccountId;
    final accountId = defaultAccountId ??
        (snapshot.accounts.isEmpty ? null : snapshot.accounts.first.id);
    final category = resolveCategoryName(
      parsed.category,
      ref.read(settingsProvider).categories.keys,
    );

    await ref.read(transactionRepositoryProvider).addTransaction(
      parsed.toDraft(accountId: accountId, category: category),
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    final label = parsed.isIncome
        ? 'Received ${rupee(parsed.amount)} · ${parsed.merchant}'
        : 'Logged ${rupee(parsed.amount)} · ${parsed.merchant}';
    ref.read(toastProvider.notifier).show(label);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final parsed = _parsed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('Voice capture'),
        const SizedBox(height: 16),

        // Glowing Animated Mic Circle
        Center(
          child: GestureDetector(
            onTap: () {
              if (_isListening) {
                _stopListening();
              } else {
                _startListening();
              }
            },
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = _isListening
                    ? 1.0 + (_pulseController.value * 0.14)
                    : 1.0;
                final glowAlpha = _isListening
                    ? 0.25 + (_pulseController.value * 0.35)
                    : 0.12;

                return Container(
                  width: 86 * scale,
                  height: 86 * scale,
                  decoration: BoxDecoration(
                    color: _isListening ? c.ac : c.c2,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? c.ac : Colors.white).withValues(
                          alpha: glowAlpha,
                        ),
                        blurRadius: _isListening ? 26 : 8,
                        spreadRadius: _isListening ? 14 : 2,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: SpendIcon(
                    _isListening ? 'mic' : 'mic',
                    size: 34,
                    color: _isListening ? c.aci : c.tx,
                    strokeWidth: 2,
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 18),

        // Spoken or Recognized Text
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _words.isNotEmpty ? '“$_words”' : _status,
            key: ValueKey(_words.isNotEmpty ? _words : _status),
            style: AppTypography.serif(
              size: _words.isNotEmpty ? 28 : 22,
              color: _words.isNotEmpty ? c.tx : c.mu,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 6),
        Text(
          _isListening
              ? 'Listening… tap mic to pause'
              : 'Tap mic or try a quick phrase below',
          textAlign: TextAlign.center,
          style: AppTypography.sans(size: 12, color: c.mu),
        ),

        const SizedBox(height: 16),

        // Detected Transaction Card
        if (parsed != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.c2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.ac.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.category(parsed.category).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: SpendIcon(
                    parsed.isIncome ? 'arrowDown' : 'arrowUp',
                    size: 20,
                    color: parsed.isIncome ? c.ac : c.co,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parsed.merchant,
                        style: AppTypography.sans(
                          size: 15,
                          color: c.tx,
                          weight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${parsed.category} · ${parsed.isIncome ? "Income" : "Expense"}',
                        style: AppTypography.sans(size: 12, color: c.mu),
                      ),
                    ],
                  ),
                ),
                Text(
                  (parsed.isIncome ? '+' : '-') + rupee(parsed.amount),
                  style: AppTypography.serif(
                    size: 22,
                    color: parsed.isIncome ? c.ac : c.tx,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Confirm & Log ${rupee(parsed.amount)}',
            onTap: _confirmAndLog,
          ),
          const SizedBox(height: 8),
        ],

        // Quick Spoken Suggestions (tap to test)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final sample in const [
              'Chai 40',
              'Uber 280',
              'Zomato four eighty six',
              'Swiggy 350',
              'Starbucks 250',
              'Dinner 1200',
              'Salary 50000',
            ])
              AppPill(
                label: sample,
                onTap: () => _applySample(sample),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
