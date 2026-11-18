import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Single source of truth for the permanent device identifier.
///
/// Survives logout (see [SecureStorageService.clearAll] — that path must
/// never delete [storageKey]) and ideally reinstalls via Android ANDROID_ID /
/// iOS Keychain `identifierForVendor`.
class DeviceIdService {
  static const storageKey = 'permanent_device_id';

  /// Legacy install-scoped UUID previously owned by [ReferralStore].
  static const legacyPrefsKey = 'setgo_install_device_id';

  static const headerName = 'X-Device-Id';

  static const FlutterSecureStorage defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    // Android uses the plugin default cipher storage (encryptedSharedPreferences
    // is deprecated in flutter_secure_storage 10+).
  );

  final FlutterSecureStorage _storage;
  final DeviceInfoPlugin _deviceInfo;
  final Uuid _uuid;

  String? _cached;
  Future<String>? _inflight;

  DeviceIdService({
    FlutterSecureStorage? storage,
    DeviceInfoPlugin? deviceInfo,
    Uuid? uuid,
  }) : _storage = storage ?? defaultStorage,
       _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
       _uuid = uuid ?? const Uuid();

  Future<String> getPermanentDeviceId() {
    if (_cached != null && _cached!.isNotEmpty) {
      return Future.value(_cached);
    }
    return _inflight ??= _resolve().whenComplete(() => _inflight = null);
  }

  Future<String> _resolve() async {
    final stored = await _storage.read(key: storageKey);
    if (stored != null && stored.isNotEmpty) {
      _cached = stored;
      return stored;
    }

    // Migrate install-scoped ID so referral/voucher history stays continuous.
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(legacyPrefsKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _persist(legacy);
      return legacy;
    }

    final derived = await _deriveHardwareId();
    await _persist(derived);
    return derived;
  }

  Future<String> _deriveHardwareId() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        if (androidInfo.id.isNotEmpty) return androidInfo.id;
      } else if (!kIsWeb && Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        final vendorId = iosInfo.identifierForVendor;
        if (vendorId != null && vendorId.isNotEmpty) return vendorId;
      }
    } catch (_) {
      // Fall through to UUID if platform plugins are unavailable (e.g. tests).
    }
    return _uuid.v4();
  }

  Future<void> _persist(String id) async {
    await _storage.write(key: storageKey, value: id);
    // Keep legacy prefs key in sync so older readers still see the same ID
    // until fully migrated off SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(legacyPrefsKey, id);
    _cached = id;
  }
}

final deviceIdServiceProvider = Provider<DeviceIdService>((ref) {
  return DeviceIdService();
});

