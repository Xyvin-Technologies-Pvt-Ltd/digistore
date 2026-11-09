import '../models/voucher_models.dart';
import '../providers/api_provider.dart';
import 'referral_store.dart';

class VoucherRepository {
  final ApiProvider _api;
  final ReferralStore _store;

  VoucherRepository(this._api, this._store);

  Future<Map<String, String>> _deviceHeaders() async {
    final deviceId = await _store.deviceId();
    return {'x-device-id': deviceId};
  }

  /// GET /vouchers/my-vouchers?status=active|redeemed|expired
  Future<List<VoucherModel>> myVouchers({String status = 'active'}) async {
    final response = await _api.get(
      '/vouchers/my-vouchers',
      requireAuth: true,
      queryParams: {'status': status},
      headers: await _deviceHeaders(),
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
    String? partnerId,
  }) async {
    final code = voucherCode.trim();
    if (code.isEmpty) {
      return const VoucherValidationResult.invalid('Enter a voucher code');
    }

    final payload = <String, dynamic>{
      'voucherCode': code,
      'cartAmount': cartAmount,
      if (category != null && category.isNotEmpty) 'category': category,
      if (partnerId != null && partnerId.isNotEmpty) 'partnerId': partnerId,
    };

    final response = await _api.post(
      '/vouchers/validate',
      payload,
      requireAuth: true,
      headers: await _deviceHeaders(),
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
    if (id.isEmpty) return const SpinStatus.unavailable();

    final response = await _api.get(
      '/vouchers/spin-status/$id',
      requireAuth: true,
      headers: await _deviceHeaders(),
    );
    final body = response.data;
    if (!response.success || body == null || body['success'] != true) {
      return const SpinStatus.unavailable();
    }
    final data = _asMap(body['data']);
    if (data == null) return const SpinStatus.unavailable();
    return SpinStatus.fromJson(data);
  }

  /// POST /vouchers/spin/:campaignId
  Future<SpinResult?> spin({
    required String campaignId,
    required String transactionId,
  }) async {
    final deviceId = await _store.deviceId();
    final response = await _api.post(
      '/vouchers/spin/$campaignId',
      {
        'transactionId': transactionId,
        'deviceId': deviceId,
      },
      requireAuth: true,
      headers: {'x-device-id': deviceId},
    );
    final body = response.data;
    if (!response.success || body == null || body['success'] != true) {
      return null;
    }
    final data = _asMap(body['data']);
    if (data == null) return null;
    return SpinResult.fromJson(
      data,
      message: body['message']?.toString(),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
