import 'spin_models.dart';

/// Single offer eligibility row from GET /shops/:id/redeemable-offers.
class RedeemableOffer {
  final String id;
  final String title;
  final bool eligible;
  final String? reason;
  final int userCompletedCount;
  final int? maxPerUser;
  final int? maxTotalRedemptions;
  final bool isScratchCard;
  final bool isScratched;
  final dynamic awardedDiscount;
  final double? offerPrice;
  final double? originalPrice;

  const RedeemableOffer({
    required this.id,
    required this.title,
    this.eligible = false,
    this.reason,
    this.userCompletedCount = 0,
    this.maxPerUser,
    this.maxTotalRedemptions,
    this.isScratchCard = false,
    this.isScratched = false,
    this.awardedDiscount,
    this.offerPrice,
    this.originalPrice,
  });

  factory RedeemableOffer.fromJson(Map<String, dynamic> json) {
    return RedeemableOffer(
      id: (json['_id'] ?? json['id'] ?? json['offerId'] ?? '').toString(),
      title: (json['title'] ?? 'Offer').toString(),
      eligible: json['eligible'] == true,
      reason: json['reason']?.toString(),
      userCompletedCount: _asInt(json['userCompletedCount']),
      maxPerUser: _asIntOrNull(json['maxPerUser']),
      maxTotalRedemptions: _asIntOrNull(json['maxTotalRedemptions']),
      isScratchCard: json['isScratchCard'] == true,
      isScratched: json['isScratched'] == true,
      awardedDiscount: json['awardedDiscount'],
      offerPrice: _asDoubleOrNull(json['offerPrice']),
      originalPrice: _asDoubleOrNull(json['originalPrice']),
    );
  }
}

/// Cart summary nested under redeemable-offers / cart APIs.
class CartOfferLink {
  final String cartId;
  final int totalQuantity;
  final double subtotal;
  final int itemsCount;
  final List<String> selectedOfferIds;
  final String? redemptionBatchId;
  final String redemptionStatus; // none | pending | completed

  const CartOfferLink({
    required this.cartId,
    this.totalQuantity = 0,
    this.subtotal = 0,
    this.itemsCount = 0,
    this.selectedOfferIds = const [],
    this.redemptionBatchId,
    this.redemptionStatus = 'none',
  });

  factory CartOfferLink.fromJson(Map<String, dynamic> json) {
    final rawIds = json['selectedOfferIds'];
    final ids = <String>[];
    if (rawIds is List) {
      for (final id in rawIds) {
        final s = id?.toString().trim() ?? '';
        if (s.isNotEmpty) ids.add(s);
      }
    }
    return CartOfferLink(
      cartId: (json['cartId'] ?? json['_id'] ?? json['id'] ?? '').toString(),
      totalQuantity: _asInt(json['totalQuantity']),
      subtotal: _asDouble(json['subtotal']),
      itemsCount: _asInt(json['itemsCount']),
      selectedOfferIds: ids,
      redemptionBatchId: json['redemptionBatchId']?.toString(),
      redemptionStatus: (json['redemptionStatus'] ?? 'none').toString(),
    );
  }
}

/// Compact offer summary attached to a cart / inquiry.
class SelectedOfferSummary {
  final String id;
  final String title;
  final String? discountType;
  final double? discountValue;
  final double? offerPrice;
  final double? originalPrice;
  final String? validTo;

  const SelectedOfferSummary({
    required this.id,
    required this.title,
    this.discountType,
    this.discountValue,
    this.offerPrice,
    this.originalPrice,
    this.validTo,
  });

  factory SelectedOfferSummary.fromJson(Map<String, dynamic> json) {
    return SelectedOfferSummary(
      id: (json['_id'] ?? json['id'] ?? json['offerId'] ?? '').toString(),
      title: (json['title'] ?? 'Offer').toString(),
      discountType: json['discountType']?.toString(),
      discountValue: _asDoubleOrNull(json['discountValue']),
      offerPrice: _asDoubleOrNull(json['offerPrice']),
      originalPrice: _asDoubleOrNull(json['originalPrice']),
      validTo: json['validTo']?.toString(),
    );
  }
}

/// Response from GET /shops/:id/redeemable-offers.
class ShopOffersBundle {
  final String? shopId;
  final int totalActiveOffers;
  final int eligibleOffersCount;
  final List<RedeemableOffer> offers;
  final CartOfferLink? cart;

  /// Legacy raw maps for callers that still expect Map offers.
  final List<Map<String, dynamic>> redeemableOffers;

  const ShopOffersBundle({
    this.shopId,
    this.totalActiveOffers = 0,
    this.eligibleOffersCount = 0,
    this.offers = const [],
    this.cart,
    this.redeemableOffers = const [],
  });

  String? get cartId => cart?.cartId;

  bool get bulkRedemptionReady => eligibleOffersCount >= 2 || offers.length >= 2;

  List<RedeemableOffer> get eligibleOffers =>
      offers.where((o) => o.eligible).toList();

  factory ShopOffersBundle.fromJson(Map<String, dynamic> json) {
    final raw =
        json['offers'] ??
        json['redeemableOffers'] ??
        json['data'] ??
        const [];
    final offers = <RedeemableOffer>[];
    final rawMaps = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          rawMaps.add(map);
          offers.add(RedeemableOffer.fromJson(map));
        }
      }
    }

    CartOfferLink? cart;
    final cartRaw = json['cart'];
    if (cartRaw is Map) {
      cart = CartOfferLink.fromJson(Map<String, dynamic>.from(cartRaw));
    } else if (json['cartId'] != null) {
      cart = CartOfferLink(
        cartId: json['cartId'].toString(),
        selectedOfferIds: const [],
      );
    }

    final eligibleCount = _asIntOrNull(json['eligibleOffersCount']) ??
        offers.where((o) => o.eligible).length;

    return ShopOffersBundle(
      shopId: json['shopId']?.toString(),
      totalActiveOffers:
          _asIntOrNull(json['totalActiveOffers']) ?? offers.length,
      eligibleOffersCount: eligibleCount,
      offers: offers,
      cart: cart,
      redeemableOffers: rawMaps,
    );
  }
}

class SkippedOffer {
  final String offerId;
  final String? title;
  final String reason;

  const SkippedOffer({
    required this.offerId,
    this.title,
    required this.reason,
  });

  factory SkippedOffer.fromJson(Map<String, dynamic> json) {
    return SkippedOffer(
      offerId: (json['offerId'] ?? json['_id'] ?? json['id'] ?? '').toString(),
      title: json['title']?.toString(),
      reason: (json['reason'] ?? 'Skipped').toString(),
    );
  }
}

class BulkRedeemOfferRef {
  final String offerId;
  final String title;
  final String? redemptionId;
  final dynamic awardedDiscount;

  const BulkRedeemOfferRef({
    required this.offerId,
    required this.title,
    this.redemptionId,
    this.awardedDiscount,
  });

  factory BulkRedeemOfferRef.fromJson(Map<String, dynamic> json) {
    return BulkRedeemOfferRef(
      offerId: (json['offerId'] ?? json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Offer').toString(),
      redemptionId: json['redemptionId']?.toString(),
      awardedDiscount: json['awardedDiscount'],
    );
  }
}

/// Per-offer bill split: `{ offerId, saleAmount }`.
class BulkOfferSaleAmount {
  final String offerId;
  final double saleAmount;

  const BulkOfferSaleAmount({
    required this.offerId,
    required this.saleAmount,
  });

  Map<String, dynamic> toJson() => {
        'offerId': offerId,
        'saleAmount': saleAmount,
      };

  factory BulkOfferSaleAmount.fromJson(Map<String, dynamic> json) {
    return BulkOfferSaleAmount(
      offerId: (json['offerId'] ?? json['_id'] ?? '').toString(),
      saleAmount: _asDouble(json['saleAmount']),
    );
  }
}

class BulkRedeemInitResult {
  final String batchId;
  final List<String> redemptionIds;
  final int offersCount;
  final List<BulkRedeemOfferRef> offers;
  final List<SkippedOffer> skippedOffers;
  final DateTime? expiresAt;
  final DateTime? otpExpiresAt;
  final String? voucherCode;
  final String? cartId;
  final String? message;
  final String? qrPayload;
  final String? qrToken;
  final String? qrCode;
  final String? otp;
  final bool? smsSent;

  const BulkRedeemInitResult({
    required this.batchId,
    this.redemptionIds = const [],
    required this.offersCount,
    this.offers = const [],
    this.skippedOffers = const [],
    this.expiresAt,
    this.otpExpiresAt,
    this.voucherCode,
    this.cartId,
    this.message,
    this.qrPayload,
    this.qrToken,
    this.qrCode,
    this.otp,
    this.smsSent,
  });

  factory BulkRedeemInitResult.fromJson(Map<String, dynamic> json) {
    final rawOffers = json['offers'];
    final offers = <BulkRedeemOfferRef>[];
    if (rawOffers is List) {
      for (final item in rawOffers) {
        if (item is Map) {
          offers.add(
            BulkRedeemOfferRef.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final skipped = <SkippedOffer>[];
    final rawSkipped = json['skippedOffers'];
    if (rawSkipped is List) {
      for (final item in rawSkipped) {
        if (item is Map) {
          skipped.add(SkippedOffer.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final redemptionIds = <String>[];
    final rawIds = json['redemptionIds'];
    if (rawIds is List) {
      for (final id in rawIds) {
        final s = id?.toString() ?? '';
        if (s.isNotEmpty) redemptionIds.add(s);
      }
    }

    final expires = _asDate(json['expiresAt'] ?? json['otpExpiresAt']);

    return BulkRedeemInitResult(
      batchId: (json['batchId'] ?? json['id'] ?? '').toString(),
      redemptionIds: redemptionIds,
      offersCount: _asInt(json['offersCount'] ?? offers.length),
      offers: offers,
      skippedOffers: skipped,
      expiresAt: expires,
      otpExpiresAt: expires,
      voucherCode: json['voucherCode']?.toString(),
      cartId: json['cartId']?.toString(),
      message: json['message']?.toString(),
      qrPayload: (json['qrPayload'] ?? json['qr'] ?? json['payload'])
          ?.toString(),
      qrToken: json['qrToken']?.toString(),
      qrCode: json['qrCode']?.toString(),
      otp: json['otp']?.toString(),
      smsSent: json['smsSent'] is bool ? json['smsSent'] as bool : null,
    );
  }
}

class BulkRedemptionLine {
  final String redemptionId;
  final String offerId;
  final String offerTitle;
  final double saleAmount;
  final double netSaleAmount;
  final dynamic awardedDiscount;
  final int pointsEarned;
  final String status;

  const BulkRedemptionLine({
    required this.redemptionId,
    required this.offerId,
    required this.offerTitle,
    this.saleAmount = 0,
    this.netSaleAmount = 0,
    this.awardedDiscount,
    this.pointsEarned = 0,
    this.status = 'completed',
  });

  factory BulkRedemptionLine.fromJson(Map<String, dynamic> json) {
    return BulkRedemptionLine(
      redemptionId: (json['redemptionId'] ?? json['_id'] ?? '').toString(),
      offerId: (json['offerId'] ?? '').toString(),
      offerTitle: (json['offerTitle'] ?? json['title'] ?? 'Offer').toString(),
      saleAmount: _asDouble(json['saleAmount']),
      netSaleAmount: _asDouble(json['netSaleAmount']),
      awardedDiscount: json['awardedDiscount'],
      pointsEarned: _asInt(json['pointsEarned']),
      status: (json['status'] ?? 'completed').toString(),
    );
  }
}

/// Common completion payload (Notion §8).
class BulkVerifyResult {
  final String? batchId;
  final List<String> redemptionIds;
  final int offersCount;
  final String? cartId;
  final int pointsEarned;
  final int pointsUsed;
  final String? voucherId;
  final String? voucherCode;
  final double voucherDiscount;
  final double saleAmount;
  final double netSaleAmount;
  final double cashAmount;
  final String? paymentMode;
  final int? pointsBalance;
  final DateTime? redeemedAt;
  final String? tier;
  final List<BulkRedemptionLine> redemptions;
  final String? billNo;
  final String? billImage;
  final String status;
  final String? message;
  final List<SkippedOffer> skippedOffers;
  final SpinUnlock? spinUnlocked;

  const BulkVerifyResult({
    this.batchId,
    this.redemptionIds = const [],
    required this.offersCount,
    this.cartId,
    this.pointsEarned = 0,
    this.pointsUsed = 0,
    this.voucherId,
    this.voucherCode,
    this.voucherDiscount = 0,
    this.saleAmount = 0,
    this.netSaleAmount = 0,
    this.cashAmount = 0,
    this.paymentMode,
    this.pointsBalance,
    this.redeemedAt,
    this.tier,
    this.redemptions = const [],
    this.billNo,
    this.billImage,
    this.status = 'completed',
    this.message,
    this.skippedOffers = const [],
    this.spinUnlocked,
  });

  /// Back-compat aliases used by existing UI.
  double get totalDiscount => voucherDiscount;
  int get totalPointsEarned => pointsEarned;

  factory BulkVerifyResult.fromJson(Map<String, dynamic> json) {
    final redemptionIds = <String>[];
    final rawIds = json['redemptionIds'];
    if (rawIds is List) {
      for (final id in rawIds) {
        final s = id?.toString() ?? '';
        if (s.isNotEmpty) redemptionIds.add(s);
      }
    }

    final lines = <BulkRedemptionLine>[];
    final rawLines = json['redemptions'];
    if (rawLines is List) {
      for (final item in rawLines) {
        if (item is Map) {
          lines.add(
            BulkRedemptionLine.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final skipped = <SkippedOffer>[];
    final rawSkipped = json['skippedOffers'];
    if (rawSkipped is List) {
      for (final item in rawSkipped) {
        if (item is Map) {
          skipped.add(SkippedOffer.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return BulkVerifyResult(
      batchId: json['batchId']?.toString(),
      redemptionIds: redemptionIds,
      offersCount: _asInt(
        json['offersCount'] ??
            (lines.isNotEmpty ? lines.length : redemptionIds.length),
      ),
      cartId: json['cartId']?.toString(),
      pointsEarned: _asInt(
        json['pointsEarned'] ?? json['totalPointsEarned'],
      ),
      pointsUsed: _asInt(json['pointsUsed']),
      voucherId: json['voucherId']?.toString(),
      voucherCode: json['voucherCode']?.toString(),
      voucherDiscount: _asDouble(
        json['voucherDiscount'] ??
            json['totalDiscount'] ??
            json['total_discount'],
      ),
      saleAmount: _asDouble(json['saleAmount']),
      netSaleAmount: _asDouble(json['netSaleAmount']),
      cashAmount: _asDouble(json['cashAmount']),
      paymentMode: json['paymentMode']?.toString(),
      pointsBalance: _asIntOrNull(json['pointsBalance']),
      redeemedAt: _asDate(json['redeemedAt']),
      tier: json['tier']?.toString(),
      redemptions: lines,
      billNo: json['billNo']?.toString(),
      billImage: json['billImage']?.toString(),
      status: (json['status'] ?? 'completed').toString(),
      message: json['message']?.toString(),
      skippedOffers: skipped,
      spinUnlocked: SpinUnlock.tryParse(json['spinUnlocked']),
    );
  }
}

class CartOffersUpdateResult {
  final String cartId;
  final String? partnerId;
  final List<String> selectedOfferIds;
  final List<SelectedOfferSummary> selectedOffers;
  final String? message;

  const CartOffersUpdateResult({
    required this.cartId,
    this.partnerId,
    this.selectedOfferIds = const [],
    this.selectedOffers = const [],
    this.message,
  });

  factory CartOffersUpdateResult.fromJson(
    Map<String, dynamic> json, {
    String? message,
  }) {
    final ids = <String>[];
    final rawIds = json['selectedOfferIds'];
    if (rawIds is List) {
      for (final id in rawIds) {
        final s = id?.toString() ?? '';
        if (s.isNotEmpty) ids.add(s);
      }
    }

    final offers = <SelectedOfferSummary>[];
    final rawOffers = json['selectedOffers'];
    if (rawOffers is List) {
      for (final item in rawOffers) {
        if (item is Map) {
          offers.add(
            SelectedOfferSummary.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return CartOffersUpdateResult(
      cartId: (json['cartId'] ?? json['_id'] ?? json['id'] ?? '').toString(),
      partnerId: json['partnerId']?.toString(),
      selectedOfferIds: ids,
      selectedOffers: offers,
      message: message ?? json['message']?.toString(),
    );
  }
}

/// Maps Notion §9 error codes to UI-friendly copy.
String bulkRedemptionErrorMessage({
  String? errorCode,
  String? fallback,
}) {
  switch ((errorCode ?? '').toUpperCase()) {
    case 'MIXED_PARTNER_OFFERS':
      return 'Selected offers belong to different shops. Keep selection to one shop.';
    case 'CART_PARTNER_MISMATCH':
      return 'This cart belongs to a different shop.';
    case 'NO_OFFERS_SELECTED':
      return 'Select at least one offer, or use Redeem All.';
    case 'NO_ELIGIBLE_OFFERS':
      return 'No eligible offers available at this shop right now.';
    case 'SCRATCH_REQUIRED':
      return 'Scratch the mystery offer before redeeming it.';
    case 'USER_REDEMPTION_LIMIT':
    case 'REDEMPTION_LIMIT_REACHED':
      return 'One of the selected offers has reached its redemption limit.';
    case 'TIER_REQUIRED':
      return 'A higher membership tier is required for one of these offers.';
    case 'INVALID_VOUCHER':
      return 'Voucher is invalid, expired, or does not apply to this bill.';
    case 'INSUFFICIENT_POINTS':
      return 'Not enough points for this redemption.';
    case 'ALREADY_COMPLETED':
    case 'ALREADY_REDEEMED':
      return 'This batch was already completed.';
    case 'OTP_EXPIRED':
      return 'OTP expired. Please request a new one.';
    case 'INVALID_OTP':
      return 'Invalid OTP. Please try again.';
    case 'INVALID_QR':
    case 'QR_MISMATCH':
      return 'QR code is invalid or expired. Ask the customer to generate a new one.';
    default:
      return fallback?.trim().isNotEmpty == true
          ? fallback!.trim()
          : 'Something went wrong. Please try again.';
  }
}

String? extractBulkErrorCode(Map<String, dynamic>? body) {
  if (body == null) return null;
  final code = body['errorCode'] ?? body['code'] ?? body['error'];
  if (code == null) return null;
  final s = code.toString().trim();
  return s.isEmpty ? null : s;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
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

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
