import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../shared/design_system/app_colors.dart';
import '../../../shared/design_system/app_haptics.dart';
import '../../../shared/design_system/widgets/primary_button.dart';
import '../data/parsed_address.dart';
import '../services/parcel_api.dart';
import '../state/intake_controller.dart';
import 'manual_entry_sheet.dart';

/// Full-screen scanner view.
///
/// Displays the live camera preview, handles barcode detection, OCR fallback
/// when an order is not found, and delegates back to the caller's
/// [IntakeController].
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.controller});

  final IntakeController controller;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late final MobileScannerController _scanner;
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  bool _busy = false;
  bool _notFound = false;
  bool _ocrBusy = false;
  String? _lastOrderId;
  String? _feedbackMessage;
  bool _feedbackIsSuccess = false;

  @override
  void initState() {
    super.initState();
    _scanner = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.normal,
      formats: const [
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code39,
        BarcodeFormat.dataMatrix,
        BarcodeFormat.pdf417,
      ],
    );
  }

  @override
  void dispose() {
    _scanner.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // Barcode detection
  // ---------------------------------------------------------------

  void _onDetect(BarcodeCapture capture) {
    if (_busy || _ocrBusy) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;
    _handleBarcode(raw);
  }

  Future<void> _handleBarcode(String value) async {
    setState(() {
      _busy = true;
      _notFound = false;
      _feedbackMessage = null;
    });
    await _scanner.stop();
    Haptics.light();

    try {
      await widget.controller.scanBarcode(value);
      if (!mounted) return;
      await _showFeedback('Parcel added', success: true);
    } on OrderNotFoundException {
      if (!mounted) return;
      setState(() => _notFound = true);
      _lastOrderId = value;
      Haptics.light();
    } on ParcelApiException catch (e) {
      if (!mounted) return;
      await _showFeedback(e.message, success: false);
    }
  }

  Future<void> _showFeedback(String message, {required bool success}) async {
    setState(() {
      _feedbackMessage = message;
      _feedbackIsSuccess = success;
    });
    if (success) Haptics.success();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _feedbackMessage = null);
    await _resumeScan();
  }

  Future<void> _resumeScan() async {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _ocrBusy = false;
      _notFound = false;
    });
    await _scanner.start();
  }

  // ---------------------------------------------------------------
  // OCR label flow
  // ---------------------------------------------------------------

  Future<void> _captureLabel() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (file == null) {
      await _resumeScan();
      return;
    }

    setState(() {
      _ocrBusy = true;
      _busy = true;
    });

    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final recognized = await _textRecognizer.processImage(inputImage);
      final text = recognized.text.trim();

      if (!mounted) return;
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No text detected on label')),
        );
        await _resumeScan();
        return;
      }

      // Send raw text to backend OCR endpoint
      final ocrResult = await widget.controller.ocrRawText(text);
      if (!mounted) return;

      // Show address confirmation sheet (pops with _OcrDecision or null)
      final decision = await showModalBottomSheet<_OcrDecision>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _OcrSheetWrapper(parsedAddress: ocrResult.parsedAddress),
      );

      if (!mounted) return;
      if (decision == null) {
        await _resumeScan();
        return;
      }

      if (decision.edited) {
        await widget.controller.commitEditedOcr(decision.address!);
      } else {
        await widget.controller.commitOcr(ocrResult);
      }
      if (!mounted) return;
      await _showFeedback('Parcel added', success: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OCR failed. Try entering manually.')),
        );
      }
    } finally {
      if (mounted) await _resumeScan();
    }
  }

  // ---------------------------------------------------------------
  // Manual entry
  // ---------------------------------------------------------------

  Future<void> _openManualEntry() async {
    final address = await showModalBottomSheet<ManualAddress>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManualEntrySheet(initialOrderId: _lastOrderId),
    );
    if (address == null || !mounted) return;

    setState(() {
      _busy = true;
      _ocrBusy = true;
    });
    await _scanner.stop();

    try {
      await widget.controller.manualSave(address);
      if (!mounted) return;
      await _showFeedback('Parcel added', success: true);
    } on ParcelApiException catch (e) {
      if (!mounted) return;
      await _showFeedback(e.message, success: false);
    }
  }

  // ---------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera
          MobileScanner(controller: _scanner, onDetect: _onDetect),

          // Dark gradient overlay at top + bottom for legibility
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black87,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black87,
                  ],
                  stops: const [0.0, 0.2, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _iconButton(Icons.close_rounded, onTap: () => Navigator.pop(context)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFC5F517))),
                        const SizedBox(width: 6),
                        const Text('Scanning', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scan window hint
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24, width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),

          // Feedback banner
          if (_feedbackMessage != null)
            Center(
              child: AnimatedOpacity(
                opacity: _feedbackMessage != null ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: (_feedbackIsSuccess ? const Color(0xFF4ADE80) : const Color(0xFFFF5C5C)).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_feedbackIsSuccess ? Icons.check_circle : Icons.error_outline, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(_feedbackMessage!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),

          // Not-found panel
          if (_notFound)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildNotFoundPanel(c),
            ),
        ],
      ),
    );
  }

  Widget _buildNotFoundPanel(AppColors c) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, color: c.warning, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Order not found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'Take a photo of the label or enter the address manually.',
              style: TextStyle(color: c.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Capture label photo',
              icon: Icons.camera_alt_rounded,
              onPressed: _captureLabel,
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Type address manually',
              variant: PrimaryButtonVariant.ghost,
              icon: Icons.keyboard_rounded,
              onPressed: () async {
                await _scanner.stop();
                await _openManualEntry();
              },
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Rescan',
              variant: PrimaryButtonVariant.ghost,
              icon: Icons.qr_code_scanner_rounded,
              onPressed: _resumeScan,
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// OCR sheet wrapper that pops with a typed result
// ---------------------------------------------------------------------------

class _OcrDecision {
  const _OcrDecision({required this.edited, this.address});
  final bool edited;
  final ManualAddress? address;
}

class _OcrSheetWrapper extends StatefulWidget {
  const _OcrSheetWrapper({required this.parsedAddress});
  final ParsedAddress parsedAddress;

  @override
  State<_OcrSheetWrapper> createState() => _OcrSheetWrapperState();
}

class _OcrSheetWrapperState extends State<_OcrSheetWrapper> {
  final _street = TextEditingController();
  final _area = TextEditingController();
  final _city = TextEditingController();
  final _pincode = TextEditingController();

  late final String _origS, _origA, _origC, _origP;

  @override
  void initState() {
    super.initState();
    _origS = widget.parsedAddress.street ?? '';
    _origA = widget.parsedAddress.area ?? '';
    _origC = widget.parsedAddress.city ?? '';
    _origP = widget.parsedAddress.pincode ?? '';
    _street.text = _origS;
    _area.text = _origA;
    _city.text = _origC;
    _pincode.text = _origP;
  }

  @override
  void dispose() {
    _street.dispose();
    _area.dispose();
    _city.dispose();
    _pincode.dispose();
    super.dispose();
  }

  bool get _edited =>
      _street.text.trim() != _origS ||
      _area.text.trim() != _origA ||
      _city.text.trim() != _origC ||
      _pincode.text.trim() != _origP;

  ManualAddress get _address => ManualAddress(
        street: _street.text.trim().isEmpty ? null : _street.text.trim(),
        area: _area.text.trim().isEmpty ? null : _area.text.trim(),
        city: _city.text.trim().isEmpty ? null : _city.text.trim(),
        pincode: _pincode.text.trim().isEmpty ? null : _pincode.text.trim(),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Confirm label address', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Parsed from label photo', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.textMuted)),
          const SizedBox(height: 16),
          _field(_street, 'Street'),
          const SizedBox(height: 12),
          _field(_area, 'Area / colony'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _field(_city, 'City')),
            const SizedBox(width: 12),
            Expanded(child: _field(_pincode, 'Pincode')),
          ]),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Confirm & save',
            icon: Icons.check_rounded,
            onPressed: () {
              Haptics.light();
              Navigator.pop(context, _OcrDecision(edited: _edited, address: _address));
            },
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Cancel',
            variant: PrimaryButtonVariant.ghost,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint) {
    return TextFormField(
      controller: ctrl,
      style: Theme.of(context).textTheme.bodyMedium,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.appColors.textMuted),
        filled: true,
        fillColor: context.appColors.surfaceHigh,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
