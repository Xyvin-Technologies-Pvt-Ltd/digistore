import 'package:shared_preferences/shared_preferences.dart';

import 'device_id_service.dart';

/// Install-scoped referral state.
///
/// Kept out of secure storage so logout does not wipe a code the next
/// signup on this device still needs, and so the first-launch flag is
/// not reset every time the session ends.
class ReferralStore {
  static const pendingCodeKey = 'setgo_pending_referral_code';
  static const deferredDoneKey = 'setgo_referral_deferred_done';
  static const clipboardCheckedKey = 'setgo_referral_clipboard_checked';

  /// Legacy prefs key — still used by [DeviceIdService] for one-time migration.
  static const deviceIdKey = DeviceIdService.legacyPrefsKey;

  final DeviceIdService _deviceIdService;

  ReferralStore({DeviceIdService? deviceIdService})
    : _deviceIdService = deviceIdService ?? DeviceIdService();

  Future<void> _queue = Future<void>.value();

  Future<T> _sync<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<String?> readCode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(pendingCodeKey);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> writeCode(String code) {
    return _sync(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(pendingCodeKey, code);
    });
  }

  /// Writes only when nothing is stored yet. An explicit link wins over
  /// install attribution if the two arrive together.
  Future<bool> saveIfEmpty(String code) {
    return _sync(() async {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(pendingCodeKey);
      if (existing != null && existing.isNotEmpty) return false;
      await prefs.setString(pendingCodeKey, code);
      return true;
    });
  }

  Future<void> clearCode() {
    return _sync(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(pendingCodeKey);
    });
  }

  Future<bool> isDeferredDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(deferredDoneKey) ?? false;
  }

  Future<void> markDeferredDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(deferredDoneKey, true);
  }

  Future<bool> isClipboardChecked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(clipboardCheckedKey) ?? false;
  }

  Future<void> markClipboardChecked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(clipboardCheckedKey, true);
  }

  /// Permanent device ID (delegates to [DeviceIdService] — same ID as API header).
  Future<String> deviceId() => _deviceIdService.getPermanentDeviceId();
}
