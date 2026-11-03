import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:setgo/src/data/services/crashlytics_service.dart';

import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/foundation.dart';
import '../services/secure_storage_service.dart';
import '../services/connectivity_service.dart';
import 'user_type_provider.dart';

String _formatErrorMessage(dynamic e) {
  if (e == null) return 'Something went wrong. Please try again.';
  final errorStr = e.toString().toLowerCase();
  if (e is SocketException ||
      e is http.ClientException ||
      e is TimeoutException ||
      errorStr.contains('socketexception') ||
      errorStr.contains('failed host lookup') ||
      errorStr.contains('clientexception') ||
      errorStr.contains('network is unreachable') ||
      errorStr.contains('connection refused') ||
      errorStr.contains('connection timed out') ||
      errorStr.contains('timed out') ||
      errorStr.contains('no address associated with hostname') ||
      errorStr.contains('network error') ||
      errorStr.contains('handshakeexception') ||
      errorStr.contains('tlsexception')) {
    ConnectivityService.instance.notifyOffline();
    return 'You are offline. Please check your internet connection.';
  }
  return 'Failed to connect to the server. Please try again.';
}

void _safeLog(String name, dynamic message) {
  if (kDebugMode) {
    String safeMessage = message.toString();
    try {
      if (safeMessage.startsWith('{') || safeMessage.startsWith('[')) {
        final dynamic decoded = json.decode(safeMessage);
        if (decoded is Map) {
          final sanitized = Map.from(decoded);
          final sensitiveKeys = [
            'otp',
            'token',
            'password',
            'fcmToken',
            '_devOtp',
          ];
          for (var key in sensitiveKeys) {
            if (sanitized.containsKey(key)) {
              sanitized[key] = '***REDACTED***';
            }
          }
          if (sanitized.containsKey('data') && sanitized['data'] is Map) {
            final dataMap = Map.from(sanitized['data']);
            for (var key in sensitiveKeys) {
              if (dataMap.containsKey(key)) {
                dataMap[key] = '***REDACTED***';
              }
            }
            sanitized['data'] = dataMap;
          }
          safeMessage = json.encode(sanitized);
        }
      }
    } catch (_) {}

    safeMessage = safeMessage.replaceAll(
      RegExp(r'"token"\s*:\s*"[^"]+"'),
      '"token":"***REDACTED***"',
    );
    safeMessage = safeMessage.replaceAll(
      RegExp(r'"otp"\s*:\s*"[^"]+"'),
      '"otp":"***REDACTED***"',
    );

    log(name: name, safeMessage);
  }
}

class ApiResponse<T> {
  final bool success;
  final T? data;
  final int? statusCode;
  final String? message;

  ApiResponse({
    required this.success,
    this.data,
    this.statusCode,
    this.message,
  });

  factory ApiResponse.success(T data, [int? statusCode]) {
    return ApiResponse(success: true, data: data, statusCode: statusCode);
  }

  factory ApiResponse.error(String message, [int? statusCode, T? data]) {
    return ApiResponse(
      success: false,
      message: message,
      statusCode: statusCode,
      data: data,
    );
  }
}

class ApiProvider {
  final String baseUrl;
  final SecureStorageService secureStorage;
  final http.Client _client;

  ApiProvider({
    required this.baseUrl,
    required this.secureStorage,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<Map<String, String>> _buildHeaders({bool requireAuth = false}) async {
    final headers = {'Content-Type': 'application/json', 'accept': '*/*'};

    if (requireAuth) {
      final token = await secureStorage.getBearerToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<ApiResponse<Map<String, dynamic>>> get(
    String endpoint, {
    bool requireAuth = true,
    Map<String, String>? queryParams,
  }) async {
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final uri = Uri.parse('$baseUrl$endpoint');
      final uriWithParams = queryParams != null && queryParams.isNotEmpty
          ? uri.replace(queryParameters: queryParams)
          : uri;
_safeLog('headers', headers.toString());
      final response = await _client.get(uriWithParams, headers: headers);

      _safeLog('API GET', '$baseUrl$endpoint');
      final decoded = json.decode(response.body);
      _safeLog('DATA', response.body);
      _safeLog('QUERY PARAMS', queryParams.toString());
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.success(decoded, response.statusCode);
      } else {
        final message = decoded['message'] ?? 'Failed to load data';
        return ApiResponse.error(message, response.statusCode);
      }
    } catch (e, stackTrace) {
      await CrashlyticsService.logError(e, stackTrace);
      await CrashlyticsService.setCustomKey('api_endpoint', endpoint);
      await CrashlyticsService.setCustomKey('api_method', 'GET');
      _safeLog('API GET EXCEPTION', '$e');
      return ApiResponse.error(_formatErrorMessage(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> post(
    String endpoint,
    Map<String, dynamic> data, {
    bool requireAuth = true,
  }) async {
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final response = await _client.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(data),
      );
      _safeLog('API POST', '$baseUrl$endpoint');
      _safeLog('API POST body', json.encode(data));
      final decoded = json.decode(response.body);
      _safeLog('API POST data ', '${decoded['data']}');
      _safeLog('API POST message', '${decoded['message']}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.success(decoded, response.statusCode);
      } else {
        final message = decoded['message'] ?? 'Failed to post data';
        _safeLog('API POST ERROR', '$message');
        return ApiResponse.error(message, response.statusCode, decoded);
      }
    } catch (e, stackTrace) {
      await CrashlyticsService.logError(e, stackTrace);
      await CrashlyticsService.setCustomKey('api_endpoint', endpoint);
      await CrashlyticsService.setCustomKey('api_method', 'POST');
      _safeLog('API POST EXCEPTION', '$e');
      return ApiResponse.error(_formatErrorMessage(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> patch(
    String endpoint,
    Map<String, dynamic>? data, {
    bool requireAuth = true,
  }) async {
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      _safeLog('API PATCH', '$baseUrl$endpoint');
      final response = await _client.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: data != null ? json.encode(data) : null,
      );

      final decoded = json.decode(response.body);
      _safeLog('API PATCH data ', '${decoded['data']}');
      _safeLog('API PATCH message', '${decoded['message']}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.success(decoded, response.statusCode);
      } else {
        final message = decoded['message'] ?? 'Failed to patch data';
        return ApiResponse.error(message, response.statusCode);
      }
    } catch (e, stackTrace) {
      await CrashlyticsService.logError(e, stackTrace);
      await CrashlyticsService.setCustomKey('api_endpoint', endpoint);
      await CrashlyticsService.setCustomKey('api_method', 'PATCH');
      _safeLog('API PATCH EXCEPTION', '$e');
      return ApiResponse.error(_formatErrorMessage(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> put(
    String endpoint,
    Map<String, dynamic> data, {
    bool requireAuth = true,
  }) async {
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final response = await _client.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(data),
      );
      _safeLog('API PUT', '$baseUrl$endpoint');
      _safeLog('API PUT payload', json.encode(data));
      final decoded = json.decode(response.body);

      _safeLog('API PUT', '$baseUrl$endpoint');
      _safeLog('API PUT data', '${decoded['data']}');
      _safeLog('API PUT message', '${decoded['message']}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.success(decoded, response.statusCode);
      } else {
        final message = decoded['message'] ?? 'Failed to put data';
        return ApiResponse.error(message, response.statusCode);
      }
    } catch (e, stackTrace) {
      await CrashlyticsService.logError(e, stackTrace);
      await CrashlyticsService.setCustomKey('api_endpoint', endpoint);
      await CrashlyticsService.setCustomKey('api_method', 'PUT');
      _safeLog('API PUT EXCEPTION', '$e');
      return ApiResponse.error(_formatErrorMessage(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> putMultipart(
    String endpoint,
    Map<String, String> body, {
    List<http.MultipartFile>? files,
    bool requireAuth = true,
  }) async {
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      headers.remove('Content-Type');

      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl$endpoint'),
      );
      request.headers.addAll(headers);
      request.fields.addAll(body);

      if (files != null) {
        request.files.addAll(files);
      }

      _safeLog('API PUT MULTIPART', '$baseUrl$endpoint');

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      final decoded = json.decode(responseBody);
      _safeLog('API PUT MULTIPART data ', '$decoded');
      _safeLog('API PUT MULTIPART message', '${decoded['message']}');
      _safeLog('API PUT MULTIPART body', '${decoded['body']}');
      if (streamedResponse.statusCode >= 200 &&
          streamedResponse.statusCode < 300) {
        return ApiResponse.success(decoded, streamedResponse.statusCode);
      } else {
        final message = decoded['message'] ?? 'Failed to put multipart data';
        return ApiResponse.error(message, streamedResponse.statusCode);
      }
    } catch (e, stackTrace) {
      _safeLog('API PUT MULTIPART Error', '$e');
      await CrashlyticsService.logError(e, stackTrace);
      return ApiResponse.error(_formatErrorMessage(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> postMultipart(
    String endpoint,
    Map<String, String> body, {
    List<http.MultipartFile>? files,
    bool requireAuth = true,
  }) async {
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      headers.remove('Content-Type');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$endpoint'),
      );
      request.headers.addAll(headers);
      request.fields.addAll(body);

      if (files != null) {
        request.files.addAll(files);
      }

      _safeLog('API POST MULTIPART', '$baseUrl$endpoint');
      _safeLog('API POST MULTIPART fields', '${request.fields}');
      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      final decoded = json.decode(responseBody);

      _safeLog('API POST MULTIPART data ', '$decoded');
      _safeLog('API POST MULTIPART message', '${decoded['message']}');
      if (streamedResponse.statusCode >= 200 &&
          streamedResponse.statusCode < 300) {
        return ApiResponse.success(decoded, streamedResponse.statusCode);
      } else {
        final message = decoded['message'] ?? 'Failed to post multipart data';
        return ApiResponse.error(message, streamedResponse.statusCode);
      }
    } catch (e, stackTrace) {
      await CrashlyticsService.logError(e, stackTrace);
      _safeLog('API POST MULTIPART EXCEPTION', '$e');
      return ApiResponse.error(_formatErrorMessage(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> delete(
    String endpoint, {
    bool requireAuth = true,
  }) async {
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final response = await _client.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );
      _safeLog('API DELETE', '$baseUrl$endpoint');
      final decoded = json.decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.success(decoded, response.statusCode);
      } else {
        final message = decoded['message'] ?? 'Failed to delete data';
        return ApiResponse.error(message, response.statusCode);
      }
    } catch (e, stackTrace) {
      await CrashlyticsService.logError(e, stackTrace);
      await CrashlyticsService.setCustomKey('api_endpoint', endpoint);
      await CrashlyticsService.setCustomKey('api_method', 'DELETE');
      _safeLog('API DELETE EXCEPTION', '$e');
      return ApiResponse.error(_formatErrorMessage(e));
    }
  }

  void dispose() {
    _client.close();
  }
}

final publicApiProvider = Provider<ApiProvider>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  const baseUrl = String.fromEnvironment('BASE_URL', defaultValue: '');

  return ApiProvider(baseUrl: baseUrl, secureStorage: secureStorage);
});

final apiProvider = Provider<ApiProvider>((ref) {
  final userType = ref.watch(userTypeProvider);
  final publicApi = ref.watch(publicApiProvider);

  String baseUrl = publicApi.baseUrl;

  if (userType == UserType.partner) {
    if (baseUrl.contains('/mobile')) {
      baseUrl = baseUrl.replaceFirst('/mobile', '/mobile/partner');
    } else {
      baseUrl = '$baseUrl/partner';
    }
  }

  return ApiProvider(baseUrl: baseUrl, secureStorage: publicApi.secureStorage);
});
