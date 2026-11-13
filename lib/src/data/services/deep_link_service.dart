import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setgo/src/data/models/app_notification_model.dart';
import 'package:setgo/src/data/router/nav_router.dart';
import 'package:setgo/src/data/services/navigation_service.dart';
import 'package:setgo/src/data/services/secure_storage_service.dart';
import 'package:setgo/src/data/services/snackbar_service.dart';
import 'package:setgo/src/data/services/notification_service/notification_controller.dart';
import 'package:setgo/src/data/providers/offers_provider.dart';
import 'package:setgo/src/data/providers/shops_provider.dart';
import 'package:setgo/src/data/providers/rewards_provider.dart';
import 'package:setgo/src/data/utils/launch_url.dart';
import 'package:setgo/src/data/utils/referral_code.dart';
import 'package:setgo/src/data/providers/referral_provider.dart';

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService(ref);
});

class DeepLinkService {
  final Ref _ref;
  final _appLinks = AppLinks();
  Uri? _pendingDeepLink;
  String? _lastNavigatedInquiryId;
  DateTime? _lastInquiryNavAt;

  DeepLinkService(this._ref);

  Uri? get pendingDeepLink => _pendingDeepLink;

  void clearPendingDeepLink() {
    _pendingDeepLink = null;
  }

  void setPendingDeepLink(Uri uri) {
    _pendingDeepLink = uri;
  }

  static bool _isInitialized = false;

  /// Initialize deep link handling
  /// Call this in your main app after navigation is ready
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('🔗 Deep link service already initialized');
      return;
    }

    try {
      debugPrint('🔗 Deep link service initializing...');

      // Handle deep link when app is launched from terminated state
      final appLink = await _appLinks.getInitialLink();
      if (appLink != null) {
        _pendingDeepLink = appLink;
        debugPrint(
          '🔗 Initial deep link stored as pending: ${appLink.toString()}',
        );
        debugPrint('🔗 Initial link path segments: ${appLink.pathSegments}');
        debugPrint('🔗 Initial link scheme: ${appLink.scheme}');
        debugPrint('🔗 Initial link host: ${appLink.host}');
        await _captureReferral(appLink);
        // The code is already stored for signup. Don't let the navbar
        // treat a referral-only link as a navigation after login.
        if (ReferralCode.isAttributionLink(appLink)) {
          _pendingDeepLink = null;
        }
      } else {
        debugPrint('🔗 No initial deep link found');
      }

      // Handle deep links when app is in background/foreground
      _appLinks.uriLinkStream.listen((uri) {
        debugPrint(
          '🔗 ⚡ Deep link received while app is running: ${uri.toString()}',
        );
        debugPrint('🔗 Link path segments: ${uri.pathSegments}');
        debugPrint('🔗 Link scheme: ${uri.scheme}');
        debugPrint('🔗 Link host: ${uri.host}');
        // Handle immediately when app is already running (not from terminated state)
        handleDeepLink(uri);
      });

      NotificationController.deepLinkStream.stream.listen((deepLink) {
        debugPrint('🔗 ⚡ Deep link received from notification tap: $deepLink');
        handleDeepLink(Uri.parse(deepLink));
      });

      _isInitialized = true;
      debugPrint('🔗 Deep link service initialized successfully');
    } catch (e) {
      debugPrint('❌ Deep link initialization error: $e');
    }
  }

  /// Handle notification payload map (FCM data / flattened action fields).
  void handleNotificationData(Map<String, dynamic> data) {
    try {
      debugPrint('📩 Processing notification data: $data');
      final notification = AppNotificationModel.fromJson(data);
      handleNotificationAction(notification);
    } catch (e) {
      debugPrint('❌ Error handling notification data: $e');
    }
  }

  /// Navigate from an in-app / push notification using backend `action`.
  Future<void> handleNotificationAction(AppNotificationModel notification) async {
    try {
      final action = notification.action;
      final metadata = notification.metadata ?? const <String, dynamic>{};

      String? meta(String key) => metadata[key]?.toString();

      if (action != null && action.isNavigable) {
        switch (action.type) {
          case 'open_offer':
            await _navigateToOffer(
              action.targetId ?? meta('offerId') ?? meta('id'),
            );
            return;
          case 'open_shop':
          case 'open_branch':
            await _navigateToShop(
              action.targetId ??
                  meta('partnerId') ??
                  meta('shopId') ??
                  meta('id'),
            );
            return;
          case 'open_reward':
            final rewardId =
                action.targetId ?? meta('rewardId') ?? meta('id');
            if (rewardId != null && rewardId.isNotEmpty) {
              await _navigateToReward(rewardId);
            } else {
              await _openMainTab('Rewards');
            }
            return;
          case 'open_url':
            final url = action.url ?? action.targetId ?? meta('url');
            if (url != null && url.trim().isNotEmpty) {
              await launchURL(url.trim());
            }
            return;
          case 'open_screen':
            await _openScreen(action.screen ?? action.targetId);
            return;
          case 'open_profile':
          case 'open_subscription':
            await _navigateToProfile();
            return;
          case 'open_booking':
            await _navigateToBookings();
            return;
          case 'open_product_inquiry':
            final inquiryId =
                action.targetId ??
                meta('inquiryId') ??
                meta('cartId') ??
                meta('id');
            await _navigateToPartnerInquiry(inquiryId);
            return;
          default:
            break;
        }
      }

      // Fallback: notification type / metadata hints.
      final offerId = meta('offerId');
      final shopId = meta('partnerId') ?? meta('shopId');
      final rewardId = meta('rewardId');
      final inquiryId =
          meta('inquiryId') ?? meta('cartId') ?? action?.targetId;
      final url = meta('url') ?? action?.url;
      final kind = (meta('kind') ?? notification.type ?? '').toLowerCase();

      if (inquiryId != null &&
          inquiryId.isNotEmpty &&
          (kind.contains('inquiry') ||
              kind.contains('cart') ||
              action?.type == 'open_product_inquiry')) {
        await _navigateToPartnerInquiry(inquiryId);
      } else if (offerId != null && offerId.isNotEmpty) {
        await _navigateToOffer(offerId);
      } else if (shopId != null && shopId.isNotEmpty) {
        await _navigateToShop(shopId);
      } else if (rewardId != null && rewardId.isNotEmpty) {
        await _navigateToReward(rewardId);
      } else if (url != null && url.trim().isNotEmpty) {
        await launchURL(url.trim());
      } else if (kind.contains('offer')) {
        await _openMainTab('Offers');
      } else if (kind.contains('shop') || kind.contains('partner')) {
        await _openMainTab('Shops');
      } else if (kind.contains('reward')) {
        await _openMainTab('Rewards');
      } else if (kind.contains('inquiry') || kind.contains('cart')) {
        await _navigateToPartnerInquiry(inquiryId);
      } else {
        debugPrint('📩 No navigable action on notification ${notification.id}');
      }
    } catch (e) {
      debugPrint('❌ Error handling notification action: $e');
      _showError('Unable to open this notification');
    }
  }

  Future<void> _openScreen(String? screen) async {
    if (screen == null || screen.trim().isEmpty) {
      await _navigateToHome();
      return;
    }
    final key = screen.trim().toLowerCase();
    switch (key) {
      case 'offers':
      case 'offerstab':
      case 'offer':
        await _openMainTab('Offers');
        break;
      case 'shops':
      case 'shopstab':
      case 'partners':
      case 'shop':
        await _openMainTab('Shops');
        break;
      case 'rewards':
      case 'rewardstab':
      case 'reward':
        await _openMainTab('Rewards');
        break;
      case 'products':
      case 'services':
      case 'products & services':
        await _openMainTab('Products & Services');
        break;
      case 'home':
      case 'general':
        await _navigateToHome();
        break;
      case 'notifications':
        await _navigateToNotifications();
        break;
      case 'profile':
      case 'myaccount':
        await _navigateToProfile();
        break;
      case 'shopdetail':
      case 'offerdetail':
      case 'rewarddetail':
        await handleDeepLink(Uri.parse('app://$key'));
        break;
      default:
        // Treat unknown screens as deep-link routes when possible.
        await handleDeepLink(Uri.parse('app://$key'));
        break;
    }
  }

  Future<void> _openMainTab(String label) async {
    try {
      NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        'navbar',
        (route) => false,
      );
      await Future.delayed(const Duration(milliseconds: 250));

      // Customer tabs: Home, Offers, Shops, Rewards, Products & Services
      const tabs = [
        'Home',
        'Offers',
        'Shops',
        'Rewards',
        'Products & Services',
      ];
      final index = tabs.indexWhere(
        (t) => t.toLowerCase() == label.toLowerCase(),
      );
      _ref
          .read(selectedIndexProvider.notifier)
          .updateIndex(index >= 0 ? index : 0);
      debugPrint('✅ Opened main tab: $label');
    } catch (e) {
      debugPrint('Error opening tab $label: $e');
    }
  }

  Future<void> _navigateToBookings() async {
    // Customer bookings live under Products & Services for now.
    await _openMainTab('Products & Services');
  }

  /// Partner-only: open inquiry details for notification / deep link.
  ///
  /// Backend contract: notification `action.targetId` (or `metadata.cartId`)
  /// is the inquiry id accepted by `GET /mobile/partner/inquiries/:id`.
  Future<void> _navigateToPartnerInquiry(
    String? inquiryId, {
    bool fromDeepLink = false,
  }) async {
    try {
      final id = inquiryId?.trim() ?? '';
      if (id.isEmpty) {
        _showError('Inquiry details unavailable');
        return;
      }

      final now = DateTime.now();
      if (_lastNavigatedInquiryId == id &&
          _lastInquiryNavAt != null &&
          now.difference(_lastInquiryNavAt!) < const Duration(seconds: 2)) {
        debugPrint('📩 Skipping duplicate inquiry navigation for $id');
        return;
      }

      final secureStorage = _ref.read(secureStorageServiceProvider);
      final savedToken = await secureStorage.getBearerToken();
      final pendingUri = Uri.parse('app://partnerinquirydetail/$id');

      if (savedToken == null || savedToken.isEmpty) {
        _pendingDeepLink = pendingUri;
        debugPrint('📩 Inquiry queued until login: $id');
        final currentRoute = _currentRouteName();
        if (currentRoute != null &&
            currentRoute != 'splash' &&
            currentRoute != 'login' &&
            currentRoute != 'otp') {
          NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
            'login',
            (route) => false,
          );
        }
        return;
      }

      final isPartner = await secureStorage.getIsPartner();
      if (!isPartner) {
        _showError('This notification is for partner accounts only');
        return;
      }

      final currentRoute = _currentRouteName();
      if (NavigationService.navigatorKey.currentState == null ||
          currentRoute == 'splash' ||
          currentRoute == 'login' ||
          currentRoute == 'otp' ||
          currentRoute == 'profileSetup') {
        _pendingDeepLink = pendingUri;
        debugPrint(
          '📩 Inquiry queued until navigation is ready (route=$currentRoute): $id',
        );
        return;
      }

      _lastNavigatedInquiryId = id;
      _lastInquiryNavAt = now;

      if (!fromDeepLink || currentRoute != 'navbar') {
        NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          'navbar',
          (route) => false,
        );
        await Future.delayed(const Duration(milliseconds: 300));
      }

      NavigationService.navigatorKey.currentState?.pushNamed(
        'partnerInquiryDetail',
        arguments: {'inquiryId': id},
      );
      debugPrint('✅ Navigated to Partner Inquiry Details: $id');
    } catch (e) {
      debugPrint('Error navigating to partner inquiry: $e');
      _showError('Unable to open inquiry details');
    }
  }

  String? _currentRouteName() {
    final context = NavigationService.navigatorKey.currentContext;
    if (context == null) return null;
    return ModalRoute.of(context)?.settings.name;
  }

  /// Main deep link handler - routes to appropriate screen
  Future<void> handleDeepLink(Uri uri) async {
    try {
      debugPrint('🔗 Deep link received: ${uri.toString()}');
      debugPrint('🔗 Path segments: ${uri.pathSegments}');
      debugPrint('🔗 Query parameters: ${uri.queryParameters}');

      final savedReferral = await _captureReferral(uri);
      final referralOnly = ReferralCode.isAttributionLink(uri);

      // External http(s) URLs (notification open_url) — open in browser.
      final isHttp = uri.scheme == 'http' || uri.scheme == 'https';
      final isAppHttpsLink = _isAppHost(uri) && uri.path.contains('/app');
      if (isHttp && !isAppHttpsLink && !referralOnly) {
        await launchURL(uri.toString());
        return;
      }

      // Filter out empty segments and 'app' prefix
      var pathSegments = uri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .toList();

      // Remove 'app' prefix if present
      if (pathSegments.isNotEmpty && pathSegments[0] == 'app') {
        pathSegments = pathSegments.sublist(1);
      }

      debugPrint('🔗 Filtered segments: $pathSegments');

      // Verify user is authenticated
      final secureStorage = _ref.read(secureStorageServiceProvider);
      final savedToken = await secureStorage.getBearerToken();

      if (savedToken == null || savedToken.isEmpty) {
        if (referralOnly) {
          // Code is already stored. Leave login / OTP on screen so the
          // field can pick it up instead of restarting the auth flow.
          return;
        }
        // Preserve destination so NavBar can open it after partner/customer login.
        _pendingDeepLink = uri;
        debugPrint(
          'Authentication required for deep link. Queued as pending: $uri',
        );

        final currentRoute = _currentRouteName();
        if (currentRoute == 'splash' || currentRoute == null) {
          // Splash still restoring session — do not interrupt with login.
          return;
        }

        if (NavigationService.navigatorKey.currentState == null) {
          debugPrint('Navigator not ready, retrying...');
          await Future.delayed(const Duration(milliseconds: 500));
        }

        NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          'login',
          (route) => false,
        );
        return;
      }

      if (referralOnly) {
        if (savedReferral) {
          final code = ReferralCode.fromUri(uri);
          if (code != null) {
            _showInfo('Referral code $code saved');
          }
        }
        return;
      }

      // Ensure navigator is ready
      if (NavigationService.navigatorKey.currentState == null) {
        debugPrint('Navigator not ready, retrying...');
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // If no valid route segments, redirect to home
      if (pathSegments.isEmpty) {
        debugPrint('🔗 No valid route in deep link, redirecting to home');
        await _navigateToHome();
        return;
      }

      // Route based on path
      final route = pathSegments[0].toLowerCase();
      final id = pathSegments.length > 1 ? pathSegments[1] : null;

      switch (route) {
        case 'shopdetail':
          await _navigateToShop(id);
          break;
        case 'offerdetail':
          await _navigateToOffer(id);
          break;
        case 'rewarddetail':
          await _navigateToReward(id);
          break;
        case 'partnerinquirydetail':
        case 'partner-inquiry-detail':
        case 'inquirydetail':
        case 'inquiry':
          await _navigateToPartnerInquiry(id, fromDeepLink: true);
          break;
        case 'notifications':
          await _navigateToNotifications();
          break;
        case 'profile':
        case 'myaccount':
          await _navigateToProfile();
          break;
        case 'general':
          await _navigateToHome();
          break;
        default:
          debugPrint(
            '🔗 Unknown deep link route: $route. Staying on current page.',
          );
          break;
      }
    } catch (e) {
      debugPrint('❌ Deep link handling error: $e');
      _showError('Unable to process the link');
    }
  }

  /// Navigate to home/navbar
  Future<void> _navigateToHome() async {
    try {
      NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        'navbar',
        (route) => false,
      );
      _ref.read(selectedIndexProvider.notifier).updateIndex(0);
      debugPrint('✅ Navigated to Home');
    } catch (e) {
      debugPrint('Error navigating to home: $e');
    }
  }

  /// Navigate to Shop
  Future<void> _navigateToShop(String? shopId) async {
    try {
      NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        'navbar',
        (route) => false,
      );
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (shopId != null && shopId.isNotEmpty) {
        final shop = await _ref.read(getShopByPartnerIdProvider(shopId).future);
        if (shop != null) {
          NavigationService.navigatorKey.currentState?.pushNamed(
            'shopDetail',
            arguments: shop,
          );
          debugPrint('✅ Navigated to Shop Details: $shopId');
        } else {
          _showError('Shop not found.');
        }
      }
    } catch (e) {
      debugPrint('Error navigating to shop: $e');
      _showError('Unable to navigate to Shop');
    }
  }

  /// Navigate to Offer
  Future<void> _navigateToOffer(String? offerId) async {
    try {
      NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        'navbar',
        (route) => false,
      );
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (offerId != null && offerId.isNotEmpty) {
        final offer = await _ref.read(getOfferByIdProvider(offerId).future);
        if (offer != null) {
          NavigationService.navigatorKey.currentState?.pushNamed(
            'offerDetail',
            arguments: offer.toJson(),
          );
          debugPrint('✅ Navigated to Offer Details: $offerId');
        } else {
          _showError('Offer not found.');
        }
      }
    } catch (e) {
      debugPrint('Error navigating to offer: $e');
      _showError('Unable to navigate to Offer');
    }
  }

  /// Navigate to Reward
  Future<void> _navigateToReward(String? rewardId) async {
    try {
      NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        'navbar',
        (route) => false,
      );
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (rewardId != null && rewardId.isNotEmpty) {
        final reward = await _ref.read(getRewardByIdProvider(rewardId).future);
        if (reward != null) {
          NavigationService.navigatorKey.currentState?.pushNamed(
            'rewardDetail',
            arguments: reward.toJson(),
          );
          debugPrint('✅ Navigated to Reward Details: $rewardId');
        } else {
          _showError('Reward not found.');
        }
      }
    } catch (e) {
      debugPrint('Error navigating to reward: $e');
      _showError('Unable to navigate to Reward');
    }
  }

  Future<void> _navigateToNotifications() async {
    try {
      NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        'navbar',
        (route) => false,
      );
      await Future.delayed(const Duration(milliseconds: 300));
      _ref
          .read(selectedIndexProvider.notifier)
          .updateIndex(0); // Use Home as base
      NavigationService.navigatorKey.currentState?.pushNamed('notifications');
      debugPrint('✅ Navigated to Notifications');
    } catch (e) {
      debugPrint('Error navigating to notifications: $e');
      _showError('Unable to navigate to Notifications');
    }
  }

  /// Navigate to profile
  Future<void> _navigateToProfile() async {
    try {
      NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        'navbar',
        (route) => false,
      );
      await Future.delayed(const Duration(milliseconds: 300));
      _ref
          .read(selectedIndexProvider.notifier)
          .updateIndex(3); // Profile is index 3
      debugPrint('✅ Navigated to Profile');
    } catch (e) {
      debugPrint('Error navigating to profile: $e');
      _showError('Unable to navigate to Profile');
    }
  }

  void _showError(String message) {
    if (NavigationService.navigatorKey.currentContext != null) {
      SnackbarService().showSnackBar(
        NavigationService.navigatorKey.currentContext!,
        message,
        type: SnackbarType.error,
      );
    }
  }

  void _showInfo(String message) {
    final context = NavigationService.navigatorKey.currentContext;
    if (context == null) return;
    SnackbarService().showSnackBar(
      context,
      message,
      type: SnackbarType.info,
    );
  }

  bool _isAppHost(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'setgo.in' ||
        host == 'www.setgo.in' ||
        host == 'setgoinnovations.com' ||
        host == 'www.setgoinnovations.com' ||
        host == 'api-deals.setgoinnovations.com' ||
        host == 'uat-api.setgoinnovations.com';
  }

  Future<bool> _captureReferral(Uri uri) async {
    try {
      final code = ReferralCode.fromUri(uri);
      if (code == null) return false;
      return await _ref.read(referralAttributionProvider).rememberExplicit(code);
    } catch (e) {
      debugPrint('Referral capture failed: $e');
      return false;
    }
  }

  /// Generate deep link URLs for sharing
  /// Use HTTPS links for WhatsApp/social media compatibility
  String generateDeepLink(String route, {String? id}) {
    // Use HTTPS for clickable links in WhatsApp, Gmail, etc.
    const baseUrl = 'https://setgo.in/app';

    switch (route.toLowerCase()) {
      case 'shopdetail':
        return id != null ? '$baseUrl/shopdetail/$id' : '$baseUrl/shopdetail';
      case 'offerdetail':
        return id != null ? '$baseUrl/offerdetail/$id' : '$baseUrl/offerdetail';
      case 'rewarddetail':
        return id != null ? '$baseUrl/rewarddetail/$id' : '$baseUrl/rewarddetail';
      case 'partnerinquirydetail':
      case 'partner-inquiry-detail':
      case 'inquirydetail':
      case 'inquiry':
        return id != null
            ? '$baseUrl/partnerinquirydetail/$id'
            : '$baseUrl/partnerinquirydetail';
      case 'notifications':
        return '$baseUrl/notifications';
      case 'profile':
      case 'myaccount':
        return '$baseUrl/myaccount';
      default:
        return '$baseUrl/general';
    }
  }
}
