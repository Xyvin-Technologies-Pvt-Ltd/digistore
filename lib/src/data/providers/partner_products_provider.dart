import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/product_model.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

part 'partner_products_provider.g.dart';

class PartnerProductsState {
  final List<ProductModel> products;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final PaginationModel? pagination;
  final String searchQuery;
  final String? currentCategoryId;
  final num? minPrice;
  final num? maxPrice;
  final String? tags;
  final String? partnerId;
  final String? sortBy;
  final double? lat;
  final double? lng;
  final bool? inStock;
  final bool? isActive;
  final String? sortOrder;

  PartnerProductsState({
    this.products = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.pagination,
    this.searchQuery = '',
    this.currentCategoryId,
    this.minPrice,
    this.maxPrice,
    this.tags,
    this.partnerId,
    this.sortBy,
    this.lat,
    this.lng,
    this.inStock,
    this.isActive,
    this.sortOrder,
  });

  PartnerProductsState copyWith({
    List<ProductModel>? products,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    PaginationModel? pagination,
    String? searchQuery,
    String? Function()? currentCategoryId,
    num? Function()? minPrice,
    num? Function()? maxPrice,
    String? Function()? tags,
    String? Function()? partnerId,
    String? Function()? sortBy,
    double? Function()? lat,
    double? Function()? lng,
    bool? Function()? inStock,
    bool? Function()? isActive,
    String? Function()? sortOrder,
  }) {
    return PartnerProductsState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error ?? this.error,
      pagination: pagination ?? this.pagination,
      searchQuery: searchQuery ?? this.searchQuery,
      currentCategoryId: currentCategoryId != null
          ? currentCategoryId()
          : this.currentCategoryId,
      minPrice: minPrice != null ? minPrice() : this.minPrice,
      maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
      tags: tags != null ? tags() : this.tags,
      partnerId: partnerId != null ? partnerId() : this.partnerId,
      sortBy: sortBy != null ? sortBy() : this.sortBy,
      lat: lat != null ? lat() : this.lat,
      lng: lng != null ? lng() : this.lng,
      inStock: inStock != null ? inStock() : this.inStock,
      isActive: isActive != null ? isActive() : this.isActive,
      sortOrder: sortOrder != null ? sortOrder() : this.sortOrder,
    );
  }
}

@Riverpod(keepAlive: true)
class PartnerProducts extends _$PartnerProducts {
  @override
  PartnerProductsState build() {
    ref.watch(sessionProvider);
    // Initial fetch
    Future.microtask(() => getProducts());
    return PartnerProductsState();
  }

  Future<void> getProducts({
    int page = 1,
    int limit = 20,
    String? search,
    String? categoryId,
    num? minPrice,
    num? maxPrice,
    String? tags,
    String? partnerId,
    String? sortBy,
    double? lat,
    double? lng,
    bool? inStock,
    bool? isActive,
    String? sortOrder,
    bool isRefresh = true,
  }) async {
    final currentSearch = search ?? state.searchQuery;
    final isCategoryChange = categoryId != state.currentCategoryId;

    final effectiveMinPrice = minPrice ?? state.minPrice;
    final effectiveMaxPrice = maxPrice ?? state.maxPrice;
    final effectiveTags = tags ?? state.tags;
    final effectivePartnerId = partnerId ?? state.partnerId;
    final effectiveSortBy = sortBy ?? state.sortBy;
    final effectiveLat = lat ?? state.lat;
    final effectiveLng = lng ?? state.lng;
    final effectiveInStock = inStock ?? state.inStock;
    final effectiveIsActive = isActive ?? state.isActive;
    final effectiveSortOrder = sortOrder ?? state.sortOrder;

    if (page == 1) {
      state = state.copyWith(
        isLoading: true,
        error: null,
        searchQuery: currentSearch,
        products: (search != null || isCategoryChange) ? [] : state.products,
        currentCategoryId: () => categoryId ?? state.currentCategoryId,
        minPrice: () => effectiveMinPrice,
        maxPrice: () => effectiveMaxPrice,
        tags: () => effectiveTags,
        partnerId: () => effectivePartnerId,
        sortBy: () => effectiveSortBy,
        lat: () => effectiveLat,
        lng: () => effectiveLng,
        inStock: () => effectiveInStock,
        isActive: () => effectiveIsActive,
        sortOrder: () => effectiveSortOrder,
      );
    } else {
      state = state.copyWith(isLoadingMore: true, error: null);
    }

    final api = ref.read(apiProvider);
    final queryParams = {
      'page': page.toString(),
      'limit': limit.clamp(1, 100).toString(),
    };
    if (currentSearch.isNotEmpty) {
      queryParams['search'] = currentSearch;
    }
    final activeCategoryId = categoryId ?? state.currentCategoryId;
    if (activeCategoryId != null &&
        activeCategoryId != 'All' &&
        activeCategoryId.isNotEmpty) {
      queryParams['category'] = activeCategoryId;
    }
    if (effectiveMinPrice != null) {
      queryParams['minPrice'] = effectiveMinPrice.toString();
    }
    if (effectiveMaxPrice != null) {
      queryParams['maxPrice'] = effectiveMaxPrice.toString();
    }
    if (effectiveTags != null && effectiveTags.trim().isNotEmpty) {
      queryParams['tags'] = effectiveTags.trim();
    }
    if (effectivePartnerId != null && effectivePartnerId.trim().isNotEmpty) {
      queryParams['partnerId'] = effectivePartnerId.trim();
    }
    if (effectiveSortBy != null && effectiveSortBy.trim().isNotEmpty) {
      queryParams['sortBy'] = effectiveSortBy.trim();
    }
    if (effectiveLat != null) {
      queryParams['lat'] = effectiveLat.toString();
    }
    if (effectiveLng != null) {
      queryParams['lng'] = effectiveLng.toString();
    }
    if (effectiveInStock != null) {
      queryParams['inStock'] = effectiveInStock.toString();
    }
    if (effectiveIsActive != null) {
      queryParams['isActive'] = effectiveIsActive.toString();
    }
    if (effectiveSortOrder != null && effectiveSortOrder.trim().isNotEmpty) {
      queryParams['sortOrder'] = effectiveSortOrder.trim();
    }

    final response = await api.get('/products', queryParams: queryParams);

    if (response.success && response.data != null) {
      final productResponse = ProductResponse.fromJson(response.data!);
      if (page == 1) {
        state = state.copyWith(
          products: productResponse.data,
          pagination: productResponse.pagination,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          products: [...state.products, ...productResponse.data],
          pagination: productResponse.pagination,
          isLoadingMore: false,
        );
      }
    } else {
      state = state.copyWith(
        error: response.message ?? 'Failed to load products',
        isLoading: false,
        isLoadingMore: false,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.pagination == null) return;
    if (state.pagination!.page >= state.pagination!.pages) return;

    await getProducts(page: state.pagination!.page + 1);
  }

  Future<void> refresh() async {
    await getProducts(page: 1);
  }

  void updateSearch(String query) {
    if (state.searchQuery == query) return;
    getProducts(page: 1, search: query);
  }

  void addProduct(ProductModel product) {
    state = state.copyWith(
      products: [product, ...state.products],
      pagination: state.pagination?.copyWith(
        total: (state.pagination?.total ?? 0) + 1,
      ),
    );
  }

  void updateProductLocally(ProductModel updatedProduct) {
    final index = state.products.indexWhere((p) => p.id == updatedProduct.id);
    if (index != -1) {
      final newProducts = List<ProductModel>.from(state.products);
      newProducts[index] = updatedProduct;
      state = state.copyWith(products: newProducts);
    }
  }

  void removeProductLocally(String id) {
    state = state.copyWith(
      products: state.products.where((p) => p.id != id).toList(),
      pagination: state.pagination?.copyWith(
        total: (state.pagination?.total ?? 1) - 1,
      ),
    );
  }

  Future<void> deleteProduct(String id) async {
    final api = ref.read(apiProvider);
    final response = await api.delete('/products/$id');
    if (response.success) {
      removeProductLocally(id);
    } else {
      throw Exception(response.message ?? 'Failed to delete product');
    }
  }
}

/// Fetches full product detail from `GET /products/:id`
/// (consumer: `/api/mobile/products/:id`, partner: `/api/mobile/partner/products/:id`).
final productDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((
      ref,
      productId,
    ) async {
      if (productId.isEmpty) return null;
      final api = ref.read(apiProvider);
      final response = await api.get('/products/$productId');
      if (response.success && response.data != null) {
        final data = response.data!['data'];
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
      }
      return null;
    });
