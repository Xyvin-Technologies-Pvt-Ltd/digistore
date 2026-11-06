import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/secure_storage_service.dart';
import 'user_provider.dart';
import 'partner_provider.dart';
import '../utils/global_variables.dart';
import 'api_provider.dart';
import 'offers_provider.dart';
import 'home_provider.dart';
import 'user_type_provider.dart';
import 'dart:io';
import '../models/partner_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../utils/notification_permission_helper.dart';
import '../services/notification_service/notification_service.dart';
import '../utils/otp_account.dart';
import '../utils/referral_code.dart';
import 'referral_provider.dart';

part 'auth_provider.g.dart';

@riverpod
class Session extends _$Session {
  @override
  String build() {
    return DateTime.now().toIso8601String();
  }

  void reset() {
    state = DateTime.now().toIso8601String();
  }
}

class AuthNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncData(null);
  }

  Future<bool> sendOtp(String phone) async {
    state = const AsyncLoading();
    try {
      final notificationsAllowed =
          await NotificationPermissionHelper.isNotificationAllowed();
      String? fcmToken;
      if (notificationsAllowed) {
        final notifService = ref.read(notificationServiceProvider);
        fcmToken = await notifService.getToken();
      }

      final payload = {
        'phone': phone,
        'platform': Platform.isAndroid ? 'android' : 'ios',
      };
      if (fcmToken != null) {
        payload['fcmToken'] = fcmToken;
      }

      final api = ref.read(apiProvider);
      final response = await api.post('/auth/send-otp', payload);

      if (response.success && response.data?['success'] == true) {
        final storage = ref.read(secureStorageServiceProvider);
        final saved = await storage.getRegistrationData() ?? <String, dynamic>{};
        final isNewUser = isNewUserInOtpResponse(response.data);
        if (isNewUser == null) {
          saved.remove('isNewUser');
        } else {
          saved['isNewUser'] = isNewUser;
        }
        await storage.saveRegistrationData(saved);
        state = const AsyncData(null);
        return true;
      } else {
        throw Exception(response.message ?? 'Failed to send OTP');
      }
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String otp,
    bool termsAccepted, {
    String? referralCode,
  }) async {
    state = const AsyncLoading();
    try {
      final api = ref.read(apiProvider);
      final payload = <String, dynamic>{
        'phone': phone,
        'otp': otp,
        'termsAccepted': termsAccepted,
      };
      final userType = ref.read(userTypeProvider);
      final code = ReferralCode.normalize(referralCode);
      if (userType == UserType.customer && code != null) {
        payload['referralCode'] = code;
      }
      final response = await api.post('/auth/verify-otp', payload);

      if (response.success && response.data?['success'] == true) {
        final responseData = response.data!;
        final token = responseData['data']?['token'];
        final userData = responseData['data']?['user'];
        final isNewUser = responseData['data']?['isNewUser'] ?? false;
        final onboardingComplete =
            responseData['data']?['onboardingComplete'] ?? false;

        final storage = ref.read(secureStorageServiceProvider);
        if (token != null) {
          await storage.saveBearerToken(token);
        }
        if (code != null) {
          await ref.read(pendingReferralProvider.notifier).clear();
        }

        // Skip profile setup for partners by forcing onboardingComplete to true
        final effectiveOnboardingComplete = (userType == UserType.partner)
            ? true
            : onboardingComplete;

        await storage.saveOnboardingComplete(effectiveOnboardingComplete);
        await storage.saveIsPartner(userType == UserType.partner);
        ref.read(userTypeProvider.notifier).setUserType(userType);

        if (userType == UserType.customer && userData != null) {
          final userModel = UserModel.fromJson(userData);
          await ref.read(userProvider.notifier).saveUser(userModel);
          GlobalVariables.setUserId(userModel.id);
        } else if (userType == UserType.partner) {
          final partnerData = responseData['data']?['partner'];
          if (partnerData != null) {
            final partnerModel = PartnerModel.fromJson(partnerData);
            await ref.read(partnerProvider.notifier).savePartner(partnerModel);
            GlobalVariables.setUserId(partnerModel.id);
          }
        }

        state = const AsyncData(null);
        return {
          'success': true,
          'onboardingComplete': effectiveOnboardingComplete,
          'isNewUser': isNewUser,
        };
      } else {
        throw Exception(response.message ?? 'Invalid OTP');
      }
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> logout() async {
    final storage = ref.read(secureStorageServiceProvider);

    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        final isPartner = await storage.getIsPartner();
        final endpoint = isPartner ? '/partner/auth/logout' : '/auth/logout';
        final api = ref.read(apiProvider);
        await api.post(endpoint, {'fcmToken': fcmToken});
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (e) {
      debugPrint('Logout API error: $e');
    }

    await storage.clearAll();
    GlobalVariables.clear();
    GlobalVariables.setPartnerMode(false);
    GlobalVariables.resetGuestMode();
    ref.read(sessionProvider.notifier).reset();
    ref.invalidate(userProvider);
    ref.invalidate(offersProvider);
    ref.invalidate(homeDataProvider);

    state = const AsyncData(null);
  }

  Future<bool> deleteAccount() async {
    state = const AsyncLoading();
    try {
      final api = ref.read(apiProvider);
      final response = await api.delete('/auth/account');
      if (!response.success) {
        throw Exception(response.message ?? 'Failed to delete account');
      }
    } catch (e) {
      debugPrint('Delete Account API error: $e');
      state = AsyncError(e, StackTrace.current);
      return false;
    }

    final storage = ref.read(secureStorageServiceProvider);
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (e) {
      debugPrint('FCM cleanup error during account deletion: $e');
    }

    await storage.clearAll();
    GlobalVariables.clear();
    GlobalVariables.setPartnerMode(false);
    GlobalVariables.resetGuestMode();
    ref.read(sessionProvider.notifier).reset();
    ref.invalidate(userProvider);
    ref.invalidate(offersProvider);
    ref.invalidate(homeDataProvider);

    state = const AsyncData(null);
    return true;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AsyncValue<void>>(
  AuthNotifier.new,
);
