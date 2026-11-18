class SpinSegment {
  final int index;
  final String label;
  final String rewardType;
  final double value;
  final bool isGrandPrize;
  final String? color;
  final String? icon;
  final int? limit;
  final int claimedCount;
  final bool isExhausted;
  final String? voucherCampaignId;
  final String? offerId;

  const SpinSegment({
    required this.index,
    required this.label,
    required this.rewardType,
    required this.value,
    this.isGrandPrize = false,
    this.color,
    this.icon,
    this.limit,
    this.claimedCount = 0,
    this.isExhausted = false,
    this.voucherCampaignId,
    this.offerId,
  });

  factory SpinSegment.fromJson(Map<String, dynamic> json) {
    return SpinSegment(
      index: _asInt(json['index']),
      label: (json['label'] ?? json['title'] ?? '').toString(),
      rewardType: (json['rewardType'] ?? 'flat_voucher').toString(),
      value: _asDouble(json['value']),
      isGrandPrize: json['isGrandPrize'] == true,
      color: json['color']?.toString(),
      icon: json['icon']?.toString(),
      limit: json['limit'] == null ? null : _asInt(json['limit']),
      claimedCount: _asInt(json['claimedCount']),
      isExhausted: json['isExhausted'] == true,
      voucherCampaignId: json['voucherCampaignId']?.toString(),
      offerId: json['offerId']?.toString(),
    );
  }
}

class SpinStatus {
  final bool hasSpinAvailable;
  final String? campaignId;
  final String? campaignTitle;
  final String? icon;
  final double? grandPrizeAmount;
  final List<String> applicableCategories;
  final List<String> applicablePartners;
  final List<SpinSegment> segments;
  final bool alreadySpun;
  final String? reason;
  final String? transactionId;

  const SpinStatus({
    required this.hasSpinAvailable,
    this.campaignId,
    this.campaignTitle,
    this.icon,
    this.grandPrizeAmount,
    this.applicableCategories = const [],
    this.applicablePartners = const [],
    this.segments = const [],
    this.alreadySpun = false,
    this.reason,
    this.transactionId,
  });

  const SpinStatus.unavailable({this.reason, this.alreadySpun = false})
    : hasSpinAvailable = false,
      campaignId = null,
      campaignTitle = null,
      icon = null,
      grandPrizeAmount = null,
      applicableCategories = const [],
      applicablePartners = const [],
      segments = const [],
      transactionId = null;

  factory SpinStatus.fromJson(Map<String, dynamic> json) {
    final rawSegments = json['segments'];
    final segments = <SpinSegment>[];
    if (rawSegments is List) {
      for (var i = 0; i < rawSegments.length; i++) {
        final item = rawSegments[i];
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          map.putIfAbsent('index', () => i);
          segments.add(SpinSegment.fromJson(map));
        }
      }
    }

    return SpinStatus(
      hasSpinAvailable: json['hasSpinAvailable'] == true,
      campaignId: json['campaignId']?.toString(),
      campaignTitle: (json['campaignTitle'] ?? json['title'])?.toString(),
      icon: json['icon']?.toString(),
      grandPrizeAmount: _asDoubleOrNull(
        json['grandPrizeAmount'] ?? json['grand_prize_amount'],
      ),
      applicableCategories: _asStringList(json['applicableCategories']),
      applicablePartners: _asStringList(json['applicablePartners']),
      segments: segments,
      alreadySpun: json['alreadySpun'] == true,
      reason: json['reason']?.toString(),
      transactionId: json['transactionId']?.toString(),
    );
  }
}

class SpinResult {
  final int winningSegmentIndex;
  final String prizeType;
  final String? voucherCode;
  final String? icon;
  final String label;
  final bool isGrandPrize;
  final List<String> applicableCategories;
  final List<String> applicablePartners;
  final String message;
  final double? value;

  const SpinResult({
    required this.winningSegmentIndex,
    required this.prizeType,
    this.voucherCode,
    this.icon,
    required this.label,
    this.isGrandPrize = false,
    this.applicableCategories = const [],
    this.applicablePartners = const [],
    required this.message,
    this.value,
  });

  factory SpinResult.fromJson(
    Map<String, dynamic> json, {
    String fallbackMessage = '',
  }) {
    return SpinResult(
      winningSegmentIndex: _asInt(
        json['winningSegmentIndex'] ?? json['winning_segment_index'],
      ),
      prizeType: (json['prizeType'] ?? json['rewardType'] ?? 'voucher')
          .toString(),
      voucherCode: (json['voucherCode'] ?? json['code'])?.toString(),
      icon: json['icon']?.toString(),
      label: (json['label'] ?? json['title'] ?? 'Prize').toString(),
      isGrandPrize: json['isGrandPrize'] == true,
      applicableCategories: _asStringList(json['applicableCategories']),
      applicablePartners: _asStringList(json['applicablePartners']),
      message: (json['message'] ?? fallbackMessage).toString(),
      value: _asDoubleOrNull(json['value'] ?? json['rewardValue']),
    );
  }
}

/// Nested unlock payload from bulk verify / scan responses.
class SpinUnlock {
  final bool hasSpinAvailable;
  final String? transactionId;
  final String? campaignId;

  const SpinUnlock({
    required this.hasSpinAvailable,
    this.transactionId,
    this.campaignId,
  });

  factory SpinUnlock.fromJson(Map<String, dynamic> json) {
    return SpinUnlock(
      hasSpinAvailable: json['hasSpinAvailable'] == true,
      transactionId: json['transactionId']?.toString(),
      campaignId: json['campaignId']?.toString(),
    );
  }

  static SpinUnlock? tryParse(dynamic value) {
    if (value is! Map) return null;
    return SpinUnlock.fromJson(Map<String, dynamic>.from(value));
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
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

List<String> _asStringList(dynamic value) {
  if (value is! List) return const [];
  return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
}
