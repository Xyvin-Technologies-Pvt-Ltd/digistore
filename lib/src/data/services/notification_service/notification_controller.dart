import 'dart:async';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../../../../firebase_options.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint('Handling background message: ${message.messageId}');

  // FCM automatically presents system notifications for message.notification != null.
  // Only create a local notification for data-only push messages to avoid duplicate notifications.
  if (message.notification == null && message.data.isNotEmpty) {
    final title = message.data['title'] ?? message.data['heading'];
    final body = message.data['body'] ?? message.data['message'];
    if (title != null || body != null) {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: message.hashCode,
          channelKey: 'channel_setgo',
          title: title.toString(),
          body: body.toString(),
          bigPicture: message.data['imageUrl']?.toString(),
          largeIcon: message.data['imageUrl']?.toString(),
          notificationLayout: message.data['imageUrl'] != null
              ? NotificationLayout.BigPicture
              : NotificationLayout.Default,
          payload: message.data.map(
            (key, value) => MapEntry(key, value.toString()),
          ),
          category: NotificationCategory.Message,
          autoDismissible: true,
          showWhen: true,
          criticalAlert: true,
          wakeUpScreen: true,
          fullScreenIntent: true,
        ),
      );
    }
  }
}

class NotificationController {
  /// Use this method to detect when a new notification or a schedule is created
  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    debugPrint('🔔 Notification created: ${receivedNotification.id}');
  }

  /// Use this method to detect every time that a new notification is displayed
  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    debugPrint('🔔 Notification displayed: ${receivedNotification.id}');
  }

  /// Use this method to detect if the user dismissed a notification
  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    debugPrint('🔔 Notification dismissed: ${receivedAction.id}');
  }

  static final StreamController<String> deepLinkStream =
      StreamController<String>.broadcast();

  /// Use this method to detect when the user taps on a notification or action button
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    debugPrint('🔔 Notification action received: ${receivedAction.payload}');

    if (receivedAction.payload != null) {
      final payload = receivedAction.payload!;
      String? deepLink = payload['deepLink'];

      if (deepLink == null) {
        final screen = payload['screen'] ?? payload['actionScreen'];
        final actionType =
            (payload['actionType'] ?? payload['action_type'] ?? '')
                .toLowerCase();
        final id = payload['actionTargetId'] ??
            payload['targetId'] ??
            payload['inquiryId'] ??
            payload['cartId'] ??
            payload['id'];

        if (screen != null) {
          // Construct the internal app link format expected by DeepLinkService
          deepLink = 'app://$screen${id != null ? '/$id' : ''}';
        } else if (actionType == 'open_product_inquiry' &&
            id != null &&
            id.isNotEmpty) {
          deepLink = 'app://partnerinquirydetail/$id';
        } else if (actionType == 'open_offer' && id != null && id.isNotEmpty) {
          deepLink = 'app://offerdetail/$id';
        } else if ((actionType == 'open_shop' || actionType == 'open_branch') &&
            id != null &&
            id.isNotEmpty) {
          deepLink = 'app://shopdetail/$id';
        } else if (actionType == 'open_reward' && id != null && id.isNotEmpty) {
          deepLink = 'app://rewarddetail/$id';
        }
      }

      if (deepLink != null) {
        debugPrint('Deep link to handle: $deepLink');
        deepLinkStream.add(deepLink);
      }
    }
  }
}
