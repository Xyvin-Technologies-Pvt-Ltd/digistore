import 'package:setgo/src/data/constants/color_constants.dart';
import 'package:setgo/src/data/providers/screen_size_provider.dart';
import 'package:setgo/src/data/models/shop_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/shops/shop_header.dart';
import '../../components/shops/shop_about.dart';
import '../../components/shops/shop_gallery.dart';
import '../../components/shops/shop_hero_media.dart';
import '../../components/shops/shop_address.dart';
import '../../components/shops/shop_reviews.dart';
import '../../components/shops/shop_socials.dart';
import '../../components/shops/shop_operating_hours.dart';
import '../../components/shops/shop_faqs.dart';
import '../../components/offers/deal_card.dart';
import '../../components/shops/product_card.dart';
import '../../components/services/service_card.dart';
import '../../../data/providers/shops_provider.dart';
import '../../../data/providers/services_provider.dart';
import '../../../data/providers/bulk_redemption_provider.dart';
import '../../../data/models/service_model.dart';
import '../services/service_details_page.dart';

import '../../components/shops/shop_branches.dart';
import '../../../../src/data/models/business_info.dart';
import '../../../data/providers/branches.dart';
import '../../components/primary_button.dart';
import '../../components/offers/redeemable_offers_sheet.dart';

class ShopDetailPage extends ConsumerStatefulWidget {
  final String? shopName;
  final ShopModel? shop;

  const ShopDetailPage({super.key, this.shopName, this.shop});

  @override
  ConsumerState<ShopDetailPage> createState() => _ShopDetailPageState();
}

class _ShopDetailPageState extends ConsumerState<ShopDetailPage> {
  BusinessBranch? _selectedBranch;

  @override
  void didUpdateWidget(ShopDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shop?.id != widget.shop?.id) {
      _selectedBranch = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    final shopId = widget.shop?.id ?? '';

    // Listen to branches provider to set the initial selected branch to the primary one
    if (shopId.isNotEmpty) {
      ref.listen<AsyncValue<List<BusinessBranch>>>(
        shopBranchesProvider(shopId),
        (previous, next) {
          if (next.hasValue && _selectedBranch == null) {
            final list = next.value ?? [];
            if (list.isNotEmpty) {
              final primary = list.firstWhere(
                (b) => b.isPrimary == true,
                orElse: () => list.first,
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _selectedBranch = primary;
                  });
                }
              });
            }
          }
        },
      );
    }
    // Featured shops return a minimal payload (no address, no branches, no contact info)
    // Full shops return complete nested objects.
    final needsFetch =
        widget.shop == null ||
        (widget.shop!.businessDetails?.address == null &&
            widget.shop!.businessInfo?.contactPhone == null &&
            (widget.shop!.businessInfo?.branches == null ||
                widget.shop!.businessInfo!.branches!.isEmpty));

    final fullShopAsync = (shopId.isNotEmpty && needsFetch)
        ? ref.watch(getShopByPartnerIdProvider(shopId))
        : null;
    final currentShop = fullShopAsync?.value ?? widget.shop;

    final currentShopName =
        currentShop?.businessDetails?.businessName ??
        widget.shopName ??
        'Unknown Shop';
    final heroMedia =
        currentShop?.businessInfo?.heroMedia ?? const <BusinessMediaItem>[];
    final galleryMedia =
        currentShop?.businessInfo?.galleryMedia ?? const <BusinessMediaItem>[];

    final offersAsync = shopId.isNotEmpty
        ? ref.watch(shopOffersProvider(shopId))
        : null;
    final offersBundleAsync = shopId.isNotEmpty
        ? ref.watch(shopOffersBundleProvider(shopId))
        : null;
    final productsAsync = shopId.isNotEmpty
        ? ref.watch(shopProductsProvider(shopId))
        : null;
    // Shop id === partner id in mobile shops API; same source as getPartnerServicesPublic.
    final servicesAsync = shopId.isNotEmpty
        ? ref.watch(storeServicesProvider(shopId))
        : null;

    final category = currentShop?.serviceCategories?.isNotEmpty == true
        ? currentShop!.serviceCategories!.first
        : (currentShop?.businessDetails?.businessType ?? 'General');

    // Food / Restaurants / Cafes — same group as the home restaurant banner.
    final isFoodOrRestaurantShop =
        currentShop != null && isShopInCategory(currentShop, 'Restaurants');
    final servicesSectionTitle = isFoodOrRestaurantShop
        ? 'Menu'
        : 'Explore Services';
    final servicesModalTitle = isFoodOrRestaurantShop
        ? 'Menu'
        : 'Explore Services';

    return Scaffold(
      backgroundColor: kWhite,
      body: fullShopAsync?.isLoading == true && widget.shop == null
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: screenSize.responsivePadding(210),
                  scrolledUnderElevation: 0,
                  floating: false,
                  pinned: true,
                  backgroundColor: kWhite,
                  elevation: 0,
                  leading: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Color(0xFF111827),
                          size: 16,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        ShopHeroMedia(
                          media: heroMedia,
                          height: screenSize.responsivePadding(210) +
                              MediaQuery.paddingOf(context).top,
                        ),
                        Positioned(
                          top: MediaQuery.paddingOf(context).top + 10,
                          right: 16,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenSize.responsivePadding(10),
                              vertical: screenSize.responsivePadding(5),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF292929),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(screenSize.responsivePadding(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShopHeader(
                          shopName: currentShopName,
                          shop: currentShop,
                          selectedBranch: _selectedBranch,
                        ),
                        SizedBox(height: screenSize.responsivePadding(16)),
                        ShopBranches(
                          shopId: shopId,
                          selectedBranch: _selectedBranch,
                          onBranchSelected: (branch) {
                            setState(() {
                              _selectedBranch = branch;
                            });
                          },
                        ),
                        ShopAbout(shop: currentShop),
                        if (galleryMedia.length > 1) ...[
                          ShopGallery(media: galleryMedia),
                          SizedBox(height: screenSize.responsivePadding(20)),
                        ],
                        ShopAddress(
                          shop: currentShop,
                          selectedBranch: _selectedBranch,
                        ),
                        ShopReviews(shop: currentShop),
                        SizedBox(height: screenSize.responsivePadding(20)),
                        ShopSocials(shop: currentShop),
                        SizedBox(height: screenSize.responsivePadding(24)),
                        ShopOperatingHours(
                          operatingHours:
                              _selectedBranch?.operatingHours ??
                              currentShop?.businessInfo?.operatingHours,
                        ),
                        if ((_selectedBranch?.operatingHours ??
                                currentShop?.businessInfo?.operatingHours) !=
                            null)
                          SizedBox(height: screenSize.responsivePadding(24)),
                        if (currentShop?.businessInfo?.faqs?.isNotEmpty ==
                            true) ...[
                          ShopFaqs(faqs: currentShop?.businessInfo?.faqs),
                          SizedBox(height: screenSize.responsivePadding(24)),
                        ],
                        if (offersAsync != null)
                          offersAsync.when(
                            data: (offers) {
                              if (offers.isEmpty)
                                return const SizedBox.shrink();
                              final displayOffers = offers.take(5).toList();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Offers',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      if (offers.length > 2)
                                        GestureDetector(
                                          onTap: () {
                                            _showAllOffersModal(
                                              context,
                                              offers,
                                              screenSize,
                                            );
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                'View All',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF07982C),
                                                ),
                                              ),
                                              SizedBox(
                                                width: screenSize
                                                    .responsivePadding(2),
                                              ),
                                              const Icon(
                                                Icons.chevron_right_rounded,
                                                size: 16,
                                                color: Color(0xFF07982C),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: screenSize.responsivePadding(12),
                                  ),
                                  SizedBox(
                                    height: screenSize.responsivePadding(195),
                                    child: ListView.separated(
                                      clipBehavior: Clip.none,
                                      scrollDirection: Axis.horizontal,
                                      itemCount: displayOffers.length,
                                      separatorBuilder: (context, index) =>
                                          SizedBox(
                                            width: screenSize.responsivePadding(
                                              12,
                                            ),
                                          ),
                                      itemBuilder: (context, index) {
                                        return SizedBox(
                                          width: screenSize.responsivePadding(
                                            190,
                                          ),
                                          child: DealCard.fromOffer(
                                            displayOffers[index],
                                            margin: EdgeInsets.zero,
                                            hideShopName: true,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  if (offersBundleAsync != null)
                                    offersBundleAsync.when(
                                      data: (bundle) {
                                        final eligible =
                                            bundle.eligibleOffersCount > 0 ||
                                            bundle.eligibleOffers.isNotEmpty ||
                                            offers.length >= 2;
                                        if (!eligible) {
                                          return const SizedBox.shrink();
                                        }
                                        final linkedCount =
                                            bundle.cart?.selectedOfferIds
                                                .length ??
                                            0;
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            top: screenSize.responsivePadding(
                                              12,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              if (bundle.eligibleOffersCount >
                                                  0)
                                                Padding(
                                                  padding: const EdgeInsets.only(
                                                    bottom: 8,
                                                  ),
                                                  child: Text(
                                                    '${bundle.eligibleOffersCount} offer(s) ready to redeem'
                                                    '${linkedCount > 0 ? ' · $linkedCount linked to cart' : ''}',
                                                    style: TextStyle(
                                                      fontFamily: 'Poppins',
                                                      fontSize: 12,
                                                      color: kPrimaryColor,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              PrimaryButton(
                                                text: 'Select / redeem offers',
                                                onPressed: () async {
                                                  final selection =
                                                      await showRedeemableOffersSheet(
                                                    context: context,
                                                    shopId: shopId,
                                                    shopName: currentShopName,
                                                  );
                                                  if (selection == null ||
                                                      !context.mounted) {
                                                    return;
                                                  }
                                                  await Navigator.of(context)
                                                      .pushNamed(
                                                    'bulkRedemption',
                                                    arguments: {
                                                      'partnerId': shopId,
                                                      'shopId': shopId,
                                                      'shopName':
                                                          currentShopName,
                                                      'cartId':
                                                          selection.cartId ??
                                                          bundle.cartId,
                                                      'offerIds':
                                                          selection.offerIds,
                                                      'redeemAll':
                                                          selection.redeemAll,
                                                      'saleAmount': selection
                                                          .cartSubtotal,
                                                      'cartSubtotal': selection
                                                          .cartSubtotal,
                                                    },
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      loading: () => const SizedBox.shrink(),
                                      error: (_, _) => const SizedBox.shrink(),
                                    ),
                                  SizedBox(
                                    height: screenSize.responsivePadding(24),
                                  ),
                                ],
                              );
                            },
                            loading: () => const Center(
                              child: CircularProgressIndicator(
                                color: kPrimaryColor,
                              ),
                            ),
                            error: (e, s) => const SizedBox.shrink(),
                          ),
                        if (productsAsync != null)
                          productsAsync.when(
                            data: (products) {
                              if (products.isEmpty)
                                return const SizedBox.shrink();
                              final displayProducts = products.take(5).toList();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Explore Products',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      if (products.length > 2)
                                        GestureDetector(
                                          onTap: () {
                                            _showAllProductsModal(
                                              context,
                                              products,
                                              screenSize,
                                            );
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                'View All',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF07982C),
                                                ),
                                              ),
                                              SizedBox(
                                                width: screenSize
                                                    .responsivePadding(2),
                                              ),
                                              const Icon(
                                                Icons.chevron_right_rounded,
                                                size: 16,
                                                color: Color(0xFF07982C),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: screenSize.responsivePadding(12),
                                  ),
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: displayProducts.length,
                                    separatorBuilder: (context, index) =>
                                        SizedBox(
                                      height:
                                          screenSize.responsivePadding(12),
                                    ),
                                    itemBuilder: (context, index) {
                                      final product = displayProducts[index];
                                      return ProductCard(
                                        index: index,
                                        name: product.title,
                                        image: product.images?.isNotEmpty ==
                                                true
                                            ? product.images!.first
                                            : null,
                                        description: product.description,
                                        price:
                                            '₹${product.price?.toStringAsFixed(2) ?? "0.0"}',
                                        tags: product.tags,
                                        rawProduct: product,
                                        hideShopInfo: true,
                                      );
                                    },
                                  ),
                                  SizedBox(
                                    height: screenSize.responsivePadding(32),
                                  ),
                                ],
                              );
                            },
                            loading: () => const Center(
                              child: CircularProgressIndicator(
                                color: kPrimaryColor,
                              ),
                            ),
                            error: (e, s) => const SizedBox.shrink(),
                          ),
                        if (servicesAsync != null)
                          servicesAsync.when(
                            data: (services) {
                              if (services.isEmpty)
                                return const SizedBox.shrink();
                              final displayServices = services.take(5).toList();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        servicesSectionTitle,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      if (services.length > 2)
                                        GestureDetector(
                                          onTap: () {
                                            _showAllServicesModal(
                                              context,
                                              services,
                                              screenSize,
                                              title: servicesModalTitle,
                                            );
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                'View All',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF07982C),
                                                ),
                                              ),
                                              SizedBox(
                                                width: screenSize
                                                    .responsivePadding(2),
                                              ),
                                              const Icon(
                                                Icons.chevron_right_rounded,
                                                size: 16,
                                                color: Color(0xFF07982C),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: screenSize.responsivePadding(12),
                                  ),
                                  SizedBox(
                                    // Image (16:9) + compact details (no shop row).
                                    height:
                                        screenSize.responsivePadding(180) *
                                            9 /
                                            16 +
                                        screenSize.responsivePadding(70),
                                    child: ListView.separated(
                                      clipBehavior: Clip.none,
                                      scrollDirection: Axis.horizontal,
                                      itemCount: displayServices.length,
                                      separatorBuilder: (context, index) =>
                                          SizedBox(
                                            width: screenSize.responsivePadding(
                                              12,
                                            ),
                                          ),
                                      itemBuilder: (context, index) {
                                        final service = displayServices[index];
                                        return SizedBox(
                                          width: screenSize.responsivePadding(
                                            180,
                                          ),
                                          child: ServiceCard(
                                            service: service,
                                            hideShopInfo: true,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    height: screenSize.responsivePadding(32),
                                  ),
                                ],
                              );
                            },
                            loading: () => Padding(
                              padding: EdgeInsets.only(
                                bottom: screenSize.responsivePadding(24),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: kPrimaryColor,
                                ),
                              ),
                            ),
                            error: (e, s) => const SizedBox.shrink(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showAllOffersModal(
    BuildContext context,
    List<dynamic> offers,
    ScreenSizeData screenSize,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final crossAxisCount = screenSize.isTablet ? 3 : 2;
        final totalPadding =
            screenSize.responsivePadding(32) +
            screenSize.responsivePadding(12 * (crossAxisCount - 1));
        final offerItemWidth =
            (screenSize.width - totalPadding) / crossAxisCount;
        final offerItemHeight = screenSize.responsivePadding(175);
        final offerAspectRatio = offerItemWidth / offerItemHeight;

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.responsivePadding(16),
                vertical: screenSize.responsivePadding(12),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'All Offers (${offers.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFF3F4F6)),
                  Expanded(
                    child: GridView.builder(
                      controller: controller,
                      padding: EdgeInsets.symmetric(
                        vertical: screenSize.responsivePadding(12),
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: offerAspectRatio,
                        crossAxisSpacing: screenSize.responsivePadding(12),
                        mainAxisSpacing: screenSize.responsivePadding(12),
                      ),
                      itemCount: offers.length,
                      itemBuilder: (context, index) {
                        return DealCard.fromOffer(
                          offers[index],
                          margin: EdgeInsets.zero,
                          hideShopName: true,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAllProductsModal(
    BuildContext context,
    List<dynamic> products,
    ScreenSizeData screenSize,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final crossAxisCount = screenSize.isTablet ? 3 : 2;
        final totalPadding =
            screenSize.responsivePadding(32) +
            screenSize.responsivePadding(12 * (crossAxisCount - 1));
        final productItemWidth =
            (screenSize.width - totalPadding) / crossAxisCount;
        final productItemHeight =
            productItemWidth * 9 / 16 + screenSize.responsivePadding(70);
        final productAspectRatio = productItemWidth / productItemHeight;

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.responsivePadding(16),
                vertical: screenSize.responsivePadding(12),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'All Products (${products.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFF3F4F6)),
                  Expanded(
                    child: GridView.builder(
                      controller: controller,
                      padding: EdgeInsets.symmetric(
                        vertical: screenSize.responsivePadding(12),
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: productAspectRatio,
                        crossAxisSpacing: screenSize.responsivePadding(12),
                        mainAxisSpacing: screenSize.responsivePadding(12),
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ProductCard(
                          index: index,
                          name: product.title,
                          image: product.images?.isNotEmpty == true
                              ? product.images!.first
                              : null,
                          description: product.description,
                          price:
                              '₹${product.price?.toStringAsFixed(2) ?? "0.0"}',
                          tags: product.tags,
                          rawProduct: product,
                          hideShopInfo: true,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAllServicesModal(
    BuildContext context,
    List<ServiceModel> services,
    ScreenSizeData screenSize, {
    String title = 'All Services',
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final crossAxisCount = screenSize.isTablet ? 3 : 2;
        final totalPadding =
            screenSize.responsivePadding(32) +
            screenSize.responsivePadding(12 * (crossAxisCount - 1));
        final itemWidth = (screenSize.width - totalPadding) / crossAxisCount;
        final itemHeight =
            itemWidth * 9 / 16 + screenSize.responsivePadding(70);
        final aspectRatio = itemWidth / itemHeight;

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.responsivePadding(16),
                vertical: screenSize.responsivePadding(12),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$title (${services.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFF3F4F6)),
                  Expanded(
                    child: GridView.builder(
                      controller: controller,
                      padding: EdgeInsets.symmetric(
                        vertical: screenSize.responsivePadding(12),
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: aspectRatio,
                        crossAxisSpacing: screenSize.responsivePadding(12),
                        mainAxisSpacing: screenSize.responsivePadding(12),
                      ),
                      itemCount: services.length,
                      itemBuilder: (context, index) {
                        return ServiceCard(
                          service: services[index],
                          hideShopInfo: true,
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ServiceDetailsPage(
                                  service: services[index],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
