import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/constants/color_constants.dart';
import '../../../data/constants/style_constants.dart';
import '../../../data/models/product_model.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/utils/interactive_feedback_button.dart';
import '../advanced_network_image.dart';
import '../../main_pages/partner/product_details_page.dart';

/// Horizontal "You May Also Like" carousel — page-local fetch, does not
/// mutate [partnerProductsProvider].
class RelatedProductsSection extends ConsumerStatefulWidget {
  final String? currentProductId;
  final String? categoryId;

  const RelatedProductsSection({
    super.key,
    this.currentProductId,
    this.categoryId,
  });

  @override
  ConsumerState<RelatedProductsSection> createState() =>
      _RelatedProductsSectionState();
}

class _RelatedProductsSectionState
    extends ConsumerState<RelatedProductsSection> {
  List<ProductModel> _products = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant RelatedProductsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId ||
        oldWidget.currentProductId != widget.currentProductId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiProvider);
      final queryParams = <String, String>{'page': '1', 'limit': '10'};
      final categoryId = widget.categoryId;
      if (categoryId != null && categoryId.isNotEmpty && categoryId != 'All') {
        queryParams['category'] = categoryId;
      }

      final response = await api.get('/products', queryParams: queryParams);
      if (!mounted) return;

      if (response.success && response.data != null) {
        final parsed = ProductResponse.fromJson(response.data!);
        final filtered = parsed.data
            .where((p) => p.id != null && p.id != widget.currentProductId)
            .take(8)
            .toList();
        setState(() {
          _products = filtered;
          _loading = false;
        });
      } else {
        setState(() {
          _products = const [];
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _products = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _products.isEmpty) return const SizedBox.shrink();

    final screenSize = ref.watch(screenSizeProvider);
    final cardWidth = screenSize.responsivePadding(148);
    final cardHeight = screenSize.responsivePadding(196);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenSize.responsivePadding(16),
          ),
          child: Text(
            'You May Also Like',
            style: kSmallTitleB.copyWith(
              color: const Color(0xFF111827),
              fontSize: 16,
            ),
          ),
        ),
        SizedBox(height: screenSize.responsivePadding(12)),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: screenSize.responsivePadding(16),
            ),
            itemCount: _products.length,
            separatorBuilder: (_, _) =>
                SizedBox(width: screenSize.responsivePadding(12)),
            itemBuilder: (context, index) {
              final p = _products[index];
              return SizedBox(
                width: cardWidth,
                child: _RelatedProductCard(product: p),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RelatedProductCard extends ConsumerWidget {
  final ProductModel product;

  const _RelatedProductCard({required this.product});

  String get _priceLabel {
    final displayPrice = product.displayPriceText;
    if (displayPrice.isNotEmpty && displayPrice != '₹0') return displayPrice;
    return '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenSize = ref.watch(screenSizeProvider);
    final image = (product.images != null && product.images!.isNotEmpty)
        ? product.images!.first
        : '';
    final priceLabel = _priceLabel;

    return InteractiveFeedbackButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsPage(product: product.toJson()),
          ),
        );
      },
      scaleFactor: 0.98,
      child: Container(
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kProductBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AdvancedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                width: double.infinity,
                disableFade: true,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(screenSize.responsivePadding(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.title ?? '',
                    style: kSmallTitleB.copyWith(
                      color: const Color(0xFF111827),
                      fontSize: 13,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (priceLabel.isNotEmpty) ...[
                    SizedBox(height: screenSize.responsivePadding(4)),
                    Text(
                      priceLabel,
                      style: kSmallTitleB.copyWith(
                        color: kProductAccentTeal,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
