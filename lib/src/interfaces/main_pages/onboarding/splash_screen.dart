import 'dart:developer';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../data/constants/color_constants.dart';
import '../../../data/constants/style_constants.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/services/secure_storage_service.dart';
import '../../../data/providers/user_provider.dart';
import '../../../data/providers/partner_provider.dart';
import '../../../data/providers/user_type_provider.dart';
import '../../../data/services/notification_service/notification_service.dart';
import '../../../data/services/deep_link_service.dart';
import '../../../data/providers/app_version_provider.dart';
import '../../../data/providers/referral_provider.dart';
import '../../components/update_maintenance_bottom_sheet.dart';
import 'login_page.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _blurAnimation;
  late Animation<Offset> _slideAnimation;

  // Slogan animations
  late AnimationController _sloganController;
  late Animation<double> _sloganOpacity;
  late Animation<Offset> _sloganSlide;

  bool _showUpdateOverlay = false;
  AppVersionCheckResult? _versionCheckResult;

  @override
  void initState() {
    super.initState();

    // Initialize notification and deep link handling.
    // Referral capture starts in parallel and must not hold the splash.
    ref.read(deepLinkServiceProvider).initialize();
    ref.read(referralAttributionProvider).resolveDeferred();
    ref.read(notificationServiceProvider).initialize();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _sloganController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.5,
          end: 1.1,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.1,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_entranceController);

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _blurAnimation = Tween<double>(begin: 15.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
          ),
        );

    _sloganOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _sloganController, curve: Curves.easeIn));

    _sloganSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _sloganController, curve: Curves.easeOutBack),
        );

    _playAnimations();
  }

  Future<void> _playAnimations() async {
    // Start the animation immediately so the screen doesn't stay blank
    final animationFuture = _entranceController.forward();
    
    // Fetch the FCM token in the background without blocking the UI
    ref.read(notificationServiceProvider).getToken().then((token) {
      log('FCM Token: $token');
    }).catchError((error) {
      log('FCM Token error: $error');
    });

    await animationFuture;
    await Future.delayed(const Duration(milliseconds: 100));
    await _sloganController.forward();
    
    // Check for app version and maintenance
    final versionResult = await ref.read(appVersionProvider.notifier).checkAppVersion();
    
    if (versionResult.isMaintenanceMode || versionResult.needsHardUpdate || versionResult.needsSoftUpdate) {
      if (mounted) {
        setState(() {
          _versionCheckResult = versionResult;
          _showUpdateOverlay = true;
        });
      }
      return; // Stop and do not proceed to onboarding automatically
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      _navigateToOnboarding();
    }
  }

  Future<void> _navigateToOnboarding() async {
    final storage = ref.read(secureStorageServiceProvider);
    final isPartner = await storage.getIsPartner();

    // Set the user type which also updates GlobalVariables and persists it
    ref
        .read(userTypeProvider.notifier)
        .setUserType(isPartner ? UserType.partner : UserType.customer);

    final hasToken = await storage.hasBearerToken();

    if (!mounted) return;

    if (hasToken) {
      while (true) {
        final userType = ref.read(userTypeProvider);
        final int? statusCode;

        if (userType == UserType.partner) {
          statusCode = await ref
              .read(partnerProvider.notifier)
              .getPartnerProfile();
        } else {
          statusCode = await ref.read(userProvider.notifier).getProfile();
        }

        if (!mounted) return;

        if (statusCode == 200) {
          final bool isComplete;
          if (userType == UserType.partner) {
            isComplete = true; // Partners bypass profile setup
          } else {
            final user = ref.watch(userProvider);
            isComplete = user?.onboardingComplete ?? false;
          }

          await storage.saveOnboardingComplete(isComplete);

          if (isComplete) {
            Navigator.of(context).pushReplacementNamed('navbar');
          } else {
            Navigator.of(context).pushReplacementNamed('profileSetup');
          }
          break;
        } else if (statusCode == null) {
          // Network problem or parsing error -> Stay and Retry
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Network error. Retrying in 3 seconds...'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          await Future.delayed(const Duration(seconds: 3));
        } else {
          // Actual status code error (401, 403, 500, etc.) -> Login
          await storage.clearAll();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
          break;
        }
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _shimmerController.dispose();
    _sloganController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    final logoSize = screenSize.responsivePadding(180);

    return Scaffold(
      backgroundColor: kWhite,
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: kWhite,
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FA)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _entranceController,
                    builder: (context, child) {
                      return SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _opacityAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: _blurAnimation.value,
                                sigmaY: _blurAnimation.value,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: logoSize,
                                    height: logoSize,
                                    child: Image.asset(
                                      'assets/png/setgo.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  if (_entranceController.value > 0.5)
                                    Shimmer.fromColors(
                                      baseColor: Colors.transparent,
                                      highlightColor: Colors.white.withOpacity(
                                        0.8,
                                      ),
                                      period: const Duration(
                                        milliseconds: 1500,
                                      ),
                                      direction: ShimmerDirection.ltr,
                                      child: SizedBox(
                                        width: logoSize,
                                        height: logoSize,
                                        child: Image.asset(
                                          'assets/png/setgo.png',
                                          fit: BoxFit.contain,
                                          color: Colors.white.withAlpha(200),
                                          colorBlendMode: BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: screenSize.responsivePadding(20)),
                  AnimatedBuilder(
                    animation: _sloganController,
                    builder: (context, child) {
                      return SlideTransition(
                        position: _sloganSlide,
                        child: FadeTransition(
                          opacity: _sloganOpacity,
                          child: Text(
                            'Spend Local. Save Big.',
                            style: kSmallTitleL.copyWith(
                              color: kSecondaryTextColor,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_showUpdateOverlay && _versionCheckResult != null)
            UpdateMaintenanceOverlay(
              isMaintenance: _versionCheckResult!.isMaintenanceMode,
              isHardUpdate: _versionCheckResult!.needsHardUpdate,
              isSoftUpdate: _versionCheckResult!.needsSoftUpdate,
              title: _versionCheckResult!.isMaintenanceMode ? 'Under Maintenance' : 'Update Available',
              message: _versionCheckResult!.isMaintenanceMode 
                  ? (_versionCheckResult!.data?.maintenanceMessage ?? 'We are currently undergoing maintenance. Please try again later.')
                  : 'A new version of the app is available. Please update for the best experience.',
              updateUrl: _versionCheckResult!.data?.updateUrl,
              onDismiss: () {
                setState(() {
                  _showUpdateOverlay = false;
                });
                _navigateToOnboarding();
              },
            ),
        ],
      ),
    );
  }
}
