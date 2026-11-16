import 'dart:convert';
import 'dart:developer';
import 'package:setgo/src/data/models/user_model.dart';
import 'package:setgo/src/data/models/partner_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secure_storage_service.g.dart';

class SecureStorageService {
  static const String _bearerTokenKey = 'bearer_token';
  static const String _userIdKey = 'user_id';
  static const String _userDataKey = 'user_data';
  static const String _fcmTokenKey = 'fcm_token';
  static const String _preferredLanguageKey = 'preferred_language';
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _tutorialCompletedKey = 'tutorial_completed';
  static const String _isPartnerKey = 'is_partner';
  static const String _partnerDataKey = 'partner_data';

  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveBearerToken(String token) async {
    await _storage.write(key: _bearerTokenKey, value: token);
  }

  Future<String?> getBearerToken() async {
    return await _storage.read(key: _bearerTokenKey);
  }

  Future<void> saveOnboardingComplete(bool value) async {
    await _storage.write(key: _onboardingCompleteKey, value: value.toString());
  }

  Future<bool> getOnboardingComplete() async {
    final value = await _storage.read(key: _onboardingCompleteKey);
    return value == 'true';
  }

  Future<void> saveTutorialCompleted(bool value) async {
    await _storage.write(key: _tutorialCompletedKey, value: value.toString());
  }

  Future<bool> getTutorialCompleted() async {
    final value = await _storage.read(key: _tutorialCompletedKey);
    return value == 'true';
  }

  Future<void> saveIsPartner(bool value) async {
    await _storage.write(key: _isPartnerKey, value: value.toString());
  }

  Future<bool> getIsPartner() async {
    final value = await _storage.read(key: _isPartnerKey);
    return value == 'true';
  }

  Future<void> saveHasPromptedForNotifications(bool value) async {
    await _storage.write(
      key: 'has_prompted_for_notifications',
      value: value.toString(),
    );
  }

  Future<bool> getHasPromptedForNotifications() async {
    final value = await _storage.read(key: 'has_prompted_for_notifications');
    return value == 'true';
  }

  /// Save user ID for reference
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }

  /// Retrieve user ID
  Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  /// Save user data as JSON
  Future<void> saveUserData(UserModel user) async {
    final jsonString = json.encode(user.toJson());
    await _storage.write(key: _userDataKey, value: jsonString);
  }

  /// Retrieve user data from local storage
  Future<UserModel?> getUserData() async {
    try {
      final jsonString = await _storage.read(key: _userDataKey);
      if (jsonString != null) {
        final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
        return UserModel.fromJson(jsonMap);
      }
    } catch (e) {
      // Log the error for debugging
      print('Error reading user data: $e');
      rethrow; // Re-throw to let caller handle it
    }
    return null;
  }

  /// Save partner data as JSON
  Future<void> savePartnerData(PartnerModel partner) async {
    final jsonString = json.encode(partner.toJson());
    await _storage.write(key: _partnerDataKey, value: jsonString);
  }

  /// Retrieve partner data from local storage
  Future<PartnerModel?> getPartnerData() async {
    try {
      final jsonString = await _storage.read(key: _partnerDataKey);
      if (jsonString != null) {
        final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
        return PartnerModel.fromJson(jsonMap);
      }
    } catch (e) {
      print('Error reading partner data: $e');
      rethrow;
    }
    return null;
  }

  /// Clear session tokens and user data on logout.
  ///
  /// Intentionally does **not** call [FlutterSecureStorage.deleteAll] and does
  /// **not** delete [DeviceIdService.storageKey] (`permanent_device_id`) — that
  /// ID must survive logout/login and is owned by [DeviceIdService].
  Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: _bearerTokenKey),
      _storage.delete(key: _userIdKey),
      _storage.delete(key: _userDataKey),
      _storage.delete(key: _fcmTokenKey),
      _storage.delete(key: _preferredLanguageKey),
      _storage.delete(key: _onboardingCompleteKey),
      _storage.delete(key: _tutorialCompletedKey),
      _storage.delete(key: _isPartnerKey),
      _storage.delete(key: _partnerDataKey),
      _storage.delete(key: 'has_prompted_for_notifications'),
      _storage.delete(key: 'registration_data'),
      _storage.delete(key: _resourceSwipeTutorialKey),
      _storage.delete(key: _doubleTapLikeTutorialKey),
    ]);
  }

  /// Check if bearer token exists
  Future<bool> hasBearerToken() async {
    final token = await getBearerToken();
    return token != null && token.isNotEmpty;
  }

  /// Save FCM token
  Future<void> saveFcmToken(String token) async {
    await _storage.write(key: _fcmTokenKey, value: token);
  }

  /// Retrieve FCM token
  Future<String?> getFcmToken() async {
    return await _storage.read(key: _fcmTokenKey);
  }

  /// Save registration data temporarily during the registration process
  Future<void> saveRegistrationData(Map<String, dynamic> data) async {
    final jsonString = json.encode(data);
    await _storage.write(key: 'registration_data', value: jsonString);
  }

  /// Retrieve registration data
  Future<Map<String, dynamic>?> getRegistrationData() async {
    final jsonString = await _storage.read(key: 'registration_data');
    if (jsonString != null) {
      try {
        return json.decode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Clear registration data after successful registration
  Future<void> clearRegistrationData() async {
    await _storage.delete(key: 'registration_data');
  }

  /// Save preferred language
  Future<void> setPreferredLanguage(String languageCode) async {
    await _storage.write(key: _preferredLanguageKey, value: languageCode);
  }

  /// Retrieve preferred language
  Future<String?> getPreferredLanguage() async {
    return await _storage.read(key: _preferredLanguageKey);
  }

  // Feature Tours
  static const _resourceSwipeTutorialKey = 'resource_swipe_tutorial_shown';

  static Future<bool> shouldShowResourceSwipeTutorial() async {
    const storage = FlutterSecureStorage();
    final result = await storage.read(key: _resourceSwipeTutorialKey);
    return result == null;
  }

  static Future<void> markResourceSwipeTutorialShown() async {
    const storage = FlutterSecureStorage();
    await storage.write(key: _resourceSwipeTutorialKey, value: 'true');
  }

  static const _doubleTapLikeTutorialKey = 'double_tap_like_tutorial_shown';

  static Future<bool> shouldShowDoubleTapLikeTutorial() async {
    const storage = FlutterSecureStorage();
    final result = await storage.read(key: _doubleTapLikeTutorialKey);
    return result == null;
  }

  static Future<void> markDoubleTapLikeTutorialShown() async {
    const storage = FlutterSecureStorage();
    await storage.write(key: _doubleTapLikeTutorialKey, value: 'true');
  }

  static Future<void> resetAllTutorials() async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: _resourceSwipeTutorialKey);
    await storage.delete(key: _doubleTapLikeTutorialKey);
  }
}

@riverpod
SecureStorageService secureStorageService(Ref ref) {
  return SecureStorageService();
}
