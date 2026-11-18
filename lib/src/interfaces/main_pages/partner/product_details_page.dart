import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/constants/color_constants.dart';
import '../../../data/constants/style_constants.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/shop_model.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/partner_products_provider.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/providers/shops_provider.dart';
import '../../../data/providers/user_type_provider.dart';
import '../../../data/services/toast_service.dart';
import '../../../data/utils/global_variables.dart';
import '../../components/advanced_network_image.dart';
import '../../components/confirmation_dialog.dart';
import '../../components/full_screen_gallery.dart';
import '../../components/guest_login_dialog.dart';
import '../../components/offer_price_row.dart';
import '../../components/offers/redeemable_offers_sheet.dart';
import '../../../data/providers/bulk_redemption_provider.dart';
import 'create_product.dart';

class ProductDetailsPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> product;
  final bool hideShopInfo;

  const ProductDetailsPage({
    super.key,
    required this.product,
    this.hideShopInfo = false,
  });

  @override
  ConsumerState<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends ConsumerState<ProductDetailsPage> {
  bool isNavigatingToShop = false;
  bool isBuying = false;
  int _currentImageIndex = 0;
  String? _selectedVariantId;

  String? get _productId {
    final id = widget.product['_id'] ?? widget.product['id'];
    final s = id?.toString();
    return (s != null && s.isNotEmpty) ? s : null;
  }

  Map<String, dynamic> _mergedProduct(Map<String, dynamic>? fetched) {
    if (fetched == null || fetched.isEmpty) {
      return Map<String, dynamic>.from(widget.product);
    }
    final merged = {...widget.product, ...fetched};

    // Detail API often returns `images: []`, which would wipe images
    // already available from the list/card payload.
    final fetchedImages = fetched['images'];
    final originalImages = widget.product['images'];
    final fetchedEmpty =
        fetchedImages is! List ||
        fetchedImages.where((e) => e.toString().trim().isNotEmpty).isEmpty;
    final originalHas =
        originalImages is List &&
        originalImages.any((e) => e.toString().trim().isNotEmpty);
    if (fetchedEmpty && originalHas) {
      merged['images'] = originalImages;
    }

    final fetchedImage = fetched['image']?.toString().trim() ?? '';
    final originalImage = widget.product['image']?.toString().trim() ?? '';
    if (fetchedImage.isEmpty && originalImage.isNotEmpty) {
      merged['image'] = originalImage;
    }

    return merged;
  }

  ProductModel _asModel(Map<String, dynamic> map) => ProductModel.fromJson(map);

  void _openGallery({
    required List<String> images,
    required String? initialUrl,
  }) {
    if (images.isEmpty) return;
    final initialIndex = initialUrl != null
        ? images.indexOf(initialUrl).clamp(0, images.length - 1)
        : 0;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenGallery(images: images, initialIndex: initialIndex);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _navigateToShop(String shopOrPartnerId) async {
    if (isNavigatingToShop || shopOrPartnerId.isEmpty) return;
    setState(() => isNavigatingToShop = true);
    try {
      final shop = await ref.read(
        getShopByPartnerIdProvider(shopOrPartnerId).future,
      );
      if (!mounted) return;
      if (shop != null) {
        Navigator.of(context).pushNamed('shopDetail', arguments: shop);
      } else {
        ToastService().showToast(
          context,
          'No such shop found for this product.',
          type: ToastType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ToastService().showToast(
        context,
        'Error loading shop: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => isNavigatingToShop = false);
    }
  }

  String _resolveShopId(Map<String, dynamic> product) {
    final directShopId = product['shopId']?.toString();
    if (directShopId != null && directShopId.isNotEmpty) return directShopId;

    final shopObj = product['shop'];
    if (shopObj is Map) {
      final id = shopObj['_id'] ?? shopObj['id'];
      if (id != null && id.toString().isNotEmpty) return id.toString();
    } else if (shopObj is String && shopObj.isNotEmpty) {
      return shopObj;
    }

    final partnerObj = product['partner'] ?? product['partnerId'];
    if (partnerObj is Map) {
      final id = partnerObj['_id'] ?? partnerObj['id'];
      if (id != null && id.toString().isNotEmpty) return id.toString();
    } else if (partnerObj is String && partnerObj.isNotEmpty) {
      return partnerObj;
    }
    return '';
  }

  String _resolveShopAddress(Map<String, dynamic> product, dynamic partnerObj) {
    final branches = product['branchLocations'];
    if (branches is List && branches.isNotEmpty) {
      final first = branches.first;
      if (first is Map) {
        final address = first['address']?.toString() ?? '';
        final city = first['city']?.toString() ?? '';
        final joined = [
          address,
          city,
        ].where((e) => e.trim().isNotEmpty).join(', ');
        if (joined.isNotEmpty) return joined;
      }
    }

    if (partnerObj is Map) {
      final details = partnerObj['businessDetails'];
      if (details is Map) {
        final address = details['address']?.toString() ?? '';
        final city = details['city']?.toString() ?? '';
        final pincode = details['pincode']?.toString() ?? '';
        final joined = [
          address,
          city,
          pincode,
        ].where((e) => e.trim().isNotEmpty).join(', ');
        if (joined.isNotEmpty) return joined;
      }
    }

    return (product['shopAddress'] ?? product['address'] ?? '')
        .toString()
        .trim();
  }

  String _formatMoney(num? value) {
    if (value == null) return '';
    final v = value.toDouble();
    final formatted = v.truncateToDouble() == v
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(2);
    return '₹$formatted';
  }

  String? _offerBadgeText(ProductModel model) {
    if (!model.hasOffer) return null;
    final type = model.offerType?.toLowerCase();
    final value = model.offerValue;
    if (value == null || value <= 0) return 'Offer';
    if (type == 'percentage') {
      final s = value.truncateToDouble() == value
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
      return '$s% OFF';
    }
    return '${_formatMoney(value)} OFF';
  }

  ProductVariant? _selectedVariant(ProductModel model) {
    if (!model.hasVariants || model.variants.isEmpty) return null;
    final id = _selectedVariantId;
    if (id != null) {
      for (final v in model.variants) {
        if (v.id == id) return v;
      }
    }
    return model.variants.first;
  }

  double? _currentPrice(ProductModel model) {
    final variant = _selectedVariant(model);
    if (variant != null) return variant.effectivePrice;
    return model.displayPrice;
  }

  double? _currentBasePrice(ProductModel model) {
    final variant = _selectedVariant(model);
    if (variant != null) return variant.price;
    return model.price;
  }

  bool _currentInStock(ProductModel model) {
    final variant = _selectedVariant(model);
    if (variant != null) return variant.inStock;
    return model.inStock;
  }

  Future<void> _onBuyNow(ProductModel model) async {
    if (isBuying) return;

    if (GlobalVariables.isGuest) {
      GuestLoginDialog.show(
        context,
        title: 'Login Required',
        subtitle: 'Please login to buy this product from the shop.',
      );
      return;
    }

    if (!_currentInStock(model)) {
      ToastService().showToast(
        context,
        'This product is currently out of stock.',
        type: ToastType.error,
      );
      return;
    }

    if (model.hasVariants && model.variants.isNotEmpty) {
      final selected = _selectedVariant(model);
      if (selected == null || selected.id == null) {
        ToastService().showToast(
          context,
          'Please select a variant.',
          type: ToastType.error,
        );
        return;
      }
      if (!selected.inStock) {
        ToastService().showToast(
          context,
          'Selected variant is out of stock.',
          type: ToastType.error,
        );
        return;
      }
    }

    final productId = model.id;
    if (productId == null || productId.isEmpty) {
      ToastService().showToast(
        context,
        'Unable to buy this product right now.',
        type: ToastType.error,
      );
      return;
    }

    setState(() => isBuying = true);
    try {
      final api = ref.read(apiProvider);
      final body = <String, dynamic>{'productId': productId, 'quantity': 1};
      final variant = _selectedVariant(model);
      if (variant?.id != null) {
        body['variantId'] = variant!.id;
      }

      final response = await api.post('/cart/buy-now', body);
      if (!mounted) return;

      if (response.success) {
        final message =
            response.data?['message']?.toString() ??
            response.message ??
            'Inquiry sent to shop owner!';
        ToastService().showToast(context, message, type: ToastType.success);

        // Optional cart ↔ offer linking (Notion §3).
        final data = response.data?['data'];
        final dataMap = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        final cartId = (dataMap['cartId'] ??
                dataMap['_id'] ??
                dataMap['id'] ??
                response.data?['cartId'])
            ?.toString();
        final shopId = _resolveShopId(_mergedProduct(null));
        final partnerId =
            (shopId.isNotEmpty ? shopId : model.partnerId)?.toString() ?? '';
        if (partnerId.isNotEmpty && mounted) {
          await _maybeLinkOffersAfterBuy(
            partnerId: partnerId,
            cartId: cartId,
            shopName: model.title ?? 'Shop',
          );
        }
      } else {
        ToastService().showToast(
          context,
          response.message ?? 'Failed to send buy request.',
          type: ToastType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ToastService().showToast(
        context,
        'Something went wrong. Please try again.',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => isBuying = false);
    }
  }

  Future<void> _maybeLinkOffersAfterBuy({
    required String partnerId,
    String? cartId,
    required String shopName,
  }) async {
    final link = await showConfirmationDialog(
      context: context,
      title: 'Link offers to this order?',
      message:
          'You can attach eligible shop offers to this cart so the merchant '
          'sees them on the inquiry.',
      confirmText: 'Select offers',
      cancelText: 'Skip',
    );
    if (link != true || !mounted) return;

    final selection = await showRedeemableOffersSheet(
      context: context,
      shopId: partnerId,
      shopName: shopName,
      allowAttachToCart: true,
    );
    if (selection == null || !mounted) return;

    try {
      final attached = await ref
          .read(bulkRedemptionRepositoryProvider)
          .updateCartOffers(
            partnerId: partnerId,
            cartId: cartId ?? selection.cartId,
            offerIds: selection.redeemAll ? null : selection.offerIds,
            redeemAll: selection.redeemAll,
          );
      if (!mounted) return;
      ToastService().showToast(
        context,
        attached.message ??
            '${attached.selectedOfferIds.length} offer(s) linked to your order',
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      ToastService().showToast(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userType = ref.watch(userTypeProvider);
    final isPartner = userType == UserType.partner || GlobalVariables.isPartner;
    final screenSize = ref.watch(screenSizeProvider);

    final productId = _productId;
    final detailAsync = productId != null
        ? ref.watch(productDetailProvider(productId))
        : null;
    final productMap = _mergedProduct(detailAsync?.value);
    final model = _asModel(productMap);

    // Default first in-stock variant once data arrives
    if (_selectedVariantId == null &&
        model.hasVariants &&
        model.variants.isNotEmpty) {
      final preferred = model.variants.firstWhere(
        (v) => v.inStock,
        orElse: () => model.variants.first,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectedVariantId != null) return;
        setState(() => _selectedVariantId = preferred.id);
      });
    }

    final partnerObj = productMap['partner'] ?? productMap['partnerId'];
    final String partnerId = (partnerObj is Map)
        ? (partnerObj['_id'] ?? partnerObj['id'] ?? '').toString()
        : (partnerObj?.toString() ?? model.partnerId ?? '');

    final String shopId = _resolveShopId(productMap);
    final String targetShopOrPartnerId = shopId.isNotEmpty ? shopId : partnerId;

    final ShopModel? fetchedShop = targetShopOrPartnerId.isNotEmpty
        ? ref.watch(getShopByPartnerIdProvider(targetShopOrPartnerId)).value
        : null;

    final partnerDetails = partnerObj is Map
        ? partnerObj['businessDetails']
        : null;
    final partnerInfo = partnerObj is Map ? partnerObj['businessInfo'] : null;

    final String rawShopName =
        productMap['shopName']?.toString() ??
        (partnerDetails is Map
            ? partnerDetails['businessName']?.toString()
            : null) ??
        '';
    final String effectiveShopName = rawShopName.isNotEmpty
        ? rawShopName
        : (fetchedShop?.businessDetails?.businessName ?? '');

    final String? rawShopLogo =
        productMap['shopLogo']?.toString() ??
        (partnerInfo is Map ? partnerInfo['businessLogo']?.toString() : null);
    final String? effectiveShopLogo =
        (rawShopLogo != null && rawShopLogo.isNotEmpty)
        ? rawShopLogo
        : (fetchedShop?.businessInfo?.businessLogo ??
              fetchedShop?.businessInfo?.coverImage);

    final String rawShopAddress = _resolveShopAddress(productMap, partnerObj);
    final String effectiveShopAddress = rawShopAddress.isNotEmpty
        ? rawShopAddress
        : (fetchedShop?.businessDetails?.address ?? '');

    final showShop =
        !isPartner &&
        !widget.hideShopInfo &&
        !(productMap['hideShopInfo'] ?? false) &&
        (targetShopOrPartnerId.isNotEmpty || effectiveShopName.isNotEmpty);

    final allImages = <String>[];
    if (model.images != null) {
      allImages.addAll(
        model.images!.map((s) => s.trim()).where((s) => s.isNotEmpty),
      );
    }
    if (allImages.isEmpty) {
      final legacy = productMap['image']?.toString().trim();
      if (legacy != null && legacy.isNotEmpty) allImages.add(legacy);
    }

    final title = model.title ?? '';
    final description = model.description?.trim() ?? '';
    final tags = model.tags ?? const <String>[];
    final categoryName = model.category?.category;
    final subcategories =
        model.category?.subcategories ??
        (model.category?.subcategory != null
            ? [model.category!.subcategory!]
            : <String>[]);

    final currentPrice = _currentPrice(model);
    final basePrice = _currentBasePrice(model);
    final inStock = _currentInStock(model);
    final showStrike =
        basePrice != null && currentPrice != null && basePrice > currentPrice;
    final offerBadge = _offerBadgeText(model);

    final metaChips = <String>[];
    if (model.brand != null && model.brand!.trim().isNotEmpty) {
      metaChips.add(model.brand!.trim());
    }
    if (model.unit != null &&
        model.unit!.trim().isNotEmpty &&
        model.unit!.toLowerCase() != 'piece') {
      metaChips.add(model.unit!.trim());
    }
    if (model.weight != null && model.weight!.trim().isNotEmpty) {
      metaChips.add(model.weight!.trim());
    }
    if (model.sku != null && model.sku!.trim().isNotEmpty) {
      metaChips.add('SKU: ${model.sku!.trim()}');
    }

    final branches = model.branchLocations ?? const [];
    final shopProductsAsync = targetShopOrPartnerId.isNotEmpty
        ? ref.watch(shopProductsProvider(targetShopOrPartnerId))
        : null;

    final isLoadingDetail =
        detailAsync?.isLoading == true &&
        (widget.product['description'] == null ||
            (widget.product['specifications'] == null &&
                widget.product['variants'] == null));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F5F4),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF373737),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Product Details',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: const Color(0xFF373737),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
        actions: isPartner
            ? [
                Container(
                  height: 32,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CreateProductPage(product: productMap),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kPrimaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(
                      'Edit',
                      style: kSmallTitleM.copyWith(color: kPrimaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 32,
                  width: 32,
                  margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                      size: 18,
                    ),
                    onPressed: () async {
                      final confirm = await showConfirmationDialog(
                        context: context,
                        title: 'Delete Product',
                        message:
                            'Are you sure you want to delete this product?',
                        confirmText: 'Delete',
                        isDestructive: true,
                        onConfirm: () async {
                          try {
                            await ref
                                .read(partnerProductsProvider.notifier)
                                .deleteProduct(
                                  productMap['_id'] ?? productMap['id'],
                                );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                      );
                      if (confirm == true && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Image carousel ───────────────────────────────────
                  GestureDetector(
                    onTap: allImages.isNotEmpty
                        ? () => _openGallery(
                            images: allImages,
                            initialUrl:
                                allImages[_currentImageIndex.clamp(
                                  0,
                                  allImages.length - 1,
                                )],
                          )
                        : null,
                    child: Container(
                      width: double.infinity,
                      height: screenSize.responsivePadding(320),
                      color: const Color(0xFFE5E7EB),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (allImages.isNotEmpty)
                            CarouselSlider(
                              options: CarouselOptions(
                                height: screenSize.responsivePadding(320),
                                viewportFraction: 1.0,
                                enableInfiniteScroll: allImages.length > 1,
                                autoPlay: allImages.length > 1,
                                autoPlayInterval: const Duration(seconds: 4),
                                onPageChanged: (index, reason) {
                                  setState(() => _currentImageIndex = index);
                                },
                              ),
                              items: allImages
                                  .map(
                                    (img) => AdvancedNetworkImage(
                                      imageUrl: img,
                                      fit: BoxFit.cover,
                                      borderRadius: BorderRadius.zero,
                                      disableFade: true,
                                    ),
                                  )
                                  .toList(),
                            )
                          else
                            const Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 48,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          if (offerBadge != null)
                            Positioned(
                              top: 12,
                              left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF07982C),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  offerBadge,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          if (allImages.length > 1)
                            Positioned(
                              bottom: 14,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: allImages.asMap().entries.map((e) {
                                  final active = _currentImageIndex == e.key;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    width: active ? 18 : 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3),
                                      color: active
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.5),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          if (isLoadingDetail)
                            const Positioned(
                              top: 12,
                              right: 16,
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ── Title / price / stock ────────────────────────────
                  _sectionCard(
                    screenSize,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (categoryName != null &&
                            categoryName.trim().isNotEmpty) ...[
                          Text(
                            categoryName.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: const Color(0xFF07838C),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                            height: 1.25,
                          ),
                        ),
                        if (metaChips.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: metaChips
                                .map(
                                  (c) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F5F4),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Text(
                                      c,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF374151),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (currentPrice != null && currentPrice > 0)
                              showStrike
                                  ? OfferPriceRow(
                                      offerPrice: _formatMoney(currentPrice),
                                      originalPrice: _formatMoney(basePrice),
                                      gap: screenSize.responsivePadding(8),
                                    )
                                  : Text(
                                      _formatMoney(currentPrice),
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF07838C),
                                        height: 1,
                                      ),
                                    ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: inStock
                                    ? const Color(0xFFDEF7EC)
                                    : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                inStock ? 'In Stock' : 'Out of Stock',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: inStock
                                      ? const Color(0xFF03543F)
                                      : const Color(0xFF991B1B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (subcategories.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: subcategories
                                .map(
                                  (s) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      s,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF6155F5),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Variants ─────────────────────────────────────────
                  if (model.hasVariants && model.variants.isNotEmpty) ...[
                    _separator(),
                    _sectionCard(
                      screenSize,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Select Option', style: _sectionTitleStyle()),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: model.variants.map((v) {
                              final selected =
                                  _selectedVariant(model)?.id == v.id;
                              final disabled = !v.inStock;
                              return GestureDetector(
                                onTap: disabled
                                    ? null
                                    : () => setState(
                                        () => _selectedVariantId = v.id,
                                      ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(
                                            0xFF07838C,
                                          ).withValues(alpha: 0.1)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFF07838C)
                                          : const Color(0xFFE5E7EB),
                                      width: selected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        v.name?.isNotEmpty == true
                                            ? v.name!
                                            : 'Option',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: disabled
                                              ? const Color(0xFF9CA3AF)
                                              : const Color(0xFF111827),
                                          decoration: disabled
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        disabled
                                            ? 'Out of stock'
                                            : _formatMoney(v.effectivePrice),
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: disabled
                                              ? const Color(0xFF9CA3AF)
                                              : const Color(0xFF07838C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Description ──────────────────────────────────────
                  if (description.isNotEmpty) ...[
                    _separator(),
                    _sectionCard(
                      screenSize,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'About this product',
                            style: _sectionTitleStyle(),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            description,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF4B5563),
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Specifications ───────────────────────────────────
                  if (model.specifications.isNotEmpty) ...[
                    _separator(),
                    _sectionCard(
                      screenSize,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Specifications', style: _sectionTitleStyle()),
                          const SizedBox(height: 12),
                          ...model.specifications.asMap().entries.map((entry) {
                            final i = entry.key;
                            final spec = entry.value;
                            final odd = i.isOdd;
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              color: odd
                                  ? const Color(0xFFF9FAFB)
                                  : Colors.white,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      spec.key,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      spec.value,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

                  // ── Available at ─────────────────────────────────────
                  if (branches.isNotEmpty) ...[
                    _separator(),
                    _sectionCard(
                      screenSize,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Available At', style: _sectionTitleStyle()),
                          const SizedBox(height: 14),
                          ...branches.asMap().entries.map((entry) {
                            final branch = entry.value;
                            if (branch is! Map) {
                              return const SizedBox.shrink();
                            }
                            final name =
                                branch['branchName']?.toString() ?? 'Branch';
                            final address = branch['address']?.toString() ?? '';
                            final city = branch['city']?.toString() ?? '';
                            final district =
                                branch['district']?.toString() ?? '';
                            final location = [
                              address,
                              city,
                              district,
                            ].where((e) => e.trim().isNotEmpty).join(', ');
                            final isLast = entry.key == branches.length - 1;
                            return Padding(
                              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF07838C,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.location_on_outlined,
                                      size: 18,
                                      color: Color(0xFF07838C),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF111827),
                                          ),
                                        ),
                                        if (location.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            location,
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 12,
                                              color: const Color(0xFF6B7280),
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

                  // ── Tags ─────────────────────────────────────────────
                  if (tags.isNotEmpty) ...[
                    _separator(),
                    _sectionCard(
                      screenSize,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tags', style: _sectionTitleStyle()),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: tags
                                .map(
                                  (tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F5F4),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Text(
                                      tag,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: const Color(0xFF07838C),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Shop card ────────────────────────────────────────
                  if (showShop) ...[
                    _separator(),
                    _sectionCard(
                      screenSize,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sold by', style: _sectionTitleStyle()),
                          const SizedBox(height: 12),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: targetShopOrPartnerId.isNotEmpty
                                  ? () => _navigateToShop(targetShopOrPartnerId)
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F5F4),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child:
                                          effectiveShopLogo != null &&
                                              effectiveShopLogo.isNotEmpty
                                          ? AdvancedNetworkImage(
                                              imageUrl: effectiveShopLogo,
                                              fit: BoxFit.cover,
                                              disableFade: true,
                                            )
                                          : const Icon(
                                              Icons.storefront,
                                              color: Color(0xFF07838C),
                                              size: 22,
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            effectiveShopName.isNotEmpty
                                                ? effectiveShopName
                                                : 'Partner Shop',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF111827),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (effectiveShopAddress
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              effectiveShopAddress,
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 12,
                                                color: const Color(0xFF4B5563),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (isNavigatingToShop)
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF07838C),
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Color(0xFF4B5563),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Related ──────────────────────────────────────────
                  if (shopProductsAsync != null)
                    shopProductsAsync.when(
                      data: (shopProducts) {
                        final related = shopProducts
                            .where((p) => p.id != null && p.id != model.id)
                            .toList();
                        if (related.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _separator(),
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                screenSize.responsivePadding(20),
                                screenSize.responsivePadding(20),
                                screenSize.responsivePadding(20),
                                screenSize.responsivePadding(12),
                              ),
                              child: Text(
                                'You May Also Like',
                                style: _sectionTitleStyle(),
                              ),
                            ),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                screenSize.responsivePadding(20),
                                0,
                                screenSize.responsivePadding(20),
                                screenSize.responsivePadding(16),
                              ),
                              itemCount: related.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: screenSize
                                        .responsivePadding(12),
                                    mainAxisSpacing: screenSize
                                        .responsivePadding(12),
                                    childAspectRatio: 0.72,
                                  ),
                              itemBuilder: (context, index) {
                                return _buildRecommendationCard(
                                  context,
                                  related[index],
                                  screenSize,
                                );
                              },
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),

                  SizedBox(height: screenSize.responsivePadding(24)),
                ],
              ),
            ),
          ),

          // ── Bottom CTA (customers) ─────────────────────────────────
          if (!isPartner)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                screenSize.responsivePadding(16),
                12,
                screenSize.responsivePadding(16),
                MediaQuery.of(context).padding.bottom > 0
                    ? MediaQuery.of(context).padding.bottom + 8
                    : 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Price',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (currentPrice != null && currentPrice > 0)
                          showStrike
                              ? OfferPriceRow(
                                  offerPrice: _formatMoney(currentPrice),
                                  originalPrice: _formatMoney(basePrice),
                                  gap: 8,
                                  offerFontSize: 18,
                                  originalFontSize: 13,
                                )
                              : Text(
                                  _formatMoney(currentPrice),
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF07838C),
                                  ),
                                )
                        else
                          Text(
                            '—',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF07838C),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: !inStock || isBuying
                          ? null
                          : () => _onBuyNow(model),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF07838C),
                        disabledBackgroundColor: const Color(
                          0xFF07838C,
                        ).withValues(alpha: 0.4),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isBuying
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              inStock ? 'I Want to Buy This' : 'Out of Stock',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  TextStyle _sectionTitleStyle() {
    return TextStyle(
      fontFamily: 'Poppins',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: const Color(0xFF111827),
    );
  }

  Widget _separator() {
    return const SizedBox(
      width: double.infinity,
      height: 8,
      child: ColoredBox(color: Color(0xFFF3F5F4)),
    );
  }

  Widget _sectionCard(ScreenSizeData screenSize, {required Widget child}) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.all(screenSize.responsivePadding(20)),
      child: child,
    );
  }

  Widget _buildRecommendationCard(
    BuildContext context,
    ProductModel productModel,
    ScreenSizeData screenSize,
  ) {
    final title = productModel.title ?? '';
    final price = productModel.displayPrice ?? productModel.price;
    final image = productModel.images?.isNotEmpty == true
        ? productModel.images!.first
        : null;
    final formattedPrice = price != null && price > 0
        ? _formatMoney(price)
        : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    ProductDetailsPage(
                      product: productModel.toJson(),
                      hideShopInfo: widget.hideShopInfo,
                    ),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      final curve = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      );
                      return FadeTransition(
                        opacity: curve,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).animate(curve),
                          child: child,
                        ),
                      );
                    },
                transitionDuration: const Duration(milliseconds: 260),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(screenSize.responsivePadding(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: image != null && image.isNotEmpty
                          ? AdvancedNetworkImage(
                              imageUrl: image,
                              fit: BoxFit.cover,
                              disableFade: true,
                            )
                          : Container(
                              color: const Color(0xFFF3F5F4),
                              child: const Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  color: Color(0xFF9CA3AF),
                                  size: 28,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                SizedBox(height: screenSize.responsivePadding(8)),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: screenSize.responsivePadding(4)),
                if (formattedPrice.isNotEmpty)
                  Text(
                    formattedPrice,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF07838C),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
