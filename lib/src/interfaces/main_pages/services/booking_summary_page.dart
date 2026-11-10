import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/booking_estimate.dart';
import '../../../data/models/service_model.dart';
import '../../../data/models/shop_model.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/providers/services_provider.dart';
import '../../../data/providers/shops_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../../components/advanced_network_image.dart';
import '../../components/loading_indicator.dart';
import 'booking_confirmed_page.dart';
import 'booking_payment_page.dart';

class BookingSummaryPage extends ConsumerStatefulWidget {
  final ServicePartnerModel partner;
  final String partnerId;
  final List<ServiceModel> services;

  /// serviceId → quantity (defaults to 1 when missing).
  final Map<String, int> quantities;
  final String bookingDate;
  final TimeSlotModel selectedSlot;
  final String notes;
  final double totalPrice;
  final double originalPrice;

  const BookingSummaryPage({
    super.key,
    required this.partner,
    required this.partnerId,
    required this.services,
    this.quantities = const {},
    required this.bookingDate,
    required this.selectedSlot,
    required this.notes,
    required this.totalPrice,
    required this.originalPrice,
  });

  @override
  ConsumerState<BookingSummaryPage> createState() => _BookingSummaryPageState();
}

class _BookingSummaryPageState extends ConsumerState<BookingSummaryPage> {
  bool _isSubmitting = false;
  bool _isValidatingVoucher = false;
  final _voucherController = TextEditingController();
  BookingEstimate? _estimate;
  String? _voucherError;

  int _qtyFor(ServiceModel s) {
    final id = s.id ?? '';
    if (id.isEmpty) return 1;
    return (widget.quantities[id] ?? 1).clamp(1, 99);
  }

  List<Map<String, dynamic>> get _bookingItems => widget.services
      .where((s) => s.id != null && s.id!.isNotEmpty)
      .map(
        (s) => <String, dynamic>{
          'serviceId': s.id,
          'quantity': _qtyFor(s),
        },
      )
      .toList();

  double get _subtotalExGst {
    if (_estimate != null) {
      return _estimate!.subtotal > 0
          ? _estimate!.subtotal
          : _estimate!.grossAmount;
    }
    return widget.services.fold(
      0.0,
      (sum, s) => sum + (s.taxableAmount * _qtyFor(s)),
    );
  }

  double get _totalGst {
    if (_estimate != null) return _estimate!.totalGstAmount;
    return widget.services.fold(
      0.0,
      (sum, s) => sum + (s.totalGstAmount * _qtyFor(s)),
    );
  }

  double get _voucherDiscount => _estimate?.voucherDiscount ?? 0;

  /// Estimate is only fetched when applying a voucher code.
  bool get _voucherApplied => _estimate != null;

  double get _payableTotal {
    if (_estimate != null) {
      final total = _estimate!.totalAmount > 0
          ? _estimate!.totalAmount
          : _estimate!.customerPays;
      return total < 0 ? 0 : total;
    }
    return widget.totalPrice < 0 ? 0 : widget.totalPrice;
  }

  String _money(double value) {
    return value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _applyVoucher() async {
    final code = _voucherController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _voucherError = 'Enter a voucher code';
        _estimate = null;
      });
      return;
    }

    if (_bookingItems.isEmpty) {
      setState(() {
        _voucherError = 'Select at least one service';
        _estimate = null;
      });
      return;
    }

    setState(() {
      _isValidatingVoucher = true;
      _voucherError = null;
    });

    // Server recalculates subtotal, applies voucher before GST, returns payable.
    final res = await BookingService.estimate(
      api: ref.read(apiProvider),
      partnerId: widget.partnerId,
      items: _bookingItems,
      voucherCode: code,
    );

    if (!mounted) return;
    setState(() {
      _isValidatingVoucher = false;
      if (res.success && res.data != null) {
        _estimate = res.data;
        _voucherError = null;
        final applied = res.data!.voucherCode?.trim();
        if (applied != null && applied.isNotEmpty) {
          _voucherController.text = applied;
        }
      } else {
        _estimate = null;
        _voucherError = res.message ?? 'Could not apply voucher';
      }
    });
  }

  void _clearVoucher() {
    setState(() {
      _voucherController.clear();
      _estimate = null;
      _voucherError = null;
    });
  }

  Future<void> _handleConfirmBooking() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final items = _bookingItems;

    final appliedCode = _voucherApplied
        ? (_estimate?.voucherCode?.trim().isNotEmpty == true
              ? _estimate!.voucherCode!.trim()
              : _voucherController.text.trim())
        : null;

    final res = await BookingService.createBooking(
      api: ref.read(apiProvider),
      partnerId: widget.partnerId,
      items: items,
      bookingDate: widget.bookingDate,
      startTime: widget.selectedSlot.startTime,
      notes: widget.notes.isNotEmpty ? widget.notes : null,
      voucherCode: appliedCode,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!res.success || res.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Booking failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = res.data!;
    final booking = result.booking;

    // Free booking → confirmed immediately (backend skips Razorpay).
    if (booking.totalAmount <= 0 || !result.requiresPayment) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BookingConfirmedPage(booking: booking),
        ),
      );
      return;
    }

    // Paid booking → payment page, then confirmed after verify.
    final shopName = widget.partner.name?.trim();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => BookingPaymentPage(
          booking: booking,
          initialOrder: result.razorpayOrder,
          shopName:
              (shopName != null &&
                  shopName.isNotEmpty &&
                  shopName != 'SetGo Partner')
              ? shopName
              : 'SetGo',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    final user = ref.watch(userProvider);
    final savings = widget.originalPrice - widget.totalPrice;

    // Fetch full shop data for logo/address fallback
    final ShopModel? fetchedShop = widget.partnerId.isNotEmpty
        ? ref.watch(getShopByPartnerIdProvider(widget.partnerId)).value
        : null;

    final String rawPartnerName = widget.partner.name ?? '';
    final String effectiveShopName =
        rawPartnerName.isNotEmpty && rawPartnerName != 'SetGo Partner'
        ? rawPartnerName
        : (fetchedShop?.businessDetails?.businessName ??
              rawPartnerName.ifEmpty('Partner Store'));

    final String? rawPartnerLogo = widget.partner.logo;
    final String? effectiveShopLogo =
        (rawPartnerLogo != null && rawPartnerLogo.isNotEmpty)
        ? rawPartnerLogo
        : (fetchedShop?.businessInfo?.businessLogo ??
              fetchedShop?.businessInfo?.coverImage);

    final rawPartnerAddress = [
      if (widget.partner.addressLine1 != null &&
          widget.partner.addressLine1!.isNotEmpty)
        widget.partner.addressLine1!,
      if (widget.partner.city != null && widget.partner.city!.isNotEmpty)
        widget.partner.city!,
    ].join(', ');
    final String effectiveShopAddress = rawPartnerAddress.isNotEmpty
        ? rawPartnerAddress
        : (fetchedShop?.businessDetails?.address ?? '');

    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(widget.bookingDate);
    } catch (_) {
      parsedDate = DateTime.now();
    }
    final displayDate = DateFormat('EEEE, d MMM yyyy').format(parsedDate);

    final String servicesSummary = widget.services.isNotEmpty
        ? widget.services
              .map((s) {
                final qty = _qtyFor(s);
                return qty > 1 ? '${s.name} ×$qty' : s.name;
              })
              .join(', ')
        : 'Service';
    final int totalDuration = widget.services.fold(
      0,
      (sum, s) => sum + s.totalTimeMinutes,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F5F4),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF373737),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Booking Summary',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: const Color(0xFF373737),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: screenSize.responsivePadding(16),
                  vertical: screenSize.responsivePadding(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Shop and Service Info Card (Figma shop-info-card 2158:3424)
                    _buildShopAndServiceCard(
                      screenSize: screenSize,
                      partnerName: effectiveShopName,
                      partnerLogo: effectiveShopLogo,
                      partnerAddress: effectiveShopAddress,
                      servicesSummary: servicesSummary,
                      totalDuration: totalDuration,
                    ),
                    SizedBox(height: screenSize.responsivePadding(16)),

                    // 2. Booking Details Card (Figma 2158:3437)
                    _buildBookingDetailsCard(
                      screenSize: screenSize,
                      servicesSummary: servicesSummary,
                      displayDate: displayDate,
                      slotTime: widget.selectedSlot.startTime,
                      savings: savings,
                      userName: user?.name,
                      userPhone: user?.phone,
                    ),
                    SizedBox(height: screenSize.responsivePadding(16)),
                    _buildVoucherCard(screenSize: screenSize),
                    SizedBox(height: screenSize.responsivePadding(24)),
                  ],
                ),
              ),
            ),

            // 3. Bottom Sticky CTA Bar (Figma 2158:3464)
            _buildBottomBar(screenSize: screenSize),
          ],
        ),
      ),
    );
  }

  // Shop & Service Info Card
  Widget _buildShopAndServiceCard({
    required ScreenSizeData screenSize,
    required String partnerName,
    required String? partnerLogo,
    required String partnerAddress,
    required String servicesSummary,
    required int totalDuration,
  }) {
    final firstService = widget.services.isNotEmpty
        ? widget.services.first
        : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: EdgeInsets.all(screenSize.responsivePadding(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Partner Details Row
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                ),
                child: ClipOval(
                  child: (partnerLogo != null && partnerLogo.isNotEmpty)
                      ? AdvancedNetworkImage(
                          imageUrl: partnerLogo,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: const Color(0xFFF3F4F6),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: Color(0xFF9CA3AF),
                              size: 26,
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: Color(0xFF9CA3AF),
                            size: 26,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partnerName,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            partnerAddress.isNotEmpty
                                ? partnerAddress
                                : 'Partner Store',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(height: 1, color: const Color(0xFFF3F4F6)),
          ),

          // Service Title
          Text(
            servicesSummary,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (firstService?.description != null &&
              firstService!.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              firstService.description!.trim(),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6B7280),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '₹${widget.totalPrice.toInt()}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF07838C),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5F4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$totalDuration mins total',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Booking Details Card
  Widget _buildBookingDetailsCard({
    required ScreenSizeData screenSize,
    required String servicesSummary,
    required String displayDate,
    required String slotTime,
    required double savings,
    required String? userName,
    required String? userPhone,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: EdgeInsets.all(screenSize.responsivePadding(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Appointment Details
          _buildDetailRow(label: 'Service', value: servicesSummary),
          const SizedBox(height: 10),
          _buildDetailRow(label: 'Date', value: displayDate),
          const SizedBox(height: 10),
          _buildDetailRow(label: 'Time', value: slotTime),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Container(height: 1, color: const Color(0xFFEDEDED)),
          ),

          // Section 2: Pricing — voucher is deducted before GST (server estimate).
          _buildDetailRow(
            label: 'Service amount',
            value: '₹${_money(_subtotalExGst)}',
          ),
          if (savings > 0 && _estimate == null) ...[
            const SizedBox(height: 10),
            _buildDetailRow(
              label: 'Offer Discount',
              value: '- ₹${savings.toInt()}',
              valueColor: const Color(0xFF07982C),
              isValueBold: true,
            ),
          ],
          if (_voucherDiscount > 0) ...[
            const SizedBox(height: 10),
            _buildDetailRow(
              label: 'Voucher Discount',
              value: '- ₹${_money(_voucherDiscount)}',
              valueColor: const Color(0xFF07982C),
              isValueBold: true,
            ),
          ],
          const SizedBox(height: 10),
          _buildDetailRow(
            label: 'GST',
            value: '+ ₹${_money(_totalGst)}',
          ),
          const SizedBox(height: 10),
          _buildDetailRow(
            label: 'Total (incl. GST)',
            value: '₹${_money(_payableTotal)}',
            isValueBold: true,
          ),
          const SizedBox(height: 10),
          _buildDetailRow(
            label: 'Payment Mode',
            value: _payableTotal > 0 ? 'Pay Online' : 'Free',
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Container(height: 1, color: const Color(0xFFEDEDED)),
          ),

          // Section 3: Customer Details
          _buildDetailRow(
            label: 'Name',
            value: (userName != null && userName.isNotEmpty)
                ? userName
                : 'Customer',
          ),
          const SizedBox(height: 10),
          _buildDetailRow(
            label: 'Phone',
            value: (userPhone != null && userPhone.isNotEmpty)
                ? userPhone
                : 'Not provided',
          ),

          // Optional Notes
          if (widget.notes.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Container(height: 1, color: const Color(0xFFEDEDED)),
            ),
            _buildDetailRow(label: 'Notes', value: widget.notes),
          ],
        ],
      ),
    );
  }

  Widget _buildVoucherCard({required ScreenSizeData screenSize}) {
    final applied = _voucherApplied;
    final successMessage = _estimate?.message.trim().isNotEmpty == true
        ? _estimate!.message
        : (_voucherDiscount > 0
              ? 'Voucher applied: ₹${_money(_voucherDiscount)} discount!'
              : 'Voucher applied');
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: EdgeInsets.all(screenSize.responsivePadding(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Have a voucher?',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1C),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _voucherController,
                  enabled: !applied && !_isValidatingVoucher,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Enter voucher code',
                    hintStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6155F5)),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                  onSubmitted: (_) => _applyVoucher(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isValidatingVoucher
                      ? null
                      : (applied ? _clearVoucher : _applyVoucher),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: applied
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF6155F5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _isValidatingVoucher
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          applied ? 'Remove' : 'Apply',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (_voucherError != null) ...[
            const SizedBox(height: 10),
            Text(
              _voucherError!,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Color(0xFFB91C1C),
              ),
            ),
          ],
          if (applied) ...[
            const SizedBox(height: 10),
            Text(
              successMessage,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF07982C),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    bool isValueBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF808080),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: isValueBold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? const Color(0xFF1C1C1C),
            ),
          ),
        ),
      ],
    );
  }

  // Bottom Sticky CTA Bar
  Widget _buildBottomBar({required ScreenSizeData screenSize}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        screenSize.responsivePadding(16),
        screenSize.responsivePadding(10),
        screenSize.responsivePadding(16),
        screenSize.responsivePadding(16),
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _handleConfirmBooking,
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
            child: _isSubmitting
                ? const LoadingAnimation(size: 24, loadingColor: Colors.white)
                : Text(
                    _payableTotal > 0
                        ? 'Pay ₹${_money(_payableTotal)}'
                        : 'Confirm Booking',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
