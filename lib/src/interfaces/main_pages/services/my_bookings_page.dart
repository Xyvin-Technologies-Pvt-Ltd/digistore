import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/providers/services_provider.dart';
import '../../components/confirmation_dialog.dart';
import '../../components/loading_indicator.dart';

class MyBookingsPage extends ConsumerStatefulWidget {
  const MyBookingsPage({super.key});

  @override
  ConsumerState<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends ConsumerState<MyBookingsPage> {
  String _selectedFilter = 'upcoming';

  final List<Map<String, String>> _filters = const [
    {'label': 'Upcoming', 'key': 'upcoming'},
    {'label': 'Past', 'key': 'past'},
    {'label': 'Cancelled', 'key': 'cancelled'},
    {'label': 'All', 'key': 'all'},
  ];

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

  (Color bg, Color text) _getStatusStyle(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return (const Color(0xFFE6F4EA), const Color(0xFF10B981));
      case 'PENDING':
        return (const Color(0xFFFFEDD5), const Color(0xFFFFB800));
      case 'IN_PROGRESS':
        return (const Color(0xFFDBEAFE), const Color(0xFF2563EB));
      case 'COMPLETED':
        return (const Color(0xFFE0E7FF), const Color(0xFF6366F1));
      case 'CANCELLED':
      case 'NO_SHOW':
        return (const Color(0xFFFEE2E2), const Color(0xFFEF4444));
      default:
        return (const Color(0xFFF3F4F6), const Color(0xFF6B7280));
    }
  }

  String _formatStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return 'In Progress';
      case 'no_show':
        return 'No Show';
      default:
        if (status.isEmpty) return 'Pending';
        return status[0].toUpperCase() + status.substring(1).toLowerCase();
    }
  }

  Future<void> _handleCancel(String bookingId) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Cancel Booking',
      message: 'Are you sure you want to cancel this booking?',
      confirmText: 'Yes, Cancel',
      cancelText: 'Keep Booking',
      isDestructive: true,
      confirmColor: const Color(0xFFEF4444),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final res = await BookingService.cancelBooking(
      api: ref.read(publicApiProvider),
      bookingId: bookingId,
    );
    if (!mounted) return;
    if (res.success) {
      ref.invalidate(allCustomerBookingsProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Booking cancelled successfully')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Failed to cancel booking'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    final bookingsAsync = ref.watch(customerBookingsProvider(_selectedFilter));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F5F4),
        surfaceTintColor: const Color(0xFFF3F5F4),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF111827),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Bookings',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: const Color(0xFF373737),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal Filter Chips
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenSize.responsivePadding(16),
              vertical: screenSize.responsivePadding(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter['key'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFilter = filter['key']!;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 20 : 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.transparent
                              : const Color(0xFFF7F4F4),
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? Border.all(
                                  color: const Color(0xFF07982C),
                                  width: 1,
                                )
                              : Border.all(
                                  color: const Color(0xFFE5E7EB),
                                  width: 0.5,
                                ),
                        ),
                        child: Text(
                          filter['label']!,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF07982C)
                                : const Color(0xFF808080),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(height: screenSize.responsivePadding(8)),

          // Bookings List Area
          Expanded(
            child: bookingsAsync.when(
              data: (bookings) {
                if (bookings.isEmpty) {
                  final currentLabel = _filters.firstWhere(
                    (f) => f['key'] == _selectedFilter,
                    orElse: () => {'label': _selectedFilter},
                  )['label'];

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy_rounded,
                          size: 56,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No $currentLabel Bookings',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: const Color(0xFF07982C),
                  onRefresh: () async {
                    ref.invalidate(allCustomerBookingsProvider);
                    await ref.read(allCustomerBookingsProvider.future);
                  },
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      screenSize.responsivePadding(16),
                      screenSize.responsivePadding(4),
                      screenSize.responsivePadding(16),
                      screenSize.responsivePadding(24),
                    ),
                    itemCount: bookings.length,
                    separatorBuilder: (_, _) =>
                        SizedBox(height: screenSize.responsivePadding(10)),
                    itemBuilder: (context, index) {
                      final booking = bookings[index];
                      final statusStyle = _getStatusStyle(booking.status);
                      final serviceName = booking.services.isNotEmpty
                          ? booking.services.join(', ')
                          : (booking.service?.name ?? 'Service Appointment');
                      final partnerName = booking.partner?.name ?? '';

                      final dateFormatted = _formatDate(booking.bookingDate);
                      final timeFormatted = _formatTime(booking.startTime);
                      final dateTimeDisplay =
                          dateFormatted.isNotEmpty && timeFormatted.isNotEmpty
                          ? '$dateFormatted • $timeFormatted'
                          : (dateFormatted.isNotEmpty
                                ? dateFormatted
                                : timeFormatted);

                      final isCancelable =
                          booking.status.toUpperCase() == 'CONFIRMED' ||
                          booking.status.toUpperCase() == 'PENDING';

                      return Container(
                        padding: EdgeInsets.all(
                          screenSize.responsivePadding(16),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row: Service + Partner Name & Token
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        serviceName,
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF111827),
                                        ),
                                      ),
                                      if (partnerName.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          partnerName,
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: const Color(0xFF373737),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (booking.tokenNumber.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF6155F5,
                                      ).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      booking.tokenNumber,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF6155F5),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: screenSize.responsivePadding(12)),

                            // Date & Time + Status Badge Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  dateTimeDisplay,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
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
                                    color: statusStyle.$1,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _formatStatusLabel(booking.status),
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: statusStyle.$2,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Total Amount and Services row (if available)
                            if (booking.totalAmount > 0 ||
                                booking.services.length > 1) ...[
                              const Divider(
                                height: 20,
                                color: Color(0xFFE5E7EB),
                                thickness: 1,
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${booking.services.length} ${booking.services.length == 1 ? "Service" : "Services"}',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      color: const Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '₹ ${booking.totalAmount.toInt()}',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF111827),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            // Cancel Button
                            if (isCancelable) ...[
                              SizedBox(
                                height: screenSize.responsivePadding(12),
                              ),
                              SizedBox(
                                width: double.infinity,
                                height: 38,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFFEF4444),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () => _handleCancel(booking.id),
                                  child: Text(
                                    'Cancel Booking',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: const Color(0xFFEF4444),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: LoadingAnimation(size: 36)),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Failed to load bookings: $e',
                    style: TextStyle(fontFamily: 'Poppins', color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
