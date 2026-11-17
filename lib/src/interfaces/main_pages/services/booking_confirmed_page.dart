import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/service_model.dart';
import '../../../data/models/spin_models.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/providers/voucher_provider.dart';
import '../../../data/services/spin_unlock_helper.dart';
import 'my_bookings_page.dart';

class BookingConfirmedPage extends ConsumerStatefulWidget {
  final BookingModel booking;
  final SpinUnlock? spinUnlocked;

  const BookingConfirmedPage({
    super.key,
    required this.booking,
    this.spinUnlocked,
  });

  @override
  ConsumerState<BookingConfirmedPage> createState() =>
      _BookingConfirmedPageState();
}

class _BookingConfirmedPageState extends ConsumerState<BookingConfirmedPage> {
  SpinStatus? _spinStatus;
  SpinUnlock? _spinUnlock;
  bool _spinChecked = false;

  BookingModel get booking => widget.booking;

  @override
  void initState() {
    super.initState();
    _spinUnlock = widget.spinUnlocked;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSpin());
  }

  String get _spinTransactionId {
    final fromUnlock = _spinUnlock?.transactionId?.trim();
    if (fromUnlock != null && fromUnlock.isNotEmpty) return fromUnlock;
    return booking.id.trim();
  }

  Future<void> _checkSpin() async {
    final unlock = _spinUnlock;
    if (unlock?.hasSpinAvailable == true) {
      if (!mounted) return;
      setState(() {
        _spinChecked = true;
        _spinStatus = SpinStatus(
          hasSpinAvailable: true,
          campaignId: unlock!.campaignId,
          transactionId: _spinTransactionId,
        );
      });
      // Still refresh full wheel metadata in the background.
      unawaited(_probeSpinStatus(retries: 1));
      return;
    }

    await _probeSpinStatus(retries: 4);
  }

  Future<void> _probeSpinStatus({int retries = 3}) async {
    final txId = _spinTransactionId;
    if (txId.isEmpty) {
      if (!mounted) return;
      setState(() => _spinChecked = true);
      return;
    }

    SpinStatus? last;
    for (var attempt = 0; attempt < retries; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 700 * attempt));
      }
      try {
        final status =
            await ref.read(voucherRepositoryProvider).spinStatus(txId);
        last = status;
        if (kDebugMode) {
          debugPrint(
            'spin-status[$txId] attempt=${attempt + 1} '
            'available=${status.hasSpinAvailable} reason=${status.reason}',
          );
        }
        if (status.hasSpinAvailable) {
          if (!mounted) return;
          setState(() {
            _spinStatus = status;
            _spinChecked = true;
            _spinUnlock ??= SpinUnlock(
              hasSpinAvailable: true,
              transactionId: txId,
              campaignId: status.campaignId,
            );
          });
          return;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('spin-status[$txId] attempt=${attempt + 1} error=$e');
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _spinStatus = last;
      _spinChecked = true;
    });
  }

  Future<void> _openSpin() async {
    final status = _spinStatus;
    final unlock = _spinUnlock;
    final available =
        status?.hasSpinAvailable == true || unlock?.hasSpinAvailable == true;
    if (!available) return;

    final txId = _spinTransactionId;
    await openSpinIfAvailable(
      context,
      transactionId: txId,
      campaignId: status?.campaignId ?? unlock?.campaignId,
      spinUnlocked: SpinUnlock(
        hasSpinAvailable: true,
        transactionId: txId,
        campaignId: status?.campaignId ?? unlock?.campaignId,
      ),
    );

    if (!mounted) return;
    final refreshed =
        await ref.read(voucherRepositoryProvider).spinStatus(txId);
    if (!mounted) return;
    setState(() {
      _spinStatus = refreshed;
      if (!refreshed.hasSpinAvailable) {
        _spinUnlock = SpinUnlock(
          hasSpinAvailable: false,
          transactionId: txId,
          campaignId: refreshed.campaignId,
        );
      }
    });
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) {
        return DateFormat('EEE, d MMM').format(parsed);
      }
    } catch (_) {}
    return dateStr;
  }

  String _formatTime(String timeStr) {
    if (timeStr.isEmpty) return '';
    try {
      if (timeStr.contains('AM') || timeStr.contains('PM')) return timeStr;
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, hour, minute);
        return DateFormat('hh:mm a').format(dt);
      }
    } catch (_) {}
    return timeStr;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    final hasSpin = _spinChecked &&
        (_spinStatus?.hasSpinAvailable == true ||
            _spinUnlock?.hasSpinAvailable == true);

    // Format fields
    final refNumber = booking.id.isNotEmpty
        ? (booking.id.length > 10
              ? 'BK${booking.id.substring(booking.id.length - 8).toUpperCase()}'
              : booking.id)
        : (booking.tokenNumber.isNotEmpty
              ? booking.tokenNumber
              : 'BK20260917001');

    final serviceName = booking.services.isNotEmpty
        ? booking.services.join(', ')
        : (booking.service?.name ?? 'Service');
    final partnerName = booking.partner?.name ?? '';
    final serviceDisplay = partnerName.isNotEmpty
        ? '$serviceName at $partnerName'
        : serviceName;

    final dateFormatted = _formatDate(booking.bookingDate);
    final timeFormatted = _formatTime(booking.startTime);
    final dateTimeDisplay = dateFormatted.isNotEmpty && timeFormatted.isNotEmpty
        ? '$dateFormatted • $timeFormatted'
        : (dateFormatted.isNotEmpty ? dateFormatted : timeFormatted);

    final status = booking.status.isNotEmpty ? booking.status : 'PENDING';
    final isConfirmed =
        status.toUpperCase() == 'CONFIRMED' ||
        status.toUpperCase() == 'COMPLETED';
    final statusText =
        status[0].toUpperCase() + status.substring(1).toLowerCase();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F5F4),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF3F5F4),
          elevation: 0,
          surfaceTintColor: const Color(0xFFF3F5F4),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF373737),
              size: 20,
            ),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
          centerTitle: false,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenSize.responsivePadding(16),
                    vertical: screenSize.responsivePadding(8),
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: screenSize.responsivePadding(12)),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: Color(0xFF07982C),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                      SizedBox(height: screenSize.responsivePadding(16)),
                      Text(
                        'Booking Confirmed!',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: screenSize.responsivePadding(8)),
                      Text(
                        'Your appointment has been booked successfully',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF6B7280),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: screenSize.responsivePadding(32)),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(
                          screenSize.responsivePadding(20),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow('Ref#', refNumber, isBold: true),
                            const Divider(
                              height: 28,
                              color: Color(0xFFE5E7EB),
                              thickness: 1,
                            ),
                            if (booking.tokenNumber.isNotEmpty) ...[
                              _buildInfoRow(
                                'Token#',
                                booking.tokenNumber,
                                isBold: true,
                                valueColor: const Color(0xFF6155F5),
                              ),
                              const Divider(
                                height: 28,
                                color: Color(0xFFE5E7EB),
                                thickness: 1,
                              ),
                            ],
                            _buildInfoRow('Service', serviceDisplay),
                            const Divider(
                              height: 28,
                              color: Color(0xFFE5E7EB),
                              thickness: 1,
                            ),
                            _buildInfoRow('Date & Time', dateTimeDisplay),
                            const Divider(
                              height: 28,
                              color: Color(0xFFE5E7EB),
                              thickness: 1,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Status',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isConfirmed
                                        ? const Color(0x2207982C)
                                        : const Color(0x22FF9F1C),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isConfirmed
                                          ? const Color(0xFF07982C)
                                          : const Color(0xFFFF9F1C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (booking.totalAmount > 0) ...[
                              const Divider(
                                height: 28,
                                color: Color(0xFFE5E7EB),
                                thickness: 1,
                              ),
                              _buildInfoRow(
                                'Amount',
                                '₹${booking.totalAmount.toStringAsFixed(0)}',
                                isBold: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (hasSpin) ...[
                        SizedBox(height: screenSize.responsivePadding(8)),
                        _buildSpinBanner(screenSize.responsivePadding(16)),
                      ],
                      SizedBox(height: screenSize.responsivePadding(24)),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  screenSize.responsivePadding(16),
                  screenSize.responsivePadding(10),
                  screenSize.responsivePadding(16),
                  screenSize.responsivePadding(32),
                ),
                child: Column(
                  children: [
                    if (hasSpin) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _openSpin,
                          icon: const Icon(Icons.casino_rounded),
                          label: const Text(
                            'Spin & Win',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFBBF24),
                            foregroundColor: const Color(0xFF111827),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: screenSize.responsivePadding(12)),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MyBookingsPage(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF6155F5),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          backgroundColor: Colors.transparent,
                        ),
                        child: Text(
                          'View Booking Details',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6155F5),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: screenSize.responsivePadding(12)),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6155F5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Back to Home',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
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
    );
  }

  Widget _buildSpinBanner(double padding) {
    final title = _spinStatus?.campaignTitle ?? 'Spin & Win';
    final grand = _spinStatus?.grandPrizeAmount;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D0BB2), Color(0xFFBE6AF1)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You unlocked a spin!',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            grand != null
                ? '$title · Grand prize up to ₹${grand.toStringAsFixed(0)}'
                : title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? const Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }
}
