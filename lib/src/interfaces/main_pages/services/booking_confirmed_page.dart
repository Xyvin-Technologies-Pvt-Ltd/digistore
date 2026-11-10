import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/service_model.dart';
import '../../../data/providers/screen_size_provider.dart';
import 'my_bookings_page.dart';

class BookingConfirmedPage extends ConsumerWidget {
  final BookingModel booking;

  const BookingConfirmedPage({super.key, required this.booking});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final screenSize = ref.watch(screenSizeProvider);

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
                      // Green Check Icon
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

                      // Confirmation Details Card
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
                            // Ref#
                            _buildInfoRow('Ref#', refNumber, isBold: true),
                            const Divider(
                              height: 28,
                              color: Color(0xFFE5E7EB),
                              thickness: 1,
                            ),

                            // Token Number (if available)
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

                            // Service
                            _buildInfoRow('Service', serviceDisplay),
                            const Divider(
                              height: 28,
                              color: Color(0xFFE5E7EB),
                              thickness: 1,
                            ),

                            // Date & Time
                            _buildInfoRow('Date & Time', dateTimeDisplay),
                            const Divider(
                              height: 28,
                              color: Color(0xFFE5E7EB),
                              thickness: 1,
                            ),

                            // Status
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

                            // Amount (if non-zero)
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
                      SizedBox(height: screenSize.responsivePadding(24)),
                    ],
                  ),
                ),
              ),

              // Bottom Buttons
              Container(
                padding: EdgeInsets.fromLTRB(
                  screenSize.responsivePadding(16),
                  screenSize.responsivePadding(10),
                  screenSize.responsivePadding(16),
                  screenSize.responsivePadding(32),
                ),
                child: Column(
                  children: [
                    // View Booking Details Button
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

                    // Back to Home Button
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
