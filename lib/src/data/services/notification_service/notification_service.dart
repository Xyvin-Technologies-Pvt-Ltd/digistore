import 'dart:developer';
import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setgo/src/data/services/deep_link_service.dart';
import 'package:setgo/src/data/services/navigation_service.dart';
import 'package:setgo/src/interfaces/components/in_app_notification_overlay.dart';
import 'package:flutter/material.dart';
import 'package:setgo/src/data/providers/notifications_provider.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final deepLinkService = ref.watch(deepLinkServiceProvider);
  return NotificationService(ref, deepLinkService);
});

/// Notification Service
///
/// Features:
/// - In-app overlay notifications (foreground) - WhatsApp style
/// - System heads-up notifications (background) - pops up on screen
/// - Deep linking support
/// - FCM integration
///
/// Permissions are handled by get_fcm.dart
class NotificationService {
  final Ref _ref;
  final DeepLinkService _deepLinkService;

  NotificationService(this._ref, this._deepLinkService);

  static const String _channelKey = 'channel_setgo';
  static const String _channelName = 'Setgo Notifications';
  static const String _channelDescription =
      'Notification channel for Setgo app';

  static bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('🔔 Notification Service already initialized');
      return;
    }
    try {
      debugPrint('🔔 Initializing Notification Service...');

      // Configure FCM foreground presentation options to prevent OS duplicate system notifications in foreground
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: true,
            sound: false,
          );

      // Channel is already initialized in main.dart
      // Just verify it exists
      final isAllowed = await AwesomeNotifications().isNotificationAllowed();
      debugPrint('✅ Notification channel verified, allowed: $isAllowed');

      // Set up FCM handlers
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint("🔑 New FCM Token: $newToken");
      });

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      await _handleInitialMessage();

      _isInitialized = true;
      debugPrint('✅ Notification Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Notification initialization error: $e');
    }
  }

  /// Check if notifications are allowed
  Future<bool> isNotificationAllowed() async {
    return await AwesomeNotifications().isNotificationAllowed();
  }

  void _handleForegroundMessage(RemoteMessage message) {
    log("Notification received in FOREGROUND: ${message.data}");

    // Update unread count and notification list locally without calling unread-count API
    _ref.read(notificationsProvider.notifier).addNotificationFromPush(message);

    try {
      final title =
          message.notification?.title ??
          message.data['title'] ??
          message.data['heading'];
      final body =
          message.notification?.body ??
          message.data['body'] ??
          message.data['message'];

      if (title != null || body != null) {
        final dataMap = Map<String, dynamic>.from(
          message.data.map((k, v) => MapEntry(k.toString(), v)),
        );
        String? deepLink;
        String? screen = dataMap['screen'] ?? dataMap['actionScreen'];
        final actionType =
            (dataMap['actionType'] ?? '').toString().toLowerCase();
        final metadata = dataMap['metadata'];
        String? metaCartId;
        String? metaInquiryId;
        if (metadata is Map) {
          metaCartId = metadata['cartId']?.toString();
          metaInquiryId = metadata['inquiryId']?.toString();
        }
        String? id = dataMap['actionTargetId']?.toString() ??
            dataMap['targetId']?.toString() ??
            metaInquiryId ??
            metaCartId ??
            dataMap['inquiryId']?.toString() ??
            dataMap['cartId']?.toString() ??
            dataMap['id']?.toString();

        if (screen != null) {
          deepLink = _deepLinkService.generateDeepLink(screen, id: id);
        } else if (actionType == 'open_product_inquiry') {
          deepLink = _deepLinkService.generateDeepLink(
            'partnerinquirydetail',
            id: id,
          );
        } else if (actionType == 'open_offer') {
          deepLink = _deepLinkService.generateDeepLink('offerdetail', id: id);
        } else if (actionType == 'open_shop' || actionType == 'open_branch') {
          deepLink = _deepLinkService.generateDeepLink('shopdetail', id: id);
        } else if (actionType == 'open_reward') {
          deepLink = _deepLinkService.generateDeepLink('rewarddetail', id: id);
        } else if (actionType == 'open_url' &&
            (dataMap['actionUrl'] ?? dataMap['url']) != null) {
          deepLink = (dataMap['actionUrl'] ?? dataMap['url']).toString();
        }

        // ALWAYS show in-app notification overlay when app is in foreground
        final context = NavigationService.navigatorKey.currentContext;
        if (context != null && context.mounted) {
          debugPrint('Showing IN-APP notification overlay');
          InAppNotificationOverlay.show(
            context,
            overlayState: NavigationService.navigatorKey.currentState?.overlay,
            title: title?.toString() ?? 'Notification',
            message: body?.toString() ?? '',
            imageUrl:
                message.notification?.android?.imageUrl ??
                message.data['imageUrl']?.toString(),
            accentColor: const Color(0xFF1e3a81),
            onTap: () {
              if (deepLink != null &&
                  (deepLink.startsWith('http://') ||
                      deepLink.startsWith('https://')) &&
                  !deepLink.contains('setgo.in/app')) {
                _deepLinkService.handleNotificationData(dataMap);
              } else if (deepLink != null) {
                _deepLinkService.handleDeepLink(Uri.parse(deepLink));
              } else {
                _deepLinkService.handleNotificationData(dataMap);
              }
            },
            onTimeout: () {
              debugPrint(
                'Overlay timed out, adding silent notification to tray',
              );
              _showSystemNotification(message, deepLink);
            },
          );
        } else {
          debugPrint(
            'Context not available, adding silent notification to tray',
          );
          _showSystemNotification(message, deepLink);
        }
      }
    } catch (e) {
      debugPrint('Foreground message handling error: $e');
    }
  }

  void _showSystemNotification(RemoteMessage message, String? deepLink) {
    debugPrint('Creating silent tray notification');
    final title =
        message.notification?.title ??
        message.data['title'] ??
        message.data['heading'];
    final body =
        message.notification?.body ??
        message.data['body'] ??
        message.data['message'];

    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: message.hashCode,
        channelKey:
            'channel_setgo_silent_v2', // Silent channel with status bar icon
        title: title?.toString(),
        body: body?.toString(),
        bigPicture:
            message.notification?.android?.imageUrl ??
            message.data['imageUrl']?.toString(),
        largeIcon:
            message.notification?.android?.imageUrl ??
            message.data['imageUrl']?.toString(),
        notificationLayout:
            (message.notification?.android?.imageUrl != null ||
                message.data['imageUrl'] != null)
            ? NotificationLayout.BigPicture
            : NotificationLayout.Default,
        payload: deepLink != null ? {'deepLink': deepLink} : null,
        category: NotificationCategory.Message,
        autoDismissible: true,
        showWhen: true,
        criticalAlert: false, // Don't pop up
        wakeUpScreen: false, // Don't turn on screen
        fullScreenIntent: false, // Keep strictly in tray
        locked: false,
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'OPEN',
          label: 'Open',
          autoDismissible: true,
        ),
      ],
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    try {
      // Refresh unread count when app is opened via notification (throttled)
      _ref.read(notificationsProvider.notifier).fetchUnreadCount();

      final dataMap = Map<String, dynamic>.from(
        message.data.map((k, v) => MapEntry(k.toString(), v)),
      );
      _deepLinkService.handleNotificationData(dataMap);
    } catch (e) {
      debugPrint('Message opened app handling error: $e');
    }
  }

  Future<void> _handleInitialMessage() async {
    try {
      RemoteMessage? initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        debugPrint('Handling initial message');
        _handleMessageOpenedApp(initialMessage);
      }
    } catch (e) {
      debugPrint('Initial message handling error: $e');
    }
  }

  Future<String?> getToken() async {
    try {
      if (Platform.isIOS) {
        final messaging = FirebaseMessaging.instance;
        String? apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null) {
          int retries = 0;
          while (apnsToken == null && retries < 10) {
            await Future.delayed(const Duration(milliseconds: 500));
            apnsToken = await messaging.getAPNSToken();
            retries++;
          }
        }
        if (apnsToken == null) {
          debugPrint('APNs token is null, skipping FCM token fetch on iOS');
          return null;
        }
      }
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  Future<void> cancelNotification(int id) async {
    await AwesomeNotifications().cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }
}
