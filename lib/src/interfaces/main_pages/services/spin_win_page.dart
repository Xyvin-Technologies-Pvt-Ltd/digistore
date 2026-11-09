import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/constants/color_constants.dart';
import '../../../data/models/voucher_models.dart';
import '../../../data/providers/voucher_provider.dart';

class SpinWinPage extends ConsumerStatefulWidget {
  final String transactionId;
  final SpinStatus status;

  const SpinWinPage({
    super.key,
    required this.transactionId,
    required this.status,
  });

  @override
  ConsumerState<SpinWinPage> createState() => _SpinWinPageState();
}

class _SpinWinPageState extends ConsumerState<SpinWinPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _spinning = false;
  SpinResult? _result;
  String? _error;

  static const _segments = [
    Color(0xFF6155F5),
    Color(0xFF33B3C5),
    Color(0xFFFBBF24),
    Color(0xFF10B981),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
      upperBound: 20,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    final campaignId = widget.status.campaignId;
    if (campaignId == null || campaignId.isEmpty || _spinning) return;

    setState(() {
      _spinning = true;
      _error = null;
      _result = null;
    });

    final result = await ref.read(voucherRepositoryProvider).spin(
          campaignId: campaignId,
          transactionId: widget.transactionId,
        );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _spinning = false;
        _error = 'Spin failed. Please try again later.';
      });
      return;
    }

    final turns = 4 + Random().nextDouble() * 2;
    await _controller.animateTo(
      turns,
      duration: const Duration(milliseconds: 4200),
      curve: Curves.easeOutCubic,
    );

    if (!mounted) return;
    setState(() {
      _spinning = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.status.campaignTitle ?? 'SetGo Spin & Win';
    final grand = widget.status.grandPrizeAmount;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1228),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Spin & Win',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (grand != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Grand prize up to ₹${grand.toStringAsFixed(grand % 1 == 0 ? 0 : 2)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _controller.value * 2 * pi,
                          child: child,
                        );
                      },
                      child: CustomPaint(
                        size: const Size(260, 260),
                        painter: _WheelPainter(colors: _segments),
                      ),
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.casino_rounded,
                        color: kPrimaryColor,
                        size: 28,
                      ),
                    ),
                    const Positioned(
                      top: 0,
                      child: Icon(
                        Icons.arrow_drop_down_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Color(0xFFFCA5A5),
                    ),
                  ),
                ),
              if (_result != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _result!.isGrandPrize ? 'Grand Prize!' : 'You won!',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _result!.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (_result!.voucherCode != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _result!.voucherCode!,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            letterSpacing: 0.6,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _result),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _spinning ? null : _spin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      disabledBackgroundColor:
                          kPrimaryColor.withValues(alpha: 0.6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _spinning ? 'Spinning…' : 'Spin Now',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _spinning ? null : () => Navigator.pop(context),
                  child: Text(
                    'Maybe later',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<Color> colors;

  _WheelPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweep = 2 * pi / colors.length;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < colors.length; i++) {
      paint.color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2 + i * sweep,
        sweep,
        true,
        paint,
      );
    }

    final border = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius - 2, border);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.colors != colors;
}
