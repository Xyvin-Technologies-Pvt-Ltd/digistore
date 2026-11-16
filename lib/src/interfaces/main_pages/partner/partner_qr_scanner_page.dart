import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../data/constants/color_constants.dart';
import '../../../data/constants/style_constants.dart';
import '../../../data/providers/bulk_redemption_provider.dart';
import '../../../data/providers/offers_provider.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/services/toast_service.dart';
import '../../components/primary_button.dart';
import '../../components/primary_text_field.dart';

class PartnerQrScannerPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> args;

  const PartnerQrScannerPage({super.key, required this.args});

  @override
  ConsumerState<PartnerQrScannerPage> createState() =>
      _PartnerQrScannerPageState();
}

class _PartnerQrScannerPageState extends ConsumerState<PartnerQrScannerPage> {
  MobileScannerController? _controller;

  bool _isProcessing = false;
  bool _torchOn = false;
  bool _permissionReady = false;
  bool _starting = true;
  String? _fatalError;

  String? get _expectedOfferId =>
      (widget.args['id'] ?? widget.args['_id'])?.toString();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;

    // Camera scanning is not supported on desktop Linux/Windows builds.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows)) {
      setState(() {
        _starting = false;
        _fatalError =
            'QR scanning is only available on Android and iOS devices.';
      });
      return;
    }

    final status = await Permission.camera.request();
    if (!mounted) return;

    if (!status.isGranted) {
      setState(() {
        _starting = false;
        _fatalError = status.isPermanentlyDenied
            ? 'Camera permission is blocked. Enable it in system settings.'
            : 'Camera permission is required to scan customer QR codes.';
      });
      return;
    }

    final controller = MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.normal,
      formats: const [BarcodeFormat.qrCode],
    );

    setState(() {
      _controller = controller;
      _permissionReady = true;
      _starting = false;
    });

    try {
      await controller.start();
    } on MissingPluginException catch (e, st) {
      debugPrint('mobile_scanner MissingPluginException: $e\n$st');
      if (!mounted) return;
      setState(() {
        _fatalError =
            'QR scanner plugin is not linked. Stop the app completely and run a full rebuild (not hot reload).';
      });
    } on MobileScannerException catch (e) {
      debugPrint('mobile_scanner error: $e');
      if (!mounted) return;
      setState(() {
        _fatalError = e.errorDetails?.message ?? e.errorCode.message;
      });
    } catch (e, st) {
      debugPrint('mobile_scanner start failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _fatalError = 'Unable to start the camera. Please try again.';
      });
    }
  }

  Map<String, dynamic>? _tryDecodeJsonMap(String raw) {
    try {
      final trimmed = raw.trim();
      if (!trimmed.startsWith('{')) return null;
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _completeBulkScan({
    required String batchId,
    required String qrToken,
  }) async {
    if (batchId.isEmpty) {
      await _handleScanError('Bulk QR is missing batch id.');
      return;
    }
    if (!mounted) return;

    final saleAmount = await _promptSaleAmount();
    if (!mounted) return;
    if (saleAmount == null) {
      await _resumeScanning();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
    );

    try {
      final result = await ref
          .read(bulkRedemptionRepositoryProvider)
          .partnerScanBulkQr(
            batchId: batchId,
            qrToken: qrToken,
            saleAmount: saleAmount,
          );

      if (!mounted) return;
      Navigator.of(context).pop();

      ToastService().showToast(
        context,
        result.message ??
            'Bulk redemption successful (${result.offersCount} offers)',
        type: ToastType.success,
      );

      Navigator.of(context).pushReplacementNamed(
        'partnerRedemptionSuccess',
        arguments: {
          'redemption': {
            'redemptionId': result.batchId ?? batchId,
            'offersCount': result.offersCount,
            'totalDiscount': result.totalDiscount,
            'totalPointsEarned': result.totalPointsEarned,
            'status': result.status,
            if (result.spinUnlocked != null)
              'spinUnlocked': {
                'hasSpinAvailable': result.spinUnlocked!.hasSpinAvailable,
                'transactionId': result.spinUnlocked!.transactionId,
                'campaignId': result.spinUnlocked!.campaignId,
              },
          },
          'offer': {
            'title': 'Bulk redemption',
            'subtitle': '${result.offersCount} offers completed',
          },
        },
      );

      if (mounted && result.spinUnlocked?.hasSpinAvailable == true) {
        ToastService().showToast(
          context,
          'Customer unlocked a Spin & Win chance',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      await _handleScanError(e.toString());
    }
  }

  /// Decode JWT payload without verification (server verifies signature).
  Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.trim().split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final jsonStr = utf8.decode(base64Url.decode(normalized));
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _controller == null) return;

    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstWhere((v) => v.trim().isNotEmpty, orElse: () => '');

    if (raw.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      await _controller!.stop();
    } catch (_) {}

    // Plain JSON bulk QR: { "type": "bulk_redemption", "batchId": "..." }
    Map<String, dynamic>? payload = _tryDecodeJsonMap(raw);
    payload ??= _decodeJwtPayload(raw);
    if (payload == null) {
      await _handleScanError(
        'Invalid QR code. Ask the customer to generate a new one.',
      );
      return;
    }

    final type = (payload['type'] ?? '').toString().toLowerCase();
    final batchId = (payload['batchId'] ?? payload['batch_id'])?.toString();
    if (type == 'bulk_redemption' ||
        (batchId != null &&
            batchId.isNotEmpty &&
            payload['redemptionId'] == null)) {
      await _completeBulkScan(
        batchId: batchId ?? '',
        qrToken: raw.trim(),
      );
      return;
    }

    final redemptionId = payload['redemptionId']?.toString();
    final offerId = payload['offerId']?.toString();

    if (redemptionId == null || redemptionId.isEmpty) {
      await _handleScanError('QR code is missing redemption details.');
      return;
    }

    final expectedOfferId = _expectedOfferId;
    if (expectedOfferId != null &&
        offerId != null &&
        offerId.isNotEmpty &&
        offerId != expectedOfferId) {
      await _handleScanError(
        'This QR is for a different offer. Ask the customer to open the correct deal.',
      );
      return;
    }

    if (!mounted) return;

    final saleAmount = await _promptSaleAmount();
    if (!mounted) return;

    if (saleAmount == null) {
      await _resumeScanning();
      return;
    }

    await _completeScan(
      redemptionId: redemptionId,
      qrToken: raw.trim(),
      saleAmount: saleAmount,
    );
  }

  Future<double?> _promptSaleAmount() {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _SaleAmountSheet(),
    );
  }

  Future<void> _completeScan({
    required String redemptionId,
    required String qrToken,
    required double saleAmount,
  }) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
    );

    final response = await ref
        .read(offersProvider.notifier)
        .partnerScanQrRedemption(
          redemptionId: redemptionId,
          qrToken: qrToken,
          saleAmount: saleAmount,
        );

    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss loader

    if (response.success) {
      final data = response.data?['data'] is Map
          ? Map<String, dynamic>.from(response.data!['data'] as Map)
          : (response.data is Map
                ? Map<String, dynamic>.from(response.data as Map)
                : <String, dynamic>{});

      ToastService().showToast(
        context,
        'Redemption successful!',
        type: ToastType.success,
      );

      Navigator.of(context).pushReplacementNamed(
        'partnerRedemptionSuccess',
        arguments: {
          'redemption': {
            'redemptionId': data['redemptionId'] ?? redemptionId,
            ...data,
          },
          'offer': widget.args,
        },
      );
    } else {
      await _handleScanError(response.message ?? 'Failed to validate QR code');
    }
  }

  Future<void> _handleScanError(String message) async {
    if (mounted) {
      ToastService().showToast(context, message, type: ToastType.error);
    }
    await _resumeScanning();
  }

  Future<void> _resumeScanning() async {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    try {
      await _controller?.start();
    } catch (_) {}
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller?.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {
      if (mounted) {
        ToastService().showToast(
          context,
          'Torch is not available on this device',
          type: ToastType.warning,
        );
      }
    }
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(
        context,
      ).pushReplacementNamed('partnerRedemption', arguments: widget.args);
    }
  }

  Widget _buildFatalError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            Text(
              _fatalError ?? 'Camera unavailable',
              textAlign: TextAlign.center,
              style: kSmallTitleM.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 24),
            if (_fatalError?.contains('settings') == true)
              PrimaryButton(text: 'Open Settings', onPressed: openAppSettings),
            const SizedBox(height: 12),
            PrimaryButton(
              text: 'Go Back',
              backgroundColor: Colors.white24,
              onPressed: _goBack,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  _fatalError = null;
                  _starting = true;
                  _permissionReady = false;
                });
                _controller?.dispose();
                _controller = null;
                _bootstrap();
              },
              child: Text(
                'Retry',
                style: kSmallTitleM.copyWith(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    final title = widget.args['title']?.toString() ?? 'Offer';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _goBack,
        ),
        title: Text(
          'Scan Customer QR',
          style: kSubHeadingM.copyWith(color: Colors.white, fontSize: 18),
        ),
        actions: [
          if (_permissionReady && _fatalError == null)
            IconButton(
              icon: Icon(
                _torchOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
              ),
              onPressed: _toggleTorch,
            ),
        ],
      ),
      body: _starting
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : _fatalError != null
          ? _buildFatalError()
          : Stack(
              fit: StackFit.expand,
              children: [
                if (_controller != null)
                  MobileScanner(
                    controller: _controller!,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            error.errorDetails?.message ??
                                error.errorCode.message,
                            textAlign: TextAlign.center,
                            style: kSmallTitleM.copyWith(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                CustomPaint(
                  painter: _ScanOverlayPainter(),
                  child: const SizedBox.expand(),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: screenSize.responsivePadding(48),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Point at the customer\'s redemption QR',
                              textAlign: TextAlign.center,
                              style: kSmallTitleM.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: kSmallerTitleM.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'QR expires ~5 minutes after generation',
                              textAlign: TextAlign.center,
                              style: kSmallerTitleM.copyWith(
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isProcessing) ...[
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(color: kPrimaryColor),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SaleAmountSheet extends StatefulWidget {
  const _SaleAmountSheet();

  @override
  State<_SaleAmountSheet> createState() => _SaleAmountSheetState();
}

class _SaleAmountSheetState extends State<_SaleAmountSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final amount = double.tryParse(_controller.text.trim());
    if (amount == null || amount <= 0) {
      ToastService().showToast(
        context,
        'Please enter a valid bill amount',
        type: ToastType.warning,
      );
      return;
    }
    // Unfocus before pop so TextFormField isn't rebuilt against a disposed
    // controller during the sheet close animation.
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kGreyLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Enter bill amount', style: kSubHeadingM.copyWith(fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            'Required to calculate customer points for this redemption.',
            style: kBodyTitleM.copyWith(color: kSecondaryTextColor),
          ),
          const SizedBox(height: 20),
          PrimaryTextField(
            controller: _controller,
            label: 'Bill amount',
            hint: 'e.g. 499',
            type: TextFieldType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
          ),
          const SizedBox(height: 24),
          PrimaryButton(text: 'Confirm & Redeem', onPressed: _confirm),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancel',
              style: kSmallTitleM.copyWith(color: kSecondaryTextColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cutoutSize = size.width * 0.72;
    final left = (size.width - cutoutSize) / 2;
    final top = (size.height - cutoutSize) / 2 - 40;
    final cutout = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, cutoutSize, cutoutSize),
      const Radius.circular(16),
    );

    final overlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()..addRRect(cutout);
    final dimmed = Path.combine(PathOperation.difference, overlay, hole);

    canvas.drawPath(
      dimmed,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final borderPaint = Paint()
      ..color = kPrimaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(cutout, borderPaint);

    final cornerLen = cutoutSize * 0.12;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final rect = cutout.outerRect;
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft + Offset(cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft + Offset(0, cornerLen),
      cornerPaint,
    );
    canvas.drawLine(
      rect.topRight,
      rect.topRight - Offset(cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      rect.topRight,
      rect.topRight + Offset(0, cornerLen),
      cornerPaint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + Offset(cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft - Offset(0, cornerLen),
      cornerPaint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight - Offset(cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight - Offset(0, cornerLen),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
