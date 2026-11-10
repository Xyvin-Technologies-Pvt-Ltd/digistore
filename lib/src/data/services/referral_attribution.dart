import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:play_install_referrer/play_install_referrer.dart';

import '../services/secure_storage_service.dart';
import '../utils/referral_code.dart';
import 'referral_repository.dart';
import 'referral_store.dart';

class ReferralAttribution {
  final ReferralRepository _repository;
  final ReferralStore _store;
  final Future<bool> Function(String code) _saveIfEmpty;
  final Future<void> Function(String code) _saveExplicit;
  final SecureStorageService _secureStorage;
  final bool enableDeferred;

  ReferralAttribution({
    required ReferralRepository repository,
    required ReferralStore store,
    required Future<bool> Function(String code) saveIfEmpty,
    required Future<void> Function(String code) saveExplicit,
    required SecureStorageService secureStorage,
    /// Debug/profile installs often inherit an old Play referrer or the same
    /// Wi‑Fi IP as a recent landing-page click. Keep deferred attribution for
    /// release builds; tests can force it on.
    bool? enableDeferred,
  }) : _repository = repository,
       _store = store,
       _saveIfEmpty = saveIfEmpty,
       _saveExplicit = saveExplicit,
       _secureStorage = secureStorage,
       enableDeferred = enableDeferred ?? kReleaseMode;

  /// First launch only: Play Install Referrer, then IP match, then clipboard.
  ///
  /// A code that is already stored (for example from a link opened on this
  /// launch) is left alone. A failed network call does not mark the attempt
  /// finished, so the next cold start can try the IP match again.
  Future<void> resolveDeferred() async {
    try {
      if (await _store.readCode() != null) {
        await _store.markDeferredDone();
        return;
      }
      if (await _store.isDeferredDone()) return;

      if (!enableDeferred) {
        debugPrint(
          'Referral: skipping deferred autofill in debug '
          '(Play referrer / IP / clipboard). Open a referral link to fill.',
        );
        await _store.markDeferredDone();
        return;
      }

      final fromStore = await _readPlayReferrer();
      if (fromStore != null) {
        debugPrint('Referral: deferred from Play Install Referrer → $fromStore');
        await _saveIfEmpty(fromStore);
        await _store.markDeferredDone();
        return;
      }

      final pending = await _repository.resolvePending();
      if (pending.code != null) {
        debugPrint('Referral: deferred from IP match → ${pending.code}');
        await _saveIfEmpty(pending.code!);
        await _store.markDeferredDone();
        return;
      }

      // IP match often misses on cellular. The landing page copies the code,
      // so read the clipboard once when the server has no match or is down.
      if (Platform.isIOS && !await _store.isClipboardChecked()) {
        final fromClipboard = await _readClipboard();
        await _store.markClipboardChecked();
        if (fromClipboard != null) {
          debugPrint('Referral: deferred from clipboard → $fromClipboard');
          await _saveIfEmpty(fromClipboard);
        }
      }

      if (pending.answered) {
        await _store.markDeferredDone();
      }
    } catch (_) {
      // Attribution is best-effort. Signup still works without a code.
    }
  }

  /// A link the user just opened. This outranks install attribution.
  Future<bool> rememberExplicit(String code) async {
    final normalized = ReferralCode.normalize(code);
    if (normalized == null) return false;
    if (!await _canAccept()) return false;
    await _saveExplicit(normalized);
    return true;
  }

  Future<bool> _canAccept() async {
    try {
      if (await _secureStorage.getIsPartner()) return false;
      final user = await _secureStorage.getUserData();
      if (user == null) return true;
      if (user.referredBy != null && user.referredBy!.trim().isNotEmpty) {
        return false;
      }
      if (user.referralRewardClaimed == true) return false;
      return true;
    } catch (_) {
      // A corrupt local cache must not drop the code or break the link.
      return true;
    }
  }

  Future<String?> _readPlayReferrer() async {
    if (!Platform.isAndroid) return null;
    try {
      final details = await PlayInstallReferrer.installReferrer;
      return ReferralCode.fromInstallReferrer(details.installReferrer);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return ReferralCode.extract(data?.text);
    } catch (_) {
      return null;
    }
  }
}
