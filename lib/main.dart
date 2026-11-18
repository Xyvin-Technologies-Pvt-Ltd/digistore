import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

import 'src/data/router/router.dart';
import 'src/data/providers/screen_size_provider.dart';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'firebase_options.dart';
import 'src/data/services/notification_service/notification_controller.dart';
import 'src/data/services/navigation_service.dart';
import 'src/data/services/connectivity_service.dart';
import 'src/data/constants/style_constants.dart';
import 'src/data/utils/install_checker.dart';

bool _isBenignSvgParseError(Object error) {
  final text = error.toString();
  return text.contains('XmlParserException') ||
      text.contains('SvgParser') ||
      text.contains('vector_graphics_compiler');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await InstallChecker().checkFirstInstall();
  ConnectivityService.instance.initialize();

  if (Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (_) {
      // Gracefully ignore if the device or OS does not support display mode switching
    }
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FlutterError.onError = (errorDetails) {
    // Mislabelled remote icons (JPEG served as .svg) can surface here via
    // flutter_svg's cache; never treat those as fatal app crashes.
    if (_isBenignSvgParseError(errorDetails.exception)) {
      FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
      return;
    }
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (_isBenignSvgParseError(error)) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
      return true;
    }
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Disable OS device notifications when app is in foreground
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: false,
    badge: false,
    sound: false,
  );

  await AwesomeNotifications().initialize(null, [
    NotificationChannel(
      channelKey: 'channel_setgo',
      channelName: 'Setgo Notifications',
      channelDescription: 'Notification channel for Setgo app',
      defaultColor: const Color(0xFF1e3a81),
      ledColor: Colors.white,
      importance: NotificationImportance.Max,
      channelShowBadge: true,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      criticalAlerts: true,
      defaultRingtoneType: DefaultRingtoneType.Notification,
    ),
    NotificationChannel(
      channelKey: 'channel_setgo_silent_v2',
      channelName: 'Setgo Silent Tray',
      channelDescription: 'Silent notifications for the tray',
      defaultColor: const Color(0xFF1e3a81),
      ledColor: Colors.white,
      importance: NotificationImportance.Default,
      channelShowBadge: true,
      playSound: false,
      enableVibration: false,
      enableLights: false,
      criticalAlerts: false,
    ),
  ], debug: true);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  AwesomeNotifications().setListeners(
    onActionReceivedMethod: NotificationController.onActionReceivedMethod,
    onNotificationCreatedMethod:
        NotificationController.onNotificationCreatedMethod,
    onNotificationDisplayedMethod:
        NotificationController.onNotificationDisplayedMethod,
    onDismissActionReceivedMethod:
        NotificationController.onDismissActionReceivedMethod,
  );
  runApp(const ProviderScope(child: ScreenSizeScope(child: MyApp())));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Setgo',
      theme: ThemeData(
        fontFamily: kFontFamily,
        textTheme: ThemeData.light().textTheme.apply(fontFamily: kFontFamily),
        primaryTextTheme: ThemeData.light().primaryTextTheme.apply(
          fontFamily: kFontFamily,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          titleTextStyle: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF373737),
          ),
        ),
      ),
      initialRoute: 'splash',
      onGenerateRoute: generateRoute,
    );
  }
}
