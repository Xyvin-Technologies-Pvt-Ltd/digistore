import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../../data/constants/color_constants.dart';
import '../../../data/constants/style_constants.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../components/primary_button.dart';
import '../../components/primary_text_field.dart';
import '../../../data/providers/offers_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../../../data/services/toast_service.dart';

class RedemptionOtpPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? args;
  const RedemptionOtpPage({super.key, this.args});

  @override
  ConsumerState<RedemptionOtpPage> createState() => _RedemptionOtpPageState();
}

class _RedemptionOtpPageState extends ConsumerState<RedemptionOtpPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final PinInputController _otpController = PinInputController();
  final TextEditingController _saleAmountController = TextEditingController();
  final TextEditingController _billNoController = TextEditingController();
  String otp = '';
  bool isLoading = false;

  Future<void> _verify() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final billAmt = double.tryParse(_saleAmountController.text.trim());
    if (billAmt == null || billAmt <= 0) {
      ToastService().showToast(
        context,
        'Please enter a valid bill amount',
        type: ToastType.warning,
      );
      return;
    }

    if (otp.length < 6) {
      ToastService().showToast(
        context,
        'Please enter 6-digit OTP',
        type: ToastType.warning,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final offerId = widget.args?['id'] as String?;
      final phone =
          widget.args?['phone'] as String? ?? ref.read(userProvider)?.phone;

      if (offerId == null || phone == null) {
        throw 'Missing offer or phone details';
      }

      final response = await ref
          .read(offersProvider.notifier)
          .verifyRedemptionOtp(
            offerId: offerId,
            userPhone: phone,
            otp: otp,
            saleAmount: double.tryParse(_saleAmountController.text.trim()),
            billNo: _billNoController.text.trim().isEmpty
                ? null
                : _billNoController.text.trim(),
            pointsToUse: (widget.args?['pointsToUse'] as num?)?.toInt(),
          );

      if (response.success && mounted) {
        ToastService().showToast(context, 'Redemption successful!');
        Navigator.of(context).pushReplacementNamed(
          'redemptionVerified',
          arguments: {
            'redemption': response.data!['data'],
            'offer': widget.args,
          },
        );
      } else {
        throw response.message ?? 'Verification failed';
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ToastService().showToast(context, e.toString(), type: ToastType.error);
      }
    }
  }

  @override
  void dispose() {
    _saleAmountController.dispose();
    _billNoController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: kTextColor,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenSize.responsivePadding(24),
            vertical: screenSize.responsivePadding(16),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Security Badge & Description
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: kPrimaryColor.withValues(alpha: 0.12),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: kPrimaryColor,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Redeem Offer',
                        style: kHeadTitleB.copyWith(fontSize: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Complete verification by entering customer invoice and OTP details.',
                        style: kBodyTitleL.copyWith(
                          color: kSecondaryTextColor,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (widget.args?['phone'] != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: kPrimaryLightColor,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            'Customer: ${widget.args!['phone']}',
                            style: kSmallerTitleSB.copyWith(
                              color: kPrimaryColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: screenSize.responsivePadding(32)),

                // Redemption Details Card
                Container(
                  padding: EdgeInsets.all(screenSize.responsivePadding(24)),
                  decoration: BoxDecoration(
                    color: kWhite,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                        spreadRadius: 0,
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Bill Amount Field
                      PrimaryTextField(
                        controller: _saleAmountController,
                        label: 'Bill Amount (₹)',
                        hint: '0.00',
                        type: TextFieldType.number,
                        isRequired: true,
                        prefixIcon: const Icon(
                          Icons.currency_rupee_rounded,
                          color: kPrimaryColor,
                          size: 20,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Bill amount is required';
                          }
                          final amt = double.tryParse(value.trim());
                          if (amt == null || amt <= 0) {
                            return 'Enter a valid bill amount';
                          }

                          final priceRange = widget.args?['priceRange'];
                          if (priceRange != null && priceRange is Map) {
                            final min = double.tryParse(
                              priceRange['min']?.toString() ?? '',
                            );
                            final max = double.tryParse(
                              priceRange['max']?.toString() ?? '',
                            );

                            if (min != null && amt < min) {
                              return 'Minimum bill amount should be ₹${min.toInt() == min ? min.toInt() : min}';
                            }
                            if (max != null && amt > max) {
                              return 'Maximum bill amount should be ₹${max.toInt() == max ? max.toInt() : max}';
                            }
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Bill Number Field
                      PrimaryTextField(
                        controller: _billNoController,
                        label: 'Bill Number',
                        hint: 'Enter invoice or bill number',
                        isRequired: true,
                        prefixIcon: const Icon(
                          Icons.receipt_long_rounded,
                          color: kPrimaryColor,
                          size: 20,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Bill number is required';
                          }
                          return null;
                        },
                      ),

                      // Divider
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Divider(
                                color: Color(0xFFE2E8F0),
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'Verification Code',
                                style: kSmallerTitleSB.copyWith(
                                  color: kSecondaryTextColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(
                                color: Color(0xFFE2E8F0),
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // OTP Field
                      Center(
                        child: FittedBox(
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
                              disabledBorderColor: const Color(0xFFE2E8F0),
                              borderColor: const Color(0xFFE2E8F0),
                              fillColor: kWhite,
                              filledFillColor: const Color(0xFFF8FAFC),
                              focusedFillColor: kWhite,
                              cursorColor: kPrimaryColor,
                            ),
                            onChanged: (value) {
                              otp = value;
                              if (value.length == 6) {
                                FocusManager.instance.primaryFocus?.unfocus();
                              }
                            },
                            onCompleted: (value) {
                              otp = value;
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: screenSize.responsivePadding(32)),

                // Action Button
                PrimaryButton(
                  text: 'Verify & Complete Redemption',
                  isLoading: isLoading,
                  onPressed: _verify,
                  borderRadius: BorderRadius.circular(16),
                  height: 54,
                  textSize: 14,
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
