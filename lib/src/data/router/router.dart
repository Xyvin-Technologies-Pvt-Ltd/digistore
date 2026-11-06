import 'package:flutter/material.dart';
import '../../interfaces/navbar.dart';
import '../../interfaces/main_pages/onboarding/splash_screen.dart';
import '../../interfaces/main_pages/shop_pages/shop_detail_page.dart';
import '../../interfaces/main_pages/onboarding/login_page.dart';
import '../../interfaces/main_pages/onboarding/otp_verification_page.dart';
import '../../interfaces/main_pages/onboarding/profile_setup_page.dart';
import '../../interfaces/main_pages/home_pages/notifications_page.dart';
import '../../interfaces/main_pages/offer_pages/offer_detail_page.dart';
import '../../interfaces/main_pages/reward_pages/reward_detail_page.dart';
import '../../interfaces/main_pages/offer_pages/redemption_otp_page.dart';
import '../../interfaces/main_pages/offer_pages/redemption_instructions_page.dart';
import '../../interfaces/main_pages/offer_pages/redemption_verified_page.dart';
import '../../interfaces/main_pages/offer_pages/scratch_card_page.dart';
import '../../interfaces/main_pages/home_pages/my_account_page.dart';
import '../../interfaces/main_pages/home_pages/refer_earn_page.dart';
import '../../interfaces/main_pages/home_pages/claimed_rewards_page.dart';
import '../../interfaces/main_pages/home_pages/help_support_page.dart';
import '../../interfaces/main_pages/support_pages/support_tickets_page.dart';
import '../../interfaces/main_pages/support_pages/support_ticket_detail_page.dart';
import '../../interfaces/main_pages/home_pages/terms_privacy_page.dart';
import '../../interfaces/main_pages/home_pages/about_app_page.dart';
import '../../interfaces/main_pages/partner/partner_redemption_page.dart';
import '../../interfaces/main_pages/partner/partner_qr_scanner_page.dart';
import '../../interfaces/main_pages/partner/partner_redemption_success_page.dart';
import '../../interfaces/main_pages/partner/partner_account_page.dart';
import '../../interfaces/main_pages/partner/create_product.dart';
import '../../interfaces/main_pages/partner/create_offer_page.dart';
import '../../interfaces/main_pages/offers.dart';
import '../../interfaces/main_pages/products.dart';
import '../../interfaces/main_pages/partner/partner_history.dart';
import '../../interfaces/main_pages/partner/partner_bookings_page.dart';
import '../../interfaces/main_pages/partner/sales_calculator_page.dart';
import '../../interfaces/main_pages/partner/partner_reviews_page.dart';
import '../../interfaces/main_pages/partner/partner_faq_page.dart';
import '../../interfaces/components/webview_page.dart';
import '../models/shop_model.dart';

enum TransitionType { slideFromBottom, slideFromRight, fade, fadeScale }

PageRouteBuilder<T> createRoute<T>(
  Widget page, {
  TransitionType? transition,
  Duration duration = const Duration(milliseconds: 300),
  RouteSettings? settings,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: _transitionsBuilderFor(transition),
  );
}

RouteTransitionsBuilder _transitionsBuilderFor(TransitionType? type) {
  switch (type) {
    case TransitionType.slideFromRight:
      return (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final tween = Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: curved.drive(tween), child: child);
      };

    case TransitionType.fade:
      return (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        );
        return FadeTransition(opacity: curved, child: child);
      };

    case TransitionType.fadeScale:
      return (context, animation, secondaryAnimation, child) {
        final fadeAnim = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        final scaleTween = Tween<double>(
          begin: 0.98,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut));
        return FadeTransition(
          opacity: fadeAnim,
          child: ScaleTransition(
            scale: animation.drive(scaleTween),
            child: child,
          ),
        );
      };

    case TransitionType.slideFromBottom:
    default:
      return (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final tween = Tween(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: curved.drive(tween), child: child);
      };
  }
}

Route<dynamic> generateRoute(RouteSettings? settings) {
  Widget? page;
  TransitionType? transitionToUse;
  Duration transitionDuration = const Duration(milliseconds: 300);

  if (settings?.arguments != null && settings!.arguments is Map) {
    final args = settings.arguments as Map;
    if (args['transition'] is TransitionType) {
      transitionToUse = args['transition'] as TransitionType;
    }
    if (args['duration'] is Duration) {
      transitionDuration = args['duration'] as Duration;
    }
  }

  switch (settings?.name) {
    case 'splash':
      page = const SplashScreen();
      transitionToUse = TransitionType.fade;
      transitionDuration = const Duration(milliseconds: 500);
      break;

    case 'shopDetail':
      if (settings?.arguments is ShopModel) {
        page = ShopDetailPage(shop: settings!.arguments as ShopModel);
      } else {
        final shopName = settings?.arguments as String? ?? 'Unknown Shop';
        page = ShopDetailPage(shopName: shopName);
      }
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'offerDetail':
      final args = settings?.arguments as Map<String, dynamic>? ?? {};
      page = OfferDetailPage(args: args);
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'rewardDetail':
      final args = settings?.arguments as Map<String, dynamic>? ?? {};
      page = RewardDetailPage(args: args);
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'redemptionOtp':
      final args = settings?.arguments as Map<String, dynamic>?;
      page = RedemptionOtpPage(args: args);
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'redemptionInstructions':
      final args = settings?.arguments as Map<String, dynamic>?;
      page = RedemptionInstructionsPage(args: args);
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'redemptionVerified':
      final args = settings?.arguments as Map<String, dynamic>?;
      page = RedemptionVerifiedPage(args: args);
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'scratchCard':
      final args = settings?.arguments as Map<String, dynamic>? ?? {};
      page = ScratchCardPage(args: args);
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'partnerRedemption':
      final args = settings?.arguments as Map<String, dynamic>? ?? {};
      page = PartnerRedemptionPage(args: args);
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'partnerQrScanner':
      final args = settings?.arguments as Map<String, dynamic>? ?? {};
      page = PartnerQrScannerPage(args: args);
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'partnerRedemptionSuccess':
      final args = settings?.arguments as Map<String, dynamic>? ?? {};
      page = PartnerRedemptionSuccessPage(args: args);
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'login':
      page = const LoginPage();
      transitionToUse = TransitionType.fade;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'otp':
      page = const OtpVerificationPage();
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'profileSetup':
      page = const ProfileSetupPage();
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'myAccount':
      final args = settings?.arguments as Map<String, dynamic>? ?? {};
      final isEditMode = args['isEditMode'] as bool? ?? false;
      page = MyAccountPage(isEditMode: isEditMode);
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'referEarn':
      page = const ReferEarnPage();
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'partnerAccount':
      final args = settings?.arguments as Map<String, dynamic>? ?? {};
      final isEditMode = args['isEditMode'] as bool? ?? false;
      page = PartnerAccountPage(isEditMode: isEditMode);
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'claimedRewards':
      page = const ClaimedRewardsPage();
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'helpSupport':
      page = const HelpSupportPage();
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'support':
    case 'supportTickets':
      page = const SupportTicketsPage();
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'supportTicketDetail':
      final args = settings?.arguments as Map<String, dynamic>? ?? {};
      page = SupportTicketDetailPage(
        initialTicket: args['ticket'],
        ticketId: args['ticketId']?.toString(),
      );
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'termsPrivacy':
      page = const TermsPrivacyPage();
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'privacyPolicy':
      page = const InAppWebViewPage(
        title: 'Privacy Policy',
        url: 'https://setgoinnovations.com/privacy',
      );
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'termsConditions':
      page = const InAppWebViewPage(
        title: 'Terms & Conditions',
        url: 'https://setgoinnovations.com/terms',
      );
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'aboutApp':
      page = const AboutAppPage();
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'createProduct':
      final args = settings?.arguments as Map<String, dynamic>?;
      page = CreateProductPage(product: args);
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'createOffer':
      final args = settings?.arguments as Map<String, dynamic>?;
      page = CreateOfferPage(offer: args);
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'offers':
      page = const OffersPage();
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'partnerProducts':
      page = const ProductsPage();
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'partnerHistory':
      page = const PartnerHistoryPage();
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'partnerBookings':
      page = const PartnerBookingsPage();
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'partnerReviews':
      page = const PartnerReviewsPage();
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'partnerFaq':
      page = const PartnerFaqPage();
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'salesCalculator':
      page = const SalesCalculatorPage();
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'navbar':
      page = const NavBar();
      transitionToUse = TransitionType.fadeScale;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    case 'notifications':
      page = const NotificationsPage();
      transitionToUse = TransitionType.slideFromRight;
      transitionDuration = const Duration(milliseconds: 300);
      break;

    default:
      if (settings?.name?.startsWith('/app') == true) {
        return PageRouteBuilder(
          opaque: false,
          settings: settings,
          pageBuilder: (context, _, _) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            });
            return const SizedBox();
          },
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
      }
      // Unknown named routes: do not push a visible error page in production.
      debugPrint('Unknown route: ${settings?.name}');
      return PageRouteBuilder(
        opaque: false,
        settings: settings,
        pageBuilder: (context, _, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
          return const SizedBox.shrink();
        },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
  }
  return createRoute(
    page,
    transition: transitionToUse,
    duration: transitionDuration,
    settings: settings,
  );
}

extension NavigatorTransitionHelpers on NavigatorState {
  Future<T?> pushWithTransition<T>(
    Widget page, {
    TransitionType transition = TransitionType.slideFromBottom,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return push<T>(
      createRoute(page, transition: transition, duration: duration),
    );
  }
}
