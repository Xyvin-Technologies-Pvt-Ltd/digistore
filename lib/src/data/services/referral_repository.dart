import '../models/referral_models.dart';
import '../providers/api_provider.dart';
import '../utils/referral_code.dart';
import 'referral_store.dart';

class ReferralRepository {
  final ApiProvider _api;
  final ReferralStore _store;

  ReferralRepository(this._api, this._store);

  Future<ResolvePendingResult> resolvePending() async {
    final response = await _api.get(
      '/referral/resolve-pending',
      requireAuth: false,
    );
    final body = response.data;
    if (!response.success || body == null || body['success'] != true) {
      return const ResolvePendingResult(answered: false);
    }
    final data = _asMap(body['data']);
    if (data?['found'] == true) {
      final code = ReferralCode.normalize(data?['referralCode']?.toString());
      return ResolvePendingResult(answered: true, code: code);
    }
    return const ResolvePendingResult(answered: true);
  }

  Future<ReferralValidation> validate(String code) async {
    final normalized = ReferralCode.normalize(code);
    if (normalized == null) {
      return const ReferralValidation.invalid('Invalid referral code');
    }

    final response = await _api.get(
      '/referral/validate/$normalized',
      requireAuth: false,
    );
    final body = response.data;
    final data = _asMap(body?['data']);
    final message = (body?['message'] ?? response.message ?? 'Invalid referral code')
        .toString();
    final valid = data?['valid'] == true;
    if (response.success && body?['success'] == true && valid) {
      return ReferralValidation(
        valid: true,
        code: ReferralCode.normalize(data?['referralCode']?.toString()) ??
            normalized,
        referrerName: data?['referrerName']?.toString(),
        message: message,
      );
    }
    return ReferralValidation.invalid(message);
  }

  Future<ReferralApplyResult> apply(String code) async {
    final normalized = ReferralCode.normalize(code);
    if (normalized == null) {
      return const ReferralApplyResult(
        applied: false,
        alreadyApplied: false,
        message: 'Invalid referral code',
      );
    }

    final deviceId = await _store.deviceId();
    final response = await _api.post(
      '/referral/apply',
      {
        'referralCode': normalized,
        'deviceId': deviceId,
      },
      requireAuth: true,
      headers: {'x-device-id': deviceId},
    );
    final body = response.data;
    final message =
        (body?['message'] ?? response.message ?? 'Could not apply referral code')
            .toString();
    final lower = message.toLowerCase();
    final alreadyApplied =
        lower.contains('already applied') || lower.contains('already received');
    final data = _asMap(body?['data']);
    final applied = response.success && body?['success'] == true;
    return ReferralApplyResult(
      applied: applied,
      alreadyApplied: alreadyApplied,
      message: message,
      referrerName: data?['referrerName']?.toString(),
      pointsAwarded: _asIntOrNull(data?['pointsAwarded']),
    );
  }

  Future<ReferralSharePayload?> myCode() async {
    final response = await _api.get('/referral/my-code', requireAuth: true);
    final body = response.data;
    final data = _asMap(body?['data']);
    if (!response.success || body?['success'] == false || data == null) {
      return null;
    }
    final payload = ReferralSharePayload.fromJson(data);
    if (payload.referralCode.isEmpty) return null;
    return payload;
  }

  Future<ReferralHistoryPage> history({int page = 1, int limit = 20}) async {
    final response = await _api.get(
      '/referral/history',
      requireAuth: true,
      queryParams: {'page': '$page', 'limit': '$limit'},
    );
    final body = response.data;
    final data = _asMap(body?['data']);
    if (!response.success || data == null) {
      return ReferralHistoryPage(items: const [], page: page, totalPages: page);
    }
    final rawItems = data['items'];
    final items = <ReferralHistoryEntry>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        final map = _asMap(item);
        if (map != null) items.add(ReferralHistoryEntry.fromJson(map));
      }
    }
    final pagination = _asMap(data['pagination']);
    return ReferralHistoryPage(
      items: items,
      page: _asIntOrNull(pagination?['page']) ?? page,
      totalPages: _asIntOrNull(pagination?['totalPages']) ?? page,
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static int? _asIntOrNull(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
