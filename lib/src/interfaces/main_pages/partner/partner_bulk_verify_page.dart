import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/constants/color_constants.dart';
import '../../../data/constants/style_constants.dart';
import '../../../data/models/bulk_redemption_models.dart';
import '../../../data/providers/bulk_redemption_provider.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/services/toast_service.dart';
import '../../components/primary_button.dart';
import '../../components/primary_text_field.dart';

/// Partner-initiated bulk OTP: generate then verify (Notion Flow 4).
class PartnerBulkVerifyPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? args;

  const PartnerBulkVerifyPage({super.key, this.args});

  @override
  ConsumerState<PartnerBulkVerifyPage> createState() =>
      _PartnerBulkVerifyPageState();
}

class _PartnerBulkVerifyPageState extends ConsumerState<PartnerBulkVerifyPage> {
  final _phoneController = TextEditingController();
  final _batchController = TextEditingController();
  final _otpController = TextEditingController();
  final _saleAmountController = TextEditingController();
  final _voucherController = TextEditingController();
  final _billNoController = TextEditingController();
  final _pointsController = TextEditingController();
  final _cartIdController = TextEditingController();

  bool _generating = false;
  bool _verifying = false;
  bool _redeemAll = true;
  BulkRedeemInitResult? _generated;
  List<SkippedOffer> _skipped = const [];
  String? _billImagePath;

  @override
  void initState() {
    super.initState();
    _phoneController.text = (widget.args?['userPhone'] ?? '').toString();
    _batchController.text = (widget.args?['batchId'] ?? '').toString();
    _cartIdController.text = (widget.args?['cartId'] ?? '').toString();
    final sale = widget.args?['saleAmount'] ?? widget.args?['subtotal'];
    if (sale != null) {
      _saleAmountController.text = sale.toString();
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _batchController.dispose();
    _otpController.dispose();
    _saleAmountController.dispose();
    _voucherController.dispose();
    _billNoController.dispose();
    _pointsController.dispose();
    _cartIdController.dispose();
    super.dispose();
  }

  double? _saleAmount() {
    final t = _saleAmountController.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  int? _points() {
    final t = _pointsController.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  Future<void> _generate() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ToastService().showToast(
        context,
        'Enter customer phone number',
        type: ToastType.warning,
      );
      return;
    }
    setState(() => _generating = true);
    try {
      final result = await ref
          .read(bulkRedemptionRepositoryProvider)
          .partnerGenerateBulkOtp(
            userPhone: phone,
            cartId: _cartIdController.text.trim().isEmpty
                ? null
                : _cartIdController.text.trim(),
            redeemAll: _redeemAll,
            saleAmount: _saleAmount(),
            voucherCode: _voucherController.text.trim().isEmpty
                ? null
                : _voucherController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _generating = false;
        _generated = result;
        _skipped = result.skippedOffers;
        _batchController.text = result.batchId;
        if (result.otp != null && result.otp!.isNotEmpty) {
          _otpController.text = result.otp!;
        }
      });
      ToastService().showToast(
        context,
        result.message ??
            'OTP sent for ${result.offersCount} offer(s). Ask the customer for the code.',
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      ToastService().showToast(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: ToastType.error,
      );
    }
  }

  Future<void> _pickBill() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _billImagePath = file.path);
  }

  Future<void> _verify() async {
    final phone = _phoneController.text.trim();
    final batchId = _batchController.text.trim();
    final otp = _otpController.text.trim();
    if (phone.isEmpty || otp.length < 4) {
      ToastService().showToast(
        context,
        'Enter customer phone and OTP',
        type: ToastType.warning,
      );
      return;
    }
    if (_verifying) return;

    setState(() => _verifying = true);
    try {
      final result = await ref
          .read(bulkRedemptionRepositoryProvider)
          .partnerVerifyBulk(
            batchId: batchId.isEmpty ? null : batchId,
            userPhone: phone,
            otp: otp,
            saleAmount: _saleAmount(),
            pointsToUse: _points(),
            voucherCode: _voucherController.text.trim().isEmpty
                ? null
                : _voucherController.text.trim(),
            billNo: _billNoController.text.trim().isEmpty
                ? null
                : _billNoController.text.trim(),
            billImagePath: _billImagePath,
          );
      if (!mounted) return;
      setState(() => _verifying = false);

      ToastService().showToast(
        context,
        result.message ??
            'Bulk redemption complete (${result.offersCount} offers)',
        type: ToastType.success,
      );

      await Navigator.of(context).pushReplacementNamed(
        'partnerRedemptionSuccess',
        arguments: {
          'redemption': {
            'redemptionId': result.batchId ?? batchId,
            'offersCount': result.offersCount,
            'totalDiscount': result.totalDiscount,
            'totalPointsEarned': result.totalPointsEarned,
            'saleAmount': result.saleAmount,
            'netSaleAmount': result.netSaleAmount,
            'paymentMode': result.paymentMode,
            'cartId': result.cartId,
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
            'subtitle': '${result.offersCount} offers',
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
      setState(() => _verifying = false);
      ToastService().showToast(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    final busy = _generating || _verifying;

    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        backgroundColor: kWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Bulk OTP redemption', style: kSubHeadingM),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(screenSize.responsivePadding(20)),
        children: [
          Text('1. Generate OTP', style: kBodyTitleB),
          const SizedBox(height: 8),
          Text(
            'Look up the customer, redeem all eligible offers (or a linked cart), and send one OTP.',
            style: kBodyTitleR.copyWith(color: kSecondaryTextColor),
          ),
          const SizedBox(height: 12),
          PrimaryTextField(
            controller: _phoneController,
            label: 'Customer phone',
            type: TextFieldType.number,
          ),
          const SizedBox(height: 12),
          PrimaryTextField(
            controller: _cartIdController,
            label: 'Cart ID (optional)',
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text('Redeem all eligible offers', style: kBodyTitleM),
            value: _redeemAll,
            activeThumbColor: kPrimaryColor,
            onChanged: busy ? null : (v) => setState(() => _redeemAll = v),
          ),
          PrimaryTextField(
            controller: _saleAmountController,
            label: 'Bill amount (optional)',
            type: TextFieldType.number,
          ),
          const SizedBox(height: 12),
          PrimaryTextField(
            controller: _voucherController,
            label: 'Voucher code (optional)',
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            text: 'Generate bulk OTP',
            onPressed: _generate,
            isLoading: _generating,
            isEnabled: !busy,
          ),
          if (_generated != null) ...[
            const SizedBox(height: 12),
            Text(
              _generated!.message ??
                  'Batch ${_generated!.batchId} · ${_generated!.offersCount} offers',
              style: kBodyTitleR.copyWith(color: kPrimaryColor),
            ),
          ],
          if (_skipped.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._skipped.map(
              (s) => Text(
                'Skipped ${s.title ?? s.offerId}: ${s.reason}',
                style: kBodyTitleR.copyWith(
                  color: kSecondaryTextColor,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),
          Text('2. Verify OTP', style: kBodyTitleB),
          const SizedBox(height: 12),
          PrimaryTextField(
            controller: _batchController,
            label: 'Batch ID (optional if latest pending)',
          ),
          const SizedBox(height: 12),
          PrimaryTextField(
            controller: _otpController,
            label: 'OTP',
            type: TextFieldType.number,
            maxLength: 6,
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
          const SizedBox(height: 12),
          PrimaryButton(
            text: _billImagePath == null
                ? 'Attach bill image (optional)'
                : 'Change bill image',
            onPressed: _pickBill,
            backgroundColor: kSecondaryColor,
            isEnabled: !busy,
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            text: 'Verify bulk OTP',
            onPressed: _verify,
            isLoading: _verifying,
            isEnabled: !busy,
          ),
        ],
      ),
    );
  }
}
