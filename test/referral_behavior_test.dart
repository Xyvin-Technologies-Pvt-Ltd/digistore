import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:setgo/src/data/models/referral_models.dart';
import 'package:setgo/src/data/providers/api_provider.dart';
import 'package:setgo/src/data/providers/referral_provider.dart';
import 'package:setgo/src/data/services/referral_attribution.dart';
import 'package:setgo/src/data/services/referral_repository.dart';
import 'package:setgo/src/data/services/referral_store.dart';
import 'package:setgo/src/data/services/secure_storage_service.dart';
import 'package:setgo/src/data/utils/referral_code.dart';
import 'package:setgo/src/interfaces/components/referral_code_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('code boundaries', () {
    test('shape is S plus five digits, case and whitespace ignored', () {
      expect(ReferralCode.normalize('s00001'), 'S00001');
      expect(ReferralCode.normalize('S99999'), 'S99999');
      expect(ReferralCode.normalize('  S00004\n'), 'S00004');
      expect(ReferralCode.normalize('S00000'), 'S00000');
      expect(ReferralCode.normalize('S0000'), isNull);
      expect(ReferralCode.normalize('S000001'), isNull);
      expect(ReferralCode.normalize('S0000A'), isNull);
      expect(ReferralCode.normalize('SS0001'), isNull);
      expect(ReferralCode.normalize('S00 004'), isNull);
    });

    test('extract takes the first bounded code and ignores glued digits', () {
      expect(ReferralCode.extract('codes S00001 and S00002'), 'S00001');
      expect(ReferralCode.extract('AS00004'), isNull);
      expect(ReferralCode.extract('S000041'), isNull);
      expect(ReferralCode.extract('see S00004.'), 'S00004');
    });

    test('install referrer survives encoding and does not throw on junk', () {
      expect(
        ReferralCode.fromInstallReferrer(
          'utm_source%3Dreferral%26utm_campaign%3DS00004',
        ),
        'S00004',
      );
      expect(ReferralCode.fromInstallReferrer('%'), isNull);
      expect(ReferralCode.fromInstallReferrer(''), isNull);
      expect(
        ReferralCode.fromInstallReferrer('utm_campaign=spring&x=S00007'),
        'S00007',
      );
    });

    test('only SetGo referral links are attribution links', () {
      expect(
        ReferralCode.isAttributionLink(
          Uri.parse('https://setgoinnovations.com/app?ref=s00004'),
        ),
        isTrue,
      );
      expect(
        ReferralCode.isAttributionLink(
          Uri.parse('https://www.setgo.in/app?code=S00009'),
        ),
        isTrue,
      );
      expect(
        ReferralCode.isAttributionLink(
          Uri.parse('setgo://referral?code=S00004'),
        ),
        isTrue,
      );
      expect(
        ReferralCode.isAttributionLink(
          Uri.parse('https://setgo.in/app/offerdetail/123?ref=S00004'),
        ),
        isFalse,
      );
      expect(
        ReferralCode.isAttributionLink(
          Uri.parse('https://news.example/app?ref=S00004'),
        ),
        isFalse,
      );
      expect(
        ReferralCode.isAttributionLink(
          Uri.parse(
            'https://play.google.com/store/apps/details?id=com.setgoinnovations&referrer=utm_source%3Dreferral%26utm_campaign%3DS00004',
          ),
        ),
        isFalse,
      );
      expect(
        ReferralCode.fromUri(Uri.parse('https://setgo.in/app?ref=')),
        isNull,
      );
    });

    test('qr payload decodes with whitespace and rejects non-images', () {
      final bytes = ReferralCode.decodeQr('data:image/png;base64, YQ==');
      expect(bytes, isNotNull);
      expect(utf8.decode(bytes!), 'a');
      expect(
        ReferralCode.decodeQr('data:image/png;base64,YQ\n=='),
        isNotNull,
      );
      expect(ReferralCode.decodeQr('data:text/plain;base64,YQ=='), isNull);
      expect(ReferralCode.decodeQr('data:image/png;base64,@@@'), isNull);
      expect(ReferralCode.decodeQr(null), isNull);
    });
  });

  group('local store', () {
    test('explicit code wins and a second install match does not replace it', () async {
      final store = ReferralStore();
      await store.writeCode('S00002');
      expect(await store.saveIfEmpty('S00003'), isFalse);
      expect(await store.readCode(), 'S00002');
    });

    test('two simultaneous empty writes keep a single code', () async {
      final store = ReferralStore();
      final saved = await Future.wait([
        store.saveIfEmpty('S00001'),
        store.saveIfEmpty('S00002'),
      ]);
      expect(saved.where((ok) => ok).length, 1);
      expect(await store.readCode(), anyOf('S00001', 'S00002'));
    });

    test('clearing the code keeps the device id and the first-launch flag', () async {
      final store = ReferralStore();
      final first = await store.deviceId();
      final second = await store.deviceId();
      await store.markDeferredDone();
      await store.writeCode('S00004');
      await store.clearCode();

      expect(second, first);
      expect(first, isNotEmpty);
      expect(await store.readCode(), isNull);
      expect(await store.isDeferredDone(), isTrue);
      expect(await store.deviceId(), first);
    });
  });

  group('api contract on the client', () {
    late RecordingClient client;
    late ReferralRepository repo;

    setUp(() {
      client = RecordingClient();
      repo = ReferralRepository(
        ApiProvider(
          baseUrl: 'https://example.test/api/mobile',
          secureStorage: SecureStorageService(
            storage: const FlutterSecureStorage(),
          ),
          client: client,
        ),
        ReferralStore(),
      );
    });

    test('resolve-pending treats a match, a miss, and a bad code differently', () async {
      client.enqueue(
        200,
        {
          'success': true,
          'data': {'found': true, 'referralCode': 's00004', 'platform': 'ios'},
        },
      );
      final found = await repo.resolvePending();
      expect(found.answered, isTrue);
      expect(found.code, 'S00004');
      expect(client.requests.single.headers.containsKey('authorization'), isFalse);

      client.enqueue(200, {
        'success': true,
        'data': {'found': false, 'referralCode': null},
      });
      final miss = await repo.resolvePending();
      expect(miss.answered, isTrue);
      expect(miss.code, isNull);

      client.enqueue(200, {
        'success': true,
        'data': {'found': true, 'referralCode': 'nope'},
      });
      final garbage = await repo.resolvePending();
      expect(garbage.answered, isTrue);
      expect(garbage.code, isNull);

      client.enqueue(500, {'success': false, 'message': 'down'});
      final down = await repo.resolvePending();
      expect(down.answered, isFalse);
    });

    test('validate accepts the server verdict and never sends a token', () async {
      secureData['bearer_token'] = 'secret';
      client.enqueue(200, {
        'success': true,
        'message': 'Referral code validated successfully',
        'data': {
          'valid': true,
          'referralCode': 'S00004',
          'referrerName': 'Jiji',
        },
      });
      final valid = await repo.validate('s00004');
      expect(valid.valid, isTrue);
      expect(valid.referrerName, 'Jiji');
      expect(client.requests.single.url.path, '/api/mobile/referral/validate/S00004');
      expect(client.requests.single.headers.containsKey('authorization'), isFalse);

      client.enqueue(200, {
        'success': false,
        'valid': false,
        'message': 'Invalid referral code',
      });
      final invalid = await repo.validate('S00000');
      expect(invalid.valid, isFalse);
      expect(invalid.message, 'Invalid referral code');

      final local = await repo.validate('NOPE');
      expect(local.valid, isFalse);
      expect(client.requests, hasLength(2));
    });

    test('apply sends the device id and classifies fraud responses', () async {
      secureData['bearer_token'] = 'user-token';
      client.enqueue(200, {
        'success': true,
        'message': 'Referral code applied successfully! 10 points awarded to referrer.',
        'data': {
          'referralCode': 'S00004',
          'pointsAwarded': 10.0,
          'referrerName': 'Jiji',
        },
      });
      final applied = await repo.apply('s00004');
      expect(applied.applied, isTrue);
      expect(applied.shouldContinue, isTrue);
      expect(applied.pointsAwarded, 10);
      final applyRequest = client.requests.single;
      expect(applyRequest.headers['authorization'], 'Bearer user-token');
      expect(applyRequest.headers['x-device-id'], isNotEmpty);
      expect(jsonDecode(applyRequest.body)['referralCode'], 'S00004');

      client.enqueue(400, {
        'success': false,
        'message': 'You cannot use your own referral code',
      });
      final self = await repo.apply('S00001');
      expect(self.applied, isFalse);
      expect(self.alreadyApplied, isFalse);
      expect(self.shouldContinue, isFalse);

      client.enqueue(400, {
        'success': false,
        'message':
            'You have already applied a referral code or received a reward',
      });
      final again = await repo.apply('S00002');
      expect(again.alreadyApplied, isTrue);
      expect(again.shouldContinue, isTrue);
    });

    test('my-code and history tolerate the documented payloads and bad rows', () async {
      secureData['bearer_token'] = 'user-token';
      client.enqueue(200, {
        'success': true,
        'data': {
          'referralCode': 'S00009',
          'rewardPoints': '10',
          'rupeeEquivalent': '1',
          'successfulReferrals': 5,
          'totalPointsEarned': 50,
          'minPurchaseForRedemption': 2500,
          'terms': 'Award 10 points.',
        },
      });
      final payload = await repo.myCode();
      expect(payload?.referralCode, 'S00009');
      expect(payload?.earnedRupees, 5);
      expect(client.requests.single.headers['authorization'], 'Bearer user-token');

      client.enqueue(200, {'success': false, 'message': 'nope'});
      expect(await repo.myCode(), isNull);

      client.enqueue(200, {
        'success': true,
        'data': {
          'items': [
            {
              'id': '1',
              'referredName': 'Kala',
              'referredPhone': '+9198*****321',
              'pointsAwarded': '10',
              'status': 'approved',
              'date': '2026-11-03T10:15:30.000Z',
            },
            'skip-me',
            {'referredName': 'No date', 'date': 'not-a-date'},
          ],
          'pagination': {'page': 1, 'limit': 20, 'total': 3, 'totalPages': 2},
        },
      });
      final history = await repo.history();
      expect(history.items, hasLength(2));
      expect(history.items.first.pointsAwarded, 10);
      expect(history.items.first.date, isNotNull);
      expect(history.items.last.date, isNull);
      expect(history.hasMore, isTrue);
      expect(client.requests.last.url.queryParameters['page'], '1');
      expect(client.requests.last.url.queryParameters['limit'], '20');

      client.enqueue(500, {'message': 'down'});
      final failed = await repo.history(page: 2);
      expect(failed.items, isEmpty);
      expect(failed.hasMore, isFalse);
    });

    test('a zero balance does not divide by zero when showing earned rupees', () {
      final payload = ReferralSharePayload.fromJson({
        'referralCode': 'S00001',
        'rewardPoints': 0,
        'rupeeEquivalent': 0,
        'totalPointsEarned': 20,
      });
      expect(payload.earnedRupees, 2);
    });
  });

  group('deferred attribution', () {
    test('a server match is stored once and is not requested again', () async {
      final store = ReferralStore();
      final script = _ScriptedRepository(store);
      script.pending.add(
        const ResolvePendingResult(answered: true, code: 'S00004'),
      );
      final attribution = _attribution(store, script);

      await attribution.resolveDeferred();
      await attribution.resolveDeferred();

      expect(script.resolveCalls, 1);
      expect(await store.readCode(), 'S00004');
      expect(await store.isDeferredDone(), isTrue);
    });

    test('a server miss finishes the attempt', () async {
      final store = ReferralStore();
      final script = _ScriptedRepository(store);
      script.pending.add(const ResolvePendingResult(answered: true));
      final attribution = _attribution(store, script);

      await attribution.resolveDeferred();
      await attribution.resolveDeferred();

      expect(script.resolveCalls, 1);
      expect(await store.readCode(), isNull);
      expect(await store.isDeferredDone(), isTrue);
    });

    test('a failed lookup is retried on the next launch', () async {
      final store = ReferralStore();
      final script = _ScriptedRepository(store);
      script.pending.add(const ResolvePendingResult(answered: false));
      script.pending.add(
        const ResolvePendingResult(answered: true, code: 'S00008'),
      );
      final attribution = _attribution(store, script);

      await attribution.resolveDeferred();
      expect(await store.isDeferredDone(), isFalse);
      await attribution.resolveDeferred();

      expect(script.resolveCalls, 2);
      expect(await store.readCode(), 'S00008');
    });

    test('an existing code is kept and the server is not called', () async {
      final store = ReferralStore();
      await store.writeCode('S00003');
      final script = _ScriptedRepository(store);
      final attribution = _attribution(store, script);

      await attribution.resolveDeferred();

      expect(script.resolveCalls, 0);
      expect(await store.readCode(), 'S00003');
      expect(await store.isDeferredDone(), isTrue);
    });

    test('explicit links respect partner and already-referred accounts', () async {
      final store = ReferralStore();
      final attribution = _attribution(store, _ScriptedRepository(store));

      expect(await attribution.rememberExplicit('nope'), isFalse);

      expect(await attribution.rememberExplicit('s00004'), isTrue);
      expect(await store.readCode(), 'S00004');

      secureData['is_partner'] = 'true';
      expect(await attribution.rememberExplicit('S00005'), isFalse);
      expect(await store.readCode(), 'S00004');

      secureData.remove('is_partner');
      secureData['user_data'] = jsonEncode({'referredBy': 'S00001'});
      expect(await attribution.rememberExplicit('S00006'), isFalse);

      secureData['user_data'] = jsonEncode({'referralRewardClaimed': true});
      expect(await attribution.rememberExplicit('S00007'), isFalse);

      secureData['user_data'] = jsonEncode({'referredBy': '   '});
      expect(await attribution.rememberExplicit('S00008'), isTrue);
      expect(await store.readCode(), 'S00008');

      secureData['user_data'] = '{';
      expect(await attribution.rememberExplicit('S00009'), isTrue);
      expect(await store.readCode(), 'S00009');
    });
  });

  group('referral field', () {
    testWidgets('partial input is quiet, lowercase validates, submit is strict', (
      tester,
    ) async {
      final store = ReferralStore();
      final repo = _ScriptedRepository(store);
      final controller = TextEditingController();
      final key = GlobalKey<ReferralCodeFieldState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            referralStoreProvider.overrideWithValue(store),
            referralRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReferralCodeField(key: key, controller: controller),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'S00');
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('Invalid referral code'), findsNothing);
      expect(repo.validated, isEmpty);

      await tester.enterText(find.byType(TextFormField), 's00004');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      expect(controller.text, 'S00004');
      expect(repo.validated, ['S00004']);
      expect(find.text('Code applied (Referred by Jiji)'), findsOneWidget);

      controller.text = 'S00';
      final blocked = await key.currentState!.resolve();
      expect(blocked.valid, isFalse);
      expect(repo.validated, ['S00004']);
    });

    testWidgets('a stored code prefills the field before the user types', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        ReferralStore.pendingCodeKey: 'S00009',
      });
      final store = ReferralStore();
      final repo = _ScriptedRepository(store);
      final controller = TextEditingController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            referralStoreProvider.overrideWithValue(store),
            referralRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: Scaffold(body: ReferralCodeField(controller: controller)),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(controller.text, 'S00009');
      expect(find.text('Code applied (Referred by Jiji)'), findsOneWidget);
    });
  });
}

class RecordingClient extends http.BaseClient {
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

class _ScriptedRepository extends ReferralRepository {
  _ScriptedRepository(ReferralStore store)
    : super(
        ApiProvider(
          baseUrl: 'https://example.test/api/mobile',
          secureStorage: SecureStorageService(
            storage: const FlutterSecureStorage(),
          ),
          client: RecordingClient(),
        ),
        store,
      );

  final List<ResolvePendingResult> pending = [];
  final List<String> validated = [];
  int resolveCalls = 0;

  @override
  Future<ResolvePendingResult> resolvePending() async {
    resolveCalls++;
    if (pending.isEmpty) return const ResolvePendingResult(answered: false);
    return pending.removeAt(0);
  }

  @override
  Future<ReferralValidation> validate(String code) async {
    validated.add(code);
    return ReferralValidation(
      valid: true,
      code: code,
      referrerName: 'Jiji',
      message: 'ok',
    );
  }
}

ReferralAttribution _attribution(ReferralStore store, ReferralRepository repo) {
  return ReferralAttribution(
    repository: repo,
    store: store,
    saveIfEmpty: store.saveIfEmpty,
    saveExplicit: store.writeCode,
    secureStorage: SecureStorageService(storage: const FlutterSecureStorage()),
  );
}
