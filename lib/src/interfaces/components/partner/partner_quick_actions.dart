import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/router/nav_router.dart';
import '../../../data/utils/interactive_feedback_button.dart';

class PartnerQuickActions extends ConsumerWidget {
  final ScreenSizeData screenSize;

  const PartnerQuickActions({super.key, required this.screenSize});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenSize.responsivePadding(16),
          ),
          child: Text(
            'Quick Actions',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
        ),
        SizedBox(height: screenSize.responsivePadding(16)),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenSize.responsivePadding(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: _actionCard(
                  context,
                  title: 'Verify OTP',
                  bgColor: const Color(0xFFE6F7EE),
                  imageAsset: 'assets/png/quick_action_verify_otp.png',
                  onTap: () {
                    ref.read(selectedIndexProvider.notifier).updateIndex(1);
                  },
                ),
              ),
              SizedBox(width: screenSize.responsivePadding(8)),
              Expanded(
                child: _actionCard(
                  context,
                  title: 'Bulk OTP',
                  bgColor: const Color(0xFFE8F0FF),
                  imageAsset: 'assets/png/quick_action_verify_otp.png',
                  onTap: () {
                    Navigator.pushNamed(context, 'partnerBulkVerify');
                  },
                ),
              ),
              SizedBox(width: screenSize.responsivePadding(8)),
              Expanded(
                child: _actionCard(
                  context,
                  title: 'Create Offer',
                  bgColor: const Color(0xFFF3E8FF),
                  imageAsset: 'assets/png/quick_action_create_offer.png',
                  onTap: () {
                    Navigator.pushNamed(context, 'createOffer');
                  },
                ),
              ),
              SizedBox(width: screenSize.responsivePadding(8)),
              Expanded(
                child: _actionCard(
                  context,
                  title: 'Create Product',
                  bgColor: const Color(0xFFFFF4E8),
                  imageAsset: 'assets/png/quick_action_create_product.png',
                  onTap: () {
                    Navigator.pushNamed(context, 'createProduct');
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required String title,
    required Color bgColor,
    required String imageAsset,
    required VoidCallback onTap,
  }) {
    return InteractiveFeedbackButton(
      onPressed: onTap,
      scaleFactor: 0.96,
      child: Container(
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                imageAsset,
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.apps_rounded, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
                height: 1.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
