import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/constants/color_constants.dart';
import '../../../data/constants/style_constants.dart';
import '../../../data/models/bulk_redemption_models.dart';
import '../../../data/providers/bulk_redemption_provider.dart';
import '../../../data/services/toast_service.dart';
import '../loading_indicator.dart';
import '../primary_button.dart';

/// Result of the select-offers / redeem-all bottom sheet.
class RedeemableOffersSelection {
  final List<String> offerIds;
  final bool redeemAll;
  final String? cartId;
  final double? cartSubtotal;
  final ShopOffersBundle bundle;

  const RedeemableOffersSelection({
    required this.offerIds,
    required this.redeemAll,
    this.cartId,
    this.cartSubtotal,
    required this.bundle,
  });
}

/// Notion UX: Select Offers / Redeem All on shop detail or cart.
Future<RedeemableOffersSelection?> showRedeemableOffersSheet({
  required BuildContext context,
  required String shopId,
  required String shopName,
  bool allowAttachToCart = true,
}) {
  return showModalBottomSheet<RedeemableOffersSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => RedeemableOffersSheet(
      shopId: shopId,
      shopName: shopName,
      allowAttachToCart: allowAttachToCart,
    ),
  );
}

class RedeemableOffersSheet extends ConsumerStatefulWidget {
  final String shopId;
  final String shopName;
  final bool allowAttachToCart;

  const RedeemableOffersSheet({
    super.key,
    required this.shopId,
    required this.shopName,
    this.allowAttachToCart = true,
  });

  @override
  ConsumerState<RedeemableOffersSheet> createState() =>
      _RedeemableOffersSheetState();
}

class _RedeemableOffersSheetState extends ConsumerState<RedeemableOffersSheet> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  ShopOffersBundle? _bundle;
  final Set<String> _selected = {};
  bool _redeemAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bundle = await ref
          .read(bulkRedemptionRepositoryProvider)
          .getRedeemableOffers(widget.shopId);
      if (!mounted) return;
      final preselected = bundle.cart?.selectedOfferIds ?? const <String>[];
      setState(() {
        _bundle = bundle;
        _selected
          ..clear()
          ..addAll(
            preselected.where(
              (id) => bundle.offers.any((o) => o.id == id && o.eligible),
            ),
          );
        if (_selected.isEmpty) {
          _selected.addAll(bundle.eligibleOffers.map((o) => o.id));
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _toggle(String id, bool eligible) {
    if (!eligible || _redeemAll) return;
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _attachToCart() async {
    final bundle = _bundle;
    if (bundle == null) return;
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(bulkRedemptionRepositoryProvider)
          .updateCartOffers(
            partnerId: widget.shopId,
            cartId: bundle.cartId,
            offerIds: _redeemAll ? null : _selected.toList(),
            redeemAll: _redeemAll,
          );
      if (!mounted) return;
      setState(() => _saving = false);
      ToastService().showToast(
        context,
        result.message ??
            '${result.selectedOfferIds.length} offer(s) attached to cart',
        type: ToastType.success,
      );
      ref.invalidate(shopOffersBundleProvider(widget.shopId));
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ToastService().showToast(context, e.toString(), type: ToastType.error);
    }
  }

  void _continue({required bool redeemAll}) {
    final bundle = _bundle;
    if (bundle == null) return;
    final ids = redeemAll
        ? bundle.eligibleOffers.map((o) => o.id).toList()
        : _selected.toList();
    if (!redeemAll && ids.isEmpty) {
      ToastService().showToast(
        context,
        'Select at least one offer, or use Redeem All.',
        type: ToastType.warning,
      );
      return;
    }
    Navigator.of(context).pop(
      RedeemableOffersSelection(
        offerIds: ids,
        redeemAll: redeemAll,
        cartId: bundle.cartId,
        cartSubtotal: bundle.cart?.subtotal,
        bundle: bundle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bundle = _bundle;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: media.viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: media.size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select offers at ${widget.shopName}',
                style: kSubHeadingM.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                bundle == null
                    ? 'Loading eligible offers…'
                    : '${bundle.eligibleOffersCount} of ${bundle.totalActiveOffers} offers eligible',
                style: kBodyTitleR.copyWith(color: kSecondaryTextColor),
              ),
              if (bundle?.cart != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Cart subtotal ₹${bundle!.cart!.subtotal.toStringAsFixed(0)} · '
                  '${bundle.cart!.selectedOfferIds.length} offer(s) linked',
                  style: kBodyTitleR.copyWith(
                    color: kPrimaryColor,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: LoadingAnimation())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: kBodyTitleM.copyWith(
                                    color: kSecondaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                PrimaryButton(text: 'Retry', onPressed: _load),
                              ],
                            ),
                          )
                        : _buildList(bundle!),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text('Redeem all eligible offers', style: kBodyTitleM),
                subtitle: Text(
                  'Skips ineligible items (e.g. unscratched scratch cards)',
                  style: kBodyTitleR.copyWith(
                    color: kSecondaryTextColor,
                    fontSize: 12,
                  ),
                ),
                value: _redeemAll,
                activeThumbColor: kPrimaryColor,
                onChanged: (v) => setState(() => _redeemAll = v),
              ),
              if (widget.allowAttachToCart) ...[
                PrimaryButton(
                  text: bundle?.cart != null
                      ? 'Save selection to cart'
                      : 'Attach offers to shop cart',
                  onPressed: _attachToCart,
                  isLoading: _saving,
                  isEnabled: !_saving,
                  backgroundColor: kSecondaryColor,
                ),
                const SizedBox(height: 8),
              ],
              PrimaryButton(
                text: _redeemAll
                    ? 'Continue with all eligible'
                    : 'Continue with ${_selected.length} selected',
                onPressed: () => _continue(redeemAll: _redeemAll),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(ShopOffersBundle bundle) {
    if (bundle.offers.isEmpty) {
      return Center(
        child: Text(
          'No offers available at this shop.',
          style: kBodyTitleM.copyWith(color: kSecondaryTextColor),
        ),
      );
    }

    return ListView.separated(
      itemCount: bundle.offers.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final offer = bundle.offers[index];
        final checked = _redeemAll
            ? offer.eligible
            : _selected.contains(offer.id);
        return CheckboxListTile(
          value: checked,
          onChanged: offer.eligible && !_redeemAll
              ? (_) => _toggle(offer.id, offer.eligible)
              : null,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: kPrimaryColor,
          title: Text(offer.title, style: kBodyTitleM),
          subtitle: Text(
            offer.eligible
                ? (offer.isScratchCard
                    ? 'Scratch card · ready'
                    : 'Eligible')
                : (offer.reason ?? 'Not eligible'),
            style: kBodyTitleR.copyWith(
              color: offer.eligible ? kPrimaryColor : kSecondaryTextColor,
              fontSize: 12,
            ),
          ),
          secondary: offer.isScratchCard && !offer.isScratched
              ? const Icon(Icons.auto_awesome, color: kSecondaryTextColor)
              : null,
        );
      },
    );
  }
}
