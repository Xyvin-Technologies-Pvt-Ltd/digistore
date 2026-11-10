import 'package:flutter_test/flutter_test.dart';
import 'package:setgo/src/data/models/referral_models.dart';
import 'package:setgo/src/data/utils/otp_account.dart';
import 'package:setgo/src/data/utils/referral_code.dart';

void main() {
  group('ReferralCode', () {
    test('normalizes a valid code and rejects everything else', () {
      expect(ReferralCode.normalize(' s00004 '), 'S00004');
      expect(ReferralCode.normalize('S00001'), 'S00001');
      expect(ReferralCode.normalize('S99999'), 'S99999');
      expect(ReferralCode.normalize('S0000'), isNull);
      expect(ReferralCode.normalize('S000001'), isNull);
      expect(ReferralCode.normalize('A00004'), isNull);
      expect(ReferralCode.normalize(''), isNull);
      expect(ReferralCode.normalize(null), isNull);
    });

    test('extracts a code from share text without grabbing extra digits', () {
      expect(
        ReferralCode.extract(
          'Use my referral code *S00009* when you sign up',
        ),
        'S00009',
      );
      expect(ReferralCode.extract('order S000041 extra'), isNull);
    });

    test('reads utm_campaign from a Play install referrer', () {
      expect(
        ReferralCode.fromInstallReferrer(
          'utm_source=referral&utm_campaign=S00004',
        ),
        'S00004',
      );
      expect(
        ReferralCode.fromInstallReferrer(
          'utm_source%3Dreferral%26utm_campaign%3DS00009',
        ),
        'S00009',
      );
      expect(ReferralCode.fromInstallReferrer('utm_source=referral'), isNull);
    });

    test('reads share links and ignores content routes that only carry ref', () {
      final share = Uri.parse('https://setgoinnovations.com/app?ref=S00004');
      expect(ReferralCode.fromUri(share), 'S00004');
      expect(ReferralCode.isAttributionLink(share), isTrue);

      final apiShare = Uri.parse(
        'https://api-deals.setgoinnovations.com/app?ref=S00004',
      );
      expect(ReferralCode.fromUri(apiShare), 'S00004');
      expect(ReferralCode.isAttributionLink(apiShare), isTrue);

      final scheme = Uri.parse('setgo://referral?code=S00009');
      expect(ReferralCode.fromUri(scheme), 'S00009');
      expect(ReferralCode.isAttributionLink(scheme), isTrue);

      final offer = Uri.parse(
        'https://setgo.in/app/offerdetail/123?ref=S00004',
      );
      expect(ReferralCode.fromUri(offer), 'S00004');
      expect(ReferralCode.isAttributionLink(offer), isFalse);

      final play = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.setgoinnovations&referrer=utm_source%3Dreferral%26utm_campaign%3DS00004',
      );
      expect(ReferralCode.fromUri(play), 'S00004');
    });
  });

  test('share payload converts points at 10 points per rupee', () {
    final payload = ReferralSharePayload.fromJson({
      'referralCode': 'S00009',
      'rewardPoints': 10,
      'rupeeEquivalent': 1,
      'successfulReferrals': 5,
      'totalPointsEarned': 50,
      'minPurchaseForRedemption': 2500,
    });

    expect(payload.earnedRupees, 5);
    expect(payload.minPurchaseForRedemption, 2500);

    final liveShape = ReferralSharePayload.fromJson({
      'referralCode': 'S00001',
      'rewardPoints': 10,
      'rupeeEquivalent': 10,
      'successfulReferrals': 1,
      'totalPointsEarned': 10,
    });
    expect(liveShape.earnedRupees, 1);
  });

  test('share payload rewrites prod landing links to the active API host', () {
    expect(
      ReferralCode.landingBaseFromApi(
        'https://uat-api.setgoinnovations.com/api/mobile',
      ),
      'https://uat-api.setgoinnovations.com/app',
    );
    expect(
      ReferralCode.landingBaseFromApi(
        'https://api-deals.setgoinnovations.com/api/mobile',
      ),
      'https://api-deals.setgoinnovations.com/app',
    );

    final aligned = ReferralSharePayload.fromJson({
      'referralCode': 'S00001',
      'shareUrl': 'https://api-deals.setgoinnovations.com/app?ref=S00001',
      'shareMessage':
          'Use my code S00001 https://api-deals.setgoinnovations.com/app?ref=S00001',
    }).alignedToApiBase('https://uat-api.setgoinnovations.com/api/mobile');

    expect(
      aligned.shareUrl,
      'https://uat-api.setgoinnovations.com/app?ref=S00001',
    );
    expect(
      aligned.shareMessage,
      contains('https://uat-api.setgoinnovations.com/app?ref=S00001'),
    );
    expect(
      aligned.shareMessage,
      isNot(contains('api-deals.setgoinnovations.com')),
    );

    final prod = aligned.alignedToApiBase(
      'https://api-deals.setgoinnovations.com/api/mobile',
    );
    expect(
      prod.shareUrl,
      'https://api-deals.setgoinnovations.com/app?ref=S00001',
    );
  });

  test('send-otp says whether this number already has an account', () {
    expect(
      isNewUserInOtpResponse({
        'success': true,
        'data': {'isNewUser': false},
      }),
      isFalse,
    );
    expect(
      isNewUserInOtpResponse({
        'success': true,
        'data': {'isNewUser': true},
      }),
      isTrue,
    );
    expect(
      isNewUserInOtpResponse({
        'success': true,
        'data': {'userExists': true},
      }),
      isFalse,
    );
    expect(isNewUserInOtpResponse({'success': true, 'message': 'OTP sent'}), isNull);
  });
}
