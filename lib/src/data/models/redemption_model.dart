import 'package:setgo/src/utils/safe_parser.dart';

import 'partner_model.dart';
import 'offer_model.dart';

class PublicUserModel {
  final String? id;
  final String? name;
  final String? phone;

  const PublicUserModel({this.id, this.name, this.phone});

  factory PublicUserModel.fromJson(Map<String, dynamic> json) {
    return PublicUserModel(
      id: json['_id'] as String?,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
    );
  }
}

class RedemptionPaymentInfo {
  final String? mode;
  final int? pointsUsed;
  final double? cashAmountDue;
  final int? offerPointsCost;

  const RedemptionPaymentInfo({
    this.mode,
    this.pointsUsed,
    this.cashAmountDue,
    this.offerPointsCost,
  });

  factory RedemptionPaymentInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RedemptionPaymentInfo();
    return RedemptionPaymentInfo(
      mode: (json['mode'] ?? json['paymentMode']) as String?,
      pointsUsed: (json['pointsUsed'] as num?)?.toInt(),
      cashAmountDue: (json['cashAmountDue'] as num?)?.toDouble() ??
          (json['cashDue'] as num?)?.toDouble() ??
          (json['cashAmount'] as num?)?.toDouble(),
      offerPointsCost: (json['offerPointsCost'] as num?)?.toInt() ??
          (json['pointsCost'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'pointsUsed': pointsUsed,
    'cashAmountDue': cashAmountDue,
    'offerPointsCost': offerPointsCost,
  };
}

class RedemptionModel {
  final String? id;
  final PublicUserModel? publicUserId;
  final PartnerModel? partnerId;
  final OfferModel? offerId;
  final String? status;
  final double? saleAmount;
  final int? pointsEarned;
  final double? commissionPercent;
  final double? commissionAmount;
  final String? billImage;
  final String? otp;
  final bool? otpVerified;
  final String? initiatedBy;
  final DateTime? redeemedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? hasReview;
  final int? pointsUsed;
  final double? cashAmount;
  final int? pointsTransferredToMerchant;
  final String? paymentMode;
  final String? billNo;
  final RedemptionPaymentInfo? payment;

  const RedemptionModel({
    this.id,
    this.publicUserId,
    this.partnerId,
    this.offerId,
    this.status,
    this.saleAmount,
    this.pointsEarned,
    this.commissionPercent,
    this.commissionAmount,
    this.billImage,
    this.otp,
    this.otpVerified,
    this.initiatedBy,
    this.redeemedAt,
    this.createdAt,
    this.updatedAt,
    this.hasReview,
    this.pointsUsed,
    this.cashAmount,
    this.pointsTransferredToMerchant,
    this.paymentMode,
    this.billNo,
    this.payment,
  });

  factory RedemptionModel.fromJson(Map<String, dynamic> json) {
    return RedemptionModel(
      id: json['_id'] as String?,
      publicUserId: SafeParser.parseObject(
        json['publicUserId'],
        PublicUserModel.fromJson,
      ),
      partnerId: SafeParser.parseObject(
        json['partnerId'],
        PartnerModel.fromJson,
      ),
      offerId: SafeParser.parseObject(json['offerId'], OfferModel.fromJson),
      status: json['status'] as String?,
      saleAmount: (json['saleAmount'] as num?)?.toDouble(),
      pointsEarned: json['pointsEarned'] as int?,
      commissionPercent: (json['commissionPercent'] as num?)?.toDouble(),
      commissionAmount: (json['commissionAmount'] as num?)?.toDouble(),
      billImage: json['billImage'] as String?,
      otp: json['otp'] as String?,
      otpVerified: json['otpVerified'] as bool?,
      initiatedBy: json['initiatedBy'] as String?,
      redeemedAt: json['redeemedAt'] != null
          ? DateTime.tryParse(json['redeemedAt'])?.toLocal()
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])?.toLocal()
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])?.toLocal()
          : null,
      hasReview: json['hasReview'] as bool?,
      pointsUsed: (json['pointsUsed'] as num?)?.toInt() ??
          (json['pointsUsedByCustomer'] as num?)?.toInt() ??
          (json['payment'] is Map
              ? (json['payment']['pointsUsed'] as num?)?.toInt()
              : null),
      cashAmount: (json['cashAmount'] as num?)?.toDouble() ??
          (json['cashDue'] as num?)?.toDouble() ??
          (json['cashPaidAtCounter'] as num?)?.toDouble() ??
          (json['payment'] is Map
              ? (json['payment']['cashAmountDue'] as num?)?.toDouble()
              : null),
      pointsTransferredToMerchant:
          (json['pointsTransferredToMerchant'] as num?)?.toInt() ??
              (json['pointsTransferredToMerchantPool'] as num?)?.toInt(),
      paymentMode: (json['paymentMode'] as String?) ??
          (json['payment'] is Map ? json['payment']['mode'] as String? : null),
      billNo: json['billNo'] as String?,
      payment: SafeParser.parseObject(
        json['payment'],
        RedemptionPaymentInfo.fromJson,
      ),
    );
  }
}

class MyRedemptionsResponse {
  final bool success;
  final List<RedemptionModel> data;
  final bool canSubmitReview;

  MyRedemptionsResponse({
    required this.success,
    required this.data,
    required this.canSubmitReview,
  });

  factory MyRedemptionsResponse.fromJson(Map<String, dynamic> json) {
    return MyRedemptionsResponse(
      success: json['success'] as bool? ?? false,
      data: SafeParser.parseList(json['data'], RedemptionModel.fromJson) ?? [],
      canSubmitReview: json['canSubmitReview'] as bool? ?? false,
    );
  }
}

class PaginatedRedemptions {
  final List<RedemptionModel> redemptions;
  final int page;
  final int limit;
  final int total;
  final int pages;

  PaginatedRedemptions({
    required this.redemptions,
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory PaginatedRedemptions.fromJson(Map<String, dynamic> json) {
    return PaginatedRedemptions(
      redemptions:
          SafeParser.parseList(json['data'], RedemptionModel.fromJson) ?? [],
      page: json['pagination']?['page'] as int? ?? 1,
      limit: json['pagination']?['limit'] as int? ?? 10,
      total: json['pagination']?['total'] as int? ?? 0,
      pages: json['pagination']?['pages'] as int? ?? 1,
    );
  }
}
