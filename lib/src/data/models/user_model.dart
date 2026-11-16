import 'package:setgo/src/utils/safe_parser.dart';

import '../utils/name_case.dart';
import 'device_model.dart';

class UserModel {
  final String? id;
  final String? phone;
  final String? name;
  final String? email;
  final String? avatar;
  final LocationModel? location;
  final int? pointsBalance;
  final int? totalPointsEarned;
  final bool? isActive;
  final DateTime? lastLogin;
  final String? referralCode;
  final String? referredBy;
  final bool? referralRewardClaimed;
  final bool? onboardingComplete;
  final bool? tutorialCompleted;
  final PreferencesModel? preferences;
  final TierModel? currentTier;
  final NextTierModel? nextTier;
  final double? progressToNextTier;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final List<DeviceModel>? devices;

  const UserModel({
    this.id,
    this.phone,
    this.name,
    this.email,
    this.avatar,
    this.location,
    this.pointsBalance,
    this.totalPointsEarned,
    this.isActive,
    this.lastLogin,
    this.referralCode,
    this.referredBy,
    this.referralRewardClaimed,
    this.onboardingComplete,
    this.tutorialCompleted,
    this.preferences,
    this.currentTier,
    this.nextTier,
    this.progressToNextTier,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.devices,
  });

  factory UserModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserModel();

    final map = (json['user'] is Map<String, dynamic>)
        ? json['user'] as Map<String, dynamic>
        : json;

    return UserModel(
      id: SafeParser.pick(map, ['id', '_id'])?.toString(),
      phone: SafeParser.pick(
        map,
        ['phone', 'mobile', 'phoneNumber', 'contactPhone'],
      )?.toString(),
      name: NameCase.maybe(map['name']?.toString()),
      email: map['email']?.toString(),
      avatar: map['avatar']?.toString(),
      location: SafeParser.parseObject(
        map['location'],
        LocationModel.fromJson,
      ),
      pointsBalance: map['pointsBalance'] as int?,
      totalPointsEarned: map['totalPointsEarned'] as int?,
      isActive: map['isActive'] as bool?,
      lastLogin: map['lastLogin'] != null
          ? DateTime.tryParse(map['lastLogin'])?.toLocal()
          : null,
      referralCode: map['referralCode'] as String?,
      referredBy: map['referredBy'] as String?,
      referralRewardClaimed: map['referralRewardClaimed'] as bool?,
      onboardingComplete: map['onboardingComplete'] as bool?,
      tutorialCompleted: map['tutorialCompleted'] as bool?,
      preferences: SafeParser.parseObject(
        map['preferences'],
        PreferencesModel.fromJson,
      ),
      currentTier: SafeParser.parseObject(
        map['currentTier'] ?? map['tier'],
        TierModel.fromJson,
      ),
      nextTier: SafeParser.parseObject(
        map['nextTier'],
        NextTierModel.fromJson,
      ),
      progressToNextTier: map['progressToNextTier'] != null
          ? (map['progressToNextTier'] as num).toDouble()
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'])?.toLocal()
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'])?.toLocal()
          : null,
      deletedAt: map['deletedAt'] != null
          ? DateTime.tryParse(map['deletedAt'])?.toLocal()
          : null,
      devices: SafeParser.parseList(map['devices'], DeviceModel.fromJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'email': email,
      'avatar': avatar,
      'location': location?.toJson(),
      'pointsBalance': pointsBalance,
      'totalPointsEarned': totalPointsEarned,
      'isActive': isActive,
      'lastLogin': lastLogin?.toIso8601String(),
      'referralCode': referralCode,
      'referredBy': referredBy,
      'referralRewardClaimed': referralRewardClaimed,
      'onboardingComplete': onboardingComplete,
      'tutorialCompleted': tutorialCompleted,
      'preferences': preferences?.toJson(),
      'currentTier': currentTier?.toJson(),
      'nextTier': nextTier?.toJson(),
      'progressToNextTier': progressToNextTier,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'devices': devices?.map((e) => e.toJson()).toList(),
    };
  }

  UserModel copyWith({
    String? id,
    String? phone,
    String? name,
    String? email,
    String? avatar,
    LocationModel? location,
    int? pointsBalance,
    int? totalPointsEarned,
    bool? isActive,
    DateTime? lastLogin,
    String? referralCode,
    String? referredBy,
    bool? referralRewardClaimed,
    bool? onboardingComplete,
    bool? tutorialCompleted,
    PreferencesModel? preferences,
    TierModel? currentTier,
    NextTierModel? nextTier,
    double? progressToNextTier,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    List<DeviceModel>? devices,
  }) {
    return UserModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      location: location ?? this.location,
      pointsBalance: pointsBalance ?? this.pointsBalance,
      totalPointsEarned: totalPointsEarned ?? this.totalPointsEarned,
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      referralRewardClaimed:
          referralRewardClaimed ?? this.referralRewardClaimed,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
      preferences: preferences ?? this.preferences,
      currentTier: currentTier ?? this.currentTier,
      nextTier: nextTier ?? this.nextTier,
      progressToNextTier: progressToNextTier ?? this.progressToNextTier,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      devices: devices ?? this.devices,
    );
  }

  UserModel mergeWith(UserModel? other) {
    if (other == null) return this;
    return UserModel(
      id: (other.id != null && other.id!.isNotEmpty) ? other.id : id,
      phone: (other.phone != null && other.phone!.isNotEmpty)
          ? other.phone
          : phone,
      name: (other.name != null && other.name!.isNotEmpty)
          ? other.name
          : name,
      email: (other.email != null && other.email!.isNotEmpty)
          ? other.email
          : email,
      avatar: (other.avatar != null && other.avatar!.isNotEmpty)
          ? other.avatar
          : avatar,
      location: (location != null)
          ? location!.mergeWith(other.location)
          : other.location,
      pointsBalance: other.pointsBalance ?? pointsBalance,
      totalPointsEarned: other.totalPointsEarned ?? totalPointsEarned,
      isActive: other.isActive ?? isActive,
      lastLogin: other.lastLogin ?? lastLogin,
      referralCode:
          (other.referralCode != null && other.referralCode!.isNotEmpty)
              ? other.referralCode
              : referralCode,
      referredBy: other.referredBy ?? referredBy,
      referralRewardClaimed:
          other.referralRewardClaimed ?? referralRewardClaimed,
      onboardingComplete: other.onboardingComplete ?? onboardingComplete,
      tutorialCompleted: other.tutorialCompleted ?? tutorialCompleted,
      preferences: other.preferences ?? preferences,
      currentTier: other.currentTier ?? currentTier,
      nextTier: other.nextTier ?? nextTier,
      progressToNextTier: other.progressToNextTier ?? progressToNextTier,
      createdAt: other.createdAt ?? createdAt,
      updatedAt: other.updatedAt ?? updatedAt,
      deletedAt: other.deletedAt ?? deletedAt,
      devices: other.devices ?? devices,
    );
  }
}

class LocationModel {
  final String? district;
  final String? localBody;
  final CoordinatesModel? coordinates;

  const LocationModel({this.district, this.localBody, this.coordinates});

  LocationModel mergeWith(LocationModel? other) {
    if (other == null) return this;
    return LocationModel(
      district: (other.district != null && other.district!.isNotEmpty)
          ? other.district
          : district,
      localBody: (other.localBody != null && other.localBody!.isNotEmpty)
          ? other.localBody
          : localBody,
      coordinates: other.coordinates ?? coordinates,
    );
  }

  factory LocationModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LocationModel();
    return LocationModel(
      district: json['district'] as String?,
      localBody: json['localBody'] as String?,
      coordinates: SafeParser.parseObject(
        json['coordinates'],
        CoordinatesModel.fromJson,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'district': district,
      'localBody': localBody,
      'coordinates': coordinates?.toJson(),
    };
  }
}

class CoordinatesModel {
  final String type;
  final List<double>? coordinates;

  const CoordinatesModel({this.type = 'Point', this.coordinates});

  factory CoordinatesModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CoordinatesModel();
    return CoordinatesModel(
      type: json['type'] as String? ?? 'Point',
      coordinates: json['coordinates'] != null
          ? (json['coordinates'] as List<dynamic>)
                .map((e) => (e as num).toDouble())
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type, 'coordinates': coordinates}
      ..removeWhere((key, value) => value == null);
  }

  double? get lng =>
      (coordinates != null && coordinates!.isNotEmpty) ? coordinates![0] : null;
  double? get lat =>
      (coordinates != null && coordinates!.length > 1) ? coordinates![1] : null;
}

class PreferencesModel {
  final bool pushNotifications;
  final bool emailNotifications;
  final String language;

  const PreferencesModel({
    this.pushNotifications = true,
    this.emailNotifications = true,
    this.language = 'en',
  });

  factory PreferencesModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PreferencesModel();
    return PreferencesModel(
      pushNotifications: json['pushNotifications'] as bool? ?? true,
      emailNotifications: json['emailNotifications'] as bool? ?? true,
      language: json['language'] as String? ?? 'en',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pushNotifications': pushNotifications,
      'emailNotifications': emailNotifications,
      'language': language,
    };
  }
}

class TierModel {
  final String? name;
  final int? minPoints;
  final double? bonusMultiplier;
  final List<String>? benefits;
  final String? badge;
  final double? customerCommissionShare;
  final int? nextTierPoints;

  const TierModel({
    this.name,
    this.minPoints,
    this.bonusMultiplier,
    this.benefits,
    this.badge,
    this.customerCommissionShare,
    this.nextTierPoints,
  });

  factory TierModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TierModel();
    return TierModel(
      name: json['name'] as String?,
      minPoints: (json['minPoints'] as num?)?.toInt(),
      bonusMultiplier: json['bonusMultiplier'] != null
          ? (json['bonusMultiplier'] as num).toDouble()
          : null,
      benefits: json['benefits'] != null
          ? List<String>.from(json['benefits'])
          : null,
      badge: json['badge'] as String?,
      customerCommissionShare:
          (json['customerCommissionShare'] as num?)?.toDouble(),
      nextTierPoints: (json['nextTierPoints'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'minPoints': minPoints,
      'bonusMultiplier': bonusMultiplier,
      'benefits': benefits,
      'badge': badge,
      'customerCommissionShare': customerCommissionShare,
      'nextTierPoints': nextTierPoints,
    };
  }
}

class NextTierModel {
  final String? name;
  final int? minPoints;
  final int? pointsNeeded;

  const NextTierModel({this.name, this.minPoints, this.pointsNeeded});

  factory NextTierModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const NextTierModel();
    return NextTierModel(
      name: json['name'] as String?,
      minPoints: json['minPoints'] as int?,
      pointsNeeded: json['pointsNeeded'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'minPoints': minPoints, 'pointsNeeded': pointsNeeded};
  }
}
