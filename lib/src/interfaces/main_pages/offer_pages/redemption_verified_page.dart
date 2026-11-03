import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/constants/style_constants.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../../components/primary_button.dart';

class RedemptionVerifiedPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? args;

  const RedemptionVerifiedPage({super.key, this.args});

  @override
  ConsumerState<RedemptionVerifiedPage> createState() =>
      _RedemptionVerifiedPageState();
}

class _RedemptionVerifiedPageState
    extends ConsumerState<RedemptionVerifiedPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeIn),
    );
    _animController.forward();

    // Refresh profile in background to get latest balance & tier
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProvider.notifier).getProfile();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    final user = ref.watch(userProvider);

    final rawArgs = widget.args ?? <String, dynamic>{};
    final redemptionData = (rawArgs['redemption'] is Map)
        ? Map<String, dynamic>.from(rawArgs['redemption'] as Map)
        : <String, dynamic>{};
    final offerData = (rawArgs['offer'] is Map)
        ? Map<String, dynamic>.from(rawArgs['offer'] as Map)
        : <String, dynamic>{};

    final nestedRedemption = (redemptionData['redemption'] is Map)
        ? Map<String, dynamic>.from(redemptionData['redemption'] as Map)
        : redemptionData;
    final paymentMap = (nestedRedemption['payment'] is Map)
        ? Map<String, dynamic>.from(nestedRedemption['payment'] as Map)
        : <String, dynamic>{};

    final String offerTitle = (offerData['title'] ??
            nestedRedemption['title'] ??
            'Reward Offer')
        .toString();
    final String shopName = (offerData['shopName'] ??
            offerData['partnerName'] ??
            (offerData['partnerId'] is Map
                ? (offerData['partnerId']['businessDetails']?['businessName'] ??
                    offerData['partnerId']['businessName'])
                : null) ??
            'Store Partner')
        .toString();

    final int pointsEarned = (nestedRedemption['pointsEarned'] ??
            redemptionData['pointsEarned'] ??
            redemptionData['customerPointsEarned'] ??
            rawArgs['pointsEarned'] ??
            0) as int? ??
        (nestedRedemption['pointsEarned'] as num?)?.toInt() ??
        0;

    final int pointsUsed = (nestedRedemption['pointsUsed'] ??
            redemptionData['pointsUsed'] ??
            redemptionData['pointsUsedByCustomer'] ??
            paymentMap['pointsUsed'] ??
            rawArgs['pointsUsed'] ??
            0) as int? ??
        (nestedRedemption['pointsUsed'] as num?)?.toInt() ??
        0;

    final num rawCash = (nestedRedemption['cashAmount'] ??
            nestedRedemption['cashPaidAtCounter'] ??
            redemptionData['cashAmount'] ??
            redemptionData['cashDue'] ??
            paymentMap['cashAmountDue'] ??
            rawArgs['cashDue'] ??
            0) as num? ??
        0;
    final double cashPaid = rawCash.toDouble();

    final num? rawSale = (nestedRedemption['saleAmount'] ??
        redemptionData['saleAmount'] ??
        rawArgs['saleAmount']) as num?;
    final double? saleAmount = rawSale?.toDouble();

    final String paymentMode = (nestedRedemption['paymentMode'] ??
            redemptionData['paymentMode'] ??
            paymentMap['mode'] ??
            rawArgs['paymentMode'] ??
            (pointsUsed > 0 && cashPaid > 0
                ? 'partial'
                : (pointsUsed > 0 ? 'full_points' : 'none')))
        .toString();

    final String redemptionId = (nestedRedemption['id'] ??
            nestedRedemption['_id'] ??
            nestedRedemption['redemptionId'] ??
            redemptionData['redemptionId'] ??
            redemptionData['id'] ??
            'SETGO-${DateTime.now().millisecondsSinceEpoch % 1000000}')
        .toString();

    final int userBalance = user?.pointsBalance ??
        (nestedRedemption['pointsBalance'] as num?)?.toInt() ??
        (redemptionData['pointsBalance'] as num?)?.toInt() ??
        0;
    final String currentTierName =
        user?.currentTier?.name ?? redemptionData['tier'] ?? 'Bronze';
    final String? nextTierName = user?.nextTier?.name;
    final int pointsNeededForNext = user?.nextTier?.pointsNeeded ?? 0;
    final double progressPercent = (user?.progressToNextTier ?? 0).clamp(0, 100);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FD),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF1E293B)),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenSize.responsivePadding(20),
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Confirmed Animation
              _buildConfirmedAnimation(),

              const SizedBox(height: 18),

              Text(
                'Redemption Confirmed! 🎉',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 6),

              Text(
                'Redeemed at $shopName',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // 2. Highlight 1: "You saved ₹X with points!"
              if (pointsUsed > 0)
                _buildSavingsCard(pointsUsed, paymentMode, cashPaid)
              else
                _buildRedeemedBanner(offerTitle),

              const SizedBox(height: 12),

              // 3. Highlight 2: "You earned +Y Loyalty Coins on this bill!"
              if (pointsEarned > 0)
                _buildCoinsEarnedCard(pointsEarned, paymentMode, cashPaid)
              else if (paymentMode == 'full_points')
                _buildFullPointsNotice(),

              const SizedBox(height: 20),

              // 4. Bill & Payment Summary Card
              _buildSummaryCard(
                screenSize: screenSize,
                offerTitle: offerTitle,
                shopName: shopName,
                saleAmount: saleAmount,
                pointsUsed: pointsUsed,
                cashPaid: cashPaid,
                paymentMode: paymentMode,
                pointsEarned: pointsEarned,
                redemptionId: redemptionId,
              ),

              const SizedBox(height: 20),

              // 5. Updated Total Balance & Next Tier Progress
              _buildTierProgressCard(
                userBalance: userBalance,
                currentTierName: currentTierName,
                nextTierName: nextTierName,
                pointsNeededForNext: pointsNeededForNext,
                progressPercent: progressPercent,
              ),

              const SizedBox(height: 28),

              // 6. Action Buttons
              PrimaryButton(
                text: 'Done',
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmedAnimation() {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer glowing pulsing ring
            Transform.scale(
              scale: 1.0 + (0.2 * math.sin(_animController.value * math.pi)),
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                ),
              ),
            ),
            // Middle ring
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.22),
              ),
            ),
            // Main checkmark circle
            Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF34D399), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x4010B981),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSavingsCard(int pointsUsed, String paymentMode, double cashPaid) {
    final bool isFullPoints = paymentMode == 'full_points' || cashPaid == 0;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF059669),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.savings_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFullPoints
                        ? 'You saved ₹$pointsUsed! (100% Points)'
                        : 'You saved ₹$pointsUsed with points!',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF065F46),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isFullPoints
                        ? '$pointsUsed points deducted • ₹0 Cash Due'
                        : '$pointsUsed points used • Remainder paid in cash',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedeemedBanner(String offerTitle) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.payments_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Full Cash Payment Completed',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    offerTitle,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFB45309),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullPointsNotice() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹0 Cash Due at Counter! 🎉',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF065F46),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Your loyalty points covered 100% of this bill at the merchant.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinsEarnedCard(int pointsEarned, String paymentMode, double cashPaid) {
    final bool isPartial = paymentMode == 'partial' || (pointsEarned > 0 && cashPaid > 0);
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.stars_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPartial
                        ? 'You earned +$pointsEarned Loyalty Coins on cash spent!'
                        : 'You earned +$pointsEarned Loyalty Coins on this bill!',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPartial
                        ? 'Cashback credited on the ₹${cashPaid.toStringAsFixed(0)} cash portion'
                        : 'Credited directly to your wallet & tier progress',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required ScreenSizeData screenSize,
    required String offerTitle,
    required String shopName,
    required double? saleAmount,
    required int pointsUsed,
    required double cashPaid,
    required String paymentMode,
    required int pointsEarned,
    required String redemptionId,
  }) {
    String prettyMode;
    Color modeBg;
    Color modeText;
    switch (paymentMode.toLowerCase()) {
      case 'full_points':
        prettyMode = 'Full Points';
        modeBg = const Color(0xFFDEF7EC);
        modeText = const Color(0xFF03543F);
        break;
      case 'partial':
        prettyMode = 'Split (Points + Cash)';
        modeBg = const Color(0xFFE1EFFE);
        modeText = const Color(0xFF1E429F);
        break;
      case 'full_cash':
        prettyMode = 'Full Cash';
        modeBg = const Color(0xFFFEF3C7);
        modeText = const Color(0xFF92400E);
        break;
      default:
        prettyMode = 'Full Cash';
        modeBg = const Color(0xFFFEF3C7);
        modeText = const Color(0xFF92400E);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Redemption Details',
                style: kBodyTitleB.copyWith(
                  fontSize: 16,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: modeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  prettyMode,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: modeText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          _buildRow('Offer', offerTitle, isBold: true),
          const SizedBox(height: 10),
          _buildRow('Merchant', shopName),
          if (saleAmount != null && saleAmount > 0) ...[
            const SizedBox(height: 10),
            _buildRow('Bill / Sale Amount', '₹${saleAmount.toStringAsFixed(0)}'),
          ],
          if (pointsUsed > 0) ...[
            const SizedBox(height: 10),
            _buildRow('Points Applied', '$pointsUsed pts (₹$pointsUsed saved)'),
          ],
          const SizedBox(height: 10),
          _buildRow('Cash Paid at Counter', cashPaid > 0 ? '₹${cashPaid.toStringAsFixed(0)}' : '₹0 (Free)'),
          if (pointsEarned > 0) ...[
            const SizedBox(height: 10),
            _buildRow('Loyalty Coins Earned', '+$pointsEarned pts', isBold: true),
          ],
          const SizedBox(height: 10),
          _buildRow('Redemption ID', redemptionId),
        ],
      ),
    );
  }

  Widget _buildTierProgressCard({
    required int userBalance,
    required String currentTierName,
    required String? nextTierName,
    required int pointsNeededForNext,
    required double progressPercent,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6155F5), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6155F5).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL POINTS BALANCE',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE0E7FF),
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        color: Color(0xFFFDE047),
                        size: 26,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$userBalance pts',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.military_tech_rounded,
                      color: Color(0xFFFDE047),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$currentTierName Tier',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Progress bar towards next tier
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressPercent / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFDE047),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progressPercent.toStringAsFixed(0)}% towards ${nextTierName ?? "Next Tier"}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFE0E7FF),
                ),
              ),
              if (pointsNeededForNext > 0 && nextTierName != null)
                Text(
                  '$pointsNeededForNext pts to $nextTierName',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFDE047),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String title, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: kSmallTitleR.copyWith(
            color: const Color(0xFF64748B),
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: isBold
                ? kBodyTitleB.copyWith(
                    fontSize: 14,
                    color: const Color(0xFF0F172A),
                  )
                : kBodyTitleM.copyWith(
                    fontSize: 14,
                    color: const Color(0xFF334155),
                  ),
          ),
        ),
      ],
    );
  }
}
