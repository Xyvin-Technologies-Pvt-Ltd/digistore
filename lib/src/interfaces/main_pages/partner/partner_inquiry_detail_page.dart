import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:setgo/src/data/constants/color_constants.dart';
import 'package:setgo/src/data/models/partner_inquiry_model.dart';
import 'package:setgo/src/data/providers/partner_inquiries_provider.dart';
import 'package:setgo/src/data/providers/screen_size_provider.dart';
import 'package:setgo/src/data/services/snackbar_service.dart';
import 'package:setgo/src/data/utils/interactive_feedback_button.dart';
import 'package:setgo/src/data/utils/launch_url.dart';
import 'package:setgo/src/interfaces/components/advanced_network_image.dart';
import 'package:setgo/src/interfaces/components/confirmation_dialog.dart';

class PartnerInquiryDetailPage extends ConsumerStatefulWidget {
  final String inquiryId;

  const PartnerInquiryDetailPage({super.key, required this.inquiryId});

  @override
  ConsumerState<PartnerInquiryDetailPage> createState() =>
      _PartnerInquiryDetailPageState();
}

class _PartnerInquiryDetailPageState
    extends ConsumerState<PartnerInquiryDetailPage> {
  static const _bg = Color(0xFFF8FAFC);
  static const _cardBorder = Color(0xFFE5E9F1);
  static const _labelColor = Color(0xFF74767D);
  static const _valueColor = Color(0xFF4E4E4E);
  static const _cancelColor = Color(0xFFFF383C);

  bool _isUpdating = false;
  String? _optimisticStatus;

  String get _inquiryId => widget.inquiryId.trim();

  Future<void> _updateStatus(String status, {bool confirmCancel = false}) async {
    if (_isUpdating || _inquiryId.isEmpty) return;

    if (confirmCancel || status == 'cancelled') {
      final confirmed = await showConfirmationDialog(
        context: context,
        title: 'Cancel Inquiry',
        message:
            'Are you sure you want to mark this inquiry as cancelled?',
        confirmText: 'Cancel Inquiry',
        cancelText: 'Keep',
        isDestructive: true,
        confirmColor: _cancelColor,
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _isUpdating = true);
    final snackbar = SnackbarService();
    final previous = _optimisticStatus;

    setState(() => _optimisticStatus = status);

    final res = await ref
        .read(partnerInquiryActionsProvider)
        .updateStatus(inquiryId: _inquiryId, status: status);

    if (!mounted) return;
    setState(() => _isUpdating = false);

    if (res.success) {
      final confirmedStatus =
          res.data?.inquiryStatus ?? status;
      setState(() => _optimisticStatus = confirmedStatus);
      snackbar.showSnackBar(
        context,
        'Inquiry marked as ${_formatStatusLabel(confirmedStatus)}',
      );
    } else {
      setState(() => _optimisticStatus = previous);
      snackbar.showSnackBar(
        context,
        res.message ?? 'Failed to update status',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _callCustomer(String? phone) async {
    final trimmed = phone?.trim() ?? '';
    if (trimmed.isEmpty) {
      SnackbarService().showSnackBar(
        context,
        'Customer phone number unavailable',
        type: SnackbarType.error,
      );
      return;
    }
    await launchPhone(trimmed);
  }

  (Color bg, Color text) _statusStyle(String status) {
    switch (status.toLowerCase()) {
      case 'contacted':
        return (const Color(0xFFDBEAFE), const Color(0xFF2563EB));
      case 'completed':
        return (const Color(0xFFE6F7EE), const Color(0xFF10B981));
      case 'cancelled':
        return (const Color(0xFFFEE2E2), const Color(0xFFEF4444));
      case 'pending':
      default:
        return (const Color(0xFFFFF3E9), const Color(0xFFFF8D28));
    }
  }

  String _formatStatusLabel(String status) {
    if (status.isEmpty) return 'Pending';
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('EEE, d MMM yyyy · h:mm a').format(dt);
  }

  String _formatMoney(num? value) {
    if (value == null) return '—';
    final v = value.toDouble();
    final formatted = v.truncateToDouble() == v
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(2);
    return '₹$formatted';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    final asyncInquiry = ref.watch(partnerInquiryDetailProvider(_inquiryId));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF373737),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Inquiry Details',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Color(0xFF373737),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            height: 20 / 18,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: asyncInquiry.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: kPrimaryColor),
        ),
        error: (error, _) => _ErrorBody(
          message: error is PartnerInquiryException
              ? error.message
              : 'Unable to load inquiry details',
          isUnauthorized:
              error is PartnerInquiryException && error.isUnauthorized,
          onRetry: () =>
              ref.invalidate(partnerInquiryDetailProvider(_inquiryId)),
        ),
        data: (inquiry) {
          if (inquiry == null) {
            return _ErrorBody(
              message: 'Inquiry not found',
              onRetry: () =>
                  ref.invalidate(partnerInquiryDetailProvider(_inquiryId)),
            );
          }
          return _buildContent(inquiry, screenSize);
        },
      ),
    );
  }

  Widget _buildContent(
    PartnerInquiryModel inquiry,
    ScreenSizeData screenSize,
  ) {
    final status =
        (_optimisticStatus ?? inquiry.inquiryStatus).toLowerCase();
    final statusStyle = _statusStyle(status);
    final customerName =
        (inquiry.customer.name?.trim().isNotEmpty == true)
            ? inquiry.customer.name!.trim()
            : 'Customer';
    final phone = inquiry.customer.phone?.trim() ?? '';
    final avatar = inquiry.customer.avatar;
    final inquiryDate =
        inquiry.lastInquirySentAt ?? inquiry.createdAt;
    final showActions = status == 'pending' || status == 'contacted';

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: kPrimaryColor,
            onRefresh: () async {
              ref.invalidate(partnerInquiryDetailProvider(_inquiryId));
              await ref.read(
                partnerInquiryDetailProvider(_inquiryId).future,
              );
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                screenSize.responsivePadding(24),
                screenSize.responsivePadding(8),
                screenSize.responsivePadding(24),
                screenSize.responsivePadding(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _card(
                    child: Row(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: avatar != null && avatar.isNotEmpty
                                ? AdvancedNetworkImage(
                                    imageUrl: avatar,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorWidget: _avatarFallback(customerName),
                                  )
                                : _avatarFallback(customerName),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customerName,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _valueColor,
                                ),
                              ),
                              if (phone.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  phone,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: _labelColor,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                _formatDateTime(inquiryDate),
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: _labelColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (phone.isNotEmpty)
                          InteractiveFeedbackButton(
                            onPressed: () => _callCustomer(phone),
                            scaleFactor: 0.95,
                            child: Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: kPrimaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.phone_outlined,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: screenSize.responsivePadding(12)),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Enquired Items',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _valueColor,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusStyle.$1,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _formatStatusLabel(status),
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusStyle.$2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (inquiry.items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No products or services in this inquiry.',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: _labelColor,
                              ),
                            ),
                          )
                        else
                          ...inquiry.items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _InquiryItemTile(
                                item: item,
                                formatMoney: _formatMoney,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: screenSize.responsivePadding(12)),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inquiry Summary',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _valueColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _DetailRow(
                          label: 'Items',
                          value: '${inquiry.itemCount}',
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          label: 'Total quantity',
                          value: '${inquiry.totalQuantity}',
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          label: 'Subtotal',
                          value: _formatMoney(inquiry.subtotal),
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          label: 'Status',
                          child: Text(
                            _formatStatusLabel(status),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: statusStyle.$2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              screenSize.responsivePadding(24),
              screenSize.responsivePadding(12),
              screenSize.responsivePadding(24),
              screenSize.responsivePadding(16),
            ),
            child: Column(
              children: [
                if (phone.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: _ActionButton(
                      label: 'Call Customer',
                      filled: false,
                      color: kPrimaryColor,
                      borderRadius: 12,
                      enabled: !_isUpdating,
                      onPressed: () => _callCustomer(phone),
                    ),
                  ),
                if (showActions) ...[
                  if (phone.isNotEmpty) const SizedBox(height: 10),
                  if (status == 'pending') ...[
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: 'Cancel',
                            filled: false,
                            color: _cancelColor,
                            borderRadius: 12,
                            enabled: !_isUpdating,
                            onPressed: () =>
                                _updateStatus('cancelled', confirmCancel: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            label: _isUpdating
                                ? 'Updating…'
                                : 'Mark Contacted',
                            filled: true,
                            color: kPrimaryColor,
                            borderRadius: 999,
                            enabled: !_isUpdating,
                            onPressed: () => _updateStatus('contacted'),
                          ),
                        ),
                      ],
                    ),
                  ] else if (status == 'contacted') ...[
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: 'Cancel',
                            filled: false,
                            color: _cancelColor,
                            borderRadius: 12,
                            enabled: !_isUpdating,
                            onPressed: () =>
                                _updateStatus('cancelled', confirmCancel: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            label: _isUpdating
                                ? 'Updating…'
                                : 'Mark Completed',
                            filled: true,
                            color: kPrimaryColor,
                            borderRadius: 999,
                            enabled: !_isUpdating,
                            onPressed: () => _updateStatus('completed'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      color: kPrimaryColor,
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.051),
            blurRadius: 16,
            spreadRadius: -6,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InquiryItemTile extends StatelessWidget {
  final PartnerInquiryItem item;
  final String Function(num?) formatMoney;

  const _InquiryItemTile({
    required this.item,
    required this.formatMoney,
  });

  @override
  Widget build(BuildContext context) {
    final effective = item.effectivePrice;
    final original = item.price;
    final showStrike =
        original != null &&
        effective != null &&
        original > effective;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 64,
            height: 64,
            child: item.image != null && item.image!.isNotEmpty
                ? AdvancedNetworkImage(
                    imageUrl: item.image!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorWidget: _imagePlaceholder(),
                  )
                : _imagePlaceholder(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4E4E4E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Qty: ${item.quantity}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF74767D),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    formatMoney(effective ?? original),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF07838C),
                    ),
                  ),
                  if (showStrike) ...[
                    const SizedBox(width: 8),
                    Text(
                      formatMoney(original),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF74767D),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: const Icon(
        Icons.inventory_2_outlined,
        color: Color(0xFF94A3B8),
        size: 24,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? child;

  const _DetailRow({
    required this.label,
    this.value,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF74767D),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child:
                child ??
                Text(
                  value ?? '—',
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4E4E4E),
                  ),
                ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final Color color;
  final double borderRadius;
  final bool enabled;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.filled,
    required this.color,
    required this.borderRadius,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InteractiveFeedbackButton(
      onPressed: enabled ? onPressed : null,
      scaleFactor: 0.98,
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
        child: Container(
          height: 51,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(borderRadius),
            border: filled ? null : Border.all(color: color, width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final bool isUnauthorized;
  final VoidCallback onRetry;

  const _ErrorBody({
    required this.message,
    required this.onRetry,
    this.isUnauthorized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUnauthorized
                  ? Icons.lock_outline_rounded
                  : Icons.error_outline_rounded,
              size: 48,
              color: const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4E4E4E),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: kPrimaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
