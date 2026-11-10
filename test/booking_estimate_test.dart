import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:setgo/src/data/models/booking_estimate.dart';
import 'package:setgo/src/data/providers/api_provider.dart';
import 'package:setgo/src/data/providers/services_provider.dart';
import 'package:setgo/src/data/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingClient extends http.BaseClient {
  final List<http.Request> requests = [];
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
    final recorded = http.Request(request.method, request.url)
      ..headers.addAll(request.headers);
    if (request is http.Request) {
      recorded.body = request.body;
    }
    requests.add(recorded);
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
  late ApiProvider api;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureData = {'bearer_token': 'tok'};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      secureData,
    );
    client = _RecordingClient();
    api = ApiProvider(
      baseUrl: 'https://example.test/api/mobile',
      secureStorage: SecureStorageService(
        storage: const FlutterSecureStorage(),
      ),
      client: client,
    );
  });

  test('BookingEstimate.fromJson maps voucher-before-GST totals', () {
    final estimate = BookingEstimate.fromJson({
      'grossAmount': 200,
      'itemDiscount': 0,
      'subtotal': 200,
      'promoCode': 'WELCOME-A1B2C3',
      'promoDiscount': 50,
      'voucherId': '67f',
      'voucherCode': 'WELCOME-A1B2C3',
      'voucherDiscount': 50,
      'voucherTitle': 'Welcome',
      'taxableAmount': 150,
      'cgstRate': 2.5,
      'cgstAmount': 3.75,
      'sgstRate': 2.5,
      'sgstAmount': 3.75,
      'totalGstRate': 5,
      'totalGstAmount': 7.5,
      'customerPays': 157.5,
      'totalAmount': 157.5,
    }, message: 'GST and pricing estimated successfully');

    expect(estimate.hasVoucher, isTrue);
    expect(estimate.voucherDiscount, 50);
    expect(estimate.taxableAmount, 150);
    expect(estimate.totalGstAmount, 7.5);
    expect(estimate.totalAmount, 157.5);
    expect(estimate.message, contains('estimated'));
  });

  test('estimate posts voucherCode to /bookings/estimate with auth', () async {
    client.enqueue(200, {
      'success': true,
      'message': 'GST and pricing estimated successfully',
      'data': {
        'grossAmount': 200,
        'subtotal': 200,
        'voucherCode': 'WELCOME-A1B2C3',
        'voucherDiscount': 50,
        'taxableAmount': 150,
        'totalGstAmount': 7.5,
        'customerPays': 157.5,
        'totalAmount': 157.5,
      },
    });

    final res = await BookingService.estimate(
      api: api,
      partnerId: 'p1',
      items: [
        {'serviceId': 's1', 'quantity': 1},
      ],
      voucherCode: 'WELCOME-A1B2C3',
    );

    expect(res.success, isTrue);
    expect(res.data!.voucherDiscount, 50);
    expect(res.data!.totalAmount, 157.5);
    expect(client.requests.single.method, 'POST');
    expect(client.requests.single.url.path, endsWith('/bookings/estimate'));
    expect(client.requests.single.headers['authorization'], 'Bearer tok');
    final body =
        jsonDecode(client.requests.single.body) as Map<String, dynamic>;
    expect(body['partnerId'], 'p1');
    expect(body['voucherCode'], 'WELCOME-A1B2C3');
    expect(body['items'], isA<List>());
  });

  test('estimate surfaces voucher validation errors', () async {
    client.enqueue(400, {
      'success': false,
      'message': 'Minimum purchase amount of ₹200 required to use this voucher',
    });

    final res = await BookingService.estimate(
      api: api,
      partnerId: 'p1',
      items: [
        {'serviceId': 's1', 'quantity': 1},
      ],
      voucherCode: 'WELCOME-A1B2C3',
    );

    expect(res.success, isFalse);
    expect(res.message, contains('Minimum purchase'));
  });
}
