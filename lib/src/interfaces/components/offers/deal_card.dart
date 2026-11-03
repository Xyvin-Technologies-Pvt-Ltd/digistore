import 'package:setgo/src/data/constants/color_constants.dart';
import 'package:setgo/src/data/constants/style_constants.dart';
import 'package:setgo/src/data/providers/screen_size_provider.dart';
import 'package:setgo/src/data/providers/user_type_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../advanced_network_image.dart';
import '../../../data/models/offer_model.dart';
import '../../../data/providers/offers_provider.dart';

class DealCard extends ConsumerWidget {
  final String? id;
  final String title;
  final String subtitle;
  final String shopName;
  final String? shopLogo;
  final String? badgeText;
  final String? dealOfTheHour;
  final Color avatarColor;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final String? imageUrl;
  final bool hideShopName;
  final List<String>? terms;
  final DateTime? validTo;
  final OfferModel? rawOffer;
  final double? distance;
  final int descriptionMaxLines;

  const DealCard({
    super.key,
    this.id,
    required this.title,
    required this.subtitle,
    required this.shopName,
    this.shopLogo,
    this.badgeText,
    this.dealOfTheHour,
    required this.avatarColor,
    this.margin,
    this.width,
    this.imageUrl,
    this.hideShopName = false,
    this.terms,
    this.validTo,
    this.rawOffer,
    this.distance,
    this.descriptionMaxLines = 1,
  });

  static String? resolveBadgeText(OfferModel offer) {
    final code = offer.offerTypeCode?.toUpperCase();
    final isFlat = offer.discountType?.toLowerCase() == 'flat' ||
        offer.discountType?.toLowerCase() == 'amount' ||
        offer.discountType?.toLowerCase() == 'fixed';

    // 1. Buy X Get Y (BG)
    if (code == "BG") {
      final metadata = offer.offerMetadata;
      final buyQty = metadata?['buyQuantity'] ?? 1;
      final getDesc = metadata?['getDescription'] ?? '1';
      return "BUY $buyQty\nGET $getDesc";
    }

    // 2. Specific Non-Discount Offer Types
    if (code == "CO" || code == "CP") {
      return "COMBO\nOFFER";
    }
    if (code == "LD") {
      return "LUCKY\nDRAW";
    }
    if (code == "LO") {
      return "LOYALTY\nOFFER";
    }
    if (code == "DNP") {
      return "NEXT\nPURCHASE";
    }
    if (code == "CS") {
      return "CLEARANCE\nSALE";
    }
    if (code == "LTO") {
      return "LIMITED TIME\nOFFER";
    }
    if (code == "RC") {
      return "REDEEMABLE\nCOUPON";
    }

    // 3. Discount Range (for DO / Discount offers)
    final dMin = offer.discountRange?.min;
    final dMax = offer.discountRange?.max;
    if (dMin != null && dMax != null && (dMin > 0 || dMax > 0)) {
      if (dMin == dMax) {
        final val = dMin % 1 == 0 ? dMin.toInt().toString() : dMin.toStringAsFixed(1);
        return isFlat ? "₹$val\nOFF" : "$val%\nOFF";
      } else {
        final minStr = dMin % 1 == 0 ? dMin.toInt().toString() : dMin.toStringAsFixed(0);
        final maxStr = dMax % 1 == 0 ? dMax.toInt().toString() : dMax.toStringAsFixed(0);
        return isFlat ? "₹$minStr - ₹$maxStr\nOFF" : "$minStr% - $maxStr%\nOFF";
      }
    } else if (dMax != null && dMax > 0) {
      final val = dMax % 1 == 0 ? dMax.toInt().toString() : dMax.toStringAsFixed(1);
      return isFlat ? "UPTO\n₹$val OFF" : "UPTO\n$val% OFF";
    } else if (dMin != null && dMin > 0) {
      final val = dMin % 1 == 0 ? dMin.toInt().toString() : dMin.toStringAsFixed(1);
      return isFlat ? "MIN\n₹$val OFF" : "MIN\n$val% OFF";
    }

    // 4. Single Discount Value
    if (offer.discountValue != null && offer.discountValue! > 0) {
      final val = offer.discountValue! % 1 == 0
          ? offer.discountValue!.toInt().toString()
          : offer.discountValue!.toStringAsFixed(1);
      return isFlat ? "₹$val\nOFF" : "$val%\nOFF";
    }

    // 5. Price Range
    final pMin = offer.priceRange?.min;
    final pMax = offer.priceRange?.max;
    if (pMin != null && pMax != null && (pMin > 0 || pMax > 0)) {
      if (pMin == pMax) {
        final val = pMin % 1 == 0 ? pMin.toInt().toString() : pMin.toStringAsFixed(0);
        return "₹$val\nONLY";
      } else {
        final minStr = pMin % 1 == 0 ? pMin.toInt().toString() : pMin.toStringAsFixed(0);
        final maxStr = pMax % 1 == 0 ? pMax.toInt().toString() : pMax.toStringAsFixed(0);
        return "₹$minStr - ₹$maxStr";
      }
    }

    if (code == "DO") {
      return "SPECIAL\nOFFER";
    }

    // 6. Fallback
    if (code != null && code.isNotEmpty) {
      final label = offerTypeLabels[code];
      if (label != null) {
        return label.toUpperCase();
      }
      return code;
    }

    return null;
  }

  factory DealCard.fromOffer(
    OfferModel offer, {
    double? width,
    EdgeInsetsGeometry? margin,
    bool hideShopName = false,
    int descriptionMaxLines = 1,
  }) {
    final badgeText = resolveBadgeText(offer);

    return DealCard(
      id: offer.id,
      title: offer.title ?? '',
      subtitle: offer.description ?? '',
      shopName: offer.partnerId?.businessDetails?.businessName ?? '',
      shopLogo: offer.partnerId?.businessInfo?.businessLogo,
      badgeText: badgeText,
      avatarColor: kPrimaryLightColor,
      imageUrl: offer.images?.isNotEmpty == true ? offer.images![0] : null,
      width: width,
      margin: margin,
      terms: offer.terms,
      validTo: offer.validTo,
      rawOffer: offer,
      hideShopName: hideShopName,
      distance: offer.distance,
      descriptionMaxLines: descriptionMaxLines,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenSize = ref.watch(screenSizeProvider);
    final isPartner = ref.watch(userTypeProvider) == UserType.partner;

    return GestureDetector(
      onTap: () {
        final Map<String, dynamic> args = Map<String, dynamic>.from(
          rawOffer?.toJson() ??
              {
                'id': id,
                'title': title,
                'subtitle': subtitle,
                'shopName': shopName,
                'shopLogo': shopLogo,
                'imageUrl': imageUrl,
                'description': subtitle,
                'terms': terms,
                'validTo': validTo?.toIso8601String(),
              },
        );
        if (hideShopName || isPartner) {
          args['hideShopInfo'] = true;
        }
        Navigator.of(context).pushNamed('offerDetail', arguments: args);
      },
      child: Container(
        width: width,
        margin: margin,
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: screenSize.responsivePadding(115),
                    width: double.infinity,
                    child: AdvancedNetworkImage(
                      imageUrl: imageUrl ?? '',
                      fit: BoxFit.cover,
                      disableFade: true,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: (badgeText == null || badgeText!.isEmpty)
                        ? const SizedBox.shrink()
                        : Container(
                            constraints: BoxConstraints(
                              maxWidth: screenSize.responsivePadding(120),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: screenSize.responsivePadding(8),
                              vertical: screenSize.responsivePadding(5),
                            ),
                            decoration: const BoxDecoration(
                              color: kPrimaryColor,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(8),
                                topRight: Radius.circular(11),
                              ),
                            ),
                            child: Text(
                              badgeText!,
                              style: kSmallerTitleM.copyWith(
                                color: kWhite,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                  ),
                  if (dealOfTheHour != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenSize.responsivePadding(12),
                          vertical: screenSize.responsivePadding(4),
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0XFFDFEAFF), Color(0xFFFFE5A1)],
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(11),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          dealOfTheHour ?? '',
                          style: kSmallerTitleM.copyWith(fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: EdgeInsets.all(screenSize.responsivePadding(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: kSmallTitleB.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: screenSize.responsivePadding(3)),
                        if (subtitle.isNotEmpty &&
                            subtitle != 'null' &&
                            subtitle != 'nil')
                          Text(
                            subtitle,
                            style: kSmallerTitleL.copyWith(
                              color: kSecondaryTextColor,
                              fontSize: 12,
                              height: 1.25,
                            ),
                            maxLines: descriptionMaxLines,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    if (!hideShopName && !isPartner) ...[
                      SizedBox(height: screenSize.responsivePadding(8)),
                      Row(
                        children: [
                          Container(
                            width: screenSize.responsivePadding(20),
                            height: screenSize.responsivePadding(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: avatarColor,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: shopLogo != null
                                ? AdvancedNetworkImage(
                                    imageUrl: shopLogo!,
                                    fit: BoxFit.cover,
                                    disableFade: true,
                                  )
                                : Icon(Icons.store, size: 12, color: kWhite),
                          ),
                          SizedBox(width: screenSize.responsivePadding(8)),
                          Expanded(
                            child: Text(
                              shopName,
                              style: kSmallerTitleM,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (rawOffer?.pointsCost != null &&
                        rawOffer!.pointsCost! > 0) ...[
                      SizedBox(height: screenSize.responsivePadding(6)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.stars_rounded,
                              size: 11,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${rawOffer!.pointsCost} pts',
                              style: kSmallerTitleB.copyWith(
                                color: const Color(0xFFB45309),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (distance != null) ...[
                      SizedBox(height: screenSize.responsivePadding(6)),
                      Text(
                        '${distance!.toStringAsFixed(1)} km',
                        style: kSmallerTitleL.copyWith(
                          color: kSecondaryTextColor,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
