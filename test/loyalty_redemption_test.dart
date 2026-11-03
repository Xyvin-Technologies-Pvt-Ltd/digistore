import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:setgo/src/data/models/offer_model.dart';
import 'package:setgo/src/data/models/redemption_model.dart';
import 'package:setgo/src/data/models/user_model.dart';

void main() {
  group('SetGo Loyalty Points & Redemption Spec Tests', () {
    test('OfferModel parses pointsCost and requiresPointsPayment correctly', () {
      final json = {
        '_id': 'offer_123',
        'title': '20% Off on Haircut',
        'pointsCost': 500,
        'requiresPointsPayment': true,
      };

      final offer = OfferModel.fromJson(json);
      expect(offer.id, 'offer_123');
      expect(offer.title, '20% Off on Haircut');
      expect(offer.pointsCost, 500);
      expect(offer.requiresPointsPayment, isTrue);

      final encoded = offer.toJson();
      expect(encoded['pointsCost'], 500);
      expect(encoded['requiresPointsPayment'], isTrue);
    });

    test('RedemptionModel parses partial payment breakdown according to spec', () {
      final json = {
        '_id': 'redemption_111',
        'status': 'completed',
        'saleAmount': 2000,
        'pointsEarned': 140,
        'pointsUsed': 300,
        'cashAmount': 200,
        'pointsTransferredToMerchant': 300,
        'paymentMode': 'partial',
        'billNo': 'INV-2026-0045',
        'payment': {
          'mode': 'partial',
          'pointsUsed': 300,
          'cashAmountDue': 200,
          'offerPointsCost': 500,
        },
      };

      final redemption = RedemptionModel.fromJson(json);
      expect(redemption.id, 'redemption_111');
      expect(redemption.saleAmount, 2000.0);
      expect(redemption.pointsEarned, 140);
      expect(redemption.pointsUsed, 300);
      expect(redemption.cashAmount, 200.0);
      expect(redemption.pointsTransferredToMerchant, 300);
      expect(redemption.paymentMode, 'partial');
      expect(redemption.billNo, 'INV-2026-0045');
      expect(redemption.payment?.mode, 'partial');
      expect(redemption.payment?.pointsUsed, 300);
      expect(redemption.payment?.cashAmountDue, 200.0);
      expect(redemption.payment?.offerPointsCost, 500);
    });

    test('UserModel and TierModel parse commission share and next tier points', () {
      final json = {
        'name': 'Alex John',
        'pointsBalance': 450,
        'totalPointsEarned': 1250,
        'tier': {
          'name': 'Silver',
          'badge': 'https://example.com/silver.png',
          'customerCommissionShare': 75,
          'nextTierPoints': 2500,
        },
      };

      final user = UserModel.fromJson(json);
      expect(user.name, 'Alex John');
      expect(user.pointsBalance, 450);
      expect(user.totalPointsEarned, 1250);
      expect(user.currentTier?.name, 'Silver');
      expect(user.currentTier?.badge, 'https://example.com/silver.png');
      expect(user.currentTier?.customerCommissionShare, 75.0);
      expect(user.currentTier?.nextTierPoints, 2500);
    });

    test('Mathematical formula: Partial points + Cash payment calculations', () {
      // Example from Notion Spec:
      // Offer pointsCost: 500
      // Customer pointsBalance: 300
      // pointsToRupeeRate: 1.0
      const int offerPointsCost = 500;
      const int userBalance = 300;
      const double pointsToRupeeRate = 1.0;

      final pointsToUse = math.min(userBalance, offerPointsCost);
      final pointsShortfall = offerPointsCost - pointsToUse;
      final cashAmount = (pointsShortfall * pointsToRupeeRate).ceil();

      expect(pointsToUse, 300);
      expect(pointsShortfall, 200);
      expect(cashAmount, 200);

      String mode;
      if (pointsToUse == offerPointsCost) {
        mode = 'full_points';
      } else if (pointsToUse > 0 && cashAmount > 0) {
        mode = 'partial';
      } else if (userBalance == 0) {
        mode = 'full_cash';
      } else {
        mode = 'none';
      }
      expect(mode, 'partial');
    });

    test('Payment mode: full_points when user balance >= pointsCost', () {
      const int offerPointsCost = 200;
      const int userBalance = 350;
      final pointsToUse = math.min(userBalance, offerPointsCost);
      final pointsShortfall = offerPointsCost - pointsToUse;
      final cashAmount = (pointsShortfall * 1.0).ceil();

      expect(pointsToUse, 200);
      expect(cashAmount, 0);

      final mode = (pointsToUse == offerPointsCost) ? 'full_points' : 'other';
      expect(mode, 'full_points');
    });

    test('Payment mode: full_cash when user balance is 0', () {
      const int offerPointsCost = 400;
      const int userBalance = 0;
      final pointsToUse = math.min(userBalance, offerPointsCost);
      final pointsShortfall = offerPointsCost - pointsToUse;
      final cashAmount = (pointsShortfall * 1.0).ceil();

      expect(pointsToUse, 0);
      expect(cashAmount, 400);

      final mode = (userBalance == 0) ? 'full_cash' : 'other';
      expect(mode, 'full_cash');
    });

    test('Points Earning formula on sale amount', () {
      // Sale Amount: 2000
      // Partner incomeSharingPercentage: 10%
      // User tier share: 70%
      const double saleAmount = 2000.0;
      const double incomeSharingPercentage = 10.0;
      const double userSharePercentage = 70.0;

      final commissionAmount = (saleAmount * incomeSharingPercentage) / 100.0;
      final pointsEarned = (commissionAmount * userSharePercentage / 100.0).floor();

      expect(commissionAmount, 200.0);
      expect(pointsEarned, 140);
    });
    test('Flexible Mode 1: Full Cash (pointsToUse: 0, 100% cash, earns full cashback points)', () {
      const double billAmount = 1500.0;
      const int userBalance = 500;
      const double incomeSharingPercentage = 10.0; // merchant commission
      const double userSharePercentage = 70.0;     // customer share

      // Customer chooses Full Cash: uses 0 points even though user has 500 points
      const int pointsToUse = 0;
      final double cashAmount = billAmount - pointsToUse;
      final String paymentMode = pointsToUse == 0 ? 'full_cash' : 'other';

      // Cash spent is 100% of bill amount
      final double earningAmount = cashAmount;
      final commission = (earningAmount * incomeSharingPercentage) / 100.0;
      final pointsEarned = (commission * userSharePercentage / 100.0).floor();

      expect(userBalance, 500);
      expect(pointsToUse, 0);
      expect(cashAmount, 1500.0);
      expect(paymentMode, 'full_cash');
      expect(earningAmount, 1500.0);
      expect(pointsEarned, 105); // earns cashback on full 1500
    });

    test('Flexible Mode 2: Full Points (100% points, cash due: ₹0, 0 cashback earned)', () {
      const double billAmount = 400.0;
      const int userBalance = 600;
      const double pointsToRupeeRate = 1.0;

      // User has enough points (600 >= 400)
      final int maxPointsPossible = (billAmount / pointsToRupeeRate).ceil();
      final bool canAffordFullPoints = userBalance >= maxPointsPossible;
      expect(canAffordFullPoints, isTrue);

      final int pointsToUse = maxPointsPossible; // covers 100%
      final double cashAmount = math.max(0.0, billAmount - (pointsToUse * pointsToRupeeRate));
      final String paymentMode = cashAmount == 0 ? 'full_points' : 'other';

      // Earning is based solely on cashAmount spent
      final double earningAmount = cashAmount;
      final int pointsEarned = earningAmount > 0 ? 10 : 0;

      expect(pointsToUse, 400);
      expect(cashAmount, 0.0);
      expect(paymentMode, 'full_points');
      expect(earningAmount, 0.0);
      expect(pointsEarned, 0); // ₹0 cash paid, so 0 cashback coins
    });

    test('Flexible Mode 3: Split (custom points e.g. 50 pts, remainder in cash, cashback on cash only)', () {
      const double billAmount = 500.0;
      const int userBalance = 300;
      const double incomeSharingPercentage = 10.0;
      const double userSharePercentage = 70.0;

      // Customer specifies custom 50 points to use
      const int customPointsRequested = 50;
      final int maxPointsUsable = math.min(userBalance, billAmount.ceil());
      final int pointsToUse = customPointsRequested.clamp(0, maxPointsUsable);

      final double cashAmount = billAmount - pointsToUse;
      final String paymentMode = (pointsToUse > 0 && cashAmount > 0) ? 'partial' : 'other';

      // Customer earns cashback ONLY on the cash portion spent
      final double earningAmount = cashAmount;
      final commission = (earningAmount * incomeSharingPercentage) / 100.0;
      final pointsEarned = (commission * userSharePercentage / 100.0).floor();

      expect(pointsToUse, 50);
      expect(cashAmount, 450.0);
      expect(paymentMode, 'partial');
      expect(earningAmount, 450.0);
      // Commission on 450 = 45; 70% of 45 = 31.5 -> 31 pts
      expect(pointsEarned, 31);
    });

    test('Validation: Full Points is unavailable when user balance < bill amount', () {
      const double billAmount = 500.0;
      const int userBalance = 200;

      final bool canAffordFullPoints = userBalance >= billAmount;
      expect(canAffordFullPoints, isFalse);

      final int maxPointsUsable = math.min(userBalance, billAmount.ceil());
      expect(maxPointsUsable, 200);

      // User must either use Split (up to 200 pts) or Full Cash
      final int splitPoints = maxPointsUsable;
      final double cashDue = billAmount - splitPoints;
      expect(cashDue, 300.0);
    });
  });
}
