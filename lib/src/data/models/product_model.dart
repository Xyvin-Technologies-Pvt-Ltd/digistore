import 'package:setgo/src/utils/safe_parser.dart';

class ProductCategory {
  final String? id;
  final String? category;
  final String? subcategory;
  final List<String>? subcategories;
  final String? iconUrl;

  const ProductCategory({
    this.id,
    this.category,
    this.subcategory,
    this.subcategories,
    this.iconUrl,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    final subs = json['subcategories'] is List
        ? (json['subcategories'] as List)
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];
    final single = json['subcategory']?.toString();
    return ProductCategory(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      category: json['category'] as String?,
      subcategory: (single != null && single.isNotEmpty)
          ? single
          : (subs.isNotEmpty ? subs.first : null),
      subcategories: subs.isNotEmpty ? subs : null,
      iconUrl: json['iconUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'category': category,
      'subcategory': subcategory,
      'subcategories': subcategories,
      'iconUrl': iconUrl,
    };
  }
}

class ProductSpec {
  final String key;
  final String value;

  const ProductSpec({required this.key, required this.value});

  factory ProductSpec.fromJson(Map<String, dynamic> json) {
    return ProductSpec(
      key: json['key']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'key': key, 'value': value};
}

class ProductVariantAttribute {
  final String name;
  final String value;

  const ProductVariantAttribute({required this.name, required this.value});

  factory ProductVariantAttribute.fromJson(Map<String, dynamic> json) {
    return ProductVariantAttribute(
      name: json['name']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'value': value};
}

class ProductVariant {
  final String? id;
  final String? name;
  final String? sku;
  final double? price;
  final double? offerPrice;
  final bool inStock;
  final List<ProductVariantAttribute> attributes;

  const ProductVariant({
    this.id,
    this.name,
    this.sku,
    this.price,
    this.offerPrice,
    this.inStock = true,
    this.attributes = const [],
  });

  double get effectivePrice {
    if (offerPrice != null &&
        offerPrice! > 0 &&
        offerPrice! < (price ?? double.infinity)) {
      return offerPrice!;
    }
    return price ?? 0;
  }

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] is List
        ? (json['attributes'] as List)
              .whereType<Map>()
              .map(
                (e) => ProductVariantAttribute.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
        : <ProductVariantAttribute>[];
    return ProductVariant(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      name: json['name']?.toString(),
      sku: json['sku']?.toString(),
      price: (json['price'] as num?)?.toDouble(),
      offerPrice: (json['offerPrice'] as num?)?.toDouble(),
      inStock: json['inStock'] as bool? ?? true,
      attributes: attrs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'sku': sku,
      'price': price,
      'offerPrice': offerPrice,
      'inStock': inStock,
      'attributes': attributes.map((e) => e.toJson()).toList(),
    };
  }
}

// ── Top-level formatting helpers (Notion Section 4) ──────────────────────────

/// 1. Format Regular Price Range
String getPriceRangeText(num price, num? maxPrice) {
  if (maxPrice != null && maxPrice > price) {
    return '₹${price.toInt()} - ₹${maxPrice.toInt()}';
  }
  return '₹${price.toInt()}';
}

/// 2. Format Discounted Offer Range
String? getOfferRangeText(bool hasOffer, num? offerPrice, num? maxOfferPrice) {
  if (!hasOffer || offerPrice == null) return null;
  if (maxOfferPrice != null && maxOfferPrice > offerPrice) {
    return '₹${offerPrice.toInt()} - ₹${maxOfferPrice.toInt()}';
  }
  return '₹${offerPrice.toInt()}';
}

/// 3. Discount Badge Label
String? getDiscountBadge(Map<String, dynamic> product) {
  if (product['hasOffer'] != true && product['hasOffer'] != 'true') return null;

  final offerType = product['offerType']?.toString().toLowerCase();
  if (offerType == 'percentage') {
    final num val = (product['offerValue'] as num?) ??
        num.tryParse(product['offerValue']?.toString() ?? '') ??
        0;
    final num? maxVal = (product['maxOfferValue'] as num?) ??
        num.tryParse(product['maxOfferValue']?.toString() ?? '');
    if (maxVal != null && maxVal > val) {
      final valStr = val % 1 == 0 ? val.toInt().toString() : val.toString();
      final maxValStr =
          maxVal % 1 == 0 ? maxVal.toInt().toString() : maxVal.toString();
      return '$valStr% -$maxValStr% OFF';
    }
    final valStr = val % 1 == 0 ? val.toInt().toString() : val.toString();
    return '$valStr% OFF';
  }

  final dynamic rawVal = product['offerValue'];
  final valStr = rawVal is num
      ? (rawVal % 1 == 0 ? rawVal.toInt().toString() : rawVal.toString())
      : rawVal?.toString();
  if (valStr != null && valStr.isNotEmpty) {
    return 'Flat ₹$valStr OFF';
  }
  return 'Offer';
}

class ProductModel {
  final String? id;
  final String? partnerId;
  final String? title;
  final String? description;
  final List<String>? images;
  final double? price;
  final double? maxPrice;
  final bool hasOffer;
  final String? offerType;
  final double? offerValue;
  final double? maxOfferValue;
  final double? offerPrice;
  final double? maxOfferPrice;
  final String? priceDisplay;
  final String? offerPriceDisplay;
  final double? effectivePrice;
  final double? effectiveMaxPrice;
  final bool inStock;
  final String? sku;
  final String? brand;
  final String? unit;
  final String? weight;
  final List<ProductSpec> specifications;
  final bool hasVariants;
  final List<ProductVariant> variants;
  final ProductCategory? category;
  final List<String>? tags;
  final bool? isActive;
  final int views;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? partnerObj;
  final List<dynamic>? branchLocations;
  final bool? isFavorited;

  const ProductModel({
    this.id,
    this.partnerId,
    this.title,
    this.description,
    this.images,
    this.price,
    this.maxPrice,
    this.hasOffer = false,
    this.offerType,
    this.offerValue,
    this.maxOfferValue,
    this.offerPrice,
    this.maxOfferPrice,
    this.priceDisplay,
    this.offerPriceDisplay,
    this.effectivePrice,
    this.effectiveMaxPrice,
    this.inStock = true,
    this.sku,
    this.brand,
    this.unit,
    this.weight,
    this.specifications = const [],
    this.hasVariants = false,
    this.variants = const [],
    this.category,
    this.tags,
    this.isActive,
    this.views = 0,
    this.createdAt,
    this.updatedAt,
    this.partnerObj,
    this.branchLocations,
    this.isFavorited,
  });

  /// True if the product defines a regular price range (maxPrice > price).
  bool get hasPriceRange =>
      maxPrice != null && price != null && maxPrice! > price!;

  /// True if the product defines a discounted offer range (maxOfferPrice > offerPrice).
  bool get hasOfferRange =>
      hasOffer &&
      maxOfferPrice != null &&
      offerPrice != null &&
      maxOfferPrice! > offerPrice!;

  /// Regular price display string e.g. "₹500 - ₹1,000" or "₹500".
  String get priceRangeText {
    if (priceDisplay != null && priceDisplay!.trim().isNotEmpty) {
      return priceDisplay!;
    }
    return getPriceRangeText(price ?? 0, maxPrice);
  }

  /// Discounted offer price display string e.g. "₹400 - ₹700" or "₹400".
  String? get offerRangeText {
    if (offerPriceDisplay != null && offerPriceDisplay!.trim().isNotEmpty) {
      return offerPriceDisplay!;
    }
    return getOfferRangeText(hasOffer, offerPrice, maxOfferPrice);
  }

  /// Discount badge label e.g. "10% - 20% OFF", "20% OFF", or "Flat ₹100 OFF".
  String? get discountBadge {
    if (!hasOffer) return null;
    return getDiscountBadge({
      'hasOffer': hasOffer,
      'offerType': offerType,
      'offerValue': offerValue,
      'maxOfferValue': maxOfferValue,
    });
  }

  /// Single primary display price string following Notion UI logic:
  /// Active price (offer range or regular range).
  String get displayPriceText {
    if (hasOffer && offerRangeText != null) {
      return offerRangeText!;
    }
    return priceRangeText;
  }

  /// Best numeric display price: effectivePrice → offerPrice → price.
  double? get displayPrice {
    if (effectivePrice != null && effectivePrice! > 0) return effectivePrice;
    if (hasOffer && offerPrice != null && offerPrice! > 0) return offerPrice;
    return price;
  }

  bool get showStrikeThrough {
    if (!hasOffer) return false;
    if (offerRangeText != null &&
        offerRangeText!.isNotEmpty &&
        offerRangeText != priceRangeText) {
      return true;
    }
    final base = price ?? 0;
    final sale = displayPrice ?? 0;
    return base > 0 && sale > 0 && sale < base;
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final specs = json['specifications'] is List
        ? (json['specifications'] as List)
              .whereType<Map>()
              .map((e) => ProductSpec.fromJson(Map<String, dynamic>.from(e)))
              .where((s) => s.key.isNotEmpty || s.value.isNotEmpty)
              .toList()
        : <ProductSpec>[];

    final variants = json['variants'] is List
        ? (json['variants'] as List)
              .whereType<Map>()
              .map((e) => ProductVariant.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <ProductVariant>[];

    final views =
        (json['viewCount'] as num?)?.toInt() ??
        (json['views'] as num?)?.toInt() ??
        0;

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return ProductModel(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      partnerId: json['partnerId'] is Map
          ? (json['partnerId']['_id']?.toString() ??
                json['partnerId']['id']?.toString())
          : json['partnerId']?.toString(),
      title: json['title'] as String? ?? json['name'] as String?,
      description: json['description'] as String?,
      images: json['images'] != null
          ? List<String>.from((json['images'] as List).map((e) => e.toString()))
          : null,
      price: parseDouble(json['price']),
      maxPrice: parseDouble(json['maxPrice']),
      hasOffer: json['hasOffer'] as bool? ?? false,
      offerType: json['offerType']?.toString(),
      offerValue: parseDouble(json['offerValue']),
      maxOfferValue: parseDouble(json['maxOfferValue']),
      offerPrice: parseDouble(json['offerPrice']),
      maxOfferPrice: parseDouble(json['maxOfferPrice']),
      priceDisplay: json['priceDisplay']?.toString(),
      offerPriceDisplay: json['offerPriceDisplay']?.toString(),
      effectivePrice: parseDouble(json['effectivePrice']),
      effectiveMaxPrice: parseDouble(json['effectiveMaxPrice']),
      inStock: json['inStock'] as bool? ?? true,
      sku: json['sku']?.toString(),
      brand: json['brand']?.toString(),
      unit: json['unit']?.toString(),
      weight: json['weight']?.toString(),
      specifications: specs,
      hasVariants: json['hasVariants'] as bool? ?? variants.isNotEmpty,
      variants: variants,
      category: json['category'] is String
          ? ProductCategory(id: json['category'] as String)
          : SafeParser.parseObject(json['category'], ProductCategory.fromJson),
      tags: json['tags'] != null
          ? List<String>.from((json['tags'] as List).map((e) => e.toString()))
          : null,
      isActive: json['isActive'] as bool?,
      views: views,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())?.toLocal()
          : null,
      partnerObj: json['partner'] is Map
          ? Map<String, dynamic>.from(json['partner'] as Map)
          : json['partnerId'] is Map
          ? Map<String, dynamic>.from(json['partnerId'] as Map)
          : null,
      branchLocations: json['branchLocations'] as List<dynamic>?,
      isFavorited: json['isFavorited'] as bool? ?? json['isFavorite'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'partnerId': partnerObj ?? partnerId,
      'title': title,
      'description': description,
      'images': images,
      'price': price,
      'maxPrice': maxPrice,
      'hasOffer': hasOffer,
      'offerType': offerType,
      'offerValue': offerValue,
      'maxOfferValue': maxOfferValue,
      'offerPrice': offerPrice,
      'maxOfferPrice': maxOfferPrice,
      'priceDisplay': priceDisplay ?? priceRangeText,
      'offerPriceDisplay': offerPriceDisplay ?? offerRangeText,
      'effectivePrice': effectivePrice,
      'effectiveMaxPrice': effectiveMaxPrice,
      'inStock': inStock,
      'sku': sku,
      'brand': brand,
      'unit': unit,
      'weight': weight,
      'specifications': specifications.map((e) => e.toJson()).toList(),
      'hasVariants': hasVariants,
      'variants': variants.map((e) => e.toJson()).toList(),
      'category': category?.toJson(),
      'tags': tags,
      'isActive': isActive,
      'views': views,
      'viewCount': views,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'partner': partnerObj,
      'branchLocations': branchLocations,
      'isFavorited': isFavorited,
      'isFavorite': isFavorited,
    };
  }

  ProductModel copyWith({
    String? id,
    String? partnerId,
    String? title,
    String? description,
    List<String>? images,
    double? price,
    double? maxPrice,
    bool? hasOffer,
    String? offerType,
    double? offerValue,
    double? maxOfferValue,
    double? offerPrice,
    double? maxOfferPrice,
    String? priceDisplay,
    String? offerPriceDisplay,
    double? effectivePrice,
    double? effectiveMaxPrice,
    bool? inStock,
    String? sku,
    String? brand,
    String? unit,
    String? weight,
    List<ProductSpec>? specifications,
    bool? hasVariants,
    List<ProductVariant>? variants,
    ProductCategory? category,
    List<String>? tags,
    bool? isActive,
    int? views,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? partnerObj,
    List<dynamic>? branchLocations,
    bool? isFavorited,
  }) {
    return ProductModel(
      id: id ?? this.id,
      partnerId: partnerId ?? this.partnerId,
      title: title ?? this.title,
      description: description ?? this.description,
      images: images ?? this.images,
      price: price ?? this.price,
      maxPrice: maxPrice ?? this.maxPrice,
      hasOffer: hasOffer ?? this.hasOffer,
      offerType: offerType ?? this.offerType,
      offerValue: offerValue ?? this.offerValue,
      maxOfferValue: maxOfferValue ?? this.maxOfferValue,
      offerPrice: offerPrice ?? this.offerPrice,
      maxOfferPrice: maxOfferPrice ?? this.maxOfferPrice,
      priceDisplay: priceDisplay ?? this.priceDisplay,
      offerPriceDisplay: offerPriceDisplay ?? this.offerPriceDisplay,
      effectivePrice: effectivePrice ?? this.effectivePrice,
      effectiveMaxPrice: effectiveMaxPrice ?? this.effectiveMaxPrice,
      inStock: inStock ?? this.inStock,
      sku: sku ?? this.sku,
      brand: brand ?? this.brand,
      unit: unit ?? this.unit,
      weight: weight ?? this.weight,
      specifications: specifications ?? this.specifications,
      hasVariants: hasVariants ?? this.hasVariants,
      variants: variants ?? this.variants,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      isActive: isActive ?? this.isActive,
      views: views ?? this.views,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      partnerObj: partnerObj ?? this.partnerObj,
      branchLocations: branchLocations ?? this.branchLocations,
      isFavorited: isFavorited ?? this.isFavorited,
    );
  }
}

class PaginationModel {
  final int page;
  final int limit;
  final int total;
  final int pages;

  const PaginationModel({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory PaginationModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    final page = parseInt(json['page'], 1);
    final limit = parseInt(json['limit'], 20);
    final total = parseInt(json['total'] ?? json['count'], 0);
    final pages = parseInt(
      json['pages'] ?? json['totalPages'] ?? json['total_pages'],
      // Infer at least one more page when total clearly exceeds this page.
      total > 0 && limit > 0 ? (total / limit).ceil() : 1,
    );

    return PaginationModel(
      page: page < 1 ? 1 : page,
      limit: limit < 1 ? 20 : limit,
      total: total,
      pages: pages < 1 ? 1 : pages,
    );
  }

  PaginationModel copyWith({int? page, int? limit, int? total, int? pages}) {
    return PaginationModel(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      total: total ?? this.total,
      pages: pages ?? this.pages,
    );
  }
}

class ProductResponse {
  final bool success;
  final List<ProductModel> data;
  final PaginationModel? pagination;

  const ProductResponse({
    required this.success,
    required this.data,
    this.pagination,
  });

  factory ProductResponse.fromJson(Map<String, dynamic> json) {
    return ProductResponse(
      success: json['success'] as bool? ?? false,
      data: SafeParser.parseList(json['data'], ProductModel.fromJson) ?? [],
      pagination: SafeParser.parseObject(
        json['pagination'],
        PaginationModel.fromJson,
      ),
    );
  }
}
