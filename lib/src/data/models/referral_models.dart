class ReferralValidation {
  final bool valid;
  final String? code;
  final String? referrerName;
  final String message;

  const ReferralValidation({
    required this.valid,
    this.code,
    this.referrerName,
    required this.message,
  });

  const ReferralValidation.empty()
    : valid = true,
      code = null,
      referrerName = null,
      message = '';

  const ReferralValidation.invalid(this.message)
    : valid = false,
      code = null,
      referrerName = null;
}

class ReferralApplyResult {
  final bool applied;
  final bool alreadyApplied;
  final String message;
  final String? referrerName;
  final int? pointsAwarded;

  const ReferralApplyResult({
    required this.applied,
    required this.alreadyApplied,
    required this.message,
    this.referrerName,
    this.pointsAwarded,
  });

  bool get shouldContinue => applied || alreadyApplied;
}

class ReferralSharePayload {
  final String referralCode;
  final int rewardPoints;
  final num rupeeEquivalent;
  final int successfulReferrals;
  final int totalPointsEarned;
  final int minPurchaseForRedemption;
  final String shareTitle;
  final String shareMessage;
  final String shareUrl;
  final String whatsappUrl;
  final String smsUrl;
  final String qrCodeData;
  final String playStoreUrl;
  final String appStoreUrl;
  final String deepLink;
  final String terms;

  const ReferralSharePayload({
    required this.referralCode,
    required this.rewardPoints,
    required this.rupeeEquivalent,
    required this.successfulReferrals,
    required this.totalPointsEarned,
    required this.minPurchaseForRedemption,
    required this.shareTitle,
    required this.shareMessage,
    required this.shareUrl,
    required this.whatsappUrl,
    required this.smsUrl,
    required this.qrCodeData,
    required this.playStoreUrl,
    required this.appStoreUrl,
    required this.deepLink,
    required this.terms,
  });

  factory ReferralSharePayload.fromJson(Map<String, dynamic> json) {
    return ReferralSharePayload(
      referralCode: json['referralCode']?.toString() ?? '',
      rewardPoints: _asInt(json['rewardPoints']),
      rupeeEquivalent: _asNum(json['rupeeEquivalent']),
      successfulReferrals: _asInt(json['successfulReferrals']),
      totalPointsEarned: _asInt(json['totalPointsEarned']),
      minPurchaseForRedemption: _asInt(json['minPurchaseForRedemption']),
      shareTitle: json['shareTitle']?.toString() ?? 'Invite Friends & Earn Points',
      shareMessage: json['shareMessage']?.toString() ?? '',
      shareUrl: json['shareUrl']?.toString() ?? '',
      whatsappUrl: json['whatsappUrl']?.toString() ?? '',
      smsUrl: json['smsUrl']?.toString() ?? '',
      qrCodeData: json['qrCodeData']?.toString() ?? '',
      playStoreUrl: json['playStoreUrl']?.toString() ?? '',
      appStoreUrl: json['appStoreUrl']?.toString() ?? '',
      deepLink: json['deepLink']?.toString() ?? '',
      terms: json['terms']?.toString() ?? '',
    );
  }

  /// Lifetime points at the program rate: 10 points = ₹1.
  ///
  /// The my-code payload also sends [rupeeEquivalent], and that value has
  /// come back equal to [rewardPoints] (both 10). Using it as rupees per
  /// point shows ₹10 for a 10-point reward.
  num get earnedRupees => totalPointsEarned / 10;
}

class ReferralHistoryEntry {
  final String id;
  final String referredName;
  final String referredPhone;
  final int pointsAwarded;
  final String status;
  final DateTime? date;

  const ReferralHistoryEntry({
    required this.id,
    required this.referredName,
    required this.referredPhone,
    required this.pointsAwarded,
    required this.status,
    this.date,
  });

  factory ReferralHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date']?.toString();
    return ReferralHistoryEntry(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      referredName: json['referredName']?.toString() ?? 'Friend',
      referredPhone: json['referredPhone']?.toString() ?? '',
      pointsAwarded: _asInt(json['pointsAwarded']),
      status: json['status']?.toString() ?? '',
      date: rawDate == null ? null : DateTime.tryParse(rawDate)?.toLocal(),
    );
  }
}

class ReferralHistoryPage {
  final List<ReferralHistoryEntry> items;
  final int page;
  final int totalPages;

  const ReferralHistoryPage({
    required this.items,
    required this.page,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}

class ResolvePendingResult {
  final bool answered;
  final String? code;

  const ResolvePendingResult({required this.answered, this.code});
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

num _asNum(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}
