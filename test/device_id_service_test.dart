import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:setgo/src/data/providers/api_provider.dart';
import 'package:setgo/src/data/services/device_id_service.dart';
import 'package:setgo/src/data/services/referral_store.dart';
import 'package:setgo/src/data/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingClient extends http.BaseClient {
  final List<http.Request> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final recorded = http.Request(request.method, request.url)
      ..headers.addAll(request.headers);
    requests.add(recorded);
    return http.StreamedResponse(
      Stream<List<int>>.value('{"success":true}'.codeUnits),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureData;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureData = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      secureData,
    );
  });

  test('migrates legacy SharedPreferences device id into permanent storage',
      () async {
    SharedPreferences.setMockInitialValues({
      DeviceIdService.legacyPrefsKey: 'legacy-device-123',
    });
    final service = DeviceIdService(storage: const FlutterSecureStorage());
    final id = await service.getPermanentDeviceId();
    expect(id, 'legacy-device-123');
    expect(secureData[DeviceIdService.storageKey], 'legacy-device-123');
    expect(await service.getPermanentDeviceId(), 'legacy-device-123');
  });

  test('ReferralStore.deviceId matches DeviceIdService', () async {
    final service = DeviceIdService(storage: const FlutterSecureStorage());
    final store = ReferralStore(deviceIdService: service);
    final a = await store.deviceId();
    final b = await service.getPermanentDeviceId();
    expect(a, b);
    expect(a, isNotEmpty);
  });

  test('logout clearAll keeps permanent device id', () async {
    final storage = SecureStorageService(
      storage: const FlutterSecureStorage(),
    );
    final devices = DeviceIdService(storage: const FlutterSecureStorage());
    final id = await devices.getPermanentDeviceId();
    await storage.saveBearerToken('tok');
    await storage.saveUserId('u1');
    await storage.clearAll();

    expect(await storage.getBearerToken(), isNull);
    expect(secureData[DeviceIdService.storageKey], id);
    expect(await devices.getPermanentDeviceId(), id);
  });

  test('ApiProvider attaches X-Device-Id on every request', () async {
    final client = _RecordingClient();
    final devices = DeviceIdService(storage: const FlutterSecureStorage());
    final api = ApiProvider(
      baseUrl: 'https://example.test/api/mobile',
      secureStorage: SecureStorageService(
        storage: const FlutterSecureStorage(),
      ),
      deviceIdService: devices,
      client: client,
    );

    await api.get('/ping', requireAuth: false);
    await api.post('/ping', {}, requireAuth: false);

    expect(client.requests, hasLength(2));
    final id = await devices.getPermanentDeviceId();
    for (final req in client.requests) {
      final header = req.headers['x-device-id'] ?? req.headers['X-Device-Id'];
      expect(header, id);
    }
  });
}
