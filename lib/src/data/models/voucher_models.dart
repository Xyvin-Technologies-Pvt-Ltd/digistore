class VoucherModel {
  final String id;
  final String? campaignId;
  final String? publicUserId;
  final String voucherCode;
  final String title;
  final String rewardType;
  final double value;
  final double? minOrderValue;
  final double? maxDiscountAmount;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String status;
  final int? daysLeft;
  final bool isExpired;
  final List<String> applicableCategories;
  final List<String> applicablePartners;
  final DateTime? createdAt;

  const VoucherModel({
    required this.id,
    this.campaignId,
    this.publicUserId,
    required this.voucherCode,
    required this.title,
    required this.rewardType,
    required this.value,
    this.minOrderValue,
    this.maxDiscountAmount,
    this.validFrom,
    this.validUntil,
    required this.status,
    this.daysLeft,
    this.isExpired = false,
    this.applicableCategories = const [],
    this.applicablePartners = const [],
    this.createdAt,
  });

  bool get isActive => status.toLowerCase() == 'active' && !isExpired;
  bool get isFlat => rewardType.toLowerCase().contains('flat');
  bool get isPercentage => rewardType.toLowerCase().contains('percent');

  String get valueLabel {
    if (isPercentage) {
      final v = value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toString();
      return '$v% Off';
    }
    final v = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
    return '₹$v Off';
  }

  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    return VoucherModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      campaignId: json['campaignId']?.toString(),
      publicUserId: json['publicUserId']?.toString(),
      voucherCode: (json['voucherCode'] ?? json['code'] ?? '').toString(),
      title: (json['title'] ?? json['label'] ?? 'Voucher').toString(),
      rewardType: (json['rewardType'] ?? 'flat_voucher').toString(),
      value: _asDouble(json['value']),
      minOrderValue: _asDoubleOrNull(json['minOrderValue']),
      maxDiscountAmount: _asDoubleOrNull(json['maxDiscountAmount']),
      validFrom: _asDate(json['validFrom']),
      validUntil: _asDate(json['validUntil']),
      status: (json['status'] ?? 'active').toString().toLowerCase(),
      daysLeft: _asIntOrNull(json['daysLeft']),
      isExpired: json['isExpired'] == true,
      applicableCategories: _asStringList(json['applicableCategories']),
      applicablePartners: _asStringList(json['applicablePartners']),
      createdAt: _asDate(json['createdAt']),
    );
  }
}

class VoucherValidationResult {
  final bool valid;
  final double discountAmount;
  final double finalAmount;
  final String message;
  final VoucherModel? voucher;

  const VoucherValidationResult({
    required this.valid,
    this.discountAmount = 0,
    this.finalAmount = 0,
    required this.message,
    this.voucher,
  });

  const VoucherValidationResult.invalid(this.message)
    : valid = false,
      discountAmount = 0,
      finalAmount = 0,
      voucher = null;

  factory VoucherValidationResult.fromJson(Map<String, dynamic> json) {
    final voucherMap = json['voucher'];
    return VoucherValidationResult(
      valid: json['valid'] == true,
      discountAmount: _asDouble(json['discountAmount']),
      finalAmount: _asDouble(json['finalAmount']),
      message: (json['message'] ?? '').toString(),
      voucher: voucherMap is Map
          ? VoucherModel.fromJson(Map<String, dynamic>.from(voucherMap))
          : null,
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _asDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _asIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

List<String> _asStringList(dynamic value) {
  if (value is! List) return const [];
  return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
}
