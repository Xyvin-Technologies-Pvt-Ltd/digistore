import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/voucher_models.dart';
import '../services/voucher_repository.dart';
import 'api_provider.dart';
import 'referral_provider.dart';

final voucherRepositoryProvider = Provider<VoucherRepository>((ref) {
  return VoucherRepository(
    ref.watch(publicApiProvider),
    ref.watch(referralStoreProvider),
  );
});

/// Active / redeemed / expired vouchers for the logged-in customer.
final myVouchersProvider =
    FutureProvider.family<List<VoucherModel>, String>((ref, status) async {
      return ref.watch(voucherRepositoryProvider).myVouchers(status: status);
    });
