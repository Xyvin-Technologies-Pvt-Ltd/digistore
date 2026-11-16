import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:setgo/src/data/utils/install_checker.dart';

class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  int deleteAllCalls = 0;
  final Map<String, String> data = {};

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    deleteAllCalls++;
    data.clear();
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      data[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return data[key];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InstallChecker', () {
    test('wipes secure storage and sets install_flag on fresh install / reinstall', () async {
      SharedPreferences.setMockInitialValues({});
      final fakeStorage = FakeFlutterSecureStorage();
      await fakeStorage.write(key: 'stale_token', value: 'old_secret_value');

      final checker = InstallChecker(secureStorage: fakeStorage);
      await checker.checkFirstInstall();

      expect(fakeStorage.deleteAllCalls, 1);
      expect(fakeStorage.data.isEmpty, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('install_flag'), isTrue);
    });

    test('preserves secure storage on subsequent launches when install_flag is true', () async {
      SharedPreferences.setMockInitialValues({'install_flag': true});
      final fakeStorage = FakeFlutterSecureStorage();
      await fakeStorage.write(key: 'active_token', value: 'valid_jwt');

      final checker = InstallChecker(secureStorage: fakeStorage);
      await checker.checkFirstInstall();

      expect(fakeStorage.deleteAllCalls, 0);
      expect(fakeStorage.data['active_token'], 'valid_jwt');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('install_flag'), isTrue);
    });
  });
}
