import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/referral_attribution.dart';
import '../services/referral_repository.dart';
import '../services/referral_store.dart';
import '../services/secure_storage_service.dart';
import 'api_provider.dart';

final referralStoreProvider = Provider<ReferralStore>((ref) {
  return ReferralStore();
});

final referralRepositoryProvider = Provider<ReferralRepository>((ref) {
  return ReferralRepository(
    ref.watch(publicApiProvider),
    ref.watch(referralStoreProvider),
  );
});

class PendingReferralNotifier extends Notifier<String?> {
  int _epoch = 0;

  @override
  String? build() {
    final epoch = _epoch;
    ref.read(referralStoreProvider).readCode().then((code) {
      if (epoch == _epoch) state = code;
    });
    return null;
  }

  Future<bool> saveIfEmpty(String code) async {
    _epoch++;
    final epoch = _epoch;
    final saved = await ref.read(referralStoreProvider).saveIfEmpty(code);
    if (epoch != _epoch) return saved;
    if (saved) state = code;
    return saved;
  }

  Future<void> saveExplicit(String code) async {
    _epoch++;
    await ref.read(referralStoreProvider).writeCode(code);
    state = code;
  }

  Future<void> clear() async {
    _epoch++;
    await ref.read(referralStoreProvider).clearCode();
    state = null;
  }
}

final pendingReferralProvider =
    NotifierProvider<PendingReferralNotifier, String?>(
      PendingReferralNotifier.new,
    );

final referralAttributionProvider = Provider<ReferralAttribution>((ref) {
  final pending = ref.watch(pendingReferralProvider.notifier);
  return ReferralAttribution(
    repository: ref.watch(referralRepositoryProvider),
    store: ref.watch(referralStoreProvider),
    saveIfEmpty: pending.saveIfEmpty,
    saveExplicit: pending.saveExplicit,
    secureStorage: ref.watch(secureStorageServiceProvider),
  );
});
