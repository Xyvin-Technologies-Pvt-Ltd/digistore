import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/constants/color_constants.dart';
import '../../../data/constants/style_constants.dart';
import '../../../data/models/offer_model.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/utils/interactive_feedback_button.dart';
import '../advanced_network_image.dart';
import '../offers/deal_card.dart';

/// White image deal card (Figma Style B) — home carousel & offers grid.
class DealOfferCard extends ConsumerWidget {
  final OfferModel offer;
  final double? width;

  /// When true, fills parent width (offers grid). When false, fixed carousel width.
  final bool expand;
  final bool hideShopName;

  const DealOfferCard({
    super.key,
    required this.offer,
    this.width,
    this.expand = false,
    this.hideShopName = false,
  });

  String? get _badgeSingleLine {
    final raw = DealCard.resolveBadgeText(offer);
    if (raw == null || raw.isEmpty) return null;
    return raw.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _openDetail(BuildContext context) {
    final args = Map<String, dynamic>.from(offer.toJson());
    if (hideShopName) {
      args['hideShopInfo'] = true;
    }
    Navigator.of(context).pushNamed('offerDetail', arguments: args);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenSize = ref.watch(screenSizeProvider);
    final title = offer.title ?? '';
    final shopName = offer.partnerId?.businessDetails?.businessName ?? '';
    final shopLogo = offer.partnerId?.businessInfo?.businessLogo;
    final imageUrl = offer.images?.isNotEmpty == true
        ? offer.images!.first
        : null;
    final badge = _badgeSingleLine;
    final cardWidth = expand
        ? double.infinity
        : (width ?? screenSize.responsivePadding(220));

    return InteractiveFeedbackButton(
      onPressed: () => _openDetail(context),
      scaleFactor: 0.98,
      child: SizedBox(
        width: cardWidth,
        height: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AdvancedNetworkImage(
                  imageUrl: imageUrl ?? '',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  disableFade: true,
                  errorWidget: Container(
                    color: const Color(0xFFF3F4F6),
                    child: const Center(
                      child: Icon(
                        Icons.local_offer_outlined,
                        color: Color(0xFF9CA3AF),
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(screenSize.responsivePadding(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: kSmallTitleB.copyWith(
                        color: const Color(0xFF111827),
                        fontSize: 14,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!hideShopName ||
                        (badge != null && badge.isNotEmpty)) ...[
                      SizedBox(height: screenSize.responsivePadding(8)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: !hideShopName
                                ? Row(
                                    children: [
                                      Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            9,
                                          ),
                                          color: kPrimaryLightColor,
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child:
                                            shopLogo != null &&
                                                shopLogo.isNotEmpty
                                            ? AdvancedNetworkImage(
                                                imageUrl: shopLogo,
                                                fit: BoxFit.cover,
                                                disableFade: true,
                                              )
                                            : const Icon(
                                                Icons.store,
                                                size: 10,
                                                color: kWhite,
                                              ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          shopName,
                                          style: kSmallerTitleM.copyWith(
                                            color: const Color(0xFF111827),
                                            fontSize: 11,
                                            height: 1.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                          if (offer.pointsCost != null &&
                              offer.pointsCost! > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.stars_rounded,
                                    size: 10,
                                    color: Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${offer.pointsCost} pts',
                                    style: kSmallerTitleB.copyWith(
                                      color: const Color(0xFFB45309),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (badge != null && badge.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF07982C),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  badge,
                                  style: kSmallerTitleB.copyWith(
                                    color: kWhite,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ],
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
