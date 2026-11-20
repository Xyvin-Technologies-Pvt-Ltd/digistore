import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:setgo/src/data/models/product_model.dart';
import 'package:setgo/src/data/providers/api_provider.dart';
import 'package:setgo/src/data/providers/partner_products_provider.dart';
import 'package:setgo/src/data/services/secure_storage_service.dart';

class _MockSecureStorageService extends SecureStorageService {
  @override
  Future<String?> getBearerToken() async => 'fake_token';
}

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
    final response = _queued.isNotEmpty
        ? _queued.removeAt(0)
        : http.Response('{"success": true, "data": []}', 200,
            headers: {'content-type': 'application/json'});
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

  late _RecordingClient client;
  late ProviderContainer container;

  setUp(() {
    client = _RecordingClient();
    final api = ApiProvider(
      baseUrl: 'https://api-deals.setgoinnovations.com/api/mobile',
      secureStorage: _MockSecureStorageService(),
      client: client,
    );

    container = ProviderContainer(
      overrides: [
        apiProvider.overrideWithValue(api),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('getProducts sends all Notion-documented query parameters correctly', () async {
    client.enqueue(200, {
      'success': true,
      'message': 'Success',
      'data': [
        {
          '_id': 'p1',
          'title': 'Hair Spa',
          'price': 500,
          'maxPrice': 1000,
          'hasOffer': true,
          'offerType': 'percentage',
          'offerValue': 20,
          'maxOfferValue': 30,
          'offerPrice': 400,
          'maxOfferPrice': 700,
          'priceDisplay': '₹500 - ₹1,000',
          'offerPriceDisplay': '₹400 - ₹700',
        }
      ],
      'pagination': {
        'page': 1,
        'limit': 20,
        'total': 1,
        'totalPages': 1,
        'hasMore': false,
      }
    });

    final notifier = container.read(partnerProductsProvider.notifier);

    await notifier.getProducts(
      page: 1,
      limit: 20,
      search: 'Hair',
      categoryId: 'cat123',
      minPrice: 100,
      maxPrice: 2000,
      tags: 'organic,spa',
      partnerId: 'partner999',
      sortBy: 'price_low',
      lat: 9.9312,
      lng: 76.2673,
    );

    expect(client.requests.isNotEmpty, isTrue);
    final request = client.requests.last;
    expect(request.url.path, '/api/mobile/products');
    final query = request.url.queryParameters;

    expect(query['page'], '1');
    expect(query['limit'], '20');
    expect(query['search'], 'Hair');
    expect(query['category'], 'cat123');
    expect(query['minPrice'], '100');
    expect(query['maxPrice'], '2000');
    expect(query['tags'], 'organic,spa');
    expect(query['partnerId'], 'partner999');
    expect(query['sortBy'], 'price_low');
    expect(query['lat'], '9.9312');
    expect(query['lng'], '76.2673');

    final state = container.read(partnerProductsProvider);
    expect(state.products.length, 1);
    expect(state.products.first.hasPriceRange, isTrue);
    expect(state.products.first.priceRangeText, '₹500 - ₹1,000');
    expect(state.products.first.offerRangeText, '₹400 - ₹700');
  });

  test('deleteProduct sends DELETE /products/:id and removes product locally', () async {
    final notifier = container.read(partnerProductsProvider.notifier);
    notifier.addProduct(const ProductModel(
      id: 'to_delete_id',
      title: 'To Delete',
      price: 100,
    ));

    expect(container.read(partnerProductsProvider).products.length, 1);

    client.enqueue(200, {
      'success': true,
      'message': 'Product deleted successfully',
    });

    await notifier.deleteProduct('to_delete_id');

    final deleteReq = client.requests.firstWhere((r) => r.method == 'DELETE');
    expect(deleteReq.url.path, '/api/mobile/products/to_delete_id');
    expect(container.read(partnerProductsProvider).products.isEmpty, isTrue);
  });
}
