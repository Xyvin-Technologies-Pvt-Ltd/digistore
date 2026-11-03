import 'package:setgo/src/data/utils/interactive_feedback_button.dart';
import 'package:setgo/src/interfaces/animations/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../data/constants/color_constants.dart';
import '../../../data/constants/style_constants.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/utils/global_variables.dart';
import '../../../data/models/user_model.dart';
import '../../components/confirmation_dialog.dart';
import '../history.dart';
import '../services/my_bookings_page.dart';
import '../../../data/utils/notification_permission_helper.dart';
import '../../../data/services/notification_service/notification_service.dart';
import '../../../data/providers/notifications_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with WidgetsBindingObserver {
  bool _wasInBackground = false;
  bool _isNotificationsEnabled = true;
  bool _isTokenRegistered = true;
  bool _isHiding = false;
  String? _currentFcmToken;

  static const _pageBg = Color(0xFFF1F3F2);
  static const _iconCircleBg = Color(0xFFF2F0FD);
  static const _menuIconColor = Color(0xFF6155F5);
  static const _dividerColor = Color(0xFFE5E7EB);

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
    final user = ref.read(userProvider);

    bool isRegistered = false;
    if (token != null && user?.devices != null) {
      isRegistered = user!.devices!.any((d) => d.fcmToken == token);
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
    final user = ref.read(userProvider);
    if (_currentFcmToken != null && user?.devices != null) {
      final isRegistered = user!.devices!.any(
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

  Widget _menuIcon(IconData icon, {Color? color}) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: _iconCircleBg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: color ?? _menuIconColor),
    );
  }

  Widget _buildMenuItem(
    String title,
    IconData iconData,
    ScreenSizeData screenSize, {
    VoidCallback? onTap,
    Color? textColor,
    Color? iconColor,
    bool showDivider = true,
  }) {
    final isDestructive = textColor == kRed;
    return Column(
      children: [
        InteractiveFeedbackButton(
          onPressed: onTap ?? () {},
          scaleFactor: 0.98,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenSize.responsivePadding(16),
              vertical: screenSize.responsivePadding(14),
            ),
            child: Row(
              children: [
                _menuIcon(
                  iconData,
                  color: isDestructive ? kRed : (iconColor ?? _menuIconColor),
                ),
                SizedBox(width: screenSize.responsivePadding(14)),
                Expanded(
                  child: Text(
                    title,
                    style: kSmallTitleL.copyWith(
                      color: textColor ?? const Color(0xFF111827),
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: screenSize.responsivePadding(22),
                  color: const Color(0xFFD1D5DB),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 1,
            color: _dividerColor,
            indent: 70,
            endIndent: 16,
          ),
      ],
    );
  }

  Widget _menuCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userProvider, (previous, next) {
      _syncWithProvider();
    });
    final screenSize = ref.watch(screenSizeProvider);
    final user = ref.watch(userProvider);
    final name = (user?.name != null && user!.name!.isNotEmpty)
        ? user.name!
        : 'Guest User';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'G';
    final phone = (user?.phone != null && user!.phone!.isNotEmpty)
        ? user.phone!
        : '9998877766';
    final locationName =
        (user?.location?.localBody != null &&
            user!.location!.localBody!.isNotEmpty)
        ? user.location!.localBody!.split(' ').first
        : (user?.location?.district != null &&
              user!.location!.district!.isNotEmpty)
        ? user.location!.district!.split(' ').first
        : 'Not Set';

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: _pageBg,
        surfaceTintColor: _pageBg,
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
          'Profile',
          style: kSmallTitleB.copyWith(
            color: const Color(0xFF111827),
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenSize.responsivePadding(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenSize.responsivePadding(8)),
              Row(
                children: [
                  Container(
                    width: screenSize.responsivePadding(56),
                    height: screenSize.responsivePadding(56),
                    decoration: const BoxDecoration(
                      color: kRewardCtaPurple,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: kLargeTitleM.copyWith(color: kWhite, fontSize: 24),
                    ),
                  ),
                  SizedBox(width: screenSize.responsivePadding(14)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: kBodyTitleB.copyWith(
                            color: const Color(0xFF111827),
                            fontSize: 18,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: screenSize.responsivePadding(4)),
                        Row(
                          children: [
                            if (phone.isNotEmpty) ...[
                              Flexible(
                                child: Text(
                                  phone,
                                  style: kSmallerTitleM.copyWith(
                                    color: const Color(0xFF6B7280),
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '  •  ',
                                style: kSmallerTitleM.copyWith(
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                            const Icon(
                              Icons.location_on_outlined,
                              color: Color(0xFF6B7280),
                              size: 14,
                            ),
                            SizedBox(width: screenSize.responsivePadding(2)),
                            Flexible(
                              child: Text(
                                locationName,
                                style: kSmallerTitleM.copyWith(
                                  color: const Color(0xFF6B7280),
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!GlobalVariables.isGuest)
                    InteractiveFeedbackButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          'myAccount',
                          arguments: {'isEditMode': true},
                        );
                      },
                      scaleFactor: 1.1,
                      child: SvgPicture.asset(
                        'assets/svg/edit.svg',
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF111827),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                ],
              ).fadeIn(),

              SizedBox(height: screenSize.responsivePadding(20)),

              // Loyalty Points & Membership Tier Card
              if (!GlobalVariables.isGuest) ...[
                _buildLoyaltyTierCard(context, screenSize, user),
                SizedBox(height: screenSize.responsivePadding(20)),
              ],

              if (!GlobalVariables.isGuest)
                _menuCard(
                  children: [
                    _buildMenuItem(
                      'My Account',
                      Icons.person_outline_rounded,
                      screenSize,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          'myAccount',
                          arguments: {'isEditMode': false},
                        );
                      },
                    ),
                    _buildMenuItem(
                      'My Claimed Vouchers',
                      Icons.card_giftcard_rounded,
                      screenSize,
                      onTap: () {
                        Navigator.pushNamed(context, 'claimedRewards');
                      },
                    ),
                    _buildMenuItem(
                      'My Bookings',
                      Icons.event_note_rounded,
                      screenSize,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyBookingsPage(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      'My History',
                      Icons.history_rounded,
                      screenSize,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HistoryPage(),
                          ),
                        );
                      },
                      showDivider: false,
                    ),
                  ],
                ).fadeSlideInFromBottom(delayMilliseconds: 100),

              if (!GlobalVariables.isGuest)
                SizedBox(height: screenSize.responsivePadding(16)),

              if (!GlobalVariables.isGuest)
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
                          alignment: Alignment.topCenter,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child:
                      (!(_isTokenRegistered && _isNotificationsEnabled) &&
                          !_isHiding)
                      ? Container(
                          key: const ValueKey('notif_card'),
                          decoration: BoxDecoration(
                            color: kWhite,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenSize.responsivePadding(16),
                              vertical: screenSize.responsivePadding(12),
                            ),
                            child: Row(
                              children: [
                                _menuIcon(Icons.notifications_active_rounded),
                                SizedBox(
                                  width: screenSize.responsivePadding(14),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Push Notifications',
                                        style: kSmallTitleL.copyWith(
                                          color: const Color(0xFF111827),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(
                                        height: screenSize.responsivePadding(4),
                                      ),
                                      Text(
                                        'Stay updated on offers & rewards',
                                        style: kSmallerTitleM.copyWith(
                                          color: const Color(0xFF6B7280),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: _isNotificationsEnabled,
                                  onChanged: _toggleNotifications,
                                  activeThumbColor: kRewardCtaPurple,
                                  activeTrackColor: kRewardCtaPurple.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).fadeSlideInFromBottom(delayMilliseconds: 150)
                      : const SizedBox.shrink(),
                ),
              if (!GlobalVariables.isGuest &&
                  !(_isTokenRegistered && _isNotificationsEnabled) &&
                  !_isHiding)
                SizedBox(height: screenSize.responsivePadding(16)),

              _menuCard(
                children: [
                  _buildMenuItem(
                    'Support Ticket',
                    Icons.support_agent_rounded,
                    screenSize,
                    onTap: () {
                      Navigator.pushNamed(context, 'support');
                    },
                  ),
                  _buildMenuItem(
                    'Help & Support',
                    Icons.help_outline_rounded,
                    screenSize,
                    onTap: () {
                      Navigator.pushNamed(context, 'helpSupport');
                    },
                  ),
                  _buildMenuItem(
                    'Privacy Policy',
                    Icons.privacy_tip_outlined,
                    screenSize,
                    onTap: () {
                      Navigator.pushNamed(context, 'privacyPolicy');
                    },
                  ),
                  _buildMenuItem(
                    'Terms & Conditions',
                    Icons.description_outlined,
                    screenSize,
                    onTap: () {
                      Navigator.pushNamed(context, 'termsConditions');
                    },
                  ),
                  _buildMenuItem(
                    'About app',
                    Icons.info_outline_rounded,
                    screenSize,
                    onTap: () {
                      Navigator.pushNamed(context, 'aboutApp');
                    },
                    showDivider: false,
                  ),
                ],
              ).fadeSlideInFromBottom(delayMilliseconds: 200),

              SizedBox(height: screenSize.responsivePadding(16)),

              _menuCard(
                children: [
                  _buildMenuItem(
                    GlobalVariables.isGuest ? 'Login / Register' : 'Logout',
                    GlobalVariables.isGuest
                        ? Icons.login_rounded
                        : Icons.logout_rounded,
                    screenSize,
                    textColor: GlobalVariables.isGuest
                        ? kRewardCtaPurple
                        : kRed,
                    iconColor: GlobalVariables.isGuest
                        ? kRewardCtaPurple
                        : kRed,
                    showDivider: !GlobalVariables.isGuest,
                    onTap: () async {
                      if (GlobalVariables.isGuest) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          'login',
                          (route) => false,
                        );
                        return;
                      }

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
                  if (!GlobalVariables.isGuest)
                    _buildMenuItem(
                      'Delete Account',
                      Icons.person_remove_rounded,
                      screenSize,
                      textColor: kRed,
                      iconColor: kRed,
                      showDivider: false,
                      onTap: () async {
                        final confirmed = await showConfirmationDialog(
                          context: context,
                          title: 'Delete Account',
                          message:
                              'Are you sure you want to delete your account? This action cannot be undone.',
                          confirmText: 'Delete',
                          cancelText: 'Cancel',
                          isDestructive: true,
                          icon: Icons.person_remove_rounded,
                          onConfirm: () async {
                            final success = await ref
                                .read(authProvider.notifier)
                                .deleteAccount();
                            if (!success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Failed to delete account. Please try again.',
                                  ),
                                  backgroundColor: kRed,
                                ),
                              );
                            }
                          },
                        );

                        if (confirmed == true && context.mounted) {
                          final state = ref.read(authProvider);
                          if (!state.hasError) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              'login',
                              (route) => false,
                            );
                          }
                        }
                      },
                    ),
                ],
              ).fadeSlideInFromBottom(delayMilliseconds: 300),

              SizedBox(height: screenSize.responsivePadding(40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoyaltyTierCard(
    BuildContext context,
    ScreenSizeData screenSize,
    UserModel? user,
  ) {
    final int pointsBalance = user?.pointsBalance ?? 0;
    final int totalEarned = user?.totalPointsEarned ?? 0;
    final String currentTier = user?.currentTier?.name ?? 'Bronze';
    final String? nextTier = user?.nextTier?.name;
    final int pointsNeeded = user?.nextTier?.pointsNeeded ?? 0;
    final double progress = (user?.progressToNextTier ?? 0).clamp(0, 100);
    final double? commissionShare = user?.currentTier?.customerCommissionShare;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6155F5), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6155F5).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LOYALTY POINTS BALANCE',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE0E7FF),
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        color: Color(0xFFFDE047),
                        size: 26,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$pointsBalance pts',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total earned: $totalEarned pts',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Color(0xFFC7D2FE),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.military_tech_rounded,
                          color: Color(0xFFFDE047),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$currentTier Tier',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    if (commissionShare != null && commissionShare > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${commissionShare.toInt()}% Commission Share',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFFDE047),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFDE047),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progress.toInt()}% towards ${nextTier ?? "Next Tier"}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFE0E7FF),
                ),
              ),
              if (pointsNeeded > 0 && nextTier != null)
                Text(
                  '$pointsNeeded pts to $nextTier',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFDE047),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

}
