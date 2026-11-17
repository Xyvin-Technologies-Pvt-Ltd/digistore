import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../data/models/booking_razorpay_order.dart';
import '../../../data/models/service_model.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/razorpay_provider.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/providers/services_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../../../data/services/razorpay_service.dart';
import '../../components/loading_indicator.dart';
import 'booking_confirmed_page.dart';

/// Completes online payment for a reserved booking slot.
///
/// Flow: open Razorpay → verify signature on backend → [BookingConfirmedPage].
/// Never trusts client-only success; confirmation requires `/payment/verify`.
class BookingPaymentPage extends ConsumerStatefulWidget {
  final BookingModel booking;
  final BookingRazorpayOrder? initialOrder;
  final String shopName;

  const BookingPaymentPage({
    super.key,
    required this.booking,
    this.initialOrder,
    this.shopName = 'SetGo',
  });

  @override
  ConsumerState<BookingPaymentPage> createState() => _BookingPaymentPageState();
}

class _BookingPaymentPageState extends ConsumerState<BookingPaymentPage> {
  bool _isBusy = false;
  bool _checkoutOpened = false;
  String? _errorMessage;
  BookingRazorpayOrder? _order;
  String? _pendingOrderId;

  RazorpayService get _razorpay => ref.read(razorpayServiceProvider);

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder?.isValid == true ? widget.initialOrder : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _razorpay.setCallbacks(
        onSuccess: _onPaymentSuccess,
        onError: _onPaymentError,
      );
      _startPayment();
    });
  }

  /// Same idea as Jamiat: prefer live profile, fall back to booking customer.
  Future<({String? contact, String? email, String? name})>
  _userPrefill() async {
    var user = ref.read(userProvider);
    final needsProfile =
        user == null ||
        (user.phone == null || user.phone!.trim().isEmpty) ||
        (user.email == null || user.email!.trim().isEmpty);

    if (needsProfile) {
      try {
        await ref.read(userProvider.notifier).getProfile();
        user = ref.read(userProvider);
      } catch (_) {
        // Keep whatever we already have / booking fallbacks.
      }
    }

    final customer = widget.booking.customerDetails;
    final contact = _firstNonEmpty([user?.phone, customer?.phone]);
    final email = _firstNonEmpty([user?.email, customer?.email]);
    final name = _firstNonEmpty([user?.name, customer?.name]);

    return (contact: contact, email: email, name: name);
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      final t = v?.trim();
      if (t != null && t.isNotEmpty) return t;
    }
    return null;
  }

  Future<void> _startPayment() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      var order = _order;
      if (order == null || !order.isValid) {
        final res = await BookingService.createPaymentOrder(
          api: ref.read(publicApiProvider),
          bookingId: widget.booking.id,
        );
        if (!res.success || res.data == null || !res.data!.isValid) {
          setState(() {
            _isBusy = false;
            _errorMessage =
                res.message ?? 'Could not start payment. Please try again.';
          });
          return;
        }
        order = res.data!;
        _order = order;
      }

      final prefill = await _userPrefill();
      _pendingOrderId = order.orderId;
      _checkoutOpened = true;

      _razorpay.openCheckout(
        keyId: order.keyId,
        orderId: order.orderId,
        amount: order.amount,
        name: 'SetGo',
        description:
            'Booking #${widget.booking.bookingNumber.isNotEmpty ? widget.booking.bookingNumber : widget.booking.tokenNumber}',
        contact: prefill.contact,
        email: prefill.email,
        customerName: prefill.name,
      );

      if (mounted) {
        setState(() => _isBusy = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    if (!mounted) return;
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    final orderId = (response.orderId?.trim().isNotEmpty == true)
        ? response.orderId!.trim()
        : (_pendingOrderId ?? _order?.orderId ?? '');
    final paymentId = response.paymentId?.trim() ?? '';
    final signature = response.signature?.trim() ?? '';

    if (orderId.isEmpty || paymentId.isEmpty || signature.isEmpty) {
      setState(() {
        _isBusy = false;
        _errorMessage =
            'Payment confirmation details are missing. If money was deducted, contact support with your booking ID.';
      });
      return;
    }

    final verify = await BookingService.verifyPayment(
      api: ref.read(publicApiProvider),
      bookingId: widget.booking.id,
      razorpayOrderId: orderId,
      razorpayPaymentId: paymentId,
      razorpaySignature: signature,
    );

    if (!mounted) return;

    if (!verify.success || verify.data == null) {
      setState(() {
        _isBusy = false;
        _errorMessage =
            verify.message ??
            'Payment received but verification failed. Please contact support before paying again.';
      });
      return;
    }

    final verified = verify.data!;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BookingConfirmedPage(
          booking: verified.booking,
          spinUnlocked: verified.spinUnlocked,
        ),
      ),
    );
  }

  Future<void> _onPaymentError(PaymentFailureResponse response) async {
    // Best-effort: tell backend the attempt failed (slot may still be held).
    unawaited(
      BookingService.failPayment(
        api: ref.read(publicApiProvider),
        bookingId: widget.booking.id,
        errorReason: response.message,
        errorCode: response.code,
      ),
    );

    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _checkoutOpened = false;
      _order = null; // Force fresh create-order on retry.
      _errorMessage = response.message ?? 'Payment cancelled or failed.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    final amount = _order?.amount ?? widget.booking.totalAmount;
    final bookingRef = widget.booking.bookingNumber.isNotEmpty
        ? widget.booking.bookingNumber
        : widget.booking.tokenNumber;

    return PopScope(
      canPop: !_isBusy,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F5F4),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF3F5F4),
          elevation: 0,
          surfaceTintColor: const Color(0xFFF3F5F4),
          title: Text(
            'Complete Payment',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(screenSize.responsivePadding(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: EdgeInsets.all(screenSize.responsivePadding(20)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.shopName,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Booking #$bookingRef',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Amount payable',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                          Text(
                            '₹${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your slot is reserved for 15 minutes. Complete payment to confirm the booking.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          height: 1.4,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  SizedBox(height: screenSize.responsivePadding(16)),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: const Color(0xFFB91C1C),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (_isBusy)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: LoadingAnimation(size: 36),
                    ),
                  ),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isBusy ? null : _startPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6155F5),
                      disabledBackgroundColor: const Color(
                        0xFF6155F5,
                      ).withValues(alpha: 0.7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _checkoutOpened && _errorMessage != null
                          ? 'Retry Payment'
                          : 'Pay Now',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
