import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/constants/color_constants.dart';
import '../../../data/constants/style_constants.dart';
import '../../../data/models/bulk_redemption_models.dart';
import '../../../data/providers/bulk_redemption_provider.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../../../data/services/toast_service.dart';
import '../../components/loading_indicator.dart';
import '../../components/primary_button.dart';
import '../../components/primary_text_field.dart';

/// Customer multi-offer bulk redemption (OTP, QR, or bill upload).
class BulkRedemptionPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? args;

  const BulkRedemptionPage({super.key, this.args});

  @override
  ConsumerState<BulkRedemptionPage> createState() => _BulkRedemptionPageState();
}

class _BulkRedemptionPageState extends ConsumerState<BulkRedemptionPage> {
  bool _loading = false;
  bool _submitting = false;
  String? _error;
  BulkRedeemInitResult? _otpBatch;
  BulkRedeemInitResult? _qrBatch;
  List<SkippedOffer> _skipped = const [];

  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _voucherController = TextEditingController();
  final TextEditingController _saleAmountController = TextEditingController();
  final TextEditingController _billNoController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();

  String? _billPath;
  bool _autoStarted = false;

  String get _partnerId =>
      (widget.args?['partnerId'] ?? widget.args?['shopId'] ?? '')
          .toString()
          .trim();

  String get _shopName => (widget.args?['shopName'] ?? 'Partner').toString();

  String? get _cartId {
    final fromArgs = widget.args?['cartId']?.toString().trim();
    if (fromArgs != null && fromArgs.isNotEmpty) return fromArgs;
    return _otpBatch?.cartId ?? _qrBatch?.cartId;
  }

  List<String> get _offerIds {
    final raw = widget.args?['offerIds'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  bool get _redeemAll => widget.args?['redeemAll'] == true || _offerIds.isEmpty;

  double? get _initialSaleAmount {
    final raw = widget.args?['saleAmount'] ?? widget.args?['cartSubtotal'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '');
  }

  @override
  void initState() {
    super.initState();
    final initial = _initialSaleAmount;
    if (initial != null && initial > 0) {
      _saleAmountController.text = initial.toStringAsFixed(0);
    }
    final voucher = widget.args?['voucherCode']?.toString();
    if (voucher != null && voucher.isNotEmpty) {
      _voucherController.text = voucher;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_autoStarted) return;
      _autoStarted = true;
      _startOtpFlow();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _voucherController.dispose();
    _saleAmountController.dispose();
    _billNoController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  double? _parsedSaleAmount() {
    final t = _saleAmountController.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  int? _parsedPoints() {
    final t = _pointsController.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  Future<void> _startOtpFlow() async {
    if (_partnerId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing partner for bulk redemption';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(bulkRedemptionRepositoryProvider)
          .initiateBulkRedeem(
            partnerId: _partnerId,
            cartId: _cartId,
            offerIds: _redeemAll ? null : _offerIds,
            redeemAll: _redeemAll,
            saleAmount: _parsedSaleAmount(),
            voucherCode: _voucherController.text.trim().isEmpty
                ? null
                : _voucherController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _otpBatch = result;
        _skipped = result.skippedOffers;
        _loading = false;
      });
      if (result.skippedOffers.isNotEmpty && mounted) {
        ToastService().showToast(
          context,
          '${result.skippedOffers.length} offer(s) skipped',
          type: ToastType.warning,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _startQrFlow() async {
    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(bulkRedemptionRepositoryProvider)
          .initiateBulkQr(
            partnerId: _partnerId,
            cartId: _cartId,
            offerIds: _redeemAll ? null : _offerIds,
            redeemAll: _redeemAll,
            saleAmount: _parsedSaleAmount(),
            voucherCode: _voucherController.text.trim().isEmpty
                ? null
                : _voucherController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _qrBatch = result;
        _skipped = [..._skipped, ...result.skippedOffers];
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ToastService().showToast(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: ToastType.error,
      );
    }
  }

  Future<void> _pickBill() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _billPath = file.path);
  }

  Future<void> _redeemWithBill() async {
    if (_partnerId.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final verified = await ref
          .read(bulkRedemptionRepositoryProvider)
          .redeemWithBill(
            partnerId: _partnerId,
            cartId: _cartId,
            offerIds: _redeemAll ? null : _offerIds,
            redeemAll: _redeemAll,
            saleAmount: _parsedSaleAmount(),
            pointsToUse: _parsedPoints(),
            billNo: _billNoController.text.trim().isEmpty
                ? null
                : _billNoController.text.trim(),
            voucherCode: _voucherController.text.trim().isEmpty
                ? null
                : _voucherController.text.trim(),
            billFilePath: _billPath,
          );
      if (!mounted) return;
      setState(() => _submitting = false);
      await _finishSuccess(verified);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ToastService().showToast(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: ToastType.error,
      );
    }
  }

  Future<void> _verifyOtp() async {
    final batch = _otpBatch;
    final otp = _otpController.text.trim();
    if (batch == null || otp.length < 4) {
      ToastService().showToast(
        context,
        'Enter the OTP from the partner',
        type: ToastType.warning,
      );
      return;
    }
    if (_submitting) return;

    final phone = ref.read(userProvider)?.phone;

    setState(() => _submitting = true);
    try {
      final verified = await ref
          .read(bulkRedemptionRepositoryProvider)
          .customerVerifyBulk(
            batchId: batch.batchId,
            userPhone: phone,
            otp: otp,
            saleAmount: _parsedSaleAmount(),
            pointsToUse: _parsedPoints(),
            voucherCode: _voucherController.text.trim().isEmpty
                ? null
                : _voucherController.text.trim(),
            billNo: _billNoController.text.trim().isEmpty
                ? null
                : _billNoController.text.trim(),
          );
      if (!mounted) return;
      setState(() => _submitting = false);
      await _finishSuccess(verified);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ToastService().showToast(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: ToastType.error,
      );
    }
  }

  Future<void> _finishSuccess(BulkVerifyResult verified) async {
    ToastService().showToast(
      context,
      verified.message ??
          'Redeemed ${verified.offersCount} offers successfully!',
      type: ToastType.success,
    );
    ref.read(userProvider.notifier).getProfile();
    if (_partnerId.isNotEmpty) {
      ref.invalidate(shopOffersBundleProvider(_partnerId));
    }

    if (!mounted) return;
    await Navigator.of(context).pushReplacementNamed(
      'redemptionVerified',
      arguments: {
        'redemption': {
          'batchId': verified.batchId,
          'offersCount': verified.offersCount,
          'totalDiscount': verified.totalDiscount,
          'voucherDiscount': verified.voucherDiscount,
          'pointsEarned': verified.totalPointsEarned,
          'pointsUsed': verified.pointsUsed,
          'saleAmount': verified.saleAmount,
          'netSaleAmount': verified.netSaleAmount,
          'paymentMode': verified.paymentMode,
          'cartId': verified.cartId,
          'status': verified.status,
          'redemptions': verified.redemptions
              .map(
                (r) => {
                  'redemptionId': r.redemptionId,
                  'offerId': r.offerId,
                  'offerTitle': r.offerTitle,
                  'saleAmount': r.saleAmount,
                  'pointsEarned': r.pointsEarned,
                  'status': r.status,
                },
              )
              .toList(),
          if (verified.spinUnlocked != null)
            'spinUnlocked': {
              'hasSpinAvailable': verified.spinUnlocked!.hasSpinAvailable,
              'transactionId': verified.spinUnlocked!.transactionId,
              'campaignId': verified.spinUnlocked!.campaignId,
            },
        },
        'offer': {
          'title': 'Bulk redemption',
          'shopName': _shopName,
        },
        'pointsEarned': verified.totalPointsEarned,
        'spinUnlocked': verified.spinUnlocked == null
            ? null
            : {
                'hasSpinAvailable': verified.spinUnlocked!.hasSpinAvailable,
                'transactionId': verified.spinUnlocked!.transactionId,
                'campaignId': verified.spinUnlocked!.campaignId,
              },
        'transactionId': verified.spinUnlocked?.transactionId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    final batch = _otpBatch;
    final qr = _qrBatch;

    return Scaffold(
      backgroundColor: kRewardPageBg,
      appBar: AppBar(
        backgroundColor: kWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: kTextColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Redeem at $_shopName',
          style: kSubHeadingM.copyWith(color: kTextColor, fontSize: 16),
        ),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: _loading
          ? const Center(child: LoadingAnimation())
          : _error != null && batch == null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(screenSize.responsivePadding(24)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: kBodyTitleM.copyWith(
                            color: kSecondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          text: 'Retry',
                          onPressed: _startOtpFlow,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.all(screenSize.responsivePadding(20)),
                  children: [
                    Text(
                      '${batch?.offersCount ?? _offerIds.length} offer(s) in this redemption',
                      style: kBodyTitleB,
                    ),
                    const SizedBox(height: 8),
                    ...?(batch?.offers.map(
                      (o) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '• ${o.title}',
                          style: kBodyTitleR.copyWith(
                            color: kSecondaryTextColor,
                          ),
                        ),
                      ),
                    )),
                    if (_skipped.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE0A3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Skipped offers', style: kBodyTitleM),
                            const SizedBox(height: 4),
                            ..._skipped.map(
                              (s) => Text(
                                '• ${s.title ?? s.offerId}: ${s.reason}',
                                style: kBodyTitleR.copyWith(
                                  color: kSecondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    PrimaryTextField(
                      controller: _saleAmountController,
                      label: 'Bill amount (optional)',
                      hint: _cartId != null
                          ? 'Defaults to cart subtotal if blank'
                          : 'Enter combined bill amount',
                      type: TextFieldType.number,
                    ),
                    const SizedBox(height: 12),
                    PrimaryTextField(
                      controller: _voucherController,
                      label: 'Voucher code (optional)',
                    ),
                    const SizedBox(height: 12),
                    PrimaryTextField(
                      controller: _pointsController,
                      label: 'Points to use (optional)',
                      type: TextFieldType.number,
                    ),
                    const SizedBox(height: 12),
                    PrimaryTextField(
                      controller: _billNoController,
                      label: 'Bill number (optional)',
                    ),
                    const SizedBox(height: 16),
                    Text('OTP redemption', style: kBodyTitleB),
                    const SizedBox(height: 8),
                    Text(
                      batch?.message ??
                          'Ask the partner for the OTP sent for this batch.',
                      style: kBodyTitleR.copyWith(color: kSecondaryTextColor),
                    ),
                    const SizedBox(height: 12),
                    PrimaryTextField(
                      controller: _otpController,
                      hint: 'Enter partner OTP',
                      type: TextFieldType.number,
                      maxLength: 6,
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      text: 'Verify & redeem',
                      onPressed: _verifyOtp,
                      isLoading: _submitting && qr == null && _billPath == null,
                      isEnabled: !_submitting,
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text('Or show a bulk QR', style: kBodyTitleB),
                    const SizedBox(height: 8),
                    Text(
                      'Partner scans once to complete every selected offer.',
                      style: kBodyTitleR.copyWith(color: kSecondaryTextColor),
                    ),
                    const SizedBox(height: 12),
                    if (qr == null)
                      PrimaryButton(
                        text: 'Generate bulk QR',
                        onPressed: _startQrFlow,
                        isLoading: _submitting,
                        isEnabled: !_submitting,
                        backgroundColor: kSecondaryColor,
                      )
                    else ...[
                      Text(
                        'Batch: ${qr.batchId}',
                        style: kBodyTitleM.copyWith(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      if (qr.qrCode != null &&
                          qr.qrCode!.startsWith('data:image'))
                        _QrDataImage(dataUri: qr.qrCode!)
                      else
                        SelectableText(
                          qr.qrPayload ??
                              qr.qrToken ??
                              jsonEncode({
                                'type': 'bulk_redemption',
                                'batchId': qr.batchId,
                              }),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        qr.message ??
                            'Show this QR to the partner to scan.',
                        style: kBodyTitleR.copyWith(
                          color: kSecondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text('Or redeem with bill upload', style: kBodyTitleB),
                    const SizedBox(height: 8),
                    Text(
                      'Upload one receipt to complete all selected offers at once. '
                      'Unscratched scratch cards are revealed automatically.',
                      style: kBodyTitleR.copyWith(color: kSecondaryTextColor),
                    ),
                    const SizedBox(height: 12),
                    if (_billPath != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_billPath!),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    PrimaryButton(
                      text: _billPath == null
                          ? 'Choose bill image'
                          : 'Change bill image',
                      onPressed: _pickBill,
                      backgroundColor: kSecondaryColor,
                      isEnabled: !_submitting,
                    ),
                    const SizedBox(height: 8),
                    PrimaryButton(
                      text: 'Submit bill redemption',
                      onPressed: _redeemWithBill,
                      isLoading: _submitting,
                      isEnabled: !_submitting,
                    ),
                  ],
                ),
    );
  }
}

class _QrDataImage extends StatelessWidget {
  final String dataUri;

  const _QrDataImage({required this.dataUri});

  @override
  Widget build(BuildContext context) {
    try {
      final comma = dataUri.indexOf(',');
      if (comma < 0) return const SizedBox.shrink();
      final bytes = base64Decode(dataUri.substring(comma + 1));
      return Center(
        child: Image.memory(
          bytes,
          width: 220,
          height: 220,
          fit: BoxFit.contain,
        ),
      );
    } catch (_) {
      return Text(dataUri, style: const TextStyle(fontSize: 11));
    }
  }
}
