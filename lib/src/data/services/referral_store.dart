import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Install-scoped referral state.
///
/// Kept out of secure storage so logout does not wipe a code the next
/// signup on this device still needs, and so the first-launch flag is
/// not reset every time the session ends.
class ReferralStore {
  static const pendingCodeKey = 'setgo_pending_referral_code';
  static const deferredDoneKey = 'setgo_referral_deferred_done';
  static const clipboardCheckedKey = 'setgo_referral_clipboard_checked';
  static const deviceIdKey = 'setgo_install_device_id';

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

  Future<String> deviceId() {
    return _sync(() async {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(deviceIdKey);
      if (existing != null && existing.isNotEmpty) return existing;
      final created = _createId();
      await prefs.setString(deviceIdKey, created);
      return created;
    });
  }

  static String _createId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
