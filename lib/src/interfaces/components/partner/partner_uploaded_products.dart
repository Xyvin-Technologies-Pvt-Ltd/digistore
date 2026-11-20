import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/product_model.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/router/nav_router.dart';
import '../../../data/utils/interactive_feedback_button.dart';
import '../../components/advanced_network_image.dart';
import '../../main_pages/partner/product_details_page.dart';

class PartnerUploadedProducts extends ConsumerWidget {
  final ScreenSizeData screenSize;
  final List<ProductModel>? products;

  const PartnerUploadedProducts({
    super.key,
    required this.screenSize,
    this.products,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products == null || products!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenSize.responsivePadding(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Uploaded Products',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
              InkWell(
                onTap: () {
                  ref.read(selectedIndexProvider.notifier).updateIndex(2);
                },
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: screenSize.responsivePadding(16)),
        CarouselSlider.builder(
          itemCount: products!.length,
          options: CarouselOptions(
            height: screenSize.responsivePadding(128),
            viewportFraction: 0.45,
            enableInfiniteScroll: false,
            padEnds: false,
          ),
          itemBuilder: (context, index, realIndex) {
            final padding = screenSize.responsivePadding(16);
            return Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? padding : 6,
                right: index == products!.length - 1 ? padding : 6,
              ),
              child: _buildProductCard(context, products![index]),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProductCard(BuildContext context, ProductModel product) {
    final imageUrl = (product.images != null && product.images!.isNotEmpty)
        ? product.images!.first
        : '';

    final displayPrice = product.displayPriceText;
    final priceStr = (displayPrice.isNotEmpty && displayPrice != '₹0')
        ? displayPrice
        : '';

    return InteractiveFeedbackButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsPage(
              product: product.toJson(),
              hideShopInfo: true,
            ),
          ),
        );
      },
      scaleFactor: 0.98,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: imageUrl.isNotEmpty
                      ? AdvancedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          disableFade: true,
                        )
                      : Container(
                          color: const Color(0xFFF3F4F6),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            size: 32,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.title ?? 'Product',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          color: const Color(0xFF111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (priceStr.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        priceStr,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
