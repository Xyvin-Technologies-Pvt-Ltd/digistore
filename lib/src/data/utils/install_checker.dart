import 'dart:developer' as developer;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InstallChecker {
  static const String _installFlagKey = 'install_flag';
  final FlutterSecureStorage _secureStorage;

  InstallChecker({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Checks if this is a fresh install or reinstall.
  /// When uninstalled, SharedPreferences is cleared by iOS and Android.
  /// If the install flag is missing, we wipe any persistent residual data
  /// (specifically iOS Keychain entries which persist across uninstalls) and initialize the flag.
  Future<void> checkFirstInstall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasInstallFlag = prefs.getBool(_installFlagKey) ?? false;

      if (!hasInstallFlag) {
        developer.log(
          'Fresh install or reinstall detected. Wiping residual data...',
          name: 'InstallChecker',
        );

        // Wipe Keychain / SecureStorage (which persists across uninstalls on iOS)
        try {
          await _secureStorage.deleteAll();
          developer.log('Secure storage cleared.', name: 'InstallChecker');
        } catch (e) {
          developer.log(
            'Error clearing secure storage: $e',
            name: 'InstallChecker',
          );
        }

        // Clear any residual SharedPreferences and mark installation complete
        await prefs.clear();
        await prefs.setBool(_installFlagKey, true);

        developer.log(
          'InstallChecker: First install initialization completed.',
          name: 'InstallChecker',
        );
      } else {
        developer.log(
          'Existing installation detected. Data preserved.',
          name: 'InstallChecker',
        );
      }
    } catch (e, st) {
      developer.log(
        'Unexpected error in InstallChecker: $e',
        name: 'InstallChecker',
        error: e,
        stackTrace: st,
      );
    }
  }
}


