import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/state/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/common.dart';
import '../services/capture_parser.dart';

void showReceiptScannerSheet(BuildContext context) {
  showAppSheet(context, (_) => const ReceiptScannerSheet());
}

class ReceiptScannerSheet extends ConsumerStatefulWidget {
  const ReceiptScannerSheet({super.key});

  @override
  ConsumerState<ReceiptScannerSheet> createState() => _ReceiptScannerSheetState();
}

class _ReceiptScannerSheetState extends ConsumerState<ReceiptScannerSheet>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late final AnimationController _scanController;

  bool _isProcessing = false;
  String? _imagePath;
  ParsedCapture? _detected;
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
        _status = 'Running ML text recognition…';
      });

      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final parsed = CaptureParser.parseReceiptText(recognizedText.text);

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _detected = parsed;
        _status = 'Receipt scanned successfully';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _status = 'Could not read receipt image. Try another photo.';
      });
    }
  }

  void _useDemoReceipt({String? merchant, double? total}) {
    setState(() {
      _isProcessing = true;
      _status = 'Reading demo receipt…';
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final sampleText = '''
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
      final parsed = CaptureParser.parseReceiptText(sampleText);
      setState(() {
        _isProcessing = false;
        _detected = parsed;
        _status = 'Receipt scanned successfully';
      });
    });
  }

  Future<void> _confirmAndLog() async {
    final detected = _detected;
    if (detected == null) return;

    final snapshot = ref.read(financeSnapshotProvider);
    final accountId = snapshot.accounts.isEmpty ? null : snapshot.accounts.first.id;

    await ref.read(transactionRepositoryProvider).addTransaction(
      detected.toDraft(accountId: accountId),
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show(
      'Logged ${rupee(detected.amount)} · ${detected.merchant}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final detected = _detected;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SheetTitle('Scan receipt'),
            if (detected != null)
              GestureDetector(
                onTap: () => setState(() {
                  _detected = null;
                  _imagePath = null;
                }),
                child: AppPill(label: 'Retake', onTap: () => setState(() => _detected = null)),
              ),
          ],
        ),
        const SizedBox(height: 14),

        if (detected == null) ...[
          // Scanner Viewfinder
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
                    child: Image.file(
                      File(_imagePath!),
                      fit: BoxFit.cover,
                    ),
                  ),

                // Corner brackets
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: CustomPaint(
                      painter: _ViewfinderPainter(accent: c.ac),
                    ),
                  ),
                ),

                // Laser scan line
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
                else
                  Center(
                    child: SpendIcon('scan', size: 48, color: c.mu.withValues(alpha: 0.6)),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Text(
            _isProcessing ? _status : 'Take a photo or upload receipt image',
            textAlign: TextAlign.center,
            style: AppTypography.sans(size: 13, color: c.mu),
          ),
          const SizedBox(height: 16),

          // Action buttons: Camera, Gallery, Demo
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
            label: 'Use Demo Receipt (Blinkit ₹842)',
            onTap: _useDemoReceipt,
          ),
          const SizedBox(height: 10),
        ] else ...[
          // Detected Receipt Breakdown
          Text(
            'Receipt detected',
            style: AppTypography.sans(size: 13, color: c.mu),
          ),
          const SizedBox(height: 2),
          Text(
            rupee(detected.amount),
            style: AppTypography.serif(size: 44, color: c.tx),
          ),
          Text(
            '${detected.merchant} · ${detected.category}',
            style: AppTypography.sans(
              size: 14,
              color: c.tx,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),

          // Items card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (detected.items.isNotEmpty) ...[
                  for (final item in detected.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: AppTypography.sans(size: 13, color: c.tx),
                            ),
                          ),
                          Text(
                            rupee(item.price),
                            style: AppTypography.sans(
                              size: 13,
                              color: c.tx,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Divider(color: c.ln, height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: AppTypography.sans(
                        size: 14,
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

          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Confirm & Log ${rupee(detected.amount)}',
            onTap: _confirmAndLog,
          ),
          const SizedBox(height: 10),
        ],
      ],
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

    // Top-left
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Top-right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter oldDelegate) => false;
}
