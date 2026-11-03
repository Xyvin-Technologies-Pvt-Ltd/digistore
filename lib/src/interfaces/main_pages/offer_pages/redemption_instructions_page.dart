import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../../data/constants/color_constants.dart';
import '../../../data/constants/style_constants.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../../components/primary_button.dart';
import '../../components/primary_text_field.dart';
import '../../../data/providers/offers_provider.dart';
import '../../../data/providers/home_provider.dart';
import '../../../data/models/home_data_model.dart';
import '../../../data/services/toast_service.dart';

enum _RedemptionView { instructions, otp, qr }

class RedemptionInstructionsPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? args;
  const RedemptionInstructionsPage({super.key, this.args});

  @override
  ConsumerState<RedemptionInstructionsPage> createState() =>
      _RedemptionInstructionsPageState();
}

class _RedemptionInstructionsPageState
    extends ConsumerState<RedemptionInstructionsPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final PinInputController _otpController = PinInputController();
  final TextEditingController _saleAmountController = TextEditingController();
  final TextEditingController _pointsInputController = TextEditingController();

  String _otp = '';
  String? _redemptionId;
  String? _returnedOtp;
  int? _pointsUsed;
  double? _cashDue;
  String? _paymentMode;
  int? _overridePointsToUse;
  String? _overridePaymentMode;

  int _getUserPointsBalance() {
    int pts = (widget.args?['userPointsBalance'] ?? widget.args?['pointsBalance']) as int? ?? 0;
    final userPts = ref.watch(userProvider)?.pointsBalance ?? 0;
    if (userPts > pts) pts = userPts;
    try {
      final homeDataState = ref.watch(homeDataProvider).value;
      if (homeDataState is CustomerHomeState) {
        final loyaltyCard = homeDataState.data.loyaltyCard;
        if (loyaltyCard?.pointsBalance != null) {
          final cardPts = loyaltyCard!.pointsBalance!;
          if (cardPts > pts) pts = cardPts;
        }
      }
    } catch (_) {}
    return pts;
  }

  bool _isInitiatingOtp = false;
  bool _isGeneratingQr = false;
  bool _isVerifying = false;

  _RedemptionView _view = _RedemptionView.instructions;
  Uint8List? _qrImageBytes;
  Timer? _qrTicker;
  Duration _qrRemaining = Duration.zero;

  DateTime? _otpExpiresAt;
  Timer? _otpTicker;
  Duration _otpRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _saleAmountController.addListener(_onSaleAmountChanged);
    final initialPts = (widget.args?['pointsToUse'] as num?)?.toInt();
    if (initialPts != null && initialPts > 0) {
      _pointsInputController.text = initialPts.toString();
      _overridePointsToUse = initialPts;
    }
  }

  void _onSaleAmountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _qrTicker?.cancel();
    _otpTicker?.cancel();
    _otpController.dispose();
    _saleAmountController.removeListener(_onSaleAmountChanged);
    _saleAmountController.dispose();
    _pointsInputController.dispose();
    super.dispose();
  }

  String? get _offerId {
    final id = widget.args?['id'] ?? widget.args?['_id'];
    return id?.toString();
  }

  int get _computedPointsCost {
    return (widget.args?['pointsCost'] as num?)?.toInt() ?? 0;
  }

  double get _effectiveBillAmount {
    final entered = double.tryParse(_saleAmountController.text.trim());
    if (entered != null && entered > 0) return entered;
    if (widget.args?['saleAmount'] != null) {
      return (widget.args!['saleAmount'] as num).toDouble();
    }
    return _computedPointsCost.toDouble();
  }

  String get _effectivePaymentMode {
    if (_overridePaymentMode != null) return _overridePaymentMode!;
    if (_paymentMode != null) return _paymentMode!;
    if (widget.args?['paymentMode'] != null) {
      return widget.args!['paymentMode'].toString();
    }
    final userBalance = _getUserPointsBalance();
    if (userBalance > 0) {
      final bill = _effectiveBillAmount.ceil();
      if (bill > 0 && userBalance >= bill) {
        return 'full_points';
      }
      return 'partial';
    }
    return 'full_cash';
  }

  int get _effectivePointsToUse {
    final mode = _effectivePaymentMode;
    if (mode == 'full_cash') return 0;
    if (_overridePointsToUse != null) return _overridePointsToUse!;
    if (_pointsUsed != null) return _pointsUsed!;
    if (widget.args?['pointsToUse'] != null) {
      return (widget.args!['pointsToUse'] as num).toInt();
    }
    final userBalance = _getUserPointsBalance();
    final billAmt = _effectiveBillAmount.ceil();
    final maxTarget = billAmt > 0 ? billAmt : _computedPointsCost;
    final maxUsable = maxTarget > 0 ? math.min(userBalance, maxTarget) : userBalance;
    if (mode == 'full_points') {
      return maxUsable;
    }
    return maxUsable > 0 ? (maxUsable ~/ 2).clamp(1, maxUsable) : 0;
  }

  double get _effectiveCashDue {
    if (_cashDue != null) return _cashDue!;
    final total = _effectiveBillAmount;
    final pts = _effectivePointsToUse;
    return math.max(0.0, total - pts);
  }

  void _resetToInstructions() {
    _qrTicker?.cancel();
    _otpTicker?.cancel();
    setState(() {
      _view = _RedemptionView.instructions;
      _redemptionId = null;
      _returnedOtp = null;
      _qrImageBytes = null;
      _qrRemaining = Duration.zero;
      _otpExpiresAt = null;
      _otpRemaining = Duration.zero;
      _otp = '';
      _otpController.clear();
    });
  }

  void _startQrCountdown(DateTime expiresAt) {
    _qrTicker?.cancel();
    void tick() {
      final left = expiresAt.difference(DateTime.now());
      if (!mounted) return;
      setState(() {
        _qrRemaining = left.isNegative ? Duration.zero : left;
      });
      if (left.isNegative || left == Duration.zero) {
        _qrTicker?.cancel();
      }
    }

    tick();
    _qrTicker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _startOtpCountdown(DateTime expiresAt) {
    _otpTicker?.cancel();
    void tick() {
      final left = expiresAt.difference(DateTime.now());
      if (!mounted) return;
      setState(() {
        _otpRemaining = left.isNegative ? Duration.zero : left;
      });
      if (left.isNegative || left == Duration.zero) {
        _otpTicker?.cancel();
      }
    }

    tick();
    _otpTicker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Uint8List? _decodeQrDataUrl(String? dataUrl) {
    if (dataUrl == null || dataUrl.isEmpty) return null;
    final marker = 'base64,';
    final idx = dataUrl.indexOf(marker);
    final raw = idx >= 0 ? dataUrl.substring(idx + marker.length) : dataUrl;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _initiateRedemption() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final offerId = _offerId;
    if (offerId == null || offerId.isEmpty) {
      ToastService().showToast(
        context,
        'Invalid offer details',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _isInitiatingOtp = true);

    final response = await ref
        .read(offersProvider.notifier)
        .customerInitiateRedemption(offerId, pointsToUse: _effectivePointsToUse);

    setState(() => _isInitiatingOtp = false);

    if (response.success && mounted) {
      final dataMap = response.data?['data'] is Map
          ? Map<String, dynamic>.from(response.data!['data'] as Map)
          : (response.data is Map
              ? Map<String, dynamic>.from(response.data as Map)
              : <String, dynamic>{});

      final redId = dataMap['redemptionId'] ?? dataMap['id'];
      final otpVal = dataMap['otp']?.toString();
      if (otpVal != null && otpVal.isNotEmpty) {
        _returnedOtp = otpVal;
        _otp = otpVal;
        _otpController.text = otpVal;
      }
      if (dataMap['pointsUsed'] != null) {
        _pointsUsed = (dataMap['pointsUsed'] as num).toInt();
      }
      if (dataMap['cashDue'] != null) {
        _cashDue = (dataMap['cashDue'] as num).toDouble();
      }
      if (dataMap['paymentMode'] != null) {
        _paymentMode = dataMap['paymentMode'].toString();
      }

      final rawExpiry = dataMap['otpExpiresAt'] ?? dataMap['expiresAt'];
      if (rawExpiry != null) {
        _otpExpiresAt = DateTime.tryParse(rawExpiry.toString())?.toLocal();
      }
      _otpExpiresAt ??= DateTime.now().add(const Duration(minutes: 5));
      _startOtpCountdown(_otpExpiresAt!);

      if (redId != null) {
        setState(() {
          _redemptionId = redId.toString();
          _view = _RedemptionView.otp;
        });
        ToastService().showToast(
          context,
          dataMap['message'] ??
              (_returnedOtp != null
                  ? 'Redemption initiated! Share OTP with merchant.'
                  : 'OTP sent to merchant!'),
          type: ToastType.success,
        );
      } else {
        ToastService().showToast(
          context,
          dataMap['message'] ?? 'Redemption initiated successfully',
          type: ToastType.success,
        );
      }
    } else if (mounted) {
      ToastService().showToast(
        context,
        response.message ?? 'Failed to initiate redemption',
        type: ToastType.error,
      );
    }
  }

  Future<void> _generateQr() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final offerId = _offerId;
    if (offerId == null || offerId.isEmpty) {
      ToastService().showToast(
        context,
        'Invalid offer details',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _isGeneratingQr = true);

    final response = await ref
        .read(offersProvider.notifier)
        .customerInitiateQrRedemption(offerId);

    setState(() => _isGeneratingQr = false);

    if (!mounted) return;

    if (response.success) {
      final dataMap = response.data?['data'] is Map
          ? Map<String, dynamic>.from(response.data!['data'] as Map)
          : (response.data is Map
              ? Map<String, dynamic>.from(response.data as Map)
              : <String, dynamic>{});

      final qrBytes = _decodeQrDataUrl(dataMap['qrCode']?.toString());
      if (qrBytes == null) {
        ToastService().showToast(
          context,
          'QR code could not be generated. Please try again.',
          type: ToastType.error,
        );
        return;
      }

      DateTime? expiresAt;
      final rawExpiry = dataMap['expiresAt'];
      if (rawExpiry != null) {
        expiresAt = DateTime.tryParse(rawExpiry.toString())?.toLocal();
      }
      expiresAt ??= DateTime.now().add(const Duration(minutes: 5));

      setState(() {
        _redemptionId = (dataMap['redemptionId'] ?? dataMap['id'])?.toString();
        _qrImageBytes = qrBytes;
        _view = _RedemptionView.qr;
      });
      _startQrCountdown(expiresAt);

      ToastService().showToast(
        context,
        dataMap['message']?.toString() ??
            'Show this QR code to the cashier to scan',
        type: ToastType.success,
      );
    } else {
      ToastService().showToast(
        context,
        response.message ?? 'Failed to generate QR code',
        type: ToastType.error,
      );
    }
  }

  Future<void> _verifyOtp() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_redemptionId == null) return;
    if (_otp.length < 6) {
      ToastService().showToast(
        context,
        'Please enter the 6-digit OTP',
        type: ToastType.warning,
      );
      return;
    }

    if (_formKey.currentState?.validate() == false) return;

    setState(() => _isVerifying = true);

    final saleAmt = double.tryParse(_saleAmountController.text.trim()) ??
        (_effectiveBillAmount > 0 ? _effectiveBillAmount : null);
    final ptsToUse = _effectivePointsToUse;

    final response = await ref
        .read(offersProvider.notifier)
        .customerVerifyRedemptionOtp(
          redemptionId: _redemptionId!,
          otp: _otp,
          saleAmount: saleAmt,
          pointsToUse: ptsToUse,
        );

    setState(() => _isVerifying = false);

    if (response.success && mounted) {
      // Refresh profile to update points balance immediately
      ref.read(userProvider.notifier).getProfile();

      ToastService().showToast(
        context,
        'Redemption completed successfully!',
        type: ToastType.success,
      );
      Navigator.of(context).pushReplacementNamed(
        'redemptionVerified',
        arguments: {
          'redemption': response.data?['data'] ?? response.data,
          'offer': widget.args,
          'pointsUsed': response.data?['data']?['pointsUsed'] ?? ptsToUse,
          'cashDue': response.data?['data']?['cashAmount'] ?? _effectiveCashDue,
          'paymentMode': response.data?['data']?['paymentMode'] ?? _effectivePaymentMode,
          'saleAmount': response.data?['data']?['saleAmount'] ?? saleAmt,
          'pointsEarned': response.data?['data']?['pointsEarned'],
        },
      );
    } else if (mounted) {
      ToastService().showToast(
        context,
        response.message ?? 'Verification failed',
        type: ToastType.error,
      );
    }
  }

  String _formatRemaining(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    final title = switch (_view) {
      _RedemptionView.instructions => 'Redemption Steps',
      _RedemptionView.otp => _returnedOtp != null ? 'Share OTP with Cashier' : 'Enter Merchant OTP',
      _RedemptionView.qr => 'Show QR to Merchant',
    };

    final pointsCost = _computedPointsCost;
    final pointsToUse = _effectivePointsToUse;
    final cashDue = _effectiveCashDue;
    final mode = _effectivePaymentMode;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: kWhite,
      appBar: AppBar(
        backgroundColor: kWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: kTextColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(screenSize.responsivePadding(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Points + Cash Breakdown & Payment Mode Selector (Always shown on Redeem Page)
              _buildPointsBreakdownBanner(
                pointsCost: pointsCost,
                pointsToUse: pointsToUse,
                cashDue: cashDue,
                mode: mode,
              ),
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF0F0F0)),
                  boxShadow: [
                    BoxShadow(
                      color: kGrey.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      _view == _RedemptionView.qr
                          ? Icons.qr_code_2_rounded
                          : (_returnedOtp != null
                              ? Icons.pin_rounded
                              : Icons.storefront_rounded),
                      size: 58,
                      color: kPrimaryColor,
                    ),
                    const SizedBox(height: 18),
                    Text(title, style: kSubHeadingM.copyWith(fontSize: 22)),
                    const SizedBox(height: 24),

                    if (_view == _RedemptionView.instructions) ...[
                      _buildInstructionStep(
                        'Step 1',
                        'Visit the store that is providing this offer.',
                        Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 20),
                      _buildInstructionStep(
                        'Step 2',
                        'Show your redemption OTP or have the cashier scan your QR code at the billing counter.',
                        Icons.sms_outlined,
                      ),
                      if (pointsCost > 0) ...[
                        const SizedBox(height: 20),
                        _buildInstructionStep(
                          'Step 3',
                          'Your $pointsToUse points will be deducted. Pay the remaining ₹${cashDue.toStringAsFixed(0)} cash at the counter and earn bonus loyalty coins!',
                          Icons.currency_rupee_rounded,
                        ),
                      ],
                    ] else if (_view == _RedemptionView.otp) ...[
                      if (_returnedOtp != null) ...[
                        // Prominent OTP Display for Customer to Share
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF6155F5).withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Share this OTP with the cashier:',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4338CA),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _returnedOtp!.split('').join('  '),
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 4,
                                  color: Color(0xFF312E81),
                                ),
                              ),
                              if (_otpRemaining.inSeconds > 0) ...[
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.timer_outlined,
                                      size: 16,
                                      color: Color(0xFF6155F5),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Expires in ${_formatRemaining(_otpRemaining)}',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF6155F5),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'The cashier will verify this code in their terminal to apply your points and discounts.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            height: 1.45,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        Text(
                          'We sent a 6-digit code to the merchant\'s phone. Ask the merchant for the code and enter it below to complete redemption.',
                          style: kSmallerTitleM.copyWith(
                            color: kSecondaryTextColor,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                      ],

                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            PrimaryTextField(
                              controller: _saleAmountController,
                              label: 'Bill / Sale Amount (Optional)',
                              hint: 'Enter amount (₹)',
                              type: TextFieldType.number,
                              prefixIcon: const Icon(
                                Icons.currency_rupee_rounded,
                                color: kPrimaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_returnedOtp == null) ...[
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: MaterialPinField(
                                  length: 6,
                                  pinController: _otpController,
                                  keyboardType: TextInputType.number,
                                  theme: MaterialPinTheme(
                                    shape: MaterialPinShape.outlined,
                                    borderRadius: BorderRadius.circular(12),
                                    cellSize: const Size(42, 50),
                                    focusedBorderColor: kPrimaryColor,
                                    disabledBorderColor:
                                        const Color(0xFFE2E8F0),
                                    borderColor: const Color(0xFFE2E8F0),
                                    fillColor: kWhite,
                                    filledFillColor: const Color(0xFFF8FAFC),
                                    focusedFillColor: kWhite,
                                    cursorColor: kPrimaryColor,
                                  ),
                                  onChanged: (value) {
                                    _otp = value;
                                    if (value.length == 6) {
                                      FocusManager.instance.primaryFocus?.unfocus();
                                    }
                                  },
                                  onCompleted: (value) {
                                    _otp = value;
                                    FocusManager.instance.primaryFocus?.unfocus();
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Show this QR code to the cashier. They will scan it in the partner app to complete your redemption.',
                        style: kSmallerTitleM.copyWith(
                          color: kSecondaryTextColor,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (_qrImageBytes != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: kWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Image.memory(
                            _qrImageBytes!,
                            width: screenSize.responsivePadding(220),
                            height: screenSize.responsivePadding(220),
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: (_qrRemaining.inSeconds <= 60
                                  ? Colors.orange
                                  : kPrimaryColor)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 18,
                              color: _qrRemaining.inSeconds <= 60
                                  ? Colors.orange.shade800
                                  : kPrimaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _qrRemaining.inSeconds > 0
                                  ? 'Expires in ${_formatRemaining(_qrRemaining)}'
                                  : 'QR expired — generate a new one',
                              style: kSmallerTitleB.copyWith(
                                color: _qrRemaining.inSeconds <= 60
                                    ? Colors.orange.shade800
                                    : kPrimaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              if (_view == _RedemptionView.instructions) ...[
                PrimaryButton(
                  text: 'Show OTP at Store',
                  isLoading: _isInitiatingOtp,
                  isEnabled: !(_isInitiatingOtp || _isGeneratingQr),
                  onPressed: () => _initiateRedemption(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: (_isGeneratingQr || _isInitiatingOtp)
                        ? null
                        : _generateQr,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimaryColor,
                      side: const BorderSide(color: kPrimaryColor, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isGeneratingQr
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: kPrimaryColor,
                            ),
                          )
                        : const Icon(Icons.qr_code_2_rounded, size: 20),
                    label: Text(
                      'Show QR Code',
                      style: kSmallTitleR.copyWith(
                        color: kPrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: kSmallerTitleM.copyWith(color: kSecondaryTextColor),
                  ),
                ),
              ] else if (_view == _RedemptionView.otp) ...[
                PrimaryButton(
                  text: 'Verify & Complete Redemption',
                  isLoading: _isVerifying,
                  onPressed: () => _verifyOtp(),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _resetToInstructions,
                  child: Text(
                    'Cancel / Go Back',
                    style: kSmallerTitleM.copyWith(color: kSecondaryTextColor),
                  ),
                ),
              ] else ...[
                if (_qrRemaining.inSeconds <= 0)
                  PrimaryButton(
                    text: 'Generate New QR',
                    isLoading: _isGeneratingQr,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: kWhite,
                      size: 20,
                    ),
                    onPressed: () => _generateQr(),
                  )
                else
                  PrimaryButton(
                    text: 'Done',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _resetToInstructions,
                  child: Text(
                    'Back to options',
                    style: kSmallerTitleM.copyWith(color: kSecondaryTextColor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildPointsBreakdownBanner({
    required int pointsCost,
    required int pointsToUse,
    required double cashDue,
    required String mode,
  }) {
    final userBalance = _getUserPointsBalance();
    final billAmt = _effectiveBillAmount;
    final maxPointsUsable = billAmt > 0 ? math.min(userBalance, billAmt.ceil()) : userBalance;

    Color badgeBg;
    Color badgeColor;
    String badgeText;
    switch (mode) {
      case 'full_points':
        badgeText = 'Full Points';
        badgeBg = const Color(0xFFDEF7EC);
        badgeColor = const Color(0xFF03543F);
        break;
      case 'partial':
        badgeText = 'Split';
        badgeBg = const Color(0xFFE1EFFE);
        badgeColor = const Color(0xFF1E429F);
        break;
      default:
        badgeText = 'Full Cash';
        badgeBg = const Color(0xFFFEF3C7);
        badgeColor = const Color(0xFF92400E);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title & Available Balance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6155F5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.stars_rounded,
                        color: Color(0xFF6155F5),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Redemption Payment Mode',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Available: $userBalance pts (1 pt = ₹1)',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6155F5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 3-way Mode Selection Segmented Control
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // 1. Full Cash
                Expanded(
                  child: _buildSelectorTab(
                    label: 'Full Cash',
                    icon: Icons.payments_outlined,
                    isSelected: mode == 'full_cash',
                    onTap: () {
                      setState(() {
                        _overridePaymentMode = 'full_cash';
                        _overridePointsToUse = 0;
                        _pointsInputController.text = '0';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 4),
                // 2. Split
                Expanded(
                  child: _buildSelectorTab(
                    label: 'Split',
                    icon: Icons.tune_rounded,
                    isSelected: mode == 'partial',
                    isEnabled: userBalance > 0,
                    onTap: () {
                      if (userBalance == 0) {
                        ToastService().showToast(
                          context,
                          'You have 0 points. Earn points to use Split mode!',
                          type: ToastType.warning,
                        );
                        return;
                      }
                      setState(() {
                        _overridePaymentMode = 'partial';
                        if (_overridePointsToUse == null || _overridePointsToUse == 0) {
                          _overridePointsToUse = maxPointsUsable > 0 ? (maxPointsUsable ~/ 2).clamp(1, maxPointsUsable) : 1;
                        }
                        _pointsInputController.text = _overridePointsToUse.toString();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 4),
                // 3. Full Points
                Expanded(
                  child: _buildSelectorTab(
                    label: 'Full Points',
                    icon: Icons.stars_rounded,
                    isSelected: mode == 'full_points',
                    isEnabled: userBalance > 0,
                    onTap: () {
                      if (userBalance == 0) {
                        ToastService().showToast(
                          context,
                          'You have 0 points. Earn points to redeem with points!',
                          type: ToastType.warning,
                        );
                        return;
                      }
                      final fullPts = maxPointsUsable > 0 ? maxPointsUsable : userBalance;
                      setState(() {
                        _overridePaymentMode = 'full_points';
                        _overridePointsToUse = fullPts;
                        _pointsInputController.text = fullPts.toString();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Mention Full Points Requirement Note when Full Points is selected
          if (mode == 'full_points') ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF2563EB),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Full Points Requirement',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          billAmt > 0 && userBalance < billAmt
                              ? 'To pay 100% with points, your points balance must equal the total bill amount (₹${billAmt.toStringAsFixed(0)}). Since you have $userBalance points, $userBalance points will be used (saves ₹$userBalance) and the remaining ₹${(billAmt - userBalance).toStringAsFixed(0)} is due in cash.'
                              : 'You need loyalty points equal to 100% of your total bill amount to use Full Points mode. Once applied, cash due at counter will be ₹0.',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1E3A8A),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Points to Use Input Field (ALWAYS VISIBLE - NEVER DISAPPEARS ON FULL AMOUNT!)
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  mode == 'full_points'
                      ? 'Points to redeem (Full Points):'
                      : (mode == 'full_cash' ? 'Points to redeem (Full Cash):' : 'Points to redeem:'),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Max: $maxPointsUsable pts',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: mode == 'full_points' ? const Color(0xFF10B981) : const Color(0xFF6155F5),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(
                  Icons.stars_rounded,
                  color: mode == 'full_points' ? const Color(0xFF10B981) : const Color(0xFF6155F5),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _pointsInputController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: const InputDecoration(
                      hintText: 'Type points to use (e.g. 50)',
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: mode == 'full_points' ? const Color(0xFF047857) : const Color(0xFF0F172A),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val) ?? 0;
                      final clamped = maxPointsUsable > 0 ? parsed.clamp(0, maxPointsUsable) : parsed;
                      setState(() {
                        _overridePointsToUse = clamped;
                        if (clamped == 0) {
                          _overridePaymentMode = 'full_cash';
                        } else if (billAmt > 0 && clamped >= billAmt.ceil() && userBalance >= billAmt.ceil()) {
                          _overridePaymentMode = 'full_points';
                        } else {
                          _overridePaymentMode = 'partial';
                        }
                      });
                    },
                  ),
                ),
                if (maxPointsUsable > 0)
                  GestureDetector(
                    onTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() {
                        final maxPts = maxPointsUsable;
                        _overridePointsToUse = maxPts;
                        _pointsInputController.text = maxPts.toString();
                        if (billAmt > 0 && maxPts >= billAmt.ceil() && userBalance >= billAmt.ceil()) {
                          _overridePaymentMode = 'full_points';
                        } else {
                          _overridePaymentMode = 'partial';
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6155F5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Max',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6155F5),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),


          const SizedBox(height: 14),

          // Live Breakdown Pill
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: mode == 'full_points'
                  ? const Color(0xFFF0FDF4)
                  : (mode == 'partial' ? const Color(0xFFF8FAFF) : const Color(0xFFFFFBEB)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: mode == 'full_points'
                    ? const Color(0xFFBBF7D0)
                    : (mode == 'partial' ? const Color(0xFFDBEAFE) : const Color(0xFFFDE68A)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mode == 'full_cash') ...[
                  const Text(
                    'Full Cash Payment',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cashDue > 0
                        ? 'Pay ₹${cashDue.toStringAsFixed(0)} at counter • 0 pts deducted • Earn loyalty coins!'
                        : '0 points used • Pay bill at counter • Earn loyalty coins!',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ] else if (mode == 'full_points') ...[
                  Row(
                    children: [
                      Text(
                        'Use $pointsToUse pts',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '(100% Points)',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cashDue == 0
                        ? '₹0 cash due at counter • 100% covered with points'
                        : 'Using $pointsToUse pts (covers ₹$pointsToUse). Remaining ₹${cashDue.toStringAsFixed(0)} paid in cash.',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Color(0xFF047857),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Text(
                        'Use $pointsToUse pts',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E429F),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(₹$pointsToUse saved)',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cashDue > 0
                        ? 'Pay ₹${cashDue.toStringAsFixed(0)} cash at counter • Earn coins on cash portion!'
                        : 'Covered with points • ₹0 cash due',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? const Color(0xFF6155F5)
                  : (isEnabled ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF6155F5)
                      : (isEnabled ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildInstructionStep(String step, String instruction, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 24, color: kPrimaryColor),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step,
                style: kSmallerTitleB.copyWith(
                  color: kPrimaryColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                instruction,
                style: kSmallerTitleM.copyWith(
                  color: kSecondaryTextColor,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
