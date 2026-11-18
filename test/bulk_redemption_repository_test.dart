import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:setgo/src/data/models/bulk_redemption_models.dart';
import 'package:setgo/src/data/models/partner_inquiry_model.dart';
import 'package:setgo/src/data/providers/api_provider.dart';
import 'package:setgo/src/data/services/bulk_redemption_repository.dart';
import 'package:setgo/src/data/services/device_id_service.dart';
import 'package:setgo/src/data/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingClient extends http.BaseClient {
  final List<http.BaseRequest> requests = [];
  final List<http.Response> _queued = [];

  void enqueue(int status, Object body) {
    _queued.add(
      http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      ),
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final response = _queued.removeAt(0);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureData;
  late _RecordingClient client;
  late BulkRedemptionRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureData = {'bearer_token': 'tok'};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      secureData,
    );
    client = _RecordingClient();
    final deviceIds = DeviceIdService(storage: const FlutterSecureStorage());
    repo = BulkRedemptionRepository(
      ApiProvider(
        baseUrl: 'https://example.test/api/mobile',
        secureStorage: SecureStorageService(
          storage: const FlutterSecureStorage(),
        ),
        deviceIdService: deviceIds,
        client: client,
      ),
    );
  });

  Map<String, dynamic> jsonBody(http.BaseRequest request) {
    expect(request, isA<http.Request>());
    return jsonDecode((request as http.Request).body) as Map<String, dynamic>;
  }

  group('ShopOffersBundle / models', () {
    test('parses redeemable-offers payload with cart link', () {
      final bundle = ShopOffersBundle.fromJson({
        'shopId': '67shop',
        'totalActiveOffers': 3,
        'eligibleOffersCount': 2,
        'offers': [
          {
            '_id': '68a',
            'title': 'Flat ₹100 Off',
            'eligible': true,
            'reason': null,
            'isScratchCard': false,
            'isScratched': false,
          },
          {
            '_id': '69b',
            'title': 'Mystery Scratch Deal',
            'eligible': false,
            'reason': 'Scratch card not revealed yet',
            'isScratchCard': true,
            'isScratched': false,
          },
        ],
        'cart': {
          'cartId': '70cart',
          'totalQuantity': 4,
          'subtotal': 1200,
          'itemsCount': 2,
          'selectedOfferIds': ['68a'],
          'redemptionBatchId': null,
          'redemptionStatus': 'none',
        },
      });

      expect(bundle.shopId, '67shop');
      expect(bundle.eligibleOffersCount, 2);
      expect(bundle.offers, hasLength(2));
      expect(bundle.eligibleOffers, hasLength(1));
      expect(bundle.cartId, '70cart');
      expect(bundle.cart!.selectedOfferIds, ['68a']);
      expect(bundle.cart!.subtotal, 1200);
      expect(bundle.bulkRedemptionReady, isTrue);
    });

    test('completion payload parses paymentMode and redemptions', () {
      final result = BulkVerifyResult.fromJson({
        'batchId': '71b',
        'redemptionIds': ['r1', 'r2'],
        'offersCount': 2,
        'cartId': '70cart',
        'pointsEarned': 15,
        'pointsUsed': 100,
        'voucherDiscount': 100,
        'saleAmount': 1000,
        'netSaleAmount': 900,
        'cashAmount': 800,
        'paymentMode': 'hybrid',
        'pointsBalance': 250,
        'status': 'completed',
        'redemptions': [
          {
            'redemptionId': 'r1',
            'offerId': '68a',
            'offerTitle': 'Offer A',
            'saleAmount': 600,
            'netSaleAmount': 540,
            'pointsEarned': 9,
            'status': 'completed',
          },
        ],
      });

      expect(result.batchId, '71b');
      expect(result.offersCount, 2);
      expect(result.paymentMode, 'hybrid');
      expect(result.totalDiscount, 100);
      expect(result.totalPointsEarned, 15);
      expect(result.redemptions.single.offerTitle, 'Offer A');
      expect(result.cartId, '70cart');
    });

    test('error code mapper covers Notion §9 codes', () {
      expect(
        bulkRedemptionErrorMessage(errorCode: 'MIXED_PARTNER_OFFERS'),
        contains('different shops'),
      );
      expect(
        bulkRedemptionErrorMessage(errorCode: 'SCRATCH_REQUIRED'),
        contains('Scratch'),
      );
      expect(
        bulkRedemptionErrorMessage(errorCode: 'ALREADY_COMPLETED'),
        contains('already completed'),
      );
      expect(
        bulkRedemptionErrorMessage(
          errorCode: 'UNKNOWN',
          fallback: 'Custom',
        ),
        'Custom',
      );
    });
  });

  group('BulkRedemptionRepository APIs', () {
    test('GET redeemable-offers uses documented path', () async {
      client.enqueue(200, {
        'success': true,
        'data': {
          'shopId': 's1',
          'eligibleOffersCount': 1,
          'offers': [
            {'_id': 'o1', 'title': 'Deal', 'eligible': true},
          ],
          'cart': null,
        },
      });

      final bundle = await repo.getRedeemableOffers('s1');
      expect(client.requests.single.method, 'GET');
      expect(
        client.requests.single.url.path,
        endsWith('/shops/s1/redeemable-offers'),
      );
      expect(bundle.eligibleOffersCount, 1);
      expect(bundle.cart, isNull);
    });

    test('PUT /cart/offers attaches selected offers', () async {
      client.enqueue(200, {
        'success': true,
        'message': '1 offer(s) attached to cart',
        'data': {
          'cartId': '70cart',
          'partnerId': '67shop',
          'selectedOfferIds': ['68a'],
          'selectedOffers': [
            {'_id': '68a', 'title': 'Flat ₹100 Off', 'discountValue': 100},
          ],
        },
      });

      final result = await repo.updateCartOffers(
        partnerId: '67shop',
        cartId: '70cart',
        offerIds: ['68a'],
      );

      expect(client.requests.single.method, 'PUT');
      expect(client.requests.single.url.path, endsWith('/cart/offers'));
      final body = jsonBody(client.requests.single);
      expect(body['partnerId'], '67shop');
      expect(body['cartId'], '70cart');
      expect(body['offerIds'], ['68a']);
      expect(result.selectedOfferIds, ['68a']);
      expect(result.message, contains('attached'));
    });

    test('POST /cart/send-inquiry forwards offerIds/redeemAll', () async {
      client.enqueue(200, {
        'success': true,
        'data': {'cartId': '70cart', 'inquiryStatus': 'pending'},
      });

      await repo.sendCartInquiry(
        cartId: '70cart',
        partnerId: '67shop',
        offerIds: ['68a'],
        redeemAll: false,
      );

      expect(client.requests.single.method, 'POST');
      expect(client.requests.single.url.path, endsWith('/cart/send-inquiry'));
      final body = jsonBody(client.requests.single);
      expect(body['offerIds'], ['68a']);
      expect(body['redeemAll'], false);
    });

    test('POST bulk/redeem sends selection payload', () async {
      client.enqueue(201, {
        'success': true,
        'data': {
          'batchId': '71b',
          'redemptionIds': ['r1', 'r2'],
          'offersCount': 2,
          'offers': [
            {'offerId': '68a', 'title': 'A', 'redemptionId': 'r1'},
          ],
          'skippedOffers': [
            {
              'offerId': '69b',
              'title': 'Scratch',
              'reason': 'Scratch card not revealed yet',
            },
          ],
          'expiresAt': '2026-11-12T08:13:00.000Z',
          'cartId': '70cart',
          'message': 'OTP sent',
        },
      });

      final result = await repo.initiateBulkRedeem(
        partnerId: '67shop',
        cartId: '70cart',
        offerIds: ['68a'],
        redeemAll: false,
        saleAmount: 1200,
        voucherCode: 'WELCOME',
      );

      expect(client.requests.single.url.path, endsWith('/offers/bulk/redeem'));
      final body = jsonBody(client.requests.single);
      expect(body['partnerId'], '67shop');
      expect(body['offerIds'], ['68a']);
      expect(body['redeemAll'], false);
      expect(body['saleAmount'], 1200);
      expect(body['voucherCode'], 'WELCOME');
      expect(result.batchId, '71b');
      expect(result.skippedOffers, hasLength(1));
      expect(result.skippedOffers.first.reason, contains('Scratch'));
    });

    test('customer verify posts otp + bill fields', () async {
      client.enqueue(200, {
        'success': true,
        'data': {
          'batchId': '71b',
          'offersCount': 2,
          'pointsEarned': 15,
          'status': 'completed',
        },
      });

      final result = await repo.customerVerifyBulk(
        batchId: '71b',
        otp: '123456',
        saleAmount: 1200,
        pointsToUse: 100,
        voucherCode: 'WELCOME',
        billNo: 'INV-101',
      );

      expect(
        client.requests.single.url.path,
        endsWith('/offers/redemptions/bulk/71b/verify'),
      );
      final body = jsonBody(client.requests.single);
      expect(body['otp'], '123456');
      expect(body['saleAmount'], 1200);
      expect(body['pointsToUse'], 100);
      expect(body['billNo'], 'INV-101');
      expect(result.offersCount, 2);
    });

    test('bulk redeem-qr and partner scan-qr', () async {
      client.enqueue(201, {
        'success': true,
        'data': {
          'batchId': '71b',
          'offersCount': 2,
          'qrToken': 'jwt.token.here',
          'qrCode': 'data:image/png;base64,aaa',
          'message': 'Show QR',
        },
      });
      client.enqueue(200, {
        'success': true,
        'data': {
          'batchId': '71b',
          'offersCount': 2,
          'status': 'completed',
          'paymentMode': 'cash',
        },
      });

      final qr = await repo.initiateBulkQr(
        partnerId: '67shop',
        redeemAll: true,
      );
      expect(qr.qrToken, 'jwt.token.here');
      expect(client.requests[0].url.path, endsWith('/offers/bulk/redeem-qr'));

      final scanned = await repo.partnerScanBulkQr(
        batchId: '71b',
        qrToken: 'jwt.token.here',
        saleAmount: 1000,
      );
      expect(
        client.requests[1].url.path,
        endsWith('/offers/redemptions/bulk/71b/scan-qr'),
      );
      expect(scanned.paymentMode, 'cash');
    });

    test('partner generate + verify bulk OTP', () async {
      client.enqueue(201, {
        'success': true,
        'data': {
          'batchId': '71b',
          'offersCount': 2,
          'expiresAt': '2026-11-12T08:13:00.000Z',
          'message': 'OTP sent',
          'otp': '654321',
          'smsSent': true,
        },
      });
      client.enqueue(200, {
        'success': true,
        'data': {
          'batchId': '71b',
          'offersCount': 2,
          'status': 'completed',
          'billNo': 'INV-103',
        },
      });

      final generated = await repo.partnerGenerateBulkOtp(
        userPhone: '9876543210',
        redeemAll: true,
        saleAmount: 800,
      );
      expect(
        client.requests[0].url.path,
        endsWith('/partner/offers/bulk/generate-otp'),
      );
      expect(generated.otp, '654321');

      final verified = await repo.partnerVerifyBulk(
        userPhone: '9876543210',
        batchId: '71b',
        otp: '654321',
        saleAmount: 800,
        billNo: 'INV-103',
      );
      expect(
        client.requests[1].url.path,
        endsWith('/partner/offers/bulk/verify-otp'),
      );
      expect(verified.billNo, 'INV-103');
    });

    test('redeem-with-bill JSON path works without file', () async {
      client.enqueue(201, {
        'success': true,
        'data': {
          'batchId': '71b',
          'offersCount': 2,
          'status': 'completed',
          'billImage': null,
          'skippedOffers': [],
        },
      });

      final result = await repo.redeemWithBill(
        partnerId: '67shop',
        redeemAll: true,
        saleAmount: 900,
        billNo: 'INV-200',
      );
      expect(
        client.requests.single.url.path,
        endsWith('/offers/bulk/redeem-with-bill'),
      );
      expect(result.offersCount, 2);
    });

    test('maps API errorCode into Exception message', () async {
      client.enqueue(400, {
        'success': false,
        'errorCode': 'NO_ELIGIBLE_OFFERS',
        'message': 'None eligible',
      });

      expect(
        () => repo.initiateBulkRedeem(partnerId: '67shop', redeemAll: true),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No eligible offers'),
          ),
        ),
      );
    });
  });

  group('PartnerInquiryModel cart-link fields', () {
    test('parses selectedOffers and redemptionStatus', () {
      final inquiry = PartnerInquiryModel.fromJson({
        '_id': 'inq1',
        'subtotal': 1200,
        'selectedOfferIds': ['68a'],
        'selectedOffers': [
          {'_id': '68a', 'title': 'Flat ₹100 Off', 'discountValue': 100},
        ],
        'redemptionBatchId': '71b',
        'redemptionStatus': 'pending',
      });
      expect(inquiry.selectedOfferIds, ['68a']);
      expect(inquiry.selectedOffers.single.title, 'Flat ₹100 Off');
      expect(inquiry.redemptionBatchId, '71b');
      expect(inquiry.redemptionStatus, 'pending');
    });
  });
}
