import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:setgo/src/data/constants/color_constants.dart';
import 'package:setgo/src/data/models/partner_inquiry_model.dart';
import 'package:setgo/src/data/providers/partner_inquiries_provider.dart';
import 'package:setgo/src/data/providers/screen_size_provider.dart';
import 'package:setgo/src/data/utils/launch_url.dart';
import 'package:setgo/src/interfaces/components/loading_indicator.dart';

/// Partner enquiry listing — all inquiries for the authenticated partner.
///
/// Opened by notification action `open_product_inquiry` (not the detail page).
class PartnerInquiriesPage extends ConsumerStatefulWidget {
  /// Optional inquiry id to softly highlight after a notification tap.
  final String? highlightInquiryId;

  const PartnerInquiriesPage({super.key, this.highlightInquiryId});

  @override
  ConsumerState<PartnerInquiriesPage> createState() =>
      _PartnerInquiriesPageState();
}

class _PartnerInquiriesPageState extends ConsumerState<PartnerInquiriesPage> {
  static const _bg = Color(0xFFF8FAFC);
  static const _chipIdleBg = Color(0xFFF7F4F4);
  static const _chipIdleText = Color(0xFF808080);
  static const _nameColor = Color(0xFF4E4E4E);

  final ScrollController _scrollController = ScrollController();
  String _selectedFilter = 'all';

  final List<Map<String, String>> _filters = const [
    {'label': 'All', 'key': 'all'},
    {'label': 'Pending', 'key': 'pending'},
    {'label': 'Contacted', 'key': 'contacted'},
    {'label': 'Completed', 'key': 'completed'},
    {'label': 'Cancelled', 'key': 'cancelled'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final highlight = widget.highlightInquiryId?.trim();
      final notifier = ref.read(partnerInquiriesProvider.notifier);
      if (highlight != null && highlight.isNotEmpty) {
        notifier.setHighlightId(highlight);
      }
      notifier.fetchInquiries(status: _selectedFilter, refresh: true);
    });
  }

  @override
  void didUpdateWidget(covariant PartnerInquiriesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.highlightInquiryId?.trim() ?? '';
    final prev = oldWidget.highlightInquiryId?.trim() ?? '';
    if (next != prev) {
      final notifier = ref.read(partnerInquiriesProvider.notifier);
      notifier.setHighlightId(next.isEmpty ? null : next);
      notifier.refresh();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(partnerInquiriesProvider.notifier).loadMore();
    }
  }

  Future<void> _loadFilter(String key) async {
    setState(() => _selectedFilter = key);
    await ref.read(partnerInquiriesProvider.notifier).setStatusFilter(key);
  }

  Future<void> _refresh() async {
    await ref.read(partnerInquiriesProvider.notifier).refresh();
  }

  void _openDetail(PartnerInquiryModel inquiry) {
    if (inquiry.id.isEmpty) return;
    Navigator.pushNamed(
      context,
      'partnerInquiryDetail',
      arguments: {'inquiryId': inquiry.id},
    );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('EEE, d MMM · h:mm a').format(dt);
  }

  String _formatMoney(num value) {
    final v = value.toDouble();
    final formatted = v.truncateToDouble() == v
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(2);
    return '₹$formatted';
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

  String _statusLabel(String status) {
    if (status.isEmpty) return 'Pending';
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  String _itemsSummary(PartnerInquiryModel inquiry) {
    if (inquiry.items.isEmpty) return 'No items';
    if (inquiry.items.length == 1) return inquiry.items.first.title;
    return '${inquiry.items.first.title} +${inquiry.items.length - 1} more';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    final state = ref.watch(partnerInquiriesProvider);
    final inquiries = state.inquiries;
    final pendingCount = inquiries
        .where((i) => i.inquiryStatus.toLowerCase() == 'pending')
        .length;

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
          'Enquiries',
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
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: kPrimaryColor),
            onPressed: state.isLoading ? null : _refresh,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 33,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.responsivePadding(16),
              ),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final key = filter['key']!;
                final isSelected = _selectedFilter == key;
                final showBadge =
                    key == 'pending' &&
                    _selectedFilter == 'pending' &&
                    pendingCount > 0;

                return GestureDetector(
                  onTap: () => _loadFilter(key),
                  child: Container(
                    height: 33,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSelected ? 24 : 16,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.transparent : _chipIdleBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? kPrimaryColor : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          filter['label']!,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            height: 1,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isSelected ? kPrimaryColor : _chipIdleText,
                          ),
                        ),
                        if (showBadge) ...[
                          const SizedBox(width: 8),
                          Container(
                            height: 16,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: kPrimaryColor,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              '$pendingCount',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                height: 1,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: screenSize.responsivePadding(8)),
          Expanded(
            child: state.isLoading && inquiries.isEmpty
                ? const Center(child: LoadingAnimation(size: 36))
                : state.error != null && inquiries.isEmpty
                ? _ErrorState(
                    message: state.error!,
                    onRetry: _refresh,
                  )
                : inquiries.isEmpty
                ? const Center(
                    child: Text(
                      'No enquiries found',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: kPrimaryColor,
                    onRefresh: _refresh,
                    child: ListView.separated(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        screenSize.responsivePadding(24),
                        screenSize.responsivePadding(8),
                        screenSize.responsivePadding(24),
                        screenSize.responsivePadding(24),
                      ),
                      itemCount:
                          inquiries.length + (state.isLoadingMore ? 1 : 0),
                      separatorBuilder: (_, _) =>
                          SizedBox(height: screenSize.responsivePadding(12)),
                      itemBuilder: (context, index) {
                        if (index >= inquiries.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: LoadingAnimation(size: 28)),
                          );
                        }
                        final inquiry = inquiries[index];
                        final highlighted =
                            state.highlightId != null &&
                            state.highlightId == inquiry.id;
                        return _InquiryCard(
                          inquiry: inquiry,
                          highlighted: highlighted,
                          nameColor: _nameColor,
                          itemsSummary: _itemsSummary(inquiry),
                          dateLabel: _formatDateTime(
                            inquiry.lastInquirySentAt ?? inquiry.createdAt,
                          ),
                          moneyLabel: _formatMoney(inquiry.subtotal),
                          statusLabel: _statusLabel(inquiry.inquiryStatus),
                          statusColors: _statusStyle(inquiry.inquiryStatus),
                          onTap: () => _openDetail(inquiry),
                          onCall: () {
                            final phone = inquiry.customer.phone?.trim() ?? '';
                            if (phone.isNotEmpty) launchPhone(phone);
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InquiryCard extends StatelessWidget {
  final PartnerInquiryModel inquiry;
  final bool highlighted;
  final Color nameColor;
  final String itemsSummary;
  final String dateLabel;
  final String moneyLabel;
  final String statusLabel;
  final (Color bg, Color text) statusColors;
  final VoidCallback onTap;
  final VoidCallback onCall;

  const _InquiryCard({
    required this.inquiry,
    required this.highlighted,
    required this.nameColor,
    required this.itemsSummary,
    required this.dateLabel,
    required this.moneyLabel,
    required this.statusLabel,
    required this.statusColors,
    required this.onTap,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final customerName =
        (inquiry.customer.name?.trim().isNotEmpty == true)
        ? inquiry.customer.name!.trim()
        : 'Customer';
    final phone = inquiry.customer.phone?.trim() ?? '';

    final bg = highlighted ? const Color(0xFFF3F0FF) : Colors.white;

    // Whole-card InkWell so the first tap always wins (ListView + deferred
    // GestureDetector hit-testing was eating the first press).
    return Material(
      color: bg,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.051),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: highlighted
                ? Border.all(color: kPrimaryColor.withValues(alpha: 0.35))
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.051),
                blurRadius: 16,
                spreadRadius: -6,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        customerName,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: nameColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColors.$1,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColors.$2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  itemsSummary,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: kPrimaryColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.shopping_bag_outlined,
                      size: 14,
                      color: _InquiryCardMeta.meta,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${inquiry.totalQuantity} qty · $moneyLabel',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: _InquiryCardMeta.meta,
                      ),
                    ),
                  ],
                ),
                if (dateLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_outlined,
                        size: 14,
                        color: _InquiryCardMeta.meta,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          dateLabel,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: _InquiryCardMeta.meta,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  // Nested InkWell absorbs the phone tap so the card onTap
                  // does not also fire.
                  InkWell(
                    onTap: onCall,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: _InquiryCardMeta.meta,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            phone,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: _InquiryCardMeta.meta,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InquiryCardMeta {
  static const meta = Color(0xFF74767D);
}
