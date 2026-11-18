import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setgo/src/data/models/partner_inquiry_model.dart';
import 'package:setgo/src/data/models/product_model.dart';
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

class PartnerInquiriesState {
  final List<PartnerInquiryModel> inquiries;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String selectedStatus;
  final String searchQuery;
  final PaginationModel? pagination;
  final String? highlightId;

  const PartnerInquiriesState({
    this.inquiries = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.selectedStatus = 'all',
    this.searchQuery = '',
    this.pagination,
    this.highlightId,
  });

  bool get hasMore {
    final p = pagination;
    if (p == null) return false;
    return p.page < p.pages;
  }

  PartnerInquiriesState copyWith({
    List<PartnerInquiryModel>? inquiries,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    String? selectedStatus,
    String? searchQuery,
    PaginationModel? pagination,
    String? highlightId,
    bool clearHighlight = false,
  }) {
    return PartnerInquiriesState(
      inquiries: inquiries ?? this.inquiries,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      selectedStatus: selectedStatus ?? this.selectedStatus,
      searchQuery: searchQuery ?? this.searchQuery,
      pagination: pagination ?? this.pagination,
      highlightId: clearHighlight ? null : (highlightId ?? this.highlightId),
    );
  }
}

class PartnerInquiriesNotifier extends Notifier<PartnerInquiriesState> {
  bool _fetchInFlight = false;

  @override
  PartnerInquiriesState build() => const PartnerInquiriesState();

  /// Soft highlight for a specific inquiry after notification navigation.
  void setHighlightId(String? id) {
    final trimmed = id?.trim() ?? '';
    state = state.copyWith(
      highlightId: trimmed.isEmpty ? null : trimmed,
      clearHighlight: trimmed.isEmpty,
    );
  }

  Future<void> fetchInquiries({
    String? status,
    String? search,
    int page = 1,
    int limit = 20,
    bool refresh = false,
  }) async {
    if (_fetchInFlight && !refresh) return;
    _fetchInFlight = true;

    final isFirstPage = page <= 1 || refresh;
    state = state.copyWith(
      isLoading: isFirstPage,
      isLoadingMore: !isFirstPage,
      clearError: true,
      selectedStatus: status ?? state.selectedStatus,
      searchQuery: search ?? state.searchQuery,
    );

    try {
      final api = ref.read(apiProvider);
      final queryParams = <String, String>{
        'page': '${isFirstPage ? 1 : page}',
        'limit': '$limit',
      };
      if (state.selectedStatus != 'all' && state.selectedStatus.isNotEmpty) {
        queryParams['status'] = state.selectedStatus;
      }
      if (state.searchQuery.trim().isNotEmpty) {
        queryParams['search'] = state.searchQuery.trim();
      }

      final res = await api.get(
        '/inquiries',
        queryParams: queryParams,
        requireAuth: true,
      );

      if (!res.success || res.data == null) {
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          error: res.message ?? 'Failed to load inquiries',
        );
        return;
      }

      final rawList = res.data!['data'] ?? res.data!['inquiries'];
      final list = <PartnerInquiryModel>[];
      if (rawList is List) {
        for (final item in rawList) {
          final map = SafeParser.asMap(item);
          if (map != null) {
            list.add(PartnerInquiryModel.fromJson(map));
          }
        }
      }

      PaginationModel? pagination;
      final rawPagination = SafeParser.asMap(res.data!['pagination']);
      if (rawPagination != null) {
        pagination = PaginationModel.fromJson(rawPagination);
      }

      state = state.copyWith(
        inquiries: isFirstPage ? list : [...state.inquiries, ...list],
        isLoading: false,
        isLoadingMore: false,
        clearError: true,
        pagination: pagination,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString(),
      );
    } finally {
      _fetchInFlight = false;
    }
  }

  Future<void> refresh() => fetchInquiries(refresh: true, page: 1);

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    final nextPage = (state.pagination?.page ?? 1) + 1;
    await fetchInquiries(page: nextPage);
  }

  Future<void> setStatusFilter(String status) async {
    await fetchInquiries(status: status, page: 1, refresh: true);
  }
}

final partnerInquiriesProvider =
    NotifierProvider<PartnerInquiriesNotifier, PartnerInquiriesState>(
      PartnerInquiriesNotifier.new,
    );

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
    // Keep listing in sync after status changes from the detail page.
    try {
      await _ref.read(partnerInquiriesProvider.notifier).refresh();
    } catch (_) {}

    return ApiResponse.success(updated, res.statusCode);
  }
}

const _allowedStatuses = {'pending', 'contacted', 'completed', 'cancelled'};

final partnerInquiryActionsProvider = Provider<PartnerInquiryActions>((ref) {
  return PartnerInquiryActions(ref);
});
