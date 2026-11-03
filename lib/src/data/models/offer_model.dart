import 'package:setgo/src/utils/safe_parser.dart';
import 'category_model.dart';
import 'partner_model.dart';
import 'redemption_rules.dart';
import 'coverage_areas.dart';
import 'premium_placement.dart';
import 'location_point.dart';
import 'user_model.dart';

class OfferModel {
  final String? id;
  final PartnerModel? partnerId;
  final String? title;
  final String? description;
  final List<String>? images;
  final CategoryModel? category;
  final String? subcategory;
  final List<String>? subcategories;
  final String? offerTypeCode;
  final Map<String, dynamic>? offerMetadata;
  final String? discountType;
  final double? discountValue;
  final RangeModel? discountRange;
  final double? originalPrice;
  final double? offerPrice;
  final RangeModel? priceRange;
  final List<String>? terms;
  final DateTime? validFrom;
  final DateTime? validTo;
  final RedemptionRules? redemptionRules;
  final CoverageAreas? coverageAreas;
  final String? status;
  final bool? isPremium;
  final PremiumPlacement? premiumPlacement;
  final int? totalRedemptions;
  final int? views;
  final bool? isActive;
  final bool? isDealOfDay;
  final TierModel? requiredTier;
  final List<String>? tags;
  final LocationPoint? location;
  final int? shareCount;
  final DateTime? createdAt;
  final BranchApplicability? branchApplicability;
  final List<dynamic>? branchLocations;
  final bool? isScratchCard;
  final bool? isScratched;
  final num? awardedDiscount;
  final DealsModel? deals;
  /// Single authoritative active promotion from API (`getOfferActiveDeal`).
  final ActiveDealModel? activeDeal;
  final double? distance;
  final int? pointsCost;
  final bool? requiresPointsPayment;

  const OfferModel({
    this.id,
    this.partnerId,
    this.title,
    this.description,
    this.images,
    this.category,
    this.subcategory,
    this.subcategories,
    this.offerTypeCode,
    this.offerMetadata,
    this.discountType,
    this.discountValue,
    this.discountRange,
    this.originalPrice,
    this.offerPrice,
    this.priceRange,
    this.terms,
    this.validFrom,
    this.validTo,
    this.redemptionRules,
    this.coverageAreas,
    this.status,
    this.isPremium,
    this.premiumPlacement,
    this.totalRedemptions,
    this.views,
    this.isActive,
    this.isDealOfDay,
    this.requiredTier,
    this.tags,
    this.location,
    this.shareCount,
    this.createdAt,
    this.branchApplicability,
    this.branchLocations,
    this.isScratchCard,
    this.isScratched,
    this.awardedDiscount,
    this.deals,
    this.activeDeal,
    this.distance,
    this.pointsCost,
    this.requiresPointsPayment,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    List<String>? parsedSubcategories;
    if (json['subcategories'] != null && json['subcategories'] is List) {
      parsedSubcategories = (json['subcategories'] as List)
          .map((e) {
            if (e is Map && e['name'] != null) return e['name'].toString();
            return e.toString();
          })
          .where((s) => s.trim().isNotEmpty)
          .toList();
    } else if (json['subcategory'] != null &&
        json['subcategory'].toString().trim().isNotEmpty) {
      parsedSubcategories = [json['subcategory'].toString().trim()];
    }

    String? singleSubcategory = json['subcategory'] as String?;
    if (singleSubcategory == null &&
        parsedSubcategories != null &&
        parsedSubcategories.isNotEmpty) {
      singleSubcategory = parsedSubcategories.first;
    }

    return OfferModel(
      id: json['_id'] as String?,
      partnerId: SafeParser.parseObject(
        json['partnerId'],
        PartnerModel.fromJson,
      ),
      title: json['title'] as String?,
      description: json['description'] as String?,
      images: json['images'] != null ? List<String>.from(json['images']) : null,
      category: SafeParser.parseObject(
        json['category'],
        CategoryModel.fromJson,
      ),
      subcategory: singleSubcategory,
      subcategories: parsedSubcategories,
      offerTypeCode: json['offerTypeCode'] as String?,
      offerMetadata: json['offerMetadata'] as Map<String, dynamic>?,
      discountType: json['discountType'] as String?,
      discountValue: (json['discountValue'] as num?)?.toDouble(),
      discountRange: SafeParser.parseObject(
        json['discountRange'],
        RangeModel.fromJson,
      ),
      originalPrice: (json['originalPrice'] as num?)?.toDouble(),
      offerPrice: (json['offerPrice'] as num?)?.toDouble(),
      priceRange: SafeParser.parseObject(
        json['priceRange'],
        RangeModel.fromJson,
      ),
      terms: json['terms'] != null ? List<String>.from(json['terms']) : null,
      validFrom: json['validFrom'] != null
          ? DateTime.tryParse(json['validFrom'])?.toLocal()
          : null,
      validTo: json['validTo'] != null
          ? DateTime.tryParse(json['validTo'])?.toLocal()
          : null,
      redemptionRules: SafeParser.parseObject(
        json['redemptionRules'],
        RedemptionRules.fromJson,
      ),
      coverageAreas: SafeParser.parseObject(
        json['coverageAreas'],
        CoverageAreas.fromJson,
      ),
      status: json['status'] as String?,
      isPremium: json['isPremium'] as bool?,
      premiumPlacement: SafeParser.parseObject(
        json['premiumPlacement'],
        PremiumPlacement.fromJson,
      ),
      totalRedemptions: json['totalRedemptions'] as int?,
      views: json['views'] as int?,
      isActive: json['isActive'] as bool?,
      isDealOfDay: json['isDealOfDay'] as bool?,
      requiredTier: SafeParser.parseObject(
        json['requiredTier'],
        TierModel.fromJson,
      ),
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      location: SafeParser.parseObject(
        json['location'],
        LocationPoint.fromJson,
      ),
      shareCount: json['shareCount'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])?.toLocal()
          : null,
      branchApplicability: SafeParser.parseObject(
        json['branchApplicability'],
        BranchApplicability.fromJson,
      ),
      branchLocations: json['branchLocations'] as List<dynamic>?,
      isScratchCard: json['isScratchCard'] as bool?,
      isScratched: json['isScratched'] as bool?,
      awardedDiscount: json['awardedDiscount'] as num?,
      deals: SafeParser.parseObject(json['deals'], DealsModel.fromJson),
      activeDeal: SafeParser.parseObject(
        json['activeDeal'],
        ActiveDealModel.fromJson,
      ),
      distance: json['distance'] != null
          ? (json['distance'] as num).toDouble()
          : null,
      pointsCost: (json['pointsCost'] as num?)?.toInt(),
      requiresPointsPayment: json['requiresPointsPayment'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'partnerId': partnerId?.toJson(),
      'title': title,
      'description': description,
      'images': images,
      'category': category?.toJson(),
      'subcategory': subcategory,
      'subcategories': subcategories,
      'offerTypeCode': offerTypeCode,
      'offerMetadata': offerMetadata,
      'discountType': discountType,
      'discountValue': discountValue,
      'discountRange': discountRange?.toJson(),
      'originalPrice': originalPrice,
      'offerPrice': offerPrice,
      'priceRange': priceRange?.toJson(),
      'terms': terms,
      'validFrom': validFrom?.toIso8601String(),
      'validTo': validTo?.toIso8601String(),
      'redemptionRules': redemptionRules?.toJson(),
      'coverageAreas': coverageAreas?.toJson(),
      'status': status,
      'isPremium': isPremium,
      'premiumPlacement': premiumPlacement?.toJson(),
      'totalRedemptions': totalRedemptions,
      'views': views,
      'isActive': isActive,
      'isDealOfDay': isDealOfDay,
      'requiredTier': requiredTier?.toJson(),
      'tags': tags,
      'location': location?.toJson(),
      'shareCount': shareCount,
      'createdAt': createdAt?.toIso8601String(),
      'branchApplicability': branchApplicability?.toJson(),
      'branchLocations': branchLocations,
      'isScratchCard': isScratchCard,
      'isScratched': isScratched,
      'awardedDiscount': awardedDiscount,
      'deals': deals?.toJson(),
      'activeDeal': activeDeal?.toJson(),
      'distance': distance,
      'pointsCost': pointsCost,
      'requiresPointsPayment': requiresPointsPayment,
    };
  }

  OfferModel copyWith({
    String? id,
    PartnerModel? partnerId,
    String? title,
    String? description,
    List<String>? images,
    CategoryModel? category,
    String? subcategory,
    String? offerTypeCode,
    Map<String, dynamic>? offerMetadata,
    String? discountType,
    double? discountValue,
    RangeModel? discountRange,
    double? originalPrice,
    double? offerPrice,
    RangeModel? priceRange,
    List<String>? terms,
    DateTime? validFrom,
    DateTime? validTo,
    RedemptionRules? redemptionRules,
    CoverageAreas? coverageAreas,
    String? status,
    bool? isPremium,
    PremiumPlacement? premiumPlacement,
    int? totalRedemptions,
    int? views,
    bool? isActive,
    bool? isDealOfDay,
    TierModel? requiredTier,
    List<String>? tags,
    LocationPoint? location,
    int? shareCount,
    DateTime? createdAt,
    BranchApplicability? branchApplicability,
    List<dynamic>? branchLocations,
    bool? isScratchCard,
    bool? isScratched,
    num? awardedDiscount,
    DealsModel? deals,
    ActiveDealModel? activeDeal,
    double? distance,
    int? pointsCost,
    bool? requiresPointsPayment,
  }) {
    return OfferModel(
      id: id ?? this.id,
      partnerId: partnerId ?? this.partnerId,
      title: title ?? this.title,
      description: description ?? this.description,
      images: images ?? this.images,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      offerTypeCode: offerTypeCode ?? this.offerTypeCode,
      offerMetadata: offerMetadata ?? this.offerMetadata,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      discountRange: discountRange ?? this.discountRange,
      originalPrice: originalPrice ?? this.originalPrice,
      offerPrice: offerPrice ?? this.offerPrice,
      priceRange: priceRange ?? this.priceRange,
      terms: terms ?? this.terms,
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      redemptionRules: redemptionRules ?? this.redemptionRules,
      coverageAreas: coverageAreas ?? this.coverageAreas,
      status: status ?? this.status,
      isPremium: isPremium ?? this.isPremium,
      premiumPlacement: premiumPlacement ?? this.premiumPlacement,
      totalRedemptions: totalRedemptions ?? this.totalRedemptions,
      views: views ?? this.views,
      isActive: isActive ?? this.isActive,
      isDealOfDay: isDealOfDay ?? this.isDealOfDay,
      requiredTier: requiredTier ?? this.requiredTier,
      tags: tags ?? this.tags,
      location: location ?? this.location,
      shareCount: shareCount ?? this.shareCount,
      createdAt: createdAt ?? this.createdAt,
      branchApplicability: branchApplicability ?? this.branchApplicability,
      branchLocations: branchLocations ?? this.branchLocations,
      isScratchCard: isScratchCard ?? this.isScratchCard,
      isScratched: isScratched ?? this.isScratched,
      awardedDiscount: awardedDiscount ?? this.awardedDiscount,
      deals: deals ?? this.deals,
      activeDeal: activeDeal ?? this.activeDeal,
      distance: distance ?? this.distance,
      pointsCost: pointsCost ?? this.pointsCost,
      requiresPointsPayment: requiresPointsPayment ?? this.requiresPointsPayment,
    );
  }
}

class BranchApplicability {
  final String? type;
  final List<String>? branchIds;

  const BranchApplicability({this.type, this.branchIds});

  factory BranchApplicability.fromJson(Map<String, dynamic> json) {
    return BranchApplicability(
      type: json['type'] as String?,
      branchIds: json['branchIds'] != null
          ? List<String>.from(json['branchIds'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type, 'branchIds': branchIds};
  }
}

class RangeModel {
  final double? min;
  final double? max;

  const RangeModel({this.min, this.max});

  factory RangeModel.fromJson(Map<String, dynamic> json) {
    return RangeModel(
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {if (min != null) 'min': min, if (max != null) 'max': max};
  }
}

class ActiveDealModel {
  final String? type;
  final String? label;
  final DateTime? startDate;
  final DateTime? expiryDate;
  final int? timeLeftMs;

  const ActiveDealModel({
    this.type,
    this.label,
    this.startDate,
    this.expiryDate,
    this.timeLeftMs,
  });

  factory ActiveDealModel.fromJson(Map<String, dynamic> json) {
    return ActiveDealModel(
      type: json['type']?.toString(),
      label: json['label']?.toString(),
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString())?.toLocal()
          : null,
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'].toString())?.toLocal()
          : null,
      timeLeftMs: json['timeLeftMs'] is num
          ? (json['timeLeftMs'] as num).toInt()
          : int.tryParse(json['timeLeftMs']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'label': label,
      'startDate': startDate?.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'timeLeftMs': timeLeftMs,
    };
  }
}

class DealsModel {
  final DealItemModel? dealOfDay;
  final DealItemModel? dealOfHour;
  final DealItemModel? dealOfWeek;
  final DealItemModel? dealOfMonth;

  const DealsModel({
    this.dealOfDay,
    this.dealOfHour,
    this.dealOfWeek,
    this.dealOfMonth,
  });

  factory DealsModel.fromJson(Map<String, dynamic> json) {
    return DealsModel(
      dealOfDay: SafeParser.parseObject(
        json['deal_of_day'],
        DealItemModel.fromJson,
      ),
      dealOfHour: SafeParser.parseObject(
        json['deal_of_hour'],
        DealItemModel.fromJson,
      ),
      dealOfWeek: SafeParser.parseObject(
        json['deal_of_week'],
        DealItemModel.fromJson,
      ),
      dealOfMonth: SafeParser.parseObject(
        json['deal_of_month'],
        DealItemModel.fromJson,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deal_of_day': dealOfDay?.toJson(),
      'deal_of_hour': dealOfHour?.toJson(),
      'deal_of_week': dealOfWeek?.toJson(),
      'deal_of_month': dealOfMonth?.toJson(),
    };
  }
}

class DealItemModel {
  final bool? isActive;
  final DateTime? startDate;
  final DateTime? expiryDate;

  const DealItemModel({this.isActive, this.startDate, this.expiryDate});

  factory DealItemModel.fromJson(Map<String, dynamic> json) {
    return DealItemModel(
      isActive: json['isActive'] as bool?,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'])?.toLocal()
          : null,
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'])?.toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'startDate': startDate?.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
    };
  }
}
