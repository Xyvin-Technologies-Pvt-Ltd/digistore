import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../../data/constants/color_constants.dart';
import '../../../data/constants/style_constants.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/offer_model.dart';
import '../../../data/models/redemption_rules.dart';
import '../../../data/models/shop_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/offers_provider.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/providers/shops_provider.dart';
import '../../../data/providers/user_type_provider.dart';
import '../../../data/services/toast_service.dart';
import '../../../data/utils/date_formatter.dart';
import '../../../data/utils/deal_resolver.dart';
import '../../../data/utils/global_variables.dart';
import '../../../data/utils/offer_status_utils.dart';
import '../../components/advanced_network_image.dart';
import '../../components/confirmation_dialog.dart';
import '../../components/full_screen_gallery.dart';
import '../../components/guest_login_dialog.dart';
import '../partner/create_offer_page.dart';

class OfferDetailPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> args;

  const OfferDetailPage({super.key, required this.args});

  @override
  ConsumerState<OfferDetailPage> createState() => _OfferDetailPageState();
}

class _OfferDetailPageState extends ConsumerState<OfferDetailPage> {
  bool isRedeeming = false;
  bool isNavigatingToShop = false;
  int _currentImageIndex = 0;

  void _openGallery({
    required List<String> images,
    required String? initialUrl,
  }) {
    if (images.isEmpty) return;
    final initialIndex = initialUrl != null
        ? images.indexOf(initialUrl).clamp(0, images.length - 1)
        : 0;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenGallery(images: images, initialIndex: initialIndex);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _navigateToShop(String partnerId) async {
    if (isNavigatingToShop || partnerId.isEmpty) return;
    setState(() {
      isNavigatingToShop = true;
    });

    try {
      final shop = await ref.read(getShopByPartnerIdProvider(partnerId).future);
      if (!mounted) return;
      if (shop != null) {
        Navigator.of(context).pushNamed('shopDetail', arguments: shop);
      } else {
        ToastService().showToast(
          context,
          'No such shop found for this offer.',
          type: ToastType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ToastService().showToast(
        context,
        'Error loading shop: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          isNavigatingToShop = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    final userType = ref.watch(userTypeProvider);
    final isPartner = userType == UserType.partner || GlobalVariables.isPartner;
    final offersState = ref.watch(offersProvider);
    final currentOfferId = widget.args['_id'] ?? widget.args['id'];
    final cachedOffer =
        offersState.offers.where((o) => o.id == currentOfferId).firstOrNull ??
        offersState.exploreOffers
            .where((o) => o.id == currentOfferId)
            .firstOrNull;

    // Resolve unified status using cachedOffer or nav args.
    // Never defaults missing status to 'active'.
    final String offerStatus = cachedOffer != null
        ? OfferStatusUtils.resolveOfferStatus(cachedOffer)
        : OfferStatusUtils.resolveMapStatus(widget.args);

    final bool isOfferActive = cachedOffer != null
        ? OfferStatusUtils.isOfferLive(cachedOffer)
        : OfferStatusUtils.isLiveForPartner(
            status: widget.args['displayStatus'] ?? widget.args['status'],
            isActive: widget.args['isActive'] is bool
                ? widget.args['isActive'] as bool
                : (widget.args['isActive'] is String
                    ? (widget.args['isActive'] as String).toLowerCase() == 'true'
                    : null),
            validFrom: widget.args['validFrom'] is DateTime
                ? widget.args['validFrom'] as DateTime
                : (widget.args['validFrom'] is String && (widget.args['validFrom'] as String).isNotEmpty
                    ? DateTime.tryParse(widget.args['validFrom'] as String)?.toLocal()
                    : null),
            validTo: widget.args['validTo'] is DateTime
                ? widget.args['validTo'] as DateTime
                : (widget.args['validTo'] is String && (widget.args['validTo'] as String).isNotEmpty
                    ? DateTime.tryParse(widget.args['validTo'] as String)?.toLocal()
                    : null),
          );

    final String title = widget.args['title'] ?? '';
    final String subtitle =
        widget.args['subtitle'] ?? widget.args['description'] ?? '';
    final String? imageUrl =
        widget.args['imageUrl'] ??
        ((widget.args['images'] is List &&
                (widget.args['images'] as List).isNotEmpty)
            ? widget.args['images'][0]
            : null);

    final partnerIdObj = widget.args['partnerId'];
    final String partnerId = (partnerIdObj is Map)
        ? (partnerIdObj['_id'] ?? partnerIdObj['id'] ?? '')
        : (partnerIdObj?.toString() ?? '');

    final ShopModel? fetchedShop = partnerId.isNotEmpty
        ? ref.watch(getShopByPartnerIdProvider(partnerId)).value
        : null;

    final bool isScratchCard =
        cachedOffer?.isScratchCard ??
        (widget.args['isScratchCard'] == true ||
            widget.args['isScratchCard'] == 'true' ||
            widget.args['offerTypeCode'] == 'SC');

    final bool isScratched =
        cachedOffer?.isScratched ??
        (widget.args['isScratched'] == true ||
            widget.args['isScratched'] == 'true');

    final num? awardedDiscount =
        cachedOffer?.awardedDiscount ??
        (widget.args['awardedDiscount'] as num?);

    final dealsJson = widget.args['deals'];
    DealsModel? deals;
    if (cachedOffer?.deals != null) {
      deals = cachedOffer!.deals;
    } else if (dealsJson != null) {
      if (dealsJson is Map<String, dynamic>) {
        deals = DealsModel.fromJson(dealsJson);
      } else if (dealsJson is Map) {
        deals = DealsModel.fromJson(Map<String, dynamic>.from(dealsJson));
      }
    }

    // Prefer API activeDeal; fall back to deals flags with Hour > Day > Week > Month.
    final rawActiveDeal = widget.args['activeDeal'];
    Map<String, dynamic>? rawActiveDealMap;
    if (rawActiveDeal is Map<String, dynamic>) {
      rawActiveDealMap = rawActiveDeal;
    } else if (rawActiveDeal is Map) {
      rawActiveDealMap = Map<String, dynamic>.from(rawActiveDeal);
    }
    Map<String, dynamic>? rawDealsMap;
    if (dealsJson is Map<String, dynamic>) {
      rawDealsMap = dealsJson;
    } else if (dealsJson is Map) {
      rawDealsMap = Map<String, dynamic>.from(dealsJson);
    }
    final String? activeDealText = resolveActiveDealLabel(
      activeDeal: cachedOffer?.activeDeal,
      deals: deals,
      rawActiveDeal: rawActiveDealMap,
      rawDeals: rawDealsMap,
    );

    List<String> images = [];
    if (widget.args['images'] is List &&
        (widget.args['images'] as List).isNotEmpty) {
      images = (widget.args['images'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      images = [imageUrl];
    }

    final rawShopName =
        widget.args['shopName'] ??
        widget.args['partnerId']?['businessDetails']?['businessName'] ??
        '';
    final String effectiveShopName = rawShopName.isNotEmpty
        ? rawShopName
        : (fetchedShop?.businessDetails?.businessName ?? 'Partner Shop');

    final rawShopLogo =
        widget.args['shopLogo'] ??
        widget.args['partnerId']?['businessInfo']?['businessLogo'];
    final String? effectiveShopLogo =
        (rawShopLogo != null && rawShopLogo.isNotEmpty)
        ? rawShopLogo
        : (fetchedShop?.businessInfo?.businessLogo ??
              fetchedShop?.businessInfo?.coverImage);

    final rawAddress = [
      if (partnerIdObj is Map &&
          partnerIdObj['addressLine1'] != null &&
          partnerIdObj['addressLine1'].toString().isNotEmpty)
        partnerIdObj['addressLine1'].toString(),
      if (partnerIdObj is Map &&
          partnerIdObj['city'] != null &&
          partnerIdObj['city'].toString().isNotEmpty)
        partnerIdObj['city'].toString(),
    ].join(', ');
    final String effectiveShopAddress = rawAddress.isNotEmpty
        ? rawAddress
        : (fetchedShop?.businessDetails?.address ?? '');

    final IconData? icon = widget.args['icon'];
    final String? logoText = widget.args['logoText'];
    final Color? logoColor = widget.args['logoColor'];

    final priceRange =
        widget.args['priceRange'] ?? cachedOffer?.priceRange?.toJson();
    final discountRange =
        widget.args['discountRange'] ?? cachedOffer?.discountRange?.toJson();

    final branchApplicability = widget.args['branchApplicability'];
    final branchLocationsObj = widget.args['branchLocations'];
    final List branchLocations = branchLocationsObj is List
        ? branchLocationsObj
        : [];

    bool isAllBranches = false;
    List specificBranches = [];

    if (branchApplicability != null && branchApplicability is Map) {
      if (branchApplicability['type'] == 'all') {
        isAllBranches = true;
      } else if (branchApplicability['type'] == 'specific') {
        final branchIdsObj = branchApplicability['branchIds'];
        final List branchIds = branchIdsObj is List ? branchIdsObj : [];
        final List<String> stringBranchIds = branchIds
            .map((e) => e.toString())
            .toList();

        specificBranches = branchLocations.where((branch) {
          if (branch is! Map) return false;
          final String bId = branch['branchId']?.toString() ?? '';
          return stringBranchIds.contains(bId);
        }).toList();
      }
    }

    bool hasPriceRange =
        priceRange != null &&
        priceRange.toString() != 'null' &&
        (priceRange is Map
            ? priceRange.isNotEmpty
            : priceRange.toString().isNotEmpty);
    bool hasDiscountRange =
        discountRange != null &&
        discountRange.toString() != 'null' &&
        (discountRange is Map
            ? discountRange.isNotEmpty
            : discountRange.toString().isNotEmpty);

    String getPriceRangeText() {
      if (priceRange is Map) {
        final min = priceRange['min'] ?? 0;
        final max = priceRange['max'] ?? 0;
        final minStr = (min is num) ? min.toStringAsFixed(2) : min.toString();
        final maxStr = (max is num) ? max.toStringAsFixed(2) : max.toString();
        return '₹$minStr - ₹$maxStr';
      }
      if (priceRange is num) {
        return priceRange.toStringAsFixed(2);
      }
      return priceRange.toString();
    }

    String getDiscountRangeText() {
      final rawType = widget.args['discountType'];
      final discountType = rawType?.toString().toLowerCase();
      final isFlat =
          discountType == 'flat' ||
          discountType == 'amount' ||
          discountType == 'fixed';

      if (discountRange is Map) {
        final min = discountRange['min'] ?? 0;
        final max = discountRange['max'] ?? 0;
        final minStr = (min is num && min % 1 != 0)
            ? min.toStringAsFixed(1)
            : min.toString();
        final maxStr = (max is num && max % 1 != 0)
            ? max.toStringAsFixed(1)
            : max.toString();
        if (min == max) {
          return isFlat ? '₹$minStr OFF' : '$minStr% OFF';
        }
        return isFlat ? '₹$minStr - ₹$maxStr OFF' : '$minStr% - $maxStr% OFF';
      }
      if (discountRange is num) {
        final val = (discountRange % 1 != 0)
            ? discountRange.toStringAsFixed(1)
            : discountRange.toString();
        return isFlat ? '₹$val OFF' : '$val% OFF';
      }
      return discountRange.toString();
    }

    String? categoryName;
    final catObj = cachedOffer?.category?.name ?? widget.args['category'];
    if (catObj is String && catObj.isNotEmpty) {
      categoryName = catObj;
    } else if (catObj is Map && catObj['name'] != null) {
      categoryName = catObj['name'].toString();
    } else if (catObj is CategoryModel) {
      categoryName = catObj.name;
    }

    final List<String> subcategories = [];
    final rawSubs =
        widget.args['subcategories'] ??
        cachedOffer?.subcategories ??
        widget.args['subcategory'] ??
        cachedOffer?.subcategory ??
        widget.args['partnerId']?['serviceCategories'] ??
        cachedOffer?.partnerId?.serviceCategories;

    void addSubcategory(dynamic s) {
      if (s == null) return;
      if (s is String && s.trim().isNotEmpty && s != 'null') {
        final val = s.trim();
        if (!subcategories.contains(val)) subcategories.add(val);
      } else if (s is Map) {
        final name =
            s['name'] ?? s['category'] ?? s['title'] ?? s['subCategoryName'];
        if (name != null &&
            name.toString().trim().isNotEmpty &&
            name.toString() != 'null') {
          final val = name.toString().trim();
          if (!subcategories.contains(val)) subcategories.add(val);
        }
      }
    }

    if (rawSubs is List) {
      for (final s in rawSubs) {
        addSubcategory(s);
      }
    } else if (rawSubs is String && rawSubs.trim().isNotEmpty) {
      if (rawSubs.trim().startsWith('[')) {
        try {
          final decoded = json.decode(rawSubs);
          if (decoded is List) {
            for (final s in decoded) {
              addSubcategory(s);
            }
          }
        } catch (_) {
          addSubcategory(rawSubs);
        }
      } else {
        addSubcategory(rawSubs);
      }
    } else if (rawSubs is Map) {
      addSubcategory(rawSubs);
    }

    final floatingTagText =
        activeDealText ??
        categoryName ??
        (subcategories.isNotEmpty ? subcategories.first : null);

    final validFromStr =
        widget.args['validFrom'] ?? cachedOffer?.validFrom?.toString();
    final validFromDate = validFromStr != null
        ? DateTime.tryParse(validFromStr)?.toLocal()
        : null;

    final validToStr =
        widget.args['validTo'] ?? cachedOffer?.validTo?.toString();
    final validToDate = validToStr != null
        ? DateTime.tryParse(validToStr)?.toLocal()
        : null;

    final termsList = () {
      if (widget.args['terms'] is List) {
        return (widget.args['terms'] as List)
            .map((e) => e.toString())
            .where((t) => t.trim().isNotEmpty && t != 'null')
            .toList();
      }
      if (cachedOffer?.terms != null) {
        return cachedOffer!.terms!
            .where((t) => t.trim().isNotEmpty && t != 'null')
            .toList();
      }
      return <String>[];
    }();

    final String? offerTypeCode =
        (cachedOffer?.offerTypeCode ?? widget.args['offerTypeCode'])
            ?.toString();
    final String? offerTypeLabel = offerTypeCode != null
        ? (offerTypeLabels[offerTypeCode.toUpperCase()] ?? offerTypeCode)
        : null;

    Map<String, dynamic>? offerMetadata;
    final rawMeta = cachedOffer?.offerMetadata ?? widget.args['offerMetadata'];
    if (rawMeta is Map<String, dynamic>) {
      offerMetadata = rawMeta;
    } else if (rawMeta is Map) {
      offerMetadata = Map<String, dynamic>.from(rawMeta);
    }

    final String? discountType =
        (cachedOffer?.discountType ?? widget.args['discountType'])?.toString();
    final num? discountValue =
        cachedOffer?.discountValue ?? (widget.args['discountValue'] as num?);
    final num? originalPrice =
        cachedOffer?.originalPrice ?? (widget.args['originalPrice'] as num?);
    final num? offerPrice =
        cachedOffer?.offerPrice ?? (widget.args['offerPrice'] as num?);
    final num? pointsCost = cachedOffer?.pointsCost ?? (widget.args['pointsCost'] as num?);
    final num totalCostNum = (pointsCost != null && pointsCost > 0)
        ? pointsCost
        : ((offerPrice != null && offerPrice > 0)
            ? offerPrice
            : (originalPrice ?? 0));
    final int effectivePointsCost = totalCostNum.toInt();
    final num? distanceKm =
        cachedOffer?.distance ?? (widget.args['distance'] as num?);
    final bool isPremium =
        cachedOffer?.isPremium == true ||
        widget.args['isPremium'] == true ||
        widget.args['isPremium'] == 'true';

    String? requiredTierName;
    final rawTier = widget.args['requiredTier'] ?? cachedOffer?.requiredTier;
    if (rawTier is TierModel) {
      requiredTierName = rawTier.name;
    } else if (rawTier is Map) {
      requiredTierName =
          (rawTier['name'] ??
                  (rawTier['id'] is Map ? rawTier['id']['name'] : null))
              ?.toString();
    }

    Map<String, dynamic>? redemptionRulesMap;
    final rawRules =
        widget.args['redemptionRules'] ?? cachedOffer?.redemptionRules;
    if (rawRules is RedemptionRules) {
      redemptionRulesMap = rawRules.toJson();
    } else if (rawRules is Map<String, dynamic>) {
      redemptionRulesMap = rawRules;
    } else if (rawRules is Map) {
      redemptionRulesMap = Map<String, dynamic>.from(rawRules);
    }

    final List<String> tags = [];
    final rawTags = widget.args['tags'] ?? cachedOffer?.tags;
    if (rawTags is List) {
      for (final t in rawTags) {
        final s = t.toString().trim();
        if (s.isNotEmpty && s != 'null' && !tags.contains(s)) tags.add(s);
      }
    }

    String formatMoney(num? value) {
      if (value == null) return '';
      if (value % 1 == 0) return '₹${value.toInt()}';
      return '₹${value.toStringAsFixed(2)}';
    }

    String formatDiscountValue(num value) {
      final isFlat =
          discountType?.toLowerCase() == 'flat' ||
          discountType?.toLowerCase() == 'amount' ||
          discountType?.toLowerCase() == 'fixed';
      final val = (value % 1 != 0)
          ? value.toStringAsFixed(1)
          : value.toInt().toString();
      return isFlat ? '₹$val OFF' : '$val% OFF';
    }

    final List<MapEntry<String, String>> metadataRows = [];
    if (offerMetadata != null) {
      const labels = <String, String>{
        'buyQuantity': 'Buy Quantity',
        'getDescription': 'You Get',
        'nextPurchaseDiscount': 'Next Purchase Discount',
        'comboDescription': 'Combo Details',
        'minPurchaseLimit': 'Lucky Draw Min Purchase',
        'prizeDescription': 'Prize',
        'purchaseCount': 'Purchases Required',
        'freeItemDescription': 'Free Reward',
        'clearanceDiscount': 'Clearance Discount',
        'timeLimitedMessage': 'Limited-time Message',
        'couponCode': 'Coupon Code',
      };
      for (final entry in labels.entries) {
        final raw = offerMetadata[entry.key];
        if (raw == null) continue;
        final text = raw.toString().trim();
        if (text.isEmpty || text == 'null') continue;
        if (entry.key == 'nextPurchaseDiscount' ||
            entry.key == 'minPurchaseLimit') {
          final n = num.tryParse(text);
          metadataRows.add(
            MapEntry(entry.value, n != null ? formatMoney(n) : text),
          );
        } else {
          metadataRows.add(MapEntry(entry.value, text));
        }
      }
    }

    final List<MapEntry<IconData, MapEntry<String, String>>> highlightRows = [];
    if (offerTypeLabel != null && offerTypeLabel.isNotEmpty) {
      highlightRows.add(
        MapEntry(
          Icons.category_outlined,
          MapEntry('Offer Type', offerTypeLabel),
        ),
      );
    }
    if (isScratchCard) {
      highlightRows.add(
        MapEntry(
          Icons.confirmation_number_outlined,
          MapEntry(
            'Scratch Card',
            isScratched
                ? (awardedDiscount != null
                      ? 'Revealed — $awardedDiscount% OFF'
                      : 'Revealed')
                : 'Scratch to reveal your discount',
          ),
        ),
      );
    }
    if (isPremium) {
      highlightRows.add(
        MapEntry(Icons.workspace_premium_outlined, MapEntry('Featured', 'Premium offer')),
      );
    }
    if (hasPriceRange) {
      highlightRows.add(
        MapEntry(
          Icons.account_balance_wallet_rounded,
          MapEntry('Price Range', getPriceRangeText()),
        ),
      );
    }
    if (originalPrice != null && originalPrice > 0) {
      highlightRows.add(
        MapEntry(
          Icons.sell_outlined,
          MapEntry('Original Price', formatMoney(originalPrice)),
        ),
      );
    }
    if (offerPrice != null && offerPrice > 0) {
      highlightRows.add(
        MapEntry(
          Icons.local_atm_outlined,
          MapEntry('Offer Price', formatMoney(offerPrice)),
        ),
      );
    }
    if (hasDiscountRange) {
      highlightRows.add(
        MapEntry(
          Icons.local_offer_rounded,
          MapEntry('Discount', getDiscountRangeText()),
        ),
      );
    } else if (discountValue != null && discountValue > 0) {
      highlightRows.add(
        MapEntry(
          Icons.local_offer_rounded,
          MapEntry('Discount', formatDiscountValue(discountValue)),
        ),
      );
    }
    if (discountType != null &&
        discountType.trim().isNotEmpty &&
        discountType != 'null') {
      final pretty = discountType[0].toUpperCase() + discountType.substring(1);
      highlightRows.add(
        MapEntry(Icons.percent_rounded, MapEntry('Discount Type', pretty)),
      );
    }
    if (pointsCost != null && pointsCost > 0) {
      highlightRows.add(
        MapEntry(
          Icons.stars_rounded,
          MapEntry('Points Required', '${pointsCost.toInt()} pts'),
        ),
      );
    }
    if (distanceKm != null && distanceKm > 0) {
      highlightRows.add(
        MapEntry(
          Icons.near_me_outlined,
          MapEntry(
            'Distance',
            distanceKm >= 1
                ? '${distanceKm.toStringAsFixed(1)} km away'
                : '${(distanceKm * 1000).round()} m away',
          ),
        ),
      );
    }
    for (final row in metadataRows) {
      highlightRows.add(
        MapEntry(Icons.info_outline_rounded, MapEntry(row.key, row.value)),
      );
    }

    final List<MapEntry<IconData, MapEntry<String, String>>> eligibilityRows =
        [];
    if (requiredTierName != null &&
        requiredTierName.trim().isNotEmpty &&
        requiredTierName != 'null') {
      eligibilityRows.add(
        MapEntry(
          Icons.military_tech_outlined,
          MapEntry('Required Tier', '$requiredTierName or above'),
        ),
      );
    }
    if (redemptionRulesMap != null) {
      final minPurchase = redemptionRulesMap['minPurchaseAmount'];
      if (minPurchase is num && minPurchase > 0) {
        eligibilityRows.add(
          MapEntry(
            Icons.receipt_long_outlined,
            MapEntry('Min Purchase', formatMoney(minPurchase)),
          ),
        );
      }
      final maxPerUser = redemptionRulesMap['maxPerUser'];
      if (maxPerUser is num && maxPerUser > 0) {
        eligibilityRows.add(
          MapEntry(
            Icons.person_outline_rounded,
            MapEntry(
              'Max Per Customer',
              '${maxPerUser.toInt()} redemption${maxPerUser.toInt() == 1 ? '' : 's'}',
            ),
          ),
        );
      }
      final maxTotal = redemptionRulesMap['maxTotalRedemptions'];
      if (maxTotal is num && maxTotal > 0) {
        eligibilityRows.add(
          MapEntry(
            Icons.inventory_2_outlined,
            MapEntry(
              'Total Redemption Limit',
              '${maxTotal.toInt()} redemption${maxTotal.toInt() == 1 ? '' : 's'}',
            ),
          ),
        );
      }
      final days = redemptionRulesMap['applicableDays'];
      if (days is List && days.isNotEmpty) {
        final dayText = days
            .map((d) {
              final s = d.toString().trim();
              if (s.isEmpty) return s;
              return s[0].toUpperCase() + s.substring(1).toLowerCase();
            })
            .where((s) => s.isNotEmpty)
            .join(', ');
        if (dayText.isNotEmpty) {
          eligibilityRows.add(
            MapEntry(
              Icons.calendar_today_outlined,
              MapEntry('Valid On', dayText),
            ),
          );
        }
      }
      final slots = redemptionRulesMap['applicableTimeSlots'];
      if (slots is List && slots.isNotEmpty) {
        final slotText = slots
            .map((s) {
              if (s is Map) {
                final start = s['start'] ?? s['from'] ?? '';
                final end = s['end'] ?? s['to'] ?? '';
                if (start.toString().isNotEmpty && end.toString().isNotEmpty) {
                  return '$start – $end';
                }
              }
              return s.toString();
            })
            .where((s) => s.trim().isNotEmpty && s != 'null')
            .join(', ');
        if (slotText.isNotEmpty) {
          eligibilityRows.add(
            MapEntry(
              Icons.access_time_rounded,
              MapEntry('Valid Hours', slotText),
            ),
          );
        }
      }
    }

    final bool hasHighlights = highlightRows.isNotEmpty;
    final bool hasEligibility = eligibilityRows.isNotEmpty;
    final bool hasTags = tags.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F5F4),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: Color(0xFF373737),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Offer Details',
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
        actions: GlobalVariables.isPartner
            ? [
                Container(
                  height: 32,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CreateOfferPage(offer: widget.args),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kPrimaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(
                      'Edit',
                      style: kSmallTitleM.copyWith(color: kPrimaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 32,
                  width: 32,
                  margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                      size: 18,
                    ),
                    onPressed: () async {
                      final confirm = await showConfirmationDialog(
                        context: context,
                        title: 'Delete Offer',
                        message: 'Are you sure you want to delete this offer?',
                        confirmText: 'Delete',
                        isDestructive: true,
                        onConfirm: () async {
                          try {
                            await ref
                                .read(offersProvider.notifier)
                                .deleteOffer(
                                  widget.args['_id'] ?? widget.args['id'] ?? '',
                                );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Something went wrong'),
                                ),
                              );
                            }
                          }
                        },
                      );

                      if (confirm == true && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Image Banner
                  GestureDetector(
                    onTap: images.isNotEmpty
                        ? () => _openGallery(
                            images: images,
                            initialUrl: images.isNotEmpty
                                ? images[_currentImageIndex.clamp(
                                    0,
                                    images.length - 1,
                                  )]
                                : null,
                          )
                        : null,
                    child: Container(
                      width: double.infinity,
                      height: screenSize.responsivePadding(220),
                      color: const Color(0xFFE5E7EB),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (images.isNotEmpty)
                            CarouselSlider(
                              options: CarouselOptions(
                                height: screenSize.responsivePadding(220),
                                viewportFraction: 1.0,
                                enableInfiniteScroll: images.length > 1,
                                autoPlay: images.length > 1,
                                autoPlayInterval: const Duration(seconds: 4),
                                onPageChanged: (index, reason) {
                                  setState(() {
                                    _currentImageIndex = index;
                                  });
                                },
                              ),
                              items: images.map((img) {
                                return SizedBox(
                                  width: double.infinity,
                                  child: AdvancedNetworkImage(
                                    imageUrl: img,
                                    fit: BoxFit.cover,
                                    borderRadius: BorderRadius.zero,
                                    disableFade: true,
                                  ),
                                );
                              }).toList(),
                            )
                          else
                            Container(
                              color: const Color(0xFFE5E7EB),
                              alignment: Alignment.center,
                              child: icon != null
                                  ? Icon(icon, size: 64, color: kPrimaryColor)
                                  : (logoText != null && logoColor != null)
                                  ? Container(
                                      color: logoColor,
                                      alignment: Alignment.center,
                                      child: Text(
                                        logoText,
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          color: logoColor == Colors.white
                                              ? kTextColor
                                              : Colors.white,
                                          fontSize: 32,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.image_outlined,
                                      size: 48,
                                      color: Color(0xFF9CA3AF),
                                    ),
                            ),

                          // Floating Tag Pill (Top-Left)
                          if (floatingTagText != null &&
                              floatingTagText.isNotEmpty)
                            Positioned(
                              top: 12,
                              left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  floatingTagText,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF292929),
                                  ),
                                ),
                              ),
                            ),

                          // Carousel Dots Indicator (Bottom-Center)
                          if (images.length > 1)
                            Positioned(
                              bottom: 20,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: images.asMap().entries.map((entry) {
                                  final isActive =
                                      _currentImageIndex == entry.key;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    width: isActive ? 18.0 : 6.0,
                                    height: 6.0,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3.0,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3.0),
                                      color: isActive
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.5),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Shop + Offer header sheet (overlaps hero slightly)
                  Transform.translate(
                    offset: const Offset(0, -16),
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        screenSize.responsivePadding(20),
                        screenSize.responsivePadding(20),
                        screenSize.responsivePadding(20),
                        screenSize.responsivePadding(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Merchant / Shop Header Row
                          if (!(widget.args['hideShopInfo'] ?? false) &&
                              !isPartner) ...[
                            InkWell(
                              onTap: partnerId.isNotEmpty
                                  ? () => _navigateToShop(partnerId)
                                  : null,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                          width: 1.5,
                                        ),
                                        color: const Color(0xFFF3F4F6),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child:
                                          effectiveShopLogo != null &&
                                              effectiveShopLogo.isNotEmpty
                                          ? AdvancedNetworkImage(
                                              imageUrl: effectiveShopLogo,
                                              fit: BoxFit.cover,
                                            )
                                          : const Center(
                                              child: Icon(
                                                Icons.storefront,
                                                color: Color(0xFF6B7280),
                                                size: 22,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            effectiveShopName,
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              height: 1.25,
                                              color: const Color(0xFF111827),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (effectiveShopAddress
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.location_on_outlined,
                                                  size: 14,
                                                  color: Color(0xFF6B7280),
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    effectiveShopAddress,
                                                    style: TextStyle(
                                                      fontFamily: 'Poppins',
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                      height: 1.3,
                                                      color: const Color(
                                                        0xFF6B7280,
                                                      ),
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (partnerId.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      if (isNavigatingToShop)
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF6155F5),
                                                ),
                                          ),
                                        )
                                      else
                                        const Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 14,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFFF3F4F6),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Offer Title & Subtitle
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          if (subtitle.isNotEmpty &&
                              subtitle != 'null' &&
                              subtitle != 'nil') ...[
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                height: 1.45,
                                color: const Color(0xFF4B5563),
                              ),
                            ),
                          ],

                          // Category & Subcategories chips
                          if (subcategories.isNotEmpty ||
                              (categoryName != null &&
                                  categoryName.isNotEmpty)) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (categoryName != null &&
                                    categoryName.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      categoryName,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: const Color(0xFF6155F5),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ...subcategories.map(
                                  (sub) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Text(
                                      sub,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: const Color(0xFF374151),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Scratch Card Revealed Banner
                          if (isScratchCard &&
                              isScratched &&
                              awardedDiscount != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDEF7EC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF31C48D),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.celebration,
                                    color: Color(0xFF03543F),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Scratch card revealed! You got $awardedDiscount% OFF.',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: const Color(0xFF03543F),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Pull following sections up to cancel Transform.translate gap
                  Transform.translate(
                    offset: const Offset(0, -16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [


                        // Separator Band
                        const SizedBox(
                          width: double.infinity,
                          height: 8,
                          child: ColoredBox(color: Color(0xFFF3F5F4)),
                        ),

                        // Details & Terms
                        Container(
                          width: double.infinity,
                          color: Colors.white,
                          padding: EdgeInsets.fromLTRB(
                            screenSize.responsivePadding(20),
                            screenSize.responsivePadding(20),
                            screenSize.responsivePadding(20),
                            screenSize.responsivePadding(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Details & Terms',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                  color: const Color(0xFF1C1C1C),
                                ),
                              ),
                              if (validFromDate != null) ...[
                                const SizedBox(height: 14),
                                Text(
                                  'Valid from: ${formatOfferDate(validFromDate)}',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                    color: const Color(0xFF1C1C1C),
                                  ),
                                ),
                              ],
                              if (validToDate != null) ...[
                                SizedBox(height: validFromDate != null ? 8 : 14),
                                Text(
                                  'Expires on: ${formatOfferDate(validToDate)}',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                    color: const Color(0xFF1C1C1C),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              if (termsList.isNotEmpty)
                                ...termsList.map(
                                  (term) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _buildBulletPoint(term),
                                  ),
                                )
                              else if (subtitle.isNotEmpty &&
                                  subtitle != 'null')
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFF4E4E4E),
                                    height: 1.55,
                                  ),
                                )
                              else
                                Text(
                                  'No specific terms provided.',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFF4E4E4E),
                                    height: 1.4,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Available At / Branch Locations
                        if (isAllBranches || specificBranches.isNotEmpty) ...[
                          const SizedBox(
                            width: double.infinity,
                            height: 8,
                            child: ColoredBox(color: Color(0xFFF3F5F4)),
                          ),
                          Container(
                            width: double.infinity,
                            color: Colors.white,
                            padding: EdgeInsets.fromLTRB(
                              screenSize.responsivePadding(20),
                              screenSize.responsivePadding(20),
                              screenSize.responsivePadding(20),
                              screenSize.responsivePadding(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF6155F5,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.storefront_rounded,
                                        color: Color(0xFF6155F5),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Available At',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: const Color(0xFF6155F5),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (isAllBranches)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.check_circle_outline,
                                          size: 18,
                                          color: Colors.green,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Available on all branches',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            color: const Color(0xFF374151),
                                            fontSize: 13,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  ...specificBranches.asMap().entries.map((
                                    entry,
                                  ) {
                                    final index = entry.key;
                                    final branch = entry.value;
                                    final isLast =
                                        index == specificBranches.length - 1;
                                    final branchName =
                                        branch['branchName']?.toString() ??
                                        'Branch';
                                    final address =
                                        branch['address']?.toString() ?? '';
                                    final city =
                                        branch['city']?.toString() ?? '';
                                    final locationDetails = [address, city]
                                        .where((e) => e.trim().isNotEmpty)
                                        .join(', ');
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        bottom: isLast ? 0 : 14,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF6155F5,
                                              ).withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.location_on_outlined,
                                              size: 18,
                                              color: Color(0xFF6155F5),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  branchName,
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    color: const Color(
                                                      0xFF111827,
                                                    ),
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                    height: 1.3,
                                                  ),
                                                ),
                                                if (locationDetails
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    locationDetails,
                                                    style: TextStyle(
                                                      fontFamily: 'Poppins',
                                                      color: const Color(
                                                        0xFF6B7280,
                                                      ),
                                                      fontSize: 12,
                                                      height: 1.35,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ],

                        // Offer Highlights
                        if (hasHighlights) ...[
                          const SizedBox(
                            width: double.infinity,
                            height: 8,
                            child: ColoredBox(color: Color(0xFFF3F5F4)),
                          ),
                          Container(
                            width: double.infinity,
                            color: Colors.white,
                            padding: EdgeInsets.fromLTRB(
                              screenSize.responsivePadding(20),
                              screenSize.responsivePadding(20),
                              screenSize.responsivePadding(20),
                              screenSize.responsivePadding(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF6155F5,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.star_rounded,
                                        color: Color(0xFF6155F5),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Offer Highlights',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: const Color(0xFF6155F5),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ...highlightRows.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final row = entry.value;
                                  final color = index % 2 == 0
                                      ? Colors.blue.shade600
                                      : Colors.green.shade600;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: index == highlightRows.length - 1
                                          ? 0
                                          : 12,
                                    ),
                                    child: _buildHighlightRow(
                                      row.key,
                                      row.value.key,
                                      row.value.value,
                                      color,
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],

                        // Eligibility & Redemption Rules
                        if (hasEligibility) ...[
                          const SizedBox(
                            width: double.infinity,
                            height: 8,
                            child: ColoredBox(color: Color(0xFFF3F5F4)),
                          ),
                          Container(
                            width: double.infinity,
                            color: Colors.white,
                            padding: EdgeInsets.fromLTRB(
                              screenSize.responsivePadding(20),
                              screenSize.responsivePadding(20),
                              screenSize.responsivePadding(20),
                              screenSize.responsivePadding(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF6155F5,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.rule_rounded,
                                        color: Color(0xFF6155F5),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Eligibility & Rules',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: const Color(0xFF6155F5),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ...eligibilityRows.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final row = entry.value;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom:
                                          index == eligibilityRows.length - 1
                                          ? 0
                                          : 12,
                                    ),
                                    child: _buildHighlightRow(
                                      row.key,
                                      row.value.key,
                                      row.value.value,
                                      const Color(0xFF6155F5),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],

                        // Tags
                        if (hasTags) ...[
                          const SizedBox(
                            width: double.infinity,
                            height: 8,
                            child: ColoredBox(color: Color(0xFFF3F5F4)),
                          ),
                          Container(
                            width: double.infinity,
                            color: Colors.white,
                            padding: EdgeInsets.fromLTRB(
                              screenSize.responsivePadding(20),
                              screenSize.responsivePadding(20),
                              screenSize.responsivePadding(20),
                              screenSize.responsivePadding(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF6155F5,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.sell_outlined,
                                        color: Color(0xFF6155F5),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Tags',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: const Color(0xFF6155F5),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: tags
                                      .map(
                                        (tag) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3F4F6),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE5E7EB),
                                            ),
                                          ),
                                          child: Text(
                                            tag,
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              color: const Color(0xFF374151),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (isPartner) ...[
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Status: ',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: const Color(0xFF6B7280),
                                  fontSize: 13,
                                ),
                              ),
                              _buildStatusChip(offerStatus),
                            ],
                          ),
                        ],

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Bar CTA
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              screenSize.responsivePadding(16),
              12,
              screenSize.responsivePadding(16),
              MediaQuery.of(context).padding.bottom > 0
                  ? MediaQuery.of(context).padding.bottom + 8
                  : 16,
            ),
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (isPartner && !isOfferActive) || isRedeeming
                    ? null
                    : () {
                        if (GlobalVariables.isGuest) {
                          GuestLoginDialog.show(
                            context,
                            title: 'Login Required',
                            subtitle:
                                'Please login or register to claim offers.',
                          );
                          return;
                        }

                        final offerDetails = {
                          ...widget.args,
                          'title': title,
                          'subtitle': subtitle,
                          'imageUrl': imageUrl,
                          'id': widget.args['id'] ?? widget.args['_id'],
                          'pointsCost': effectivePointsCost,
                          'offerPrice': offerPrice,
                          'originalPrice': originalPrice,
                        };
                        if (isPartner) {
                          Navigator.of(context).pushNamed(
                            'partnerRedemption',
                            arguments: offerDetails,
                          );
                        } else {
                          if (isScratchCard && !isScratched) {
                            Navigator.of(context)
                                .pushNamed(
                                  'scratchCard',
                                  arguments: offerDetails,
                                )
                                .then((_) {
                                  if (mounted) setState(() {});
                                });
                          } else {
                            Navigator.of(context).pushNamed(
                              'redemptionInstructions',
                              arguments: offerDetails,
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6155F5),
                  disabledBackgroundColor: const Color(
                    0xFF6155F5,
                  ).withValues(alpha: 0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isRedeeming
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        isPartner
                        ? 'Initiate Redemption'
                        : 'Redeem Offer',
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
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7, right: 10),
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Color(0xFF6B7280),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF4E4E4E),
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;
    String displayStatus = status.replaceAll('_', ' ').toUpperCase();

    switch (status.toLowerCase()) {
      case 'active':
        bgColor = const Color(0xFFDEF7EC);
        textColor = const Color(0xFF03543F);
        break;
      case 'pending_approval':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF92400E);
        break;
      case 'paused':
        bgColor = const Color(0xFFE5E7EB);
        textColor = const Color(0xFF374151);
        break;
      case 'expired':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        break;
      case 'rejected':
        bgColor = const Color(0xFFFDE8E8);
        textColor = const Color(0xFF9B1C1C);
        break;
      case 'draft':
      default:
        bgColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF4B5563);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          fontFamily: 'Poppins',
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildHighlightRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  height: 1.3,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

}
