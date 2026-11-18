import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:setgo/src/data/models/app_notification_model.dart';
import 'package:setgo/src/data/models/partner_inquiry_model.dart';
import 'package:setgo/src/data/providers/api_provider.dart';
import 'package:setgo/src/data/providers/partner_inquiries_provider.dart';
import 'package:setgo/src/data/services/deep_link_service.dart';
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
  group('PartnerInquiryModel', () {
    test('parses multi-item inquiry payload from API', () {
      final json = {
        '_id': '6724abc',
        'customer': {
          'name': 'Anirudh K Manoj',
          'phone': '8606154706',
          'avatar': null,
        },
        'items': [
          {
            'title': 'CCTV Installation',
            'quantity': 1,
            'effectivePrice': 349,
            'price': 699,
            'image': 'https://example.com/cctv.png',
          },
          {
            'title': 'Networking Setup',
            'quantity': 2,
            'effectivePrice': 500,
            'price': 500,
          },
        ],
        'totalQuantity': 3,
        'subtotal': 1349,
        'inquiryStatus': 'pending',
        'lastInquirySentAt': '2026-11-05T04:20:00.000Z',
      };

      final inquiry = PartnerInquiryModel.fromJson(json);
      expect(inquiry.id, '6724abc');
      expect(inquiry.customer.name, 'Anirudh K Manoj');
      expect(inquiry.customer.phone, '8606154706');
      expect(inquiry.items.length, 2);
      expect(inquiry.items.first.title, 'CCTV Installation');
      expect(inquiry.items.first.effectivePrice, 349);
      expect(inquiry.items.first.price, 699);
      expect(inquiry.items[1].quantity, 2);
      expect(inquiry.totalQuantity, 3);
      expect(inquiry.subtotal, 1349);
      expect(inquiry.inquiryStatus, 'pending');
      expect(inquiry.lastInquirySentAt, isNotNull);
      expect(inquiry.itemCount, 2);
    });

    test('computes totals when API omits totalQuantity/subtotal', () {
      final inquiry = PartnerInquiryModel.fromJson({
        '_id': 'x1',
        'items': [
          {'title': 'A', 'quantity': 2, 'effectivePrice': 100},
          {'title': 'B', 'quantity': 1, 'price': 50},
        ],
      });
      expect(inquiry.totalQuantity, 3);
      expect(inquiry.subtotal, 250);
    });

    test('handles missing customer and empty items safely', () {
      final inquiry = PartnerInquiryModel.fromJson({'_id': 'empty'});
      expect(inquiry.id, 'empty');
      expect(inquiry.items, isEmpty);
      expect(inquiry.customer.name, isNull);
      expect(inquiry.inquiryStatus, 'pending');
    });
  });

  group('AppNotificationModel inquiry action parsing', () {
    test('parses nested open_product_inquiry action with targetId', () {
      final model = AppNotificationModel.fromJson({
        '_id': 'n1',
        'title': 'New inquiry',
        'message': 'Customer inquired',
        'action': {
          'type': 'open_product_inquiry',
          'targetId': 'inq_123',
          'screen': 'PartnerInquiries',
        },
      });
      expect(model.action?.type, 'open_product_inquiry');
      expect(model.action?.targetId, 'inq_123');
      expect(model.action?.screen, 'PartnerInquiries');
      expect(model.action?.isNavigable, isTrue);
    });

    test('uses metadata.cartId when flattened action has no targetId', () {
      final model = AppNotificationModel.fromJson({
        'title': 'Inquiry',
        'body': 'New products inquired',
        'actionType': 'open_product_inquiry',
        'metadata': {'cartId': 'cart_456'},
      });
      expect(model.action?.type, 'open_product_inquiry');
      expect(model.action?.targetId, 'cart_456');
    });

    test('prefers actionTargetId over cartId for flattened FCM payload', () {
      final model = AppNotificationModel.fromJson({
        'actionType': 'open_product_inquiry',
        'actionTargetId': 'inq_789',
        'cartId': 'cart_should_not_win',
        'metadata': {'cartId': 'cart_meta'},
      });
      expect(model.action?.targetId, 'inq_789');
    });

    test('fills targetId from metadata.cartId when nested action omits it', () {
      final model = AppNotificationModel.fromJson({
        '_id': 'notif_only',
        'title': 'Inquiry',
        'message': 'New inquiry',
        'action': {'type': 'open_product_inquiry'},
        'metadata': {'cartId': 'cart_from_meta'},
      });
      expect(model.action?.type, 'open_product_inquiry');
      expect(model.action?.targetId, 'cart_from_meta');
    });
  });

  group('DeepLinkService inquiry deep links', () {
    test('generateDeepLink builds partner inquiry listing URL', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = container.read(deepLinkServiceProvider);
      expect(
        service.generateDeepLink('partnerInquiries', id: 'inq_99'),
        'https://setgo.in/app/partnerInquiries/inq_99',
      );
      expect(
        service.generateDeepLink('PartnerInquiries'),
        'https://setgo.in/app/partnerInquiries',
      );
      expect(
        service.generateDeepLink('inquiry', id: 'cart_1'),
        'https://setgo.in/app/partnerInquiries/cart_1',
      );
    });

    test('generateDeepLink still supports explicit detail URLs', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = container.read(deepLinkServiceProvider);
      expect(
        service.generateDeepLink('partnerinquirydetail', id: 'inq_99'),
        'https://setgo.in/app/partnerinquirydetail/inq_99',
      );
    });
  });

  group('PartnerInquiriesNotifier', () {
    late _RecordingClient client;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({
        'bearer_token': 'partner-token',
        'is_partner': 'true',
      });
      client = _RecordingClient();
      final storage = SecureStorageService(
        storage: const FlutterSecureStorage(),
      );
      container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(
            ApiProvider(
              baseUrl: 'https://example.test/api/mobile/partner',
              secureStorage: storage,
              deviceIdService: DeviceIdService(
                storage: const FlutterSecureStorage(),
              ),
              client: client,
            ),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('fetchInquiries loads paginated list from GET /inquiries', () async {
      client.enqueue(200, {
        'success': true,
        'message': 'ok',
        'data': [
          {
            '_id': 'inq_1',
            'customer': {'name': 'Ada', 'phone': '999'},
            'items': [
              {'title': 'CCTV', 'quantity': 1, 'effectivePrice': 100},
            ],
            'totalQuantity': 1,
            'subtotal': 100,
            'inquiryStatus': 'pending',
            'lastInquirySentAt': '2026-11-05T04:20:00.000Z',
          },
          {
            '_id': 'inq_2',
            'customer': {'name': 'Bob'},
            'items': [],
            'inquiryStatus': 'contacted',
          },
        ],
        'pagination': {'total': 2, 'page': 1, 'limit': 20, 'pages': 1},
      });

      await container
          .read(partnerInquiriesProvider.notifier)
          .fetchInquiries(refresh: true);

      expect(client.requests.single.url.path, endsWith('/inquiries'));
      expect(client.requests.single.url.queryParameters['page'], '1');

      final state = container.read(partnerInquiriesProvider);
      expect(state.error, isNull);
      expect(state.isLoading, isFalse);
      expect(state.inquiries.length, 2);
      expect(state.inquiries.first.id, 'inq_1');
      expect(state.inquiries.first.customer.name, 'Ada');
      expect(state.pagination?.total, 2);
      expect(state.hasMore, isFalse);
    });

    test('fetchInquiries surfaces API errors', () async {
      client.enqueue(401, {'success': false, 'message': 'Unauthorized'});

      await container.read(partnerInquiriesProvider.notifier).refresh();
      final state = container.read(partnerInquiriesProvider);
      expect(state.inquiries, isEmpty);
      expect(state.error, isNotNull);
    });

    test('setHighlightId stores soft-highlight target', () {
      container
          .read(partnerInquiriesProvider.notifier)
          .setHighlightId('inq_highlight');
      expect(
        container.read(partnerInquiriesProvider).highlightId,
        'inq_highlight',
      );
    });
  });
}
