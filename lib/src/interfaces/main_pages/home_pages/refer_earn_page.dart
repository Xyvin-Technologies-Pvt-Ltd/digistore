import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/constants/color_constants.dart';
import '../../../data/constants/style_constants.dart';
import '../../../data/models/referral_models.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/referral_provider.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../../../data/services/toast_service.dart';
import '../../../data/utils/referral_code.dart';
import '../../components/primary_button.dart';
import '../../components/referral_code_field.dart';

class ReferEarnPage extends ConsumerStatefulWidget {
  const ReferEarnPage({super.key});

  @override
  ConsumerState<ReferEarnPage> createState() => _ReferEarnPageState();
}

class _ReferEarnPageState extends ConsumerState<ReferEarnPage> {
  ReferralSharePayload? _payload;
  final List<ReferralHistoryEntry> _history = [];
  int _page = 1;
  int _totalPages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _applying = false;
  String? _error;
  final _applyKey = GlobalKey<ReferralCodeFieldState>();
  final _applyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _applyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(referralRepositoryProvider);
    final payload = await repo.myCode();
    final history = await repo.history();
    if (!mounted) return;
    if (payload == null) {
      setState(() {
        _loading = false;
        _error = 'Could not load your referral code. Pull to retry.';
      });
      return;
    }
    setState(() {
      _payload = payload;
      _history
        ..clear()
        ..addAll(history.items);
      _page = history.page;
      _totalPages = history.totalPages;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _totalPages) return;
    setState(() => _loadingMore = true);
    final history = await ref
        .read(referralRepositoryProvider)
        .history(page: _page + 1);
    if (!mounted) return;
    setState(() {
      _history.addAll(history.items);
      _page = history.page;
      _totalPages = history.totalPages;
      _loadingMore = false;
    });
  }

  bool get _canApplyCode {
    final user = ref.read(userProvider);
    if (user?.referralRewardClaimed == true) return false;
    final referredBy = user?.referredBy?.trim() ?? '';
    return referredBy.isEmpty;
  }

  Future<void> _apply() async {
    final status = await _applyKey.currentState?.resolve();
    final code = status?.code;
    if (!mounted) return;
    if (status == null || code == null) {
      ToastService().showToast(
        context,
        status != null && !status.valid && status.message.isNotEmpty
            ? status.message
            : 'Enter a referral code',
        type: ToastType.error,
      );
      return;
    }
    setState(() => _applying = true);
    final result = await ref.read(referralRepositoryProvider).apply(code);
    if (!mounted) return;
    setState(() => _applying = false);
    if (!result.shouldContinue) {
      ToastService().showToast(context, result.message, type: ToastType.error);
      return;
    }
    await ref.read(pendingReferralProvider.notifier).clear();
    await ref.read(userProvider.notifier).getProfile();
    if (!mounted) return;
    _applyController.clear();
    ToastService().showToast(
      context,
      result.alreadyApplied
          ? 'A referral code is already on this account'
          : result.message,
      type: ToastType.success,
    );
    setState(() {});
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ToastService().showToast(context, 'Code copied', type: ToastType.success);
  }

  ReferralSharePayload _aligned(ReferralSharePayload payload) {
    return payload.alignedToApiBase(ref.read(publicApiProvider).baseUrl);
  }

  Future<void> _share(ReferralSharePayload payload) async {
    final aligned = _aligned(payload);
    final text = aligned.shareMessage.isNotEmpty
        ? aligned.shareMessage
        : 'Use my SetGo referral code ${aligned.referralCode}. ${aligned.shareUrl}';
    debugPrint('Referral shareUrl=${aligned.shareUrl} api=${ref.read(publicApiProvider).baseUrl}');
    await SharePlus.instance.share(
      ShareParams(text: text, title: aligned.shareTitle),
    );
  }

  Future<void> _open(String url, ReferralSharePayload payload) async {
    final aligned = _aligned(payload);
    final target = url.contains('whatsapp')
        ? aligned.whatsappUrl
        : url.startsWith('sms:')
            ? aligned.smsUrl
            : aligned.shareUrl;
    if (target.isEmpty) {
      await _share(aligned);
      return;
    }
    final uri = Uri.tryParse(target);
    if (uri == null) {
      await _share(aligned);
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) await _share(aligned);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    final payload = _payload;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F2),
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
          'Refer & Earn',
          style: kSubHeadingM.copyWith(color: kTextColor),
        ),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : payload == null
          ? _ErrorState(message: _error ?? 'Something went wrong', onRetry: _load)
          : RefreshIndicator(
              color: kPrimaryColor,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(screenSize.responsivePadding(20)),
                children: [
                  _CodeCard(
                    code: payload.referralCode,
                    onCopy: () => _copyCode(payload.referralCode),
                  ),
                  SizedBox(height: screenSize.responsivePadding(16)),
                  _StatsRow(payload: payload),
                  SizedBox(height: screenSize.responsivePadding(16)),
                  _ShareCard(
                    onWhatsApp: () => _open(payload.whatsappUrl, payload),
                    onShare: () => _share(payload),
                    onSms: () => _open(payload.smsUrl, payload),
                  ),
                  if (ReferralCode.decodeQr(payload.qrCodeData) != null) ...[
                    SizedBox(height: screenSize.responsivePadding(16)),
                    _QrCard(bytes: ReferralCode.decodeQr(payload.qrCodeData)!),
                  ],
                  SizedBox(height: screenSize.responsivePadding(16)),
                  _RulesCard(payload: payload),
                  if (_canApplyCode) ...[
                    SizedBox(height: screenSize.responsivePadding(16)),
                    _ApplyCard(
                      fieldKey: _applyKey,
                      controller: _applyController,
                      applying: _applying,
                      onApply: _apply,
                    ),
                  ],
                  SizedBox(height: screenSize.responsivePadding(20)),
                  Text('Referral history', style: kSubHeadingM),
                  SizedBox(height: screenSize.responsivePadding(12)),
                  if (_history.isEmpty)
                    const _EmptyHistory()
                  else
                    ..._history.map((entry) => _HistoryTile(entry: entry)),
                  if (_page < _totalPages)
                    TextButton(
                      onPressed: _loadingMore ? null : _loadMore,
                      child: Text(_loadingMore ? 'Loading...' : 'Load more'),
                    ),
                ],
              ),
            ),
    );
  }
}

String _rupees(num value) {
  if (value == value.roundToDouble()) return '₹${value.toInt()}';
  return '₹${value.toStringAsFixed(2)}';
}

class _CodeCard extends StatelessWidget {
  final String code;
  final VoidCallback onCopy;

  const _CodeCard({required this.code, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: kPrimaryColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your code',
            style: kSmallTitleL.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  code,
                  style: kSubHeadingM.copyWith(
                    color: kWhite,
                    fontSize: 28,
                    letterSpacing: 2,
                  ),
                ),
              ),
              IconButton(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, color: kWhite),
                tooltip: 'Copy code',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final ReferralSharePayload payload;

  const _StatsRow({required this.payload});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Total referrals',
            value: '${payload.successfulReferrals}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'Points earned',
            value:
                '${payload.totalPointsEarned} · ${_rupees(payload.earnedRupees)}',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: kSmallerTitleM.copyWith(color: kSecondaryTextColor)),
          const SizedBox(height: 6),
          Text(value, style: kBodyTitleM),
        ],
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  final VoidCallback onWhatsApp;
  final VoidCallback onShare;
  final VoidCallback onSms;

  const _ShareCard({
    required this.onWhatsApp,
    required this.onShare,
    required this.onSms,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invite friends', style: kBodyTitleM),
          const SizedBox(height: 12),
          PrimaryButton(text: 'WhatsApp', onPressed: onWhatsApp),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _OutlineAction(label: 'Share', onTap: onShare)),
              const SizedBox(width: 10),
              Expanded(child: _OutlineAction(label: 'SMS', onTap: onSms)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OutlineAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimaryColor,
        side: const BorderSide(color: kPrimaryColor),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: kSmallTitleSB.copyWith(color: kPrimaryColor)),
    );
  }
}

class _QrCard extends StatelessWidget {
  final Uint8List bytes;

  const _QrCard({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        children: [
          Text('Show this QR in person', style: kBodyTitleM),
          const SizedBox(height: 12),
          Image.memory(bytes, width: 180, height: 180, fit: BoxFit.contain),
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  final ReferralSharePayload payload;

  const _RulesCard({required this.payload});

  @override
  Widget build(BuildContext context) {
    final min = payload.minPurchaseForRedemption;
    final fallback = min > 0
        ? 'Earn points when a friend registers with your code. Points can be used on store purchases of ₹$min or more.'
        : 'Earn points when a friend registers with your code.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How it works', style: kBodyTitleM),
          const SizedBox(height: 8),
          Text(
            payload.terms.isNotEmpty ? payload.terms : fallback,
            style: kSmallTitleL.copyWith(color: kSecondaryTextColor, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ApplyCard extends StatelessWidget {
  final GlobalKey<ReferralCodeFieldState> fieldKey;
  final TextEditingController controller;
  final bool applying;
  final VoidCallback onApply;

  const _ApplyCard({
    required this.fieldKey,
    required this.controller,
    required this.applying,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Have a friend\'s code?', style: kBodyTitleM),
          const SizedBox(height: 4),
          Text(
            'You can still apply one if you skipped it during signup.',
            style: kSmallerTitleM.copyWith(color: kSecondaryTextColor),
          ),
          const SizedBox(height: 12),
          ReferralCodeField(key: fieldKey, controller: controller),
          const SizedBox(height: 12),
          PrimaryButton(
            text: 'Apply code',
            isLoading: applying,
            onPressed: onApply,
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final ReferralHistoryEntry entry;

  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final date = entry.date == null
        ? ''
        : DateFormat('d MMM yyyy').format(entry.date!);
    final approved = entry.status.toLowerCase() == 'approved';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.referredName, style: kBodyTitleM),
                if (entry.referredPhone.isNotEmpty)
                  Text(
                    entry.referredPhone,
                    style: kSmallerTitleM.copyWith(color: kSecondaryTextColor),
                  ),
                if (date.isNotEmpty)
                  Text(
                    date,
                    style: kSmallerTitleM.copyWith(color: kSecondaryTextColor),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+${entry.pointsAwarded}', style: kBodyTitleM),
              Text(
                approved ? 'Approved' : entry.status,
                style: kSmallerTitleM.copyWith(
                  color: approved
                      ? const Color(0xFF15803D)
                      : kSecondaryTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Text(
        'No referrals yet. Share your code to start earning.',
        style: kSmallTitleL.copyWith(color: kSecondaryTextColor),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: kBodyTitleM),
            const SizedBox(height: 16),
            PrimaryButton(text: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

final _cardDecoration = BoxDecoration(
  color: kWhite,
  borderRadius: BorderRadius.circular(20),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ],
);
