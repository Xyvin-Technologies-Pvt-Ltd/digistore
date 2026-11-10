import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/category_model.dart';
import '../models/booking_estimate.dart';
import '../models/booking_razorpay_order.dart';
import '../models/service_model.dart';
import '../utils/name_case.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

final selectedProductsTabProvider = StateProvider<int>(
  (ref) => 0,
); // 0: Products, 1: Services
final selectedServicesCategoryProvider = StateProvider<int>((ref) => 0);

final serviceCategoriesProvider = FutureProvider<List<CategoryModel>>((
  ref,
) async {
  final api = ref.watch(publicApiProvider);
  final res = await api.get('/services/categories', requireAuth: false);
  if (res.success && res.data != null) {
    dynamic raw = res.data!['data'] ?? res.data!['categories'] ?? res.data;
    if (raw is Map) {
      raw = raw['categories'] ?? raw['data'] ?? raw['items'];
    }
    if (raw is List) {
      final list = raw
          .whereType<Map>()
          .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
          .where(
            (c) =>
                (c.name != null && c.name!.trim().isNotEmpty) || (c.id != null),
          )
          .toList();
      if (list.isNotEmpty) return list;
    }
  }
  return const [
    CategoryModel(id: 'hair', name: 'Hair'),
    CategoryModel(id: 'facial', name: 'Facial'),
    CategoryModel(id: 'massage', name: 'Massage'),
    CategoryModel(id: 'spa', name: 'Spa'),
    CategoryModel(id: 'auto', name: 'Auto'),
    CategoryModel(id: 'daily_needs', name: 'Daily needs'),
    CategoryModel(id: 'fashion', name: 'Fashion'),
    CategoryModel(id: 'home_services', name: 'Home services'),
  ];
});

class ServicesState {
  final List<ServiceModel> services;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int page;
  final int pages;
  final String? currentCategory;
  final String searchQuery;

  const ServicesState({
    this.services = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.page = 1,
    this.pages = 1,
    this.currentCategory,
    this.searchQuery = '',
  });

  ServicesState copyWith({
    List<ServiceModel>? services,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? page,
    int? pages,
    String? currentCategory,
    bool clearCategory = false,
    String? searchQuery,
  }) {
    return ServicesState(
      services: services ?? this.services,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      page: page ?? this.page,
      pages: pages ?? this.pages,
      currentCategory: clearCategory
          ? null
          : (currentCategory ?? this.currentCategory),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

List<dynamic> _extractServicesList(dynamic root) {
  if (root == null) return [];
  if (root is List) return root;
  if (root is Map) {
    if (root['services'] is List) return root['services'] as List;
    if (root['data'] is List) return root['data'] as List;
    if (root['data'] is Map) {
      final dataMap = root['data'] as Map;
      if (dataMap['services'] is List) return dataMap['services'] as List;
      if (dataMap['data'] is List) return dataMap['data'] as List;
      if (dataMap['items'] is List) return dataMap['items'] as List;
      if (dataMap['list'] is List) return dataMap['list'] as List;
      if (dataMap['results'] is List) return dataMap['results'] as List;
    }
    if (root['items'] is List) return root['items'] as List;
    if (root['list'] is List) return root['list'] as List;
    if (root['results'] is List) return root['results'] as List;
  }
  return [];
}

class ServicesNotifier extends Notifier<ServicesState> {
  @override
  ServicesState build() {
    ref.watch(sessionProvider);
    Future.microtask(() => getServices());
    return const ServicesState();
  }

  Future<void> getServices({
    int page = 1,
    String? category,
    String? search,
    bool isCategoryChange = false,
    bool isRefresh = false,
  }) async {
    final activeCategory = isCategoryChange
        ? category
        : (category ?? state.currentCategory);
    final activeSearch = search ?? state.searchQuery;

    if (page == 1) {
      state = state.copyWith(
        isLoading: true,
        error: null,
        currentCategory: activeCategory,
        clearCategory:
            isCategoryChange &&
            (activeCategory == null || activeCategory == 'All'),
        searchQuery: activeSearch,
        services: isRefresh ? [] : state.services,
      );
    } else {
      state = state.copyWith(isLoadingMore: true, error: null);
    }

    final api = ref.read(publicApiProvider);
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': '20',
    };

    if (activeCategory != null &&
        activeCategory != 'All' &&
        activeCategory.isNotEmpty) {
      queryParams['category'] = activeCategory;
    }
    if (activeSearch.isNotEmpty) {
      queryParams['search'] = activeSearch;
    }

    final res = await api.get(
      '/services',
      queryParams: queryParams,
      requireAuth: false,
    );

    if (res.success && res.data != null) {
      final dynamic rawList = _extractServicesList(res.data);
      final List<ServiceModel> fetched = [];
      for (var item in rawList) {
        if (item is Map) {
          try {
            fetched.add(ServiceModel.fromJson(Map<String, dynamic>.from(item)));
          } catch (e) {
            if (kDebugMode) {
              print('Error parsing ServiceModel: $e for item: $item');
            }
          }
        }
      }

      int totalPages = 1;
      if (res.data is Map) {
        final Map map = res.data as Map;
        final dynamic innerData = map['data'];
        final dynamic pagination =
            map['pagination'] ??
            (innerData is Map ? innerData['pagination'] : null);
        if (pagination is Map) {
          final dynamic rawPages =
              pagination['pages'] ?? pagination['totalPages'];
          if (rawPages is num) {
            totalPages = rawPages.toInt();
          } else if (rawPages != null) {
            totalPages = int.tryParse(rawPages.toString()) ?? 1;
          }
        }
      }

      if (page == 1) {
        state = state.copyWith(
          services: fetched,
          isLoading: false,
          page: 1,
          pages: totalPages,
        );
      } else {
        state = state.copyWith(
          services: [...state.services, ...fetched],
          isLoadingMore: false,
          page: page,
          pages: totalPages,
        );
      }
    } else {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: res.message ?? 'Failed to load services',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || state.page >= state.pages)
      return;
    await getServices(page: state.page + 1);
  }

  Future<void> refresh() async {
    await getServices(page: 1, isRefresh: true);
  }

  void updateSearch(String query) {
    if (query == state.searchQuery) return;
    getServices(page: 1, search: query, isRefresh: true);
  }

  void updateCategory(String? category) {
    getServices(
      page: 1,
      category: category,
      isCategoryChange: true,
      isRefresh: true,
    );
  }
}

final servicesListProvider = NotifierProvider<ServicesNotifier, ServicesState>(
  () {
    return ServicesNotifier();
  },
);

// Partner store specific services — mobile GET /services/partner/:partnerId
// (backend: getPartnerServices / getPartnerServicesPublic).
final storeServicesProvider = FutureProvider.family<List<ServiceModel>, String>((
  ref,
  partnerId,
) async {
  if (partnerId.isEmpty) return [];
  final api = ref.watch(publicApiProvider);
  final res = await api.get('/services/partner/$partnerId', requireAuth: false);
  if (res.success && res.data != null) {
    final root = res.data!;
    final dataNode = root['data'] ?? root;
    final partnerJson = dataNode is Map ? dataNode['partner'] : null;

    final rawList = _extractServicesList(res.data);
    final List<ServiceModel> list = [];
    for (var item in rawList) {
      if (item is Map) {
        try {
          final map = Map<String, dynamic>.from(item);
          // Wrapper partner is not embedded per-service — attach for booking/detail.
          if (partnerJson is Map && map['partner'] == null) {
            map['partner'] = Map<String, dynamic>.from(partnerJson);
          }
          map['partnerId'] ??= partnerId;
          list.add(ServiceModel.fromJson(map));
        } catch (_) {}
      }
    }
    return list;
  }
  return [];
});

/// Shared slots fetch — API expects `serviceIds` (comma-separated), not `serviceId`.
Future<SlotsResponseModel?> _fetchBookingSlots({
  required dynamic api,
  required String partnerId,
  required String date,
  required List<String> serviceIds,
}) async {
  final ids = serviceIds.where((id) => id.trim().isNotEmpty).toList();
  final res = await api.get(
    '/bookings/slots',
    queryParams: {
      if (ids.isNotEmpty) 'serviceIds': ids.join(','),
      if (partnerId.isNotEmpty) 'partnerId': partnerId,
      if (date.isNotEmpty) 'date': date,
    },
    requireAuth: false,
  );
  if (res.success && res.data != null) {
    final data = res.data!['data'] ?? res.data!;
    if (data is Map) {
      return SlotsResponseModel.fromJson(Map<String, dynamic>.from(data));
    }
  }
  return null;
}

List<String> _parseServiceIdsParam(dynamic raw) {
  if (raw is List) {
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  if (raw is String && raw.trim().isNotEmpty) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

// Booking slots family provider (map-based, used by legacy callers)
final bookingSlotsFamily =
    FutureProvider.family<SlotsResponseModel?, Map<String, dynamic>>((
      ref,
      params,
    ) async {
      final api = ref.watch(publicApiProvider);
      final partnerId = params['partnerId']?.toString() ?? '';
      final date = params['date']?.toString() ?? '';
      final serviceIds = params['serviceIds'] != null
          ? _parseServiceIdsParam(params['serviceIds'])
          : _parseServiceIdsParam(params['serviceId']);

      return _fetchBookingSlots(
        api: api,
        partnerId: partnerId,
        date: date,
        serviceIds: serviceIds,
      );
    });

/// Customer booking slots.
/// [serviceIds] is a stable comma-separated key (sorted) so Riverpod family
/// equality works across rebuilds.
final bookingSlotsProvider =
    FutureProvider.family<
      SlotsResponseModel?,
      ({String serviceIds, String partnerId, String date})
    >((ref, params) async {
      final api = ref.watch(publicApiProvider);
      return _fetchBookingSlots(
        api: api,
        partnerId: params.partnerId,
        date: params.date,
        serviceIds: _parseServiceIdsParam(params.serviceIds),
      );
    });

DateTime? _bookingDateTime(BookingModel booking) {
  final date = DateTime.tryParse(booking.date);
  if (date == null) return null;

  final time = booking.timeSlot.trim();
  if (time.isEmpty) {
    // Date-only: keep the booking upcoming for the whole calendar day.
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  final amPm = RegExp(
    r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(time);
  final twentyFour = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(time);

  var hour = 0;
  var minute = 0;
  if (amPm != null) {
    hour = int.tryParse(amPm.group(1)!) ?? 0;
    minute = int.tryParse(amPm.group(2)!) ?? 0;
    final period = amPm.group(3)!.toUpperCase();
    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
  } else if (twentyFour != null) {
    hour = int.tryParse(twentyFour.group(1)!) ?? 0;
    minute = int.tryParse(twentyFour.group(2)!) ?? 0;
  } else {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  return DateTime(date.year, date.month, date.day, hour, minute);
}

/// Client-side filter for My Bookings tabs.
///
/// API booking statuses are PENDING / CONFIRMED / IN_PROGRESS / COMPLETED /
/// CANCELLED / NO_SHOW — not conceptual labels like "upcoming" / "past".
List<BookingModel> _filterCustomerBookings(
  List<BookingModel> bookings,
  String statusFilter,
) {
  final filter = statusFilter.toLowerCase().trim();
  if (filter.isEmpty || filter == 'all') return bookings;

  final now = DateTime.now();

  bool isCancelled(BookingModel b) => b.status.toUpperCase() == 'CANCELLED';

  bool isPast(BookingModel b) {
    final status = b.status.toUpperCase();
    if (status == 'CANCELLED') return false;
    if (status == 'COMPLETED' || status == 'NO_SHOW') return true;
    final dt = _bookingDateTime(b);
    if (dt == null) return false;
    return dt.isBefore(now);
  }

  bool isUpcoming(BookingModel b) {
    if (isCancelled(b) || isPast(b)) return false;
    final status = b.status.toUpperCase();
    return status == 'PENDING' ||
        status == 'CONFIRMED' ||
        status == 'IN_PROGRESS';
  }

  switch (filter) {
    case 'upcoming':
      return bookings.where(isUpcoming).toList();
    case 'past':
      return bookings.where(isPast).toList();
    case 'cancelled':
      return bookings.where(isCancelled).toList();
    default:
      return bookings;
  }
}

// Fetches all customer bookings once; tabs filter client-side.
final allCustomerBookingsProvider = FutureProvider<List<BookingModel>>((
  ref,
) async {
  final api = ref.watch(apiProvider);
  final res = await api.get('/bookings/my-bookings');
  if (res.success && res.data != null) {
    final rawList = _extractServicesList(res.data);
    final List<BookingModel> list = [];
    for (var item in rawList) {
      if (item is Map) {
        try {
          list.add(BookingModel.fromJson(Map<String, dynamic>.from(item)));
        } catch (_) {}
      }
    }
    return list;
  }
  return [];
});

// Customer bookings provider with status filter family
final customerBookingsProvider =
    Provider.family<AsyncValue<List<BookingModel>>, String>((
      ref,
      statusFilter,
    ) {
      final async = ref.watch(allCustomerBookingsProvider);
      return async.whenData(
        (list) => _filterCustomerBookings(list, statusFilter),
      );
    });

class BookingService {
  /// POST /bookings/estimate — server pricing preview (voucher before GST).
  ///
  /// Auth is required when [voucherCode] is sent (voucher ownership check).
  static Future<ApiResponse<BookingEstimate>> estimate({
    required ApiProvider api,
    required String partnerId,
    required List<Map<String, dynamic>> items,
    String? voucherCode,
  }) async {
    final code = voucherCode?.trim();
    final payload = <String, dynamic>{
      'partnerId': partnerId,
      'items': items,
      if (code != null && code.isNotEmpty) 'voucherCode': code,
    };

    final res = await api.post(
      '/bookings/estimate',
      payload,
      requireAuth: code != null && code.isNotEmpty,
    );

    if (res.success && res.data != null) {
      final data = res.data!['data'] ?? res.data!;
      if (data is Map) {
        return ApiResponse.success(
          BookingEstimate.fromJson(
            Map<String, dynamic>.from(data),
            message: res.data!['message']?.toString() ?? res.message,
          ),
        );
      }
    }
    return ApiResponse.error(
      res.message ?? 'Could not estimate booking price',
    );
  }

  static Future<ApiResponse<CreateBookingResult>> createBooking({
    required ApiProvider api,
    String? partnerId,
    List<String>? serviceIds,

    /// Preferred payload: `[{ serviceId, quantity, variantId?, variantName? }]`.
    List<Map<String, dynamic>>? items,
    String? bookingDate,
    String? startTime,
    String? notes,
    String? voucherCode,
    Map<String, dynamic>? bookingData,
  }) async {
    final payload =
        bookingData ??
        {
          'partnerId': partnerId,
          if (items != null && items.isNotEmpty)
            'items': items
          else
            'serviceIds': serviceIds,
          'bookingDate': bookingDate,
          'date': bookingDate,
          'startTime': startTime,
          'timeSlot': startTime,
          // Backend requires online payment for paid slots.
          'paymentMethod': 'online',
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (voucherCode != null && voucherCode.trim().isNotEmpty)
            'voucherCode': voucherCode.trim(),
        };
    final res = await api.post('/bookings', payload);
    if (res.success && res.data != null) {
      final data = res.data!['data'] ?? res.data!;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final booking = BookingModel.fromJson(map);
        BookingRazorpayOrder? order;
        final rawOrder = map['razorpayOrder'] ?? map['razorpay_order'];
        if (rawOrder is Map) {
          order = BookingRazorpayOrder.fromJson(
            Map<String, dynamic>.from(rawOrder),
          );
        }
        return ApiResponse.success(
          CreateBookingResult(booking: booking, razorpayOrder: order),
        );
      }
    }
    return ApiResponse.error(res.message ?? 'Failed to complete booking');
  }

  /// POST /bookings/:id/payment/create-order — recreate Razorpay order for retry.
  static Future<ApiResponse<BookingRazorpayOrder>> createPaymentOrder({
    required ApiProvider api,
    required String bookingId,
  }) async {
    final res = await api.post('/bookings/$bookingId/payment/create-order', {});
    if (res.success && res.data != null) {
      final data = res.data!['data'] ?? res.data!;
      if (data is Map) {
        final order = BookingRazorpayOrder.fromJson(
          Map<String, dynamic>.from(data),
        );
        if (order.isValid) return ApiResponse.success(order);
      }
    }
    return ApiResponse.error(res.message ?? 'Failed to create payment order');
  }

  /// POST /bookings/:id/payment/verify — server-side signature check.
  static Future<ApiResponse<BookingModel>> verifyPayment({
    required ApiProvider api,
    required String bookingId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final res = await api.post('/bookings/$bookingId/payment/verify', {
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    });
    if (res.success && res.data != null) {
      final data = res.data!['data'] ?? res.data!;
      if (data is Map) {
        return ApiResponse.success(
          BookingModel.fromJson(Map<String, dynamic>.from(data)),
        );
      }
    }
    return ApiResponse.error(res.message ?? 'Payment verification failed');
  }

  /// POST /bookings/:id/payment/fail — record cancel / gateway failure.
  static Future<ApiResponse<bool>> failPayment({
    required ApiProvider api,
    required String bookingId,
    String? errorReason,
    int? errorCode,
  }) async {
    final res = await api.post('/bookings/$bookingId/payment/fail', {
      if (errorReason != null && errorReason.isNotEmpty)
        'errorReason': errorReason,
      if (errorCode != null) 'errorCode': errorCode,
    });
    if (res.success) return ApiResponse.success(true);
    return ApiResponse.error(res.message ?? 'Failed to record payment failure');
  }

  static Future<ApiResponse<bool>> cancelBooking({
    required ApiProvider api,
    required String bookingId,
    String? reason,
  }) async {
    final res = await api.post('/bookings/$bookingId/cancel', {
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    if (res.success) {
      return ApiResponse.success(true);
    }
    return ApiResponse.error(res.message ?? 'Failed to cancel booking');
  }
}

class CreateBookingResult {
  final BookingModel booking;
  final BookingRazorpayOrder? razorpayOrder;

  const CreateBookingResult({required this.booking, this.razorpayOrder});

  /// Free bookings are confirmed immediately (no Razorpay).
  bool get requiresPayment =>
      booking.totalAmount > 0 &&
      (razorpayOrder?.isValid == true ||
          booking.paymentStatus.toUpperCase() == 'PENDING');
}
