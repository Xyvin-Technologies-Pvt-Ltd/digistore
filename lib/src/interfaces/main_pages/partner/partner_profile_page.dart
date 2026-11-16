import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/providers/partner_provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../components/partner/partner_menu_item.dart';
import '../../components/partner/partner_action_card.dart';
import '../../components/partner/partner_profile_header.dart';
import '../../components/partner/partner_plan_details_sheet.dart';
import '../../components/confirmation_dialog.dart';
import '../../animations/index.dart';
import '../../../data/utils/notification_permission_helper.dart';
import '../../../data/services/notification_service/notification_service.dart';
import '../../../data/providers/notifications_provider.dart';

class PartnerProfilePage extends ConsumerStatefulWidget {
  const PartnerProfilePage({super.key});

  @override
  ConsumerState<PartnerProfilePage> createState() => _PartnerProfilePageState();
}

class _PartnerProfilePageState extends ConsumerState<PartnerProfilePage>
    with WidgetsBindingObserver {
  static const _bg = Color(0xFFF3F5F4);
  static const _accent = Color(0xFF6155F5);

  bool _wasInBackground = false;
  bool _isNotificationsEnabled = true;
  bool _isTokenRegistered = true;
  bool _isHiding = false;
  String? _currentFcmToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNotificationStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasInBackground = true;
    } else if (state == AppLifecycleState.resumed) {
      if (_wasInBackground) {
        _wasInBackground = false;
        _checkNotificationStatus();
      }
    }
  }

  Future<void> _checkNotificationStatus() async {
    final isAllowed =
        await NotificationPermissionHelper.isNotificationAllowed();
    final notifService = ref.read(notificationServiceProvider);
    final token = await notifService.getToken();
    final partner = ref.read(partnerProvider);

    bool isRegistered = false;
    if (token != null && partner?.devices != null) {
      isRegistered = partner!.devices!.any((d) => d.fcmToken == token);
    }

    if (mounted) {
      setState(() {
        _isNotificationsEnabled = isAllowed && isRegistered;
        _isTokenRegistered = isRegistered;
        _currentFcmToken = token;
      });
    }
  }

  void _syncWithProvider() {
    final partner = ref.read(partnerProvider);
    if (_currentFcmToken != null && partner?.devices != null) {
      final isRegistered = partner!.devices!.any(
        (d) => d.fcmToken == _currentFcmToken,
      );
      if (isRegistered != _isTokenRegistered && !_isHiding) {
        setState(() {
          _isTokenRegistered = isRegistered;
          if (isRegistered) _isNotificationsEnabled = true;
        });
      }
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      final permissions =
          await NotificationPermissionHelper.requestAllPermissions(context);
      if (permissions) {
        final notifService = ref.read(notificationServiceProvider);
        final token = await notifService.getToken();
        if (token != null) {
          final success = await ref
              .read(notificationsProvider.notifier)
              .registerDeviceToken(token);
          if (success && mounted) {
            setState(() {
              _isNotificationsEnabled = true;
              _currentFcmToken = token;
            });

            await Future.delayed(const Duration(seconds: 1));

            if (mounted) {
              setState(() {
                _isHiding = true;
              });

              await Future.delayed(const Duration(milliseconds: 600));

              if (mounted) {
                setState(() {
                  _isTokenRegistered = true;
                  _isHiding = false;
                });
              }
            }
          }
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please disable notifications from system settings.'),
        ),
      );
    }
  }

  Widget _menuIcon(IconData icon) {
    return Icon(icon, color: const Color(0xFF595959), size: 20);
  }

  Widget _settingsGap() => const SizedBox(height: 12);

  @override
  Widget build(BuildContext context) {
    ref.listen(partnerProvider, (previous, next) {
      _syncWithProvider();
    });
    final screenSize = ref.watch(screenSizeProvider);
    final showNotifCard =
        !(_isTokenRegistered && _isNotificationsEnabled) && !_isHiding;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: _bg,
        surfaceTintColor: _bg,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          'Profile',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF373737),
            letterSpacing: 0.1,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF373737),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenSize.responsivePadding(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              PartnerProfileHeader(screenSize: screenSize),
              const SizedBox(height: 16),
              Row(
                children: [
                  PartnerActionCard(
                    screenSize: screenSize,
                    title: 'Offers',
                    iconData: Icons.local_offer_outlined,
                    onTap: () => Navigator.pushNamed(context, 'offers'),
                  ),
                  const SizedBox(width: 16),
                  PartnerActionCard(
                    screenSize: screenSize,
                    title: 'Products',
                    iconData: Icons.inventory_2_outlined,
                    onTap: () =>
                        Navigator.pushNamed(context, 'partnerProducts'),
                  ),
                  const SizedBox(width: 16),
                  PartnerActionCard(
                    screenSize: screenSize,
                    title: 'History',
                    iconData: Icons.history_rounded,
                    onTap: () => Navigator.pushNamed(context, 'partnerHistory'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                switchOutCurve: Curves.easeInOutBack,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        axisAlignment: -1,
                        child: child,
                      ),
                    ),
                  );
                },
                child: showNotifCard
                    ? Container(
                        key: const ValueKey('notif_card_partner'),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _accent.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_active_rounded,
                                  color: _accent,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Push Notifications',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Stay updated on sales & redemptions',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _isNotificationsEnabled,
                                onChanged: _toggleNotifications,
                                activeColor: _accent,
                                activeTrackColor: _accent.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).fadeSlideInFromBottom(delayMilliseconds: 150)
                    : const SizedBox.shrink(),
              ),
              if (showNotifCard) const SizedBox(height: 16),
              PartnerMenuItem(
                title: 'Account',
                icon: _menuIcon(Icons.person_outline_rounded),
                screenSize: screenSize,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    'partnerAccount',
                    arguments: {'isEditMode': false},
                  );
                },
              ),
              _settingsGap(),
              PartnerMenuItem(
                title: 'Bookings',
                icon: _menuIcon(Icons.calendar_month_outlined),
                screenSize: screenSize,
                onTap: () => Navigator.pushNamed(context, 'partnerBookings'),
              ),
              _settingsGap(),
              PartnerMenuItem(
                title: 'Enquiries',
                icon: _menuIcon(Icons.shopping_bag_outlined),
                screenSize: screenSize,
                onTap: () => Navigator.pushNamed(context, 'partnerInquiries'),
              ),
              _settingsGap(),
              PartnerMenuItem(
                title: 'Plan Details',
                icon: _menuIcon(Icons.card_membership_outlined),
                screenSize: screenSize,
                onTap: () => PartnerPlanDetailsSheet.show(context),
              ),
              _settingsGap(),
              PartnerMenuItem(
                title: 'Reviews',
                icon: _menuIcon(Icons.star_outline_rounded),
                screenSize: screenSize,
                onTap: () => Navigator.pushNamed(context, 'partnerReviews'),
              ),
              _settingsGap(),
              PartnerMenuItem(
                title: 'Support Ticket',
                icon: _menuIcon(Icons.support_agent_rounded),
                screenSize: screenSize,
                onTap: () => Navigator.pushNamed(context, 'support'),
              ),
              _settingsGap(),
              PartnerMenuItem(
                title: 'Help & Support',
                icon: _menuIcon(Icons.help_outline_rounded),
                screenSize: screenSize,
                onTap: () => Navigator.pushNamed(context, 'helpSupport'),
              ),
              _settingsGap(),
              PartnerMenuItem(
                title: 'Privacy Policy',
                icon: _menuIcon(Icons.privacy_tip_outlined),
                screenSize: screenSize,
                onTap: () => Navigator.pushNamed(context, 'privacyPolicy'),
              ),
              _settingsGap(),
              PartnerMenuItem(
                title: 'Terms & Conditions',
                icon: _menuIcon(Icons.description_outlined),
                screenSize: screenSize,
                onTap: () => Navigator.pushNamed(context, 'termsConditions'),
              ),
              _settingsGap(),
              PartnerMenuItem(
                title: 'About app',
                icon: _menuIcon(Icons.info_outline_rounded),
                screenSize: screenSize,
                onTap: () => Navigator.pushNamed(context, 'aboutApp'),
              ),
              _settingsGap(),
              PartnerMenuItem(
                title: 'FAQ',
                icon: _menuIcon(Icons.chat_bubble_outline_rounded),
                screenSize: screenSize,
                onTap: () => Navigator.pushNamed(context, 'partnerFaq'),
              ),
              _settingsGap(),
              PartnerMenuItem(
                title: 'Logout',
                icon: _menuIcon(Icons.logout_rounded),
                screenSize: screenSize,
                onTap: () async {
                  final confirmed = await showConfirmationDialog(
                    context: context,
                    title: 'Logout',
                    message:
                        'Are you sure you want to logout from your account?',
                    confirmText: 'Logout',
                    cancelText: 'Cancel',
                    isDestructive: true,
                    icon: Icons.logout_rounded,
                    onConfirm: () async {
                      await ref.read(authProvider.notifier).logout();
                    },
                  );

                  if (confirmed == true && context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      'login',
                      (route) => false,
                    );
                  }
                },
              ),
              SizedBox(height: screenSize.responsivePadding(40)),
            ],
          ),
        ),
      ),
    );
  }
}
