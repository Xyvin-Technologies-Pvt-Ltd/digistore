import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/constants/color_constants.dart';
import '../../../data/constants/style_constants.dart';
import '../../../data/models/spin_models.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/providers/voucher_provider.dart';
import '../../../data/services/toast_service.dart';
import '../../components/loading_indicator.dart';
import '../../components/primary_button.dart';

class SpinWinPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? args;

  const SpinWinPage({super.key, this.args});

  @override
  ConsumerState<SpinWinPage> createState() => _SpinWinPageState();
}

class _SpinWinPageState extends ConsumerState<SpinWinPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  SpinStatus? _status;
  SpinResult? _result;
  bool _loading = true;
  bool _spinning = false;
  String? _error;
  double _turns = 0;

  String get _transactionId =>
      (widget.args?['transactionId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStatus());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    if (_transactionId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing transaction for spin';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await ref
          .read(voucherRepositoryProvider)
          .spinStatus(_transactionId);
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
        if (!status.hasSpinAvailable) {
          _error = status.reason ??
              (status.alreadySpun
                  ? 'You already spun for this transaction'
                  : 'No spin available');
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _spinNow() async {
    final status = _status;
    if (status == null || !status.hasSpinAvailable || _spinning) return;
    final campaignId = status.campaignId;
    if (campaignId == null || campaignId.isEmpty) {
      ToastService().showToast(
        context,
        'Missing campaign for spin',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _spinning = true);

    try {
      // Call API immediately, then animate to the winning index.
      final result = await ref.read(voucherRepositoryProvider).executeSpin(
            campaignId: campaignId,
            transactionId: _transactionId,
          );

      final segments = status.segments;
      final count = math.max(segments.length, 1);
      final index = result.winningSegmentIndex.clamp(0, count - 1);
      final segmentAngle = 1.0 / count;
      // Pointer is at top; wheel rotates clockwise in our painter.
      final targetFraction = 1.0 - (index * segmentAngle) - (segmentAngle / 2);
      final extraSpins = 5 + math.Random().nextInt(2);
      final endTurns = _turns.floorToDouble() + extraSpins + targetFraction;

      final animation = Tween<double>(begin: _turns, end: endTurns).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );

      void listener() {
        setState(() => _turns = animation.value);
      }

      animation.addListener(listener);
      _controller
        ..reset()
        ..duration = const Duration(milliseconds: 4200);
      await _controller.forward();
      animation.removeListener(listener);

      if (!mounted) return;
      setState(() {
        _result = result;
        _spinning = false;
        _turns = endTurns;
      });
      await _showCelebration(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _spinning = false);
      ToastService().showToast(context, e.toString(), type: ToastType.error);
    }
  }

  Future<void> _showCelebration(SpinResult result) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            result.isGrandPrize ? 'Grand Prize!' : 'You won!',
            style: kSubHeadingM.copyWith(color: kPrimaryColor),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (result.icon != null && result.icon!.isNotEmpty)
                Text(result.icon!, style: const TextStyle(fontSize: 42)),
              const SizedBox(height: 8),
              Text(
                result.label,
                style: kBodyTitleB.copyWith(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (result.voucherCode != null &&
                  result.voucherCode!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: kPrimaryLightColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    result.voucherCode!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: kPrimaryColor,
                    ),
                  ),
                ),
              ],
              if (result.message.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  result.message,
                  textAlign: TextAlign.center,
                  style: kBodyTitleR.copyWith(
                    color: kSecondaryTextColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(result);
              },
              child: const Text('Awesome'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    final status = _status;
    final segments = status?.segments ?? const <SpinSegment>[];

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
          status?.campaignTitle ?? 'Spin & Win',
          style: kSubHeadingM.copyWith(color: kTextColor),
        ),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: _loading
          ? const Center(child: LoadingAnimation())
          : _error != null && (status == null || !status.hasSpinAvailable)
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(screenSize.responsivePadding(24)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.casino_outlined,
                          size: 48,
                          color: kSecondaryTextColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: kBodyTitleM.copyWith(
                            color: kSecondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        PrimaryButton(
                          text: 'Go back',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(screenSize.responsivePadding(20)),
                    child: Column(
                      children: [
                        if (status?.grandPrizeAmount != null)
                          Text(
                            'Grand prize up to ₹${status!.grandPrizeAmount!.toStringAsFixed(0)}',
                            style: kBodyTitleM.copyWith(
                              color: kPrimaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: AnimatedBuilder(
                                animation: _controller,
                                builder: (_, _) {
                                  return Transform.rotate(
                                    angle: _turns * 2 * math.pi,
                                    child: CustomPaint(
                                      painter: _WheelPainter(segments),
                                      child: const SizedBox.expand(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down,
                          size: 40,
                          color: kPrimaryColor,
                        ),
                        const SizedBox(height: 8),
                        PrimaryButton(
                          text: _spinning
                              ? 'Spinning...'
                              : (_result != null ? 'Spun' : 'SPIN NOW'),
                          onPressed: _spinNow,
                          isLoading: _spinning,
                          isEnabled: !_spinning && _result == null,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<SpinSegment> segments;

  _WheelPainter(this.segments);

  static const _fallbackColors = [
    Color(0xFF6155F5),
    Color(0xFF33B3C5),
    Color(0xFFFF6900),
    Color(0xFF10B981),
    Color(0xFFFBBF24),
    Color(0xFFE52022),
    Color(0xFF2B74E1),
    Color(0xFFBE6AF1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final count = math.max(segments.length, 1);
    final sweep = 2 * math.pi / count;

    for (var i = 0; i < count; i++) {
      final segment = i < segments.length ? segments[i] : null;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = _parseColor(segment?.color) ??
            _fallbackColors[i % _fallbackColors.length];
      final start = -math.pi / 2 + i * sweep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        paint,
      );

      final label = segment?.label ?? '';
      if (label.isNotEmpty) {
        final mid = start + sweep / 2;
        final tp = TextPainter(
          text: TextSpan(
            text: label.length > 14 ? '${label.substring(0, 12)}…' : label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 2,
        )..layout(maxWidth: radius * 0.55);
        final labelRadius = radius * 0.62;
        final offset = Offset(
          center.dx + math.cos(mid) * labelRadius - tp.width / 2,
          center.dy + math.sin(mid) * labelRadius - tp.height / 2,
        );
        tp.paint(canvas, offset);
      }
    }

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white;
    canvas.drawCircle(center, radius, border);
    canvas.drawCircle(center, radius * 0.12, Paint()..color = Colors.white);
  }

  Color? _parseColor(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    var hex = raw.replaceAll('#', '').trim();
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return Color(value);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.segments != segments;
}
