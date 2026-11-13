import 'package:setgo/src/utils/safe_parser.dart';

class PartnerInquiryCustomer {
  final String? name;
  final String? phone;
  final String? avatar;

  const PartnerInquiryCustomer({this.name, this.phone, this.avatar});

  factory PartnerInquiryCustomer.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PartnerInquiryCustomer();
    return PartnerInquiryCustomer(
      name: SafeParser.pick(json, ['name', 'fullName'])?.toString(),
      phone: SafeParser.pick(json, ['phone', 'mobile', 'phoneNumber'])
          ?.toString(),
      avatar: SafeParser.pick(json, ['avatar', 'image', 'profileImage'])
          ?.toString(),
    );
  }
}

class PartnerInquiryItem {
  final String? id;
  final String title;
  final int quantity;
  final double? price;
  final double? effectivePrice;
  final String? image;
  final String? type;

  const PartnerInquiryItem({
    this.id,
    required this.title,
    this.quantity = 1,
    this.price,
    this.effectivePrice,
    this.image,
    this.type,
  });

  factory PartnerInquiryItem.fromJson(Map<String, dynamic> json) {
    final qtyRaw = SafeParser.pick(json, ['quantity', 'qty']);
    final qty = qtyRaw is num
        ? qtyRaw.toInt()
        : int.tryParse(qtyRaw?.toString() ?? '') ?? 1;

    double? asDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return PartnerInquiryItem(
      id: SafeParser.pick(json, ['_id', 'id', 'productId', 'serviceId'])
          ?.toString(),
      title:
          (SafeParser.pick(json, ['title', 'name', 'productName', 'serviceName'])
                  ?.toString() ??
              'Item')
              .trim(),
      quantity: qty < 1 ? 1 : qty,
      price: asDouble(SafeParser.pick(json, ['price', 'originalPrice', 'mrp'])),
      effectivePrice: asDouble(
        SafeParser.pick(json, [
          'effectivePrice',
          'salePrice',
          'offerPrice',
          'finalPrice',
        ]),
      ),
      image: SafeParser.pick(json, [
        'image',
        'imageUrl',
        'thumbnail',
        'photo',
      ])?.toString(),
      type: SafeParser.pick(json, ['type', 'itemType'])?.toString(),
    );
  }
}

class PartnerInquiryModel {
  final String id;
  final PartnerInquiryCustomer customer;
  final List<PartnerInquiryItem> items;
  final int totalQuantity;
  final double subtotal;
  final String inquiryStatus;
  final DateTime? lastInquirySentAt;
  final DateTime? createdAt;

  const PartnerInquiryModel({
    required this.id,
    this.customer = const PartnerInquiryCustomer(),
    this.items = const [],
    this.totalQuantity = 0,
    this.subtotal = 0,
    this.inquiryStatus = 'pending',
    this.lastInquirySentAt,
    this.createdAt,
  });

  PartnerInquiryModel copyWith({
    String? id,
    PartnerInquiryCustomer? customer,
    List<PartnerInquiryItem>? items,
    int? totalQuantity,
    double? subtotal,
    String? inquiryStatus,
    DateTime? lastInquirySentAt,
    DateTime? createdAt,
  }) {
    return PartnerInquiryModel(
      id: id ?? this.id,
      customer: customer ?? this.customer,
      items: items ?? this.items,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      subtotal: subtotal ?? this.subtotal,
      inquiryStatus: inquiryStatus ?? this.inquiryStatus,
      lastInquirySentAt: lastInquirySentAt ?? this.lastInquirySentAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  int get itemCount => items.length;

  factory PartnerInquiryModel.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    int asInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    final customerMap = SafeParser.asMap(
      SafeParser.pick(json, ['customer', 'user', 'customerDetails']),
    );

    final rawItems = SafeParser.pick(json, ['items', 'products', 'services']);
    final items =
        SafeParser.parseList(rawItems, PartnerInquiryItem.fromJson) ??
            const <PartnerInquiryItem>[];

    final computedQty = items.fold<int>(0, (sum, i) => sum + i.quantity);
    final computedSubtotal = items.fold<double>(0, (sum, i) {
      final unit = i.effectivePrice ?? i.price ?? 0;
      return sum + (unit * i.quantity);
    });

    final totalQty = asInt(
      SafeParser.pick(json, ['totalQuantity', 'totalQty', 'quantity']),
    );
    final subtotal = asDouble(
      SafeParser.pick(json, ['subtotal', 'total', 'totalAmount', 'amount']),
    );

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    return PartnerInquiryModel(
      id: (SafeParser.pick(json, ['_id', 'id', 'inquiryId', 'cartId'])
                  ?.toString() ??
              '')
          .trim(),
      customer: PartnerInquiryCustomer.fromJson(customerMap),
      items: items,
      totalQuantity: totalQty > 0 ? totalQty : computedQty,
      subtotal: subtotal > 0 ? subtotal : computedSubtotal,
      inquiryStatus:
          (SafeParser.pick(json, [
                    'inquiryStatus',
                    'status',
                  ])?.toString() ??
                  'pending')
              .trim()
              .toLowerCase(),
      lastInquirySentAt: parseDate(
        SafeParser.pick(json, [
          'lastInquirySentAt',
          'sentAt',
          'inquiredAt',
          'updatedAt',
        ]),
      ),
      createdAt: parseDate(
        SafeParser.pick(json, ['createdAt', 'created_at']),
      ),
    );
  }
}
