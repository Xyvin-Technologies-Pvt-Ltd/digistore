import '../utils/referral_code.dart';

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

class ReferralRewardDetail {
  final int points;
  final num rupeeValue;
  final String title;

  const ReferralRewardDetail({
    required this.points,
    required this.rupeeValue,
    required this.title,
  });

  factory ReferralRewardDetail.fromJson(Map<String, dynamic> json) {
    return ReferralRewardDetail(
      points: _asInt(json['points']),
      rupeeValue: _asNum(json['rupeeValue']),
      title: json['title']?.toString() ?? '',
    );
  }
}

class ReferralSharePayload {
  final bool isActive;
  final String referralCode;
  final int rewardPoints;
  final num rupeeEquivalent;
  final int newUserRewardPoints;
  final num newUserRupeeEquivalent;
  final int pointConversionRate;
  final int successfulReferrals;
  final int totalPointsEarned;
  final num totalRupeeEarned;
  final int minPurchaseForRedemption;
  final int? maxReferrals;
  final String shareTitle;
  final String shareDescription;
  final String shareImage;
  final String shareMessage;
  final String shareUrl;
  final String whatsappUrl;
  final String smsUrl;
  final String qrCodeData;
  final String playStoreUrl;
  final String appStoreUrl;
  final String deepLink;
  final ReferralRewardDetail? referrerReward;
  final ReferralRewardDetail? newUserReward;
  final String terms;

  const ReferralSharePayload({
    this.isActive = true,
    required this.referralCode,
    required this.rewardPoints,
    required this.rupeeEquivalent,
    this.newUserRewardPoints = 0,
    this.newUserRupeeEquivalent = 0,
    this.pointConversionRate = 10,
    required this.successfulReferrals,
    required this.totalPointsEarned,
    this.totalRupeeEarned = 0,
    required this.minPurchaseForRedemption,
    this.maxReferrals,
    required this.shareTitle,
    this.shareDescription = '',
    this.shareImage = '',
    required this.shareMessage,
    required this.shareUrl,
    required this.whatsappUrl,
    required this.smsUrl,
    required this.qrCodeData,
    required this.playStoreUrl,
    required this.appStoreUrl,
    required this.deepLink,
    this.referrerReward,
    this.newUserReward,
    required this.terms,
  });

  factory ReferralSharePayload.fromJson(Map<String, dynamic> json) {
    final referrerRewardMap = _asMap(json['referrerReward']);
    final newUserRewardMap = _asMap(json['newUserReward']);

    return ReferralSharePayload(
      isActive: json['isActive'] != false,
      referralCode: json['referralCode']?.toString() ?? '',
      rewardPoints: _asInt(json['rewardPoints']),
      rupeeEquivalent: _asNum(json['rupeeEquivalent']),
      newUserRewardPoints: _asInt(json['newUserRewardPoints']),
      newUserRupeeEquivalent: _asNum(json['newUserRupeeEquivalent']),
      pointConversionRate: _asInt(json['pointConversionRate']) > 0
          ? _asInt(json['pointConversionRate'])
          : 10,
      successfulReferrals: _asInt(json['successfulReferrals']),
      totalPointsEarned: _asInt(json['totalPointsEarned']),
      totalRupeeEarned: _asNum(json['totalRupeeEarned']),
      minPurchaseForRedemption: _asInt(json['minPurchaseForRedemption']),
      maxReferrals: json['maxReferrals'] != null
          ? _asIntOrNull(json['maxReferrals'])
          : null,
      shareTitle: json['shareTitle']?.toString() ??
          'Invite Friends & Earn SetGo Rewards',
      shareDescription: json['shareDescription']?.toString() ?? '',
      shareImage: json['shareImage']?.toString() ?? '',
      shareMessage: json['shareMessage']?.toString() ?? '',
      shareUrl: json['shareUrl']?.toString() ?? '',
      whatsappUrl: json['whatsappUrl']?.toString() ?? '',
      smsUrl: json['smsUrl']?.toString() ?? '',
      qrCodeData: json['qrCodeData']?.toString() ?? '',
      playStoreUrl: json['playStoreUrl']?.toString() ?? '',
      appStoreUrl: json['appStoreUrl']?.toString() ?? '',
      deepLink: json['deepLink']?.toString() ?? '',
      referrerReward: referrerRewardMap != null
          ? ReferralRewardDetail.fromJson(referrerRewardMap)
          : null,
      newUserReward: newUserRewardMap != null
          ? ReferralRewardDetail.fromJson(newUserRewardMap)
          : null,
      terms: json['terms']?.toString() ?? '',
    );
  }

  /// Lifetime points at the program rate: 10 points = ₹1 (or backend totalRupeeEarned).
  num get earnedRupees {
    if (totalRupeeEarned > 0) return totalRupeeEarned;
    final rate = pointConversionRate > 0 ? pointConversionRate : 10;
    return totalPointsEarned / rate;
  }

  /// Formats the official referral invite message in Malayalam with code and link.
  static String buildInviteMessage({
    required String referralCode,
    required String shareUrl,
  }) {
    final code = referralCode.trim().toUpperCase();
    return 'ഇനി ഓരോ ഷോപ്പിംഗും കൂടുതൽ ലാഭകരമാക്കാം!\n\n'
        'നമ്മുടെ നാട്ടിലെ കടകളിലെ മികച്ച ഓഫറുകളും ഡിസ്കൗണ്ടുകളും കണ്ടെത്താനും ഓരോ പർച്ചേസിനും റിവാർഡ് പോയിന്റുകൾ നേടാനും ഇതാ SETGO ആപ്പ്!\n\n'
        'Referral Code ഉപയോഗിച്ച് രജിസ്റ്റർ ചെയ്യുമ്പോൾ കുറഞ്ഞത് ₹100 മൂല്യമുള്ള വൗച്ചർ നേടാം!\n\n'
        'സുഹൃത്തുക്കളെ റഫർ ചെയ്ത് ₹10,000 വരെ ക്യാഷ്ബാക്ക് നേടാനുള്ള അവസരവും!\n\n'
        'നാട്ടിലെ കടകളിലെ ആകർഷകമായ ഓഫറുകളും ഡിസ്കൗണ്ടുകളും അറിയാം. ഓരോ പർച്ചേസിലും റിവാർഡ് പോയിന്റുകൾ നേടാം.\n\n'
        'ഇപ്പോൾ തന്നെ SETGO ആപ്പ് ഡൗൺലോഡ് ചെയ്യൂ!\n'
        '$shareUrl\n\n'
        'Referral Code: *$code*';
  }

  /// Rewrites invite links to match the API host the app is actually using.
  ///
  /// Preserves the backend's share content / template, only rewriting the
  /// URL when running on a different test environment (e.g. UAT).
  ReferralSharePayload alignedToApiBase(String apiBaseUrl) {
    final code = referralCode.trim().toUpperCase();
    if (code.isEmpty) return this;

    final targetLanding = ReferralCode.landingBaseFromApi(apiBaseUrl);
    final correctUrl = '$targetLanding?ref=$code';

    // Align URL if shareUrl is empty or if environments mismatch (e.g. UAT vs Prod)
    final needsAlignment = shareUrl.isEmpty ||
        (apiBaseUrl.contains('uat') != shareUrl.contains('uat'));
    final finalShareUrl = needsAlignment ? correctUrl : shareUrl;

    // Use backend share message if provided, aligning URL or placeholders as needed
    String message;
    if (shareMessage.isNotEmpty) {
      message = shareMessage;
      if (shareUrl.isNotEmpty && shareUrl != finalShareUrl) {
        message = message.replaceAll(shareUrl, finalShareUrl);
      }
      if (message.contains('{code}')) {
        message = message.replaceAll('{code}', code);
      }
      if (message.contains('{link}')) {
        message = message.replaceAll('{link}', finalShareUrl);
      }
    } else if (shareDescription.isNotEmpty) {
      message = shareDescription
          .replaceAll('{code}', code)
          .replaceAll('{link}', finalShareUrl);
    } else {
      message = buildInviteMessage(
        referralCode: code,
        shareUrl: finalShareUrl,
      );
    }

    final finalWhatsapp = (whatsappUrl.isNotEmpty && shareUrl == finalShareUrl)
        ? whatsappUrl
        : 'https://api.whatsapp.com/send?text=${Uri.encodeComponent(message)}';
    final finalSms = (smsUrl.isNotEmpty && shareUrl == finalShareUrl)
        ? smsUrl
        : 'sms:?body=${Uri.encodeComponent(message)}';

    return ReferralSharePayload(
      isActive: isActive,
      referralCode: referralCode,
      rewardPoints: rewardPoints,
      rupeeEquivalent: rupeeEquivalent,
      newUserRewardPoints: newUserRewardPoints,
      newUserRupeeEquivalent: newUserRupeeEquivalent,
      pointConversionRate: pointConversionRate,
      successfulReferrals: successfulReferrals,
      totalPointsEarned: totalPointsEarned,
      totalRupeeEarned: totalRupeeEarned,
      minPurchaseForRedemption: minPurchaseForRedemption,
      maxReferrals: maxReferrals,
      shareTitle: shareTitle,
      shareDescription: shareDescription,
      shareImage: shareImage,
      shareMessage: message,
      shareUrl: finalShareUrl,
      whatsappUrl: finalWhatsapp,
      smsUrl: finalSms,
      qrCodeData: qrCodeData,
      playStoreUrl: playStoreUrl,
      appStoreUrl: appStoreUrl,
      deepLink: deepLink.isNotEmpty
          ? deepLink
          : 'setgo://referral?code=$code',
      referrerReward: referrerReward,
      newUserReward: newUserReward,
      terms: terms,
    );
  }
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

int? _asIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

num _asNum(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

