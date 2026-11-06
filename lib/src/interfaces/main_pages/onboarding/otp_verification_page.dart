import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../../data/constants/color_constants.dart';
import '../../../data/constants/style_constants.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../components/primary_button.dart';
import '../../components/confirmation_dialog.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/services/toast_service.dart';
import '../../../data/services/secure_storage_service.dart';
import '../../../data/providers/user_type_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../../../data/providers/partner_provider.dart';
import '../../components/referral_code_field.dart';

class OtpVerificationPage extends ConsumerStatefulWidget {
  const OtpVerificationPage({super.key});

  @override
  ConsumerState<OtpVerificationPage> createState() =>
      _OtpVerificationPageState();
}

class _OtpVerificationPageState extends ConsumerState<OtpVerificationPage> {
  final PinInputController _otpController = PinInputController();
  final TextEditingController _referralController = TextEditingController();
  final GlobalKey<ReferralCodeFieldState> _referralKey =
      GlobalKey<ReferralCodeFieldState>();
  String otp = '';
  bool _termsAccepted = false;
  late Future<Map<String, dynamic>?> _registrationDataFuture;
  int _resendTimerSeconds = 90;
  Timer? _resendTimer;
  bool _offerReferralCode = false;

  @override
  void initState() {
    super.initState();
    _registrationDataFuture = ref
        .read(secureStorageServiceProvider)
        .getRegistrationData();
    _registrationDataFuture.then(_rememberAccountType);
    _startResendTimer();
  }

  void _rememberAccountType(Map<String, dynamic>? data) {
    if (!mounted) return;
    final customer = ref.read(userTypeProvider) == UserType.customer;
    final existingAccount = data?['isNewUser'] == false;
    setState(() {
      _offerReferralCode = customer && !existingAccount;
    });
  }

  void _startResendTimer() {
    setState(() {
      _resendTimerSeconds = 90;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimerSeconds > 0) {
        setState(() {
          _resendTimerSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    return Scaffold(
      backgroundColor: kWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(screenSize.responsivePadding(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: screenSize.responsivePadding(40)),
              Image.asset(
                'assets/png/setgo.png',
                height: screenSize.responsivePadding(80),
              ),
              SizedBox(height: screenSize.responsivePadding(8)),
              Text(
                'Spend Local. Save Big.',
                style: kSmallerTitleL.copyWith(
                  color: kSecondaryTextColor,
                  fontSize: 10,
                ),
              ),
              SizedBox(height: screenSize.responsivePadding(40)),
              Text('OTP Verification', style: kSubHeadingM),
              SizedBox(height: screenSize.responsivePadding(8)),
              Text(
                'Enter the verification code sent to your number',
                style: kBodyTitleL.copyWith(color: Color(0XFF797979)),
              ),
              FutureBuilder<Map<String, dynamic>?>(
                future: _registrationDataFuture,
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  final phone = data?['phone'] as String?;
                  final devOtp = data?['devOtp'] as String?;

                  String maskedPhone = phone ?? '';
                  if (maskedPhone.length > 5) {
                    final prefix = maskedPhone.substring(0, 5);
                    final suffix = maskedPhone.substring(
                      maskedPhone.length - 3,
                    );
                    maskedPhone =
                        '$prefix${'X' * (maskedPhone.length - 8)}$suffix';
                  }

                  return Column(
                    children: [
                      if (phone != null && phone.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(
                            top: screenSize.responsivePadding(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                maskedPhone,
                                style: kSmallTitleSB.copyWith(
                                  color: kGreyDark,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              SizedBox(width: screenSize.responsivePadding(8)),
                              GestureDetector(
                                onTap: () async {
                                  final confirm = await showConfirmationDialog(
                                    context: context,
                                    title: 'Change Number',
                                    message:
                                        'Are you sure you want to change your mobile number?',
                                    confirmText: 'Change',
                                    icon: Icons.edit_rounded,
                                  );
                                  if (confirm == true && context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: screenSize.responsivePadding(
                                      10,
                                    ),
                                    vertical: screenSize.responsivePadding(2),
                                  ),
                                  decoration: BoxDecoration(
                                    color: kPrimaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    'Change',
                                    style: kSmallTitleSB.copyWith(
                                      color: kPrimaryColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (devOtp != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Testing OTP: $devOtp',
                            style: kBodyTitleM.copyWith(color: kPrimaryColor),
                          ),
                        ),
                    ],
                  );
                },
              ),

              SizedBox(height: screenSize.responsivePadding(16)),

              MaterialPinField(
                length: 6,
                pinController: _otpController,
                keyboardType: TextInputType.number,
                theme: MaterialPinTheme(
                  shape: MaterialPinShape.outlined,
                  borderRadius: BorderRadius.circular(12),
                  cellSize: const Size(45, 50),
                  focusedBorderColor: kPrimaryColor,
                  disabledBorderColor: Color(0xFFF7F4F4),
                  borderColor: Color(0xFFF7F4F4),
                  fillColor: Color(0xFFF7F4F4),
                  filledFillColor: const Color(0xFFF5F5F5),
                  focusedFillColor: Color(0xFFF7F4F4),
                  cursorColor: kPrimaryColor,
                ),
                onChanged: (value) {
                  otp = value;
                },
              ),

              if (_offerReferralCode) ...[
                SizedBox(height: screenSize.responsivePadding(24)),
                ReferralCodeField(
                  key: _referralKey,
                  controller: _referralController,
                ),
              ],

              SizedBox(height: screenSize.responsivePadding(24)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _termsAccepted,
                      activeColor: kPrimaryColor.withValues(alpha: 0.8),
                      side: const BorderSide(
                        color: Color(0xFFC4C4C4),
                        width: 1.5,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _termsAccepted = value ?? false;
                        });
                      },
                    ),
                  ),
                  SizedBox(width: screenSize.responsivePadding(12)),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: kSmallTitleL.copyWith(
                          color: kSecondaryTextColor,
                          height: 1.5,
                          fontSize: 11,
                        ),
                        children: [
                          const TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: kSmallTitleSB.copyWith(
                              color: kPrimaryColor,
                              height: 1.5,
                              fontSize: 11,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.pushNamed(context, 'termsConditions');
                              },
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: kSmallTitleSB.copyWith(
                              color: kPrimaryColor,
                              height: 1.5,
                              fontSize: 11,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.pushNamed(context, 'privacyPolicy');
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenSize.responsivePadding(24)),
              Opacity(
                opacity: (otp.length == 6 && _termsAccepted) ? 1.0 : 0.5,
                child: PrimaryButton(
                  text: 'Verify',
                  isEnabled: otp.length == 6 && _termsAccepted,
                  isLoading: ref.watch(authProvider).isLoading,
                  onPressed: () async {
                    if (otp.length == 6 && _termsAccepted) {
                      final storage = ref.read(secureStorageServiceProvider);
                      final data = await storage.getRegistrationData();
                      final phone = data?['phone'] ?? '';

                      if (phone.isNotEmpty) {
                        String? referralCode;
                        if (_offerReferralCode &&
                            _referralController.text.trim().isNotEmpty) {
                          final check = await _referralKey.currentState
                              ?.resolve();
                          if (!context.mounted) return;
                          if (check == null || !check.valid || check.code == null) {
                            ToastService().showToast(
                              context,
                              check?.message.isNotEmpty == true
                                  ? check!.message
                                  : 'Enter a valid referral code or leave it blank',
                              type: ToastType.error,
                            );
                            return;
                          }
                          referralCode = check.code;
                        }

                        final result = await ref
                            .read(authProvider.notifier)
                            .verifyOtp(
                              phone,
                              otp,
                              _termsAccepted,
                              referralCode: referralCode,
                            );
                        if (result['success'] == true && context.mounted) {
                          final userType = ref.read(userTypeProvider);

                          // Fetch appropriate data based on user type
                          if (userType == UserType.customer) {
                            await ref.read(userProvider.notifier).getProfile();
                          } else {
                            await ref
                                .read(partnerProvider.notifier)
                                .getPartnerProfile();
                          }

                          if (result['onboardingComplete'] == false &&
                              userType == UserType.customer) {
                            if (!context.mounted) return;
                            Navigator.of(context).pushNamed('profileSetup');
                          } else {
                            await storage.clearRegistrationData();
                            if (!context.mounted) return;
                            // For partners or completed customers, go to navbar
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              'navbar',
                              (route) => false,
                            );
                          }
                        } else if (result['success'] == false &&
                            context.mounted) {
                          ToastService().showToast(
                            context,
                            (result['message'] as String).replaceAll(
                              'Exception: ',
                              '',
                            ),
                            type: ToastType.error,
                          );
                        }
                      } else {
                        if (!context.mounted) return;
                        ToastService().showToast(
                          context,
                          'Phone number not found. Please login again.',
                          type: ToastType.error,
                        );
                      }
                    } else if (!_termsAccepted) {
                      ToastService().showToast(
                        context,
                        'Please accept the Terms & Conditions and Privacy Policy',
                        type: ToastType.warning,
                      );
                    } else {
                      ToastService().showToast(
                        context,
                        'Please enter a valid 6-digit OTP',
                        type: ToastType.warning,
                      );
                    }
                  },
                ),
              ),
              SizedBox(height: screenSize.responsivePadding(24)),
              _resendTimerSeconds > 0
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Resend code in ',
                          style: kSmallTitleL.copyWith(
                            color: const Color(0xFF626165),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${(_resendTimerSeconds ~/ 60).toString().padLeft(2, '0')}:${(_resendTimerSeconds % 60).toString().padLeft(2, '0')}',
                          style: kBodyTitleM.copyWith(
                            color: kPrimaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: GestureDetector(
                        onTap: () async {
                          final storage = ref.read(
                            secureStorageServiceProvider,
                          );
                          final data = await storage.getRegistrationData();
                          final phone = data?['phone'] ?? '';

                          if (phone.isNotEmpty) {
                            final success = await ref
                                .read(authProvider.notifier)
                                .sendOtp(phone);
                            if (success && context.mounted) {
                              ToastService().showToast(
                                context,
                                'OTP resent successfully',
                                type: ToastType.success,
                              );
                              final refreshed = storage.getRegistrationData();
                              setState(() {
                                _registrationDataFuture = refreshed;
                              });
                              refreshed.then(_rememberAccountType);
                              _startResendTimer();
                            } else if (!success && context.mounted) {
                              ToastService().showToast(
                                context,
                                'Failed to resend OTP',
                                type: ToastType.error,
                              );
                            }
                          }
                        },
                        child: Text(
                          'Resend Code',
                          style: kBodyTitleM.copyWith(
                            color: kPrimaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
