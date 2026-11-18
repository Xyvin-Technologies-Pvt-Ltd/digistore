import '../models/spin_models.dart';
import '../models/voucher_models.dart';
import '../providers/api_provider.dart';

class VoucherRepository {
  final ApiProvider _api;

  VoucherRepository(this._api);

  /// GET /vouchers/my-vouchers?status=active|redeemed|expired
  Future<List<VoucherModel>> myVouchers({String status = 'active'}) async {
    final response = await _api.get(
      '/vouchers/my-vouchers',
      requireAuth: true,
      queryParams: {'status': status},
    );
    final body = response.data;
    if (!response.success || body == null || body['success'] == false) {
      return const [];
    }

    final raw = body['data'];
    final list = <VoucherModel>[];
    if (raw is List) {
      for (final item in raw) {
        final map = _asMap(item);
        if (map != null) list.add(VoucherModel.fromJson(map));
      }
    }
    return list;
  }

  /// POST /vouchers/validate
  Future<VoucherValidationResult> validate({
    required String voucherCode,
    required double cartAmount,
    String? category,
    List<String>? categories,
    String? partnerId,
  }) async {
    final code = voucherCode.trim();
    if (code.isEmpty) {
      return const VoucherValidationResult.invalid('Enter a voucher code');
    }

    final cats = <String>[
      if (categories != null) ...categories.where((c) => c.trim().isNotEmpty),
      if (category != null && category.trim().isNotEmpty) category.trim(),
    ];

    final payload = <String, dynamic>{
      'voucherCode': code,
      'cartAmount': cartAmount,
      if (cats.isNotEmpty) 'categories': cats,
      // Keep singular for older backends that still expect it.
      if (cats.length == 1) 'category': cats.first,
      if (partnerId != null && partnerId.isNotEmpty) 'partnerId': partnerId,
    };

    final response = await _api.post(
      '/vouchers/validate',
      payload,
      requireAuth: true,
    );
    final body = response.data;
    final message =
        (body?['message'] ?? response.message ?? 'Could not validate voucher')
            .toString();

    if (!response.success || body == null || body['success'] != true) {
      return VoucherValidationResult.invalid(message);
    }

    final data = _asMap(body['data']);
    if (data == null) {
      return VoucherValidationResult.invalid(message);
    }

    final result = VoucherValidationResult.fromJson(data);
    if (!result.valid) {
      return VoucherValidationResult.invalid(
        result.message.isNotEmpty ? result.message : message,
      );
    }
    return result.message.isNotEmpty
        ? result
        : VoucherValidationResult(
            valid: result.valid,
            discountAmount: result.discountAmount,
            finalAmount: result.finalAmount,
            message: message,
            voucher: result.voucher,
          );
  }

  /// GET /vouchers/spin-status/:transactionId
  Future<SpinStatus> spinStatus(String transactionId) async {
    final id = transactionId.trim();
    if (id.isEmpty) {
      return const SpinStatus.unavailable(reason: 'Missing transaction');
    }

    final response = await _api.get(
      '/vouchers/spin-status/$id',
      requireAuth: true,
    );
    final body = response.data;
    if (!response.success || body == null) {
      return SpinStatus.unavailable(
        reason: response.message ?? 'Spin not available',
      );
    }

    final data = _asMap(body['data']) ?? body;
    return SpinStatus.fromJson(data);
  }

  /// POST /vouchers/spin/:campaignId
  ///
  /// Sends [deviceId] in the body and relies on [ApiProvider] for
  /// `X-Device-Id` (anti-abuse), per Spin & Win API guide.
  Future<SpinResult> executeSpin({
    required String campaignId,
    required String transactionId,
  }) async {
    final deviceId =
        await _api.deviceIdService?.getPermanentDeviceId() ?? '';
    final response = await _api.post(
      '/vouchers/spin/${campaignId.trim()}',
      {
        'transactionId': transactionId.trim(),
        if (deviceId.isNotEmpty) 'deviceId': deviceId,
      },
      requireAuth: true,
    );
    final body = response.data;
    final message =
        (body?['message'] ?? response.message ?? 'Could not spin').toString();

    if (!response.success || body == null || body['success'] == false) {
      throw Exception(message);
    }

    final data = _asMap(body['data']) ?? body;
    return SpinResult.fromJson(data, fallbackMessage: message);
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
