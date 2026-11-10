import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/constants/color_constants.dart';
import '../../../data/constants/style_constants.dart';
import '../../../data/models/voucher_models.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/providers/voucher_provider.dart';
import '../../components/empty_state.dart';
import '../../components/loading_indicator.dart';

class MyVouchersPage extends ConsumerStatefulWidget {
  const MyVouchersPage({super.key});

  @override
  ConsumerState<MyVouchersPage> createState() => _MyVouchersPageState();
}

class _MyVouchersPageState extends ConsumerState<MyVouchersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _statuses = ['active', 'redeemed', 'expired'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _statuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final status = _statuses[_tabs.index];
    ref.invalidate(myVouchersProvider(status));
    await ref.read(myVouchersProvider(status).future);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);

    return Scaffold(
      backgroundColor: kRewardPageBg,
      appBar: AppBar(
        backgroundColor: kWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: kTextColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Vouchers',
          style: kSubHeadingM.copyWith(color: kTextColor),
        ),
        centerTitle: false,
        titleSpacing: 0,
        bottom: TabBar(
          controller: _tabs,
          labelColor: kPrimaryColor,
          unselectedLabelColor: kSecondaryTextColor,
          indicatorColor: kPrimaryColor,
          labelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Redeemed'),
            Tab(text: 'Expired'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: _statuses
            .map(
              (status) => _VoucherTab(
                status: status,
                padding: screenSize.responsivePadding(16),
                onRefresh: _refresh,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _VoucherTab extends ConsumerWidget {
  final String status;
  final double padding;
  final Future<void> Function() onRefresh;

  const _VoucherTab({
    required this.status,
    required this.padding,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myVouchersProvider(status));

    return RefreshIndicator(
      color: kPrimaryColor,
      onRefresh: onRefresh,
      child: async.when(
        data: (vouchers) {
          if (vouchers.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                EmptyState(
                  imagePath: 'assets/png/empty_rewards.png',
                  title: _emptyTitle(status),
                  subtitle: _emptySubtitle(status),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(padding),
            itemCount: vouchers.length,
            separatorBuilder: (_, _) => SizedBox(height: padding * 0.75),
            itemBuilder: (context, index) {
              return _VoucherCard(voucher: vouchers[index]);
            },
          );
        },
        loading: () => const Center(child: LoadingAnimation()),
        error: (_, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
            const EmptyState(
              imagePath: 'assets/png/empty_rewards.png',
              title: 'Could not load vouchers',
              subtitle: 'Pull to refresh and try again.',
            ),
          ],
        ),
      ),
    );
  }

  String _emptyTitle(String status) {
    switch (status) {
      case 'redeemed':
        return 'No redeemed vouchers';
      case 'expired':
        return 'No expired vouchers';
      default:
        return 'No active vouchers';
    }
  }

  String _emptySubtitle(String status) {
    switch (status) {
      case 'redeemed':
        return 'Vouchers you use at checkout will show up here.';
      case 'expired':
        return 'Expired vouchers will appear in this tab.';
      default:
        return 'Apply a referral code or complete bookings to earn vouchers.';
    }
  }
}

class _VoucherCard extends StatelessWidget {
  final VoucherModel voucher;

  const _VoucherCard({required this.voucher});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');
    final until = voucher.validUntil != null
        ? dateFmt.format(voucher.validUntil!.toLocal())
        : null;
    final minSpend = voucher.minOrderValue != null && voucher.minOrderValue! > 0
        ? 'Min. order ₹${voucher.minOrderValue!.toStringAsFixed(voucher.minOrderValue! % 1 == 0 ? 0 : 2)}'
        : null;

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 88,
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    voucher.valueLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kPrimaryColor,
                      height: 1.2,
                    ),
                  ),
                  if (voucher.daysLeft != null && voucher.isActive) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${voucher.daysLeft}d left',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kSecondaryTextColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voucher.title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(text: voucher.voucherCode),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied')),
                        );
                      },
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              voucher.voucherCode,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                                color: kPrimaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: kPrimaryColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (minSpend != null)
                      Text(
                        minSpend,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: kSecondaryTextColor,
                        ),
                      ),
                    if (until != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        voucher.isExpired || voucher.status == 'expired'
                            ? 'Expired $until'
                            : 'Valid until $until',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: kSecondaryTextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
