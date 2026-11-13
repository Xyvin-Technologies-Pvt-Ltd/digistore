import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setgo/src/data/models/partner_inquiry_model.dart';
import 'package:setgo/src/utils/safe_parser.dart';
import 'api_provider.dart';

/// Fetches a single partner inquiry by id (notification `targetId` / `cartId`).
final partnerInquiryDetailProvider =
    FutureProvider.autoDispose.family<PartnerInquiryModel?, String>((
      ref,
      inquiryId,
    ) async {
      final trimmed = inquiryId.trim();
      if (trimmed.isEmpty) return null;

      final api = ref.watch(apiProvider);
      final res = await api.get(
        '/inquiries/$trimmed',
        requireAuth: true,
      );

      if (!res.success || res.data == null) {
        throw PartnerInquiryException(
          res.message ?? 'Failed to load inquiry',
          statusCode: res.statusCode,
        );
      }

      final map = SafeParser.asMap(res.data!['data']) ??
          SafeParser.asMap(res.data!) ??
          SafeParser.asMap(res.data!['inquiry']);
      if (map == null) {
        throw PartnerInquiryException(
          'Invalid inquiry response',
          statusCode: res.statusCode,
        );
      }

      final inquiry = PartnerInquiryModel.fromJson(map);
      if (inquiry.id.isEmpty) {
        return inquiry.copyWith(id: trimmed);
      }
      return inquiry;
    });

class PartnerInquiryException implements Exception {
  final String message;
  final int? statusCode;

  const PartnerInquiryException(this.message, {this.statusCode});

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

class PartnerInquiryActions {
  PartnerInquiryActions(this._ref);

  final Ref _ref;

  Future<ApiResponse<PartnerInquiryModel?>> updateStatus({
    required String inquiryId,
    required String status,
  }) async {
    final id = inquiryId.trim();
    final normalized = status.trim().toLowerCase();
    if (id.isEmpty) {
      return ApiResponse.error('Invalid inquiry');
    }
    if (!_allowedStatuses.contains(normalized)) {
      return ApiResponse.error('Unsupported status: $status');
    }

    final api = _ref.read(apiProvider);
    final res = await api.patch(
      '/inquiries/$id/status',
      {'status': normalized},
      requireAuth: true,
    );

    if (!res.success) {
      return ApiResponse.error(
        res.message ?? 'Failed to update inquiry status',
        res.statusCode,
      );
    }

    PartnerInquiryModel? updated;
    final map = SafeParser.asMap(res.data?['data']) ??
        SafeParser.asMap(res.data) ??
        SafeParser.asMap(res.data?['inquiry']);
    if (map != null) {
      updated = PartnerInquiryModel.fromJson(map);
    }

    _ref.invalidate(partnerInquiryDetailProvider(id));
    return ApiResponse.success(updated, res.statusCode);
  }
}

const _allowedStatuses = {'pending', 'contacted', 'completed', 'cancelled'};

final partnerInquiryActionsProvider = Provider<PartnerInquiryActions>((ref) {
  return PartnerInquiryActions(ref);
});
