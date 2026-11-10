import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/state/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/category_aliases.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/transaction.dart';
import '../services/capture_parser.dart';

void showReceiptScannerSheet(BuildContext context) {
  showAppSheet(context, (_) => const ReceiptScannerSheet());
}

class ReceiptScannerSheet extends ConsumerStatefulWidget {
  const ReceiptScannerSheet({super.key});

  @override
  ConsumerState<ReceiptScannerSheet> createState() =>
      _ReceiptScannerSheetState();
}

class _ReceiptScannerSheetState extends ConsumerState<ReceiptScannerSheet>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final _merchant = TextEditingController();
  final _amount = TextEditingController();
  late final AnimationController _scanController;

  bool _isProcessing = false;
  String? _imagePath;
  ParsedCapture? _detected;
  String? _receiptError;
  double _confidence = 0;
  String? _category;
  String? _source;
  DateTime _date = DateTime.now();
  String _status = 'Align receipt within frame';

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    _merchant.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 90,
      );
      if (image == null) return;

      setState(() {
        _imagePath = image.path;
        _isProcessing = true;
        _detected = null;
        _receiptError = null;
        _status = 'Checking the image and reading text…';
      });

      final inputImage = InputImage.fromFilePath(image.path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      RecognizedText recognizedText;
      try {
        recognizedText = await recognizer.processImage(inputImage);
      } finally {
        await recognizer.close();
      }

      if (!mounted) return;
      _applyResult(CaptureParser.parseReceipt(recognizedText.text));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _detected = null;
        _confidence = 0;
        _receiptError = 'Could not read that image. Use a clear, well-lit photo of the receipt.';
        _status = _receiptError!;
      });
    }
  }

  void _applyResult(ReceiptParseResult result) {
    final capture = result.capture;
    if (!result.isReceipt || capture == null) {
      setState(() {
        _isProcessing = false;
        _detected = null;
        _confidence = 0;
        _receiptError = result.message;
        _status = result.message;
      });
      return;
    }

    final snapshot = ref.read(financeSnapshotProvider);
    final categories = ref.read(settingsProvider).categories.keys;
    final defaultAccountId = ref
        .read(userProfileRepositoryProvider)
        ?.defaultAccountId;
    var source = '';
    if (defaultAccountId != null &&
        snapshot.accounts.any((account) => account.id == defaultAccountId)) {
      source = 'a:$defaultAccountId';
    } else if (snapshot.accounts.isNotEmpty) {
      source = 'a:${snapshot.accounts.first.id}';
    } else if (snapshot.cards.isNotEmpty) {
      source = 'c:${snapshot.cards.first.id}';
    }

    _merchant.text = capture.merchant;
    _amount.text = capture.amount == capture.amount.roundToDouble()
        ? capture.amount.round().toString()
        : capture.amount.toStringAsFixed(2);

    setState(() {
      _isProcessing = false;
      _detected = capture;
      _receiptError = null;
      _confidence = result.confidence;
      _category = resolveCategoryName(capture.category, categories);
      _source = source;
      _date = capture.date ?? DateTime.now();
      _status = result.message;
    });
  }

  void _useDemoReceipt() {
    setState(() {
      _isProcessing = true;
      _detected = null;
      _receiptError = null;
      _status = 'Reading demo receipt…';
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      const sampleText = '''
Blinkit Commerce Pvt Ltd
Order #BK-948123
Date: 09/11/2026
Amul Gold Milk 500ml x2  128.00
Farm Fresh Eggs 12pk     96.00
Daawat Basmati Rice 5kg  520.00
Delivery Fee              98.00
Total Amount Payable    ₹842.00
Thank you for shopping with us!
''';
      _applyResult(CaptureParser.parseReceipt(sampleText));
    });
  }

  void _reset() {
    setState(() {
      _detected = null;
      _receiptError = null;
      _confidence = 0;
      _imagePath = null;
      _category = null;
      _source = null;
      _merchant.clear();
      _amount.clear();
      _status = 'Take a clear photo of the receipt';
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final c = context.spend;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme
                .copyWith(primary: c.ac, surface: c.c1, onSurface: c.tx),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _confirmAndLog() async {
    final detected = _detected;
    if (detected == null) return;
    final value = double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;
    final merchant = _merchant.text.trim();
    if (merchant.isEmpty) {
      ref.read(toastProvider.notifier).show('Add a merchant name');
      return;
    }
    if (value <= 0) {
      ref.read(toastProvider.notifier).show('Check the receipt total');
      return;
    }

    final isCard = _source?.startsWith('c:') ?? false;
    final sourceId = (_source?.length ?? 0) > 2 ? _source!.substring(2) : null;
    final category = _category ?? 'Other';
    final note = detected.items.isEmpty
        ? 'Scanned receipt'
        : 'Scanned receipt · ${detected.items.length} items';

    await ref
        .read(transactionRepositoryProvider)
        .addTransaction(
          TransactionDraft(
            merchant: merchant,
            category: category,
            amount: -value,
            date: DateTime(_date.year, _date.month, _date.day, 12),
            addedAt: DateTime.now(),
            accountId: isCard ? null : sourceId,
            cardId: isCard ? sourceId : null,
            note: note,
          ),
        );

    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('Logged ${rupee(value)} · $merchant');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final detected = _detected;
    final snapshot = ref.watch(financeSnapshotProvider);
    final categories = ref.watch(settingsProvider).categories.keys.toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SheetTitle('Scan receipt'),
            if (detected != null || _imagePath != null)
              AppPill(label: 'Retake', onTap: _reset),
          ],
        ),
        const SizedBox(height: 14),
        if (detected == null) ...[
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: c.c2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.ln),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_imagePath != null)
                  Positioned.fill(
                    child: Image.file(File(_imagePath!), fit: BoxFit.cover),
                  ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: CustomPaint(
                      painter: _ViewfinderPainter(accent: c.ac),
                    ),
                  ),
                ),
                if (_isProcessing)
                  AnimatedBuilder(
                    animation: _scanController,
                    builder: (context, child) {
                      return Positioned(
                        top: 24 + (_scanController.value * 142),
                        left: 24,
                        right: 24,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: c.ac,
                            boxShadow: [
                              BoxShadow(
                                color: c.ac.withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                else if (_imagePath == null)
                  Center(
                    child: SpendIcon(
                      'scan',
                      size: 48,
                      color: c.mu.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _receiptError ??
                (_isProcessing
                    ? _status
                    : 'Take a photo or upload a receipt image'),
            textAlign: TextAlign.center,
            style: AppTypography.sans(
              size: 13,
              color: _receiptError == null ? c.mu : c.co,
            ),
          ),
          if (_receiptError != null) ...[
            const SizedBox(height: 10),
            AppCard(
              child: Row(
                children: [
                  IconTile(icon: 'receipt', color: c.co, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Make sure the full bill is visible, avoid glare, and keep the total line in frame.',
                      style: AppTypography.sans(size: 12, color: c.mu),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Camera',
                  leading: SpendIcon('scan', size: 16, color: c.tx),
                  onTap: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'Gallery',
                  leading: SpendIcon('search', size: 16, color: c.tx),
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Use demo receipt (Blinkit ₹842)',
            onTap: _useDemoReceipt,
          ),
          const SizedBox(height: 10),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Receipt detected',
                  style: AppTypography.sans(size: 13, color: c.mu),
                ),
              ),
              AppPill(
                label: '${(_confidence * 100).round()}% match',
                active: _confidence >= 0.65,
                textColor: _confidence < 0.65 ? c.co : null,
                borderColor: _confidence < 0.65
                    ? c.co.withValues(alpha: 0.5)
                    : null,
              ),
            ],
          ),
          if (_confidence < 0.65) ...[
            const SizedBox(height: 6),
            Text(
              'The scan is uncertain. Check the merchant, total and date before logging.',
              style: AppTypography.sans(size: 12, color: c.co),
            ),
          ],
          const SizedBox(height: 12),
          const _ReceiptLabel('Merchant'),
          _ReceiptInput(
            controller: _merchant,
            hint: 'Merchant name',
            capitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 10),
          const _ReceiptLabel('Total'),
          _ReceiptInput(
            controller: _amount,
            hint: '0.00',
            number: true,
            prefix: '₹ ',
            large: true,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ReceiptLabel('Category'),
                    AppSelect<String>(
                      value:
                          _category ??
                          (categories.contains('Other')
                              ? 'Other'
                              : (categories.isNotEmpty
                                    ? categories.first
                                    : 'Other')),
                      options: [
                        if (categories.isEmpty)
                          const AppSelectOption('Other', 'Other'),
                        for (final category in categories)
                          AppSelectOption(category, category),
                      ],
                      onChanged: (value) => setState(
                        () => _category = value == null || value.isEmpty
                            ? 'Other'
                            : value,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ReceiptLabel('Account'),
                    AppSelect<String>(
                      value: _source ?? '',
                      options: [
                        for (final account in snapshot.accounts)
                          AppSelectOption(
                            'a:${account.id}',
                            '${account.name} (${rupee(account.balance)})',
                          ),
                        for (final card in snapshot.cards)
                          AppSelectOption(
                            'c:${card.id}',
                            '${card.name} (${rupee(card.outstanding)} due)',
                          ),
                        if (snapshot.accounts.isEmpty && snapshot.cards.isEmpty)
                          const AppSelectOption('', 'No account'),
                      ],
                      onChanged: (value) =>
                          setState(() => _source = value ?? ''),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _ReceiptLabel('Date'),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: c.c2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      shortDate(_date),
                      style: AppTypography.sans(size: 14, color: c.tx),
                    ),
                  ),
                  SpendIcon('calendar', size: 16, color: c.mu),
                ],
              ),
            ),
          ),
          if (detected.items.isNotEmpty) ...[
            const SizedBox(height: 14),
            const _ReceiptLabel('Items found'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < detected.items.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              detected.items[i].name,
                              style: AppTypography.sans(size: 13, color: c.tx),
                            ),
                          ),
                          Text(
                            rupee(detected.items[i].price),
                            style: AppTypography.sans(
                              size: 13,
                              color: c.tx,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (detected.items.isNotEmpty)
                    Divider(color: c.ln, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Scanned total',
                        style: AppTypography.sans(
                          size: 13,
                          color: c.mu,
                          weight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        rupee(detected.amount),
                        style: AppTypography.serif(size: 20, color: c.tx),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            label:
                'Log receipt · ${rupee(double.tryParse(_amount.text.replaceAll(',', '')) ?? detected.amount)}',
            onTap: _confirmAndLog,
          ),
        ],
      ],
    );
  }
}

class _ReceiptLabel extends StatelessWidget {
  const _ReceiptLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.caption(context.spend.mu),
      ),
    );
  }
}

class _ReceiptInput extends StatelessWidget {
  const _ReceiptInput({
    required this.controller,
    required this.hint,
    this.number = false,
    this.prefix,
    this.large = false,
    this.capitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String hint;
  final bool number;
  final String? prefix;
  final bool large;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 13, vertical: large ? 10 : 13),
      decoration: BoxDecoration(
        color: c.c2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textCapitalization: capitalization,
        style: large
            ? AppTypography.serif(
                size: 30,
                color: c.tx,
                letterSpacing: -0.8,
                height: 1.1,
              )
            : AppTypography.sans(size: 14, color: c.tx),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: AppTypography.sans(size: 13, color: c.mu),
          prefixText: prefix,
          prefixStyle: AppTypography.serif(size: 24, color: c.mu),
        ),
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  final Color accent;

  const _ViewfinderPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 22.0;

    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - cornerLength),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - cornerLength, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter oldDelegate) => false;
}
