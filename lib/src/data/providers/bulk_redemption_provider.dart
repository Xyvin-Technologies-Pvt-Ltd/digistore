import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bulk_redemption_models.dart';
import '../services/bulk_redemption_repository.dart';
import 'api_provider.dart';

final bulkRedemptionRepositoryProvider = Provider<BulkRedemptionRepository>((
  ref,
) {
  return BulkRedemptionRepository(ref.watch(publicApiProvider));
});

final shopOffersBundleProvider =
    FutureProvider.family<ShopOffersBundle, String>((ref, shopId) async {
      return ref.watch(bulkRedemptionRepositoryProvider).shopOffers(shopId);
    });
