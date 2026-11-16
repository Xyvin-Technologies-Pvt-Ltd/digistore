import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:setgo/src/data/providers/api_provider.dart';
import 'package:setgo/src/data/services/device_id_service.dart';
import 'package:setgo/src/data/services/secure_storage_service.dart';
import 'package:setgo/src/data/services/voucher_repository.dart';
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
  late VoucherRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureData = {'bearer_token': 'tok'};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      secureData,
    );
    client = _RecordingClient();
    final deviceIds = DeviceIdService(
      storage: const FlutterSecureStorage(),
    );
    repo = VoucherRepository(
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

  String? deviceHeader(http.Request request) =>
      request.headers['x-device-id'] ?? request.headers['X-Device-Id'];

  test('myVouchers parses active list and sends device header', () async {
    client.enqueue(200, {
      'success': true,
      'data': [
        {
          '_id': 'v1',
          'voucherCode': 'WELCOME-7A2F8B',
          'title': 'Welcome',
          'rewardType': 'flat_voucher',
          'value': 50,
          'minOrderValue': 200,
          'status': 'active',
          'daysLeft': 14,
          'isExpired': false,
          'applicableCategories': ['Beauty Parlour'],
          'icon': '🎁',
        },
      ],
    });

    final list = await repo.myVouchers(status: 'active');
    expect(list, hasLength(1));
    expect(list.first.voucherCode, 'WELCOME-7A2F8B');
    expect(list.first.valueLabel, '₹50 Off');
    expect(list.first.applicableCategories, ['Beauty Parlour']);
    expect(list.first.icon, '🎁');
    expect(client.requests.single.method, 'GET');
    expect(client.requests.single.url.path, endsWith('/vouchers/my-vouchers'));
    expect(client.requests.single.url.queryParameters['status'], 'active');
    expect(deviceHeader(client.requests.single), isNotEmpty);
    expect(client.requests.single.headers['authorization'], 'Bearer tok');
  });

  test('validate returns discount and handles errors', () async {
    client.enqueue(200, {
      'success': true,
      'message': 'Voucher applied: ₹50 discount!',
      'data': {
        'valid': true,
        'discount': 50,
        'finalAmount': 400,
        'message': 'Voucher applied: ₹50 discount!',
        'voucher': {
          '_id': 'v1',
          'voucherCode': 'WELCOME-7A2F8B',
          'title': 'Welcome',
          'rewardType': 'flat_voucher',
          'value': 50,
          'minOrderValue': 200,
          'status': 'active',
        },
      },
    });

    final ok = await repo.validate(
      voucherCode: 'WELCOME-7A2F8B',
      cartAmount: 450,
      category: 'Beauty Parlour',
      partnerId: 'p1',
    );
    expect(ok.valid, isTrue);
    expect(ok.discountAmount, 50);
    expect(ok.discount, 50);
    expect(ok.finalAmount, 400);
    final body =
        jsonDecode(client.requests.single.body) as Map<String, dynamic>;
    expect(body['voucherCode'], 'WELCOME-7A2F8B');
    expect(body['cartAmount'], 450);
    expect(body['categories'], ['Beauty Parlour']);
    expect(deviceHeader(client.requests.single), isNotEmpty);

    client.enqueue(400, {
      'success': false,
      'message': 'Minimum purchase amount of ₹200 required to use this voucher',
    });
    final bad = await repo.validate(voucherCode: 'X', cartAmount: 50);
    expect(bad.valid, isFalse);
    expect(bad.message, contains('Minimum purchase'));
  });

  test('spinStatus and executeSpin hit voucher spin paths', () async {
    client.enqueue(200, {
      'success': true,
      'data': {
        'hasSpinAvailable': true,
        'campaignId': 'c1',
        'campaignTitle': 'Lucky Spin',
        'segments': [
          {'index': 0, 'label': '₹50', 'rewardType': 'flat_voucher', 'value': 50},
          {
            'index': 1,
            'label': 'Grand',
            'rewardType': 'flat_voucher',
            'value': 500,
            'isGrandPrize': true,
          },
        ],
      },
    });
    final status = await repo.spinStatus('tx1');
    expect(status.hasSpinAvailable, isTrue);
    expect(status.campaignId, 'c1');
    expect(status.segments, hasLength(2));
    expect(client.requests.single.url.path, endsWith('/vouchers/spin-status/tx1'));
    expect(deviceHeader(client.requests.single), isNotEmpty);

    client.enqueue(200, {
      'success': true,
      'data': {
        'winningSegmentIndex': 1,
        'prizeType': 'flat_voucher',
        'voucherCode': 'SPIN-9X',
        'label': 'Grand',
        'isGrandPrize': true,
        'message': 'You won!',
      },
    });
    final result = await repo.executeSpin(
      campaignId: 'c1',
      transactionId: 'tx1',
    );
    expect(result.winningSegmentIndex, 1);
    expect(result.voucherCode, 'SPIN-9X');
    expect(client.requests.last.method, 'POST');
    expect(client.requests.last.url.path, endsWith('/vouchers/spin/c1'));
  });
}
