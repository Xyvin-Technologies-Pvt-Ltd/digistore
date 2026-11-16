import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/secure_storage_service.dart';
import '../utils/name_case.dart';
import 'api_provider.dart';

class UserNotifier extends Notifier<UserModel?> {
  @override
  UserModel? build() {
    _loadUser();
    return null;
  }

  Future<void> _loadUser() async {
    try {
      final storage = ref.read(secureStorageServiceProvider);
      final user = await storage.getUserData();
      if (user != null && state == null) {
        state = user;
      }
    } catch (_) {}
  }

  Future<int?> getProfile() async {
    final api = ref.read(apiProvider);
    final response = await api.get('/profile', requireAuth: true);

    if (response.success && response.data != null) {
      final rawData = response.data!['data'];
      final userData = (rawData is Map<String, dynamic> &&
              rawData['user'] is Map<String, dynamic>)
          ? rawData['user'] as Map<String, dynamic>
          : (rawData is Map<String, dynamic> ? rawData : null);

      if (userData != null) {
        final parsedUser = UserModel.fromJson(userData);
        final user =
            (state != null) ? state!.mergeWith(parsedUser) : parsedUser;
        state = user;
        await saveUser(user);
        return 200;
      }
    }
    return response.statusCode;
  }

  Future<void> saveUser(UserModel user) async {
    final storage = ref.read(secureStorageServiceProvider);
    await storage.saveUserData(user);
    state = user;
  }

  Future<void> clearUser() async {
    final storage = ref.read(secureStorageServiceProvider);
    await storage.clearAll();
    state = null;
  }

  Future<bool> updateProfile({
    required String name,
    required String email,
    bool? onboardingComplete,
  }) async {
    final api = ref.read(apiProvider);

    final Map<String, dynamic> payload = {
      'name': NameCase.toTitleCase(name),
      if (email.isNotEmpty) 'email': email,
    };

    if (onboardingComplete != null) {
      payload['onboardingComplete'] = onboardingComplete;
    }

    final response = await api.put('/profile', payload, requireAuth: true);

    if (response.success && response.data != null) {
      final rawData = response.data!['data'];
      final userData = (rawData is Map<String, dynamic> &&
              rawData['user'] is Map<String, dynamic>)
          ? rawData['user'] as Map<String, dynamic>
          : (rawData is Map<String, dynamic> ? rawData : null);

      final base = state ?? const UserModel();
      if (userData != null) {
        final parsedUser = UserModel.fromJson(userData);
        final userToSave = base.mergeWith(parsedUser).copyWith(
              name: (parsedUser.name != null && parsedUser.name!.isNotEmpty)
                  ? parsedUser.name
                  : NameCase.toTitleCase(name),
              email: (parsedUser.email != null && parsedUser.email!.isNotEmpty)
                  ? parsedUser.email
                  : (email.isNotEmpty ? email : null),
              onboardingComplete: onboardingComplete ??
                  parsedUser.onboardingComplete ??
                  base.onboardingComplete,
            );
        await saveUser(userToSave);
      } else if (state != null) {
        final updatedUser = state!.copyWith(
          name: NameCase.toTitleCase(name),
          email: email,
          onboardingComplete: onboardingComplete,
        );
        await saveUser(updatedUser);
      }
      return true;
    }
    throw Exception(response.message ?? 'Failed to update profile');
  }

  Future<bool> updateLocation({
    required double lat,
    required double lng,
    required String district,
    required String localBody,
  }) async {
    final api = ref.read(apiProvider);
    final response = await api.put('/profile/location', {
      'lat': lat,
      'lng': lng,
      'district': district,
      'localBody': localBody,
    }, requireAuth: true);

    if (response.success && response.data != null) {
      final newLocation = LocationModel(
        district: district,
        localBody: localBody,
        coordinates: CoordinatesModel(coordinates: [lng, lat]),
      );

      final rawData = response.data!['data'];
      final userData = (rawData is Map<String, dynamic> &&
              rawData['user'] is Map<String, dynamic>)
          ? rawData['user'] as Map<String, dynamic>
          : (rawData is Map<String, dynamic> ? rawData : null);

      final base = state ?? const UserModel();
      var userToSave = base.copyWith(location: newLocation);

      if (userData != null) {
        final parsed = UserModel.fromJson(userData);
        userToSave = userToSave.mergeWith(parsed);
        userToSave = userToSave.copyWith(
          location: (userToSave.location != null)
              ? userToSave.location!.mergeWith(newLocation)
              : newLocation,
        );
      }

      await saveUser(userToSave);
      return true;
    }
    throw Exception(response.message ?? 'Failed to update location');
  }
}

final userProvider = NotifierProvider<UserNotifier, UserModel?>(
  UserNotifier.new,
);
