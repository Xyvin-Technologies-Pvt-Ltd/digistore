/// Server-side booking price preview from `POST /bookings/estimate`.
///
/// Voucher discount is applied to the subtotal **before** GST, so clients
/// must use these totals instead of subtracting a discount from a GST-inclusive
/// cart amount.
class BookingEstimate {
  final double grossAmount;
  final double itemDiscount;
  final double subtotal;
  final String? promoCode;
  final double promoDiscount;
  final String? voucherId;
  final String? voucherCode;
  final double voucherDiscount;
  final String? voucherTitle;
  final double taxableAmount;
  final double cgstRate;
  final double cgstAmount;
  final double sgstRate;
  final double sgstAmount;
  final double totalGstRate;
  final double totalGstAmount;
  final double customerPays;
  final double totalAmount;
  final String message;

  const BookingEstimate({
    this.grossAmount = 0,
    this.itemDiscount = 0,
    this.subtotal = 0,
    this.promoCode,
    this.promoDiscount = 0,
    this.voucherId,
    this.voucherCode,
    this.voucherDiscount = 0,
    this.voucherTitle,
    this.taxableAmount = 0,
    this.cgstRate = 0,
    this.cgstAmount = 0,
    this.sgstRate = 0,
    this.sgstAmount = 0,
    this.totalGstRate = 0,
    this.totalGstAmount = 0,
    this.customerPays = 0,
    this.totalAmount = 0,
    this.message = '',
  });

  bool get hasVoucher =>
      (voucherCode != null && voucherCode!.trim().isNotEmpty) ||
      voucherDiscount > 0;

  factory BookingEstimate.fromJson(
    Map<String, dynamic> json, {
    String? message,
  }) {
    double n(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    final voucherDiscount = n(
      json['voucherDiscount'] ?? json['promoDiscount'],
    );
    final total = n(
      json['totalAmount'] ?? json['customerPays'] ?? json['finalAmount'],
    );
    final customerPays = n(json['customerPays']);

    return BookingEstimate(
      grossAmount: n(json['grossAmount']),
      itemDiscount: n(json['itemDiscount']),
      subtotal: n(json['subtotal']),
      promoCode: json['promoCode']?.toString(),
      promoDiscount: n(json['promoDiscount']),
      voucherId: json['voucherId']?.toString(),
      voucherCode: (json['voucherCode'] ?? json['promoCode'])?.toString(),
      voucherDiscount: voucherDiscount,
      voucherTitle: json['voucherTitle']?.toString(),
      taxableAmount: n(json['taxableAmount']),
      cgstRate: n(json['cgstRate']),
      cgstAmount: n(json['cgstAmount']),
      sgstRate: n(json['sgstRate']),
      sgstAmount: n(json['sgstAmount']),
      totalGstRate: n(json['totalGstRate']),
      totalGstAmount: n(json['totalGstAmount']),
      customerPays: customerPays > 0 ? customerPays : total,
      totalAmount: total > 0 ? total : customerPays,
      message: (message ?? json['message'] ?? '').toString(),
    );
  }
}
