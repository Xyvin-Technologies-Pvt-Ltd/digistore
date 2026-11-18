import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:setgo/src/data/services/deep_link_service.dart';

final shareProviderProvider = Provider<ShareService>((ref) {
  final deepLinkService = ref.watch(deepLinkServiceProvider);
  return ShareService(deepLinkService);
});

class ShareService {
  final DeepLinkService _deepLinkService;

  ShareService(this._deepLinkService);

  /// Share a feed with deep link
  Future<ShareResult> shareFeed({
    required String feedId,
    required String feedTitle,
    String? feedDescription,
  }) async {
    try {
      // Generate deep link for the feed
      final deepLink = _deepLinkService.generateDeepLink('feed', id: feedId);

      // Create share text with title and link
      final shareText = feedDescription != null
          ? '$feedTitle\n\n$feedDescription\n\n$deepLink'
          : '$feedTitle\n\n$deepLink';

      final params = ShareParams(text: shareText, title: 'Share Feed');

      final result = await SharePlus.instance.share(params);
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Share a campaign with deep link
  Future<ShareResult> shareCampaign({
    required String campaignId,
    required String campaignTitle,
    String? campaignDescription,
  }) async {
    try {
      final deepLink = _deepLinkService.generateDeepLink(
        'campaign',
        id: campaignId,
      );

      final shareText = campaignDescription != null
          ? '$campaignTitle\n\n$campaignDescription\n\n$deepLink'
          : '$campaignTitle\n\n$deepLink';

      final params = ShareParams(text: shareText, title: 'Share Campaign');

      final result = await SharePlus.instance.share(params);
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Share a resource with deep link
  Future<ShareResult> shareResource({
    required String resourceId,
    required String resourceTitle,
    String? resourceDescription,
  }) async {
    try {
      final deepLink = _deepLinkService.generateDeepLink(
        'resource',
        id: resourceId,
      );

      final shareText = resourceDescription != null
          ? '$resourceTitle\n\n$resourceDescription\n\n$deepLink'
          : '$resourceTitle\n\n$deepLink';

      final params = ShareParams(text: shareText, title: 'Share Resource');

      final result = await SharePlus.instance.share(params);
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Share an event with deep link
  Future<ShareResult> shareEvent({
    required String eventId,
    required String eventTitle,
    String? eventDescription,
  }) async {
    try {
      final deepLink = _deepLinkService.generateDeepLink('event', id: eventId);

      final shareText = eventDescription != null
          ? '$eventTitle\n\n$eventDescription\n\n$deepLink'
          : '$eventTitle\n\n$deepLink';

      final params = ShareParams(text: shareText, title: 'Share Event');

      final result = await SharePlus.instance.share(params);
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Share referral code with app links
  Future<ShareResult> shareReferral({
    required String referralCode,
    required String androidLink,
    required String iosLink,
  }) async {
    try {
      final code = referralCode.trim().toUpperCase();
      final shareText =
          'ഇനി ഓരോ ഷോപ്പിംഗും കൂടുതൽ ലാഭകരമാക്കാം!\n\n'
          'നമ്മുടെ നാട്ടിലെ കടകളിലെ മികച്ച ഓഫറുകളും ഡിസ്കൗണ്ടുകളും കണ്ടെത്താനും ഓരോ പർച്ചേസിനും റിവാർഡ് പോയിന്റുകൾ നേടാനും ഇതാ SETGO ആപ്പ്!\n\n'
          'Referral Code ഉപയോഗിച്ച് രജിസ്റ്റർ ചെയ്യുമ്പോൾ കുറഞ്ഞത് ₹100 മൂല്യമുള്ള വൗച്ചർ നേടാം!\n\n'
          'സുഹൃത്തുക്കളെ റഫർ ചെയ്ത് ₹10,000 വരെ ക്യാഷ്ബാക്ക് നേടാനുള്ള അവസരവും!\n\n'
          'നാട്ടിലെ കടകളിലെ ആകർഷകമായ ഓഫറുകളും ഡിസ്കൗണ്ടുകളും അറിയാം. ഓരോ പർച്ചേസിലും റിവാർഡ് പോയിന്റുകൾ നേടാം.\n\n'
          'ഇപ്പോൾ തന്നെ SETGO ആപ്പ് ഡൗൺലോഡ് ചെയ്യൂ!\n'
          'Android: $androidLink\n'
          'iOS: $iosLink\n\n'
          'Referral Code: *$code*';

      final params = ShareParams(text: shareText, title: 'SETGO - Invite Friends');

      final result = await SharePlus.instance.share(params);
      return result;
    } catch (e) {
      rethrow;
    }
  }
}
