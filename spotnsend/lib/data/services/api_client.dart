import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/core/config/app_config.dart';
import 'package:spotnsend/data/services/token_storage.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return ApiClient(tokenStorage);
});

class ApiClient {
  ApiClient(this._tokenStorage)
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode;
          final requestPath = error.requestOptions.path;
          final alreadyRetried = error.requestOptions.extra['retried'] == true;
          if (statusCode == 401 && !alreadyRetried && !_authExemptPaths.contains(requestPath)) {
            final refreshed = await _refreshTokens();
            if (refreshed) {
              final newToken = await _tokenStorage.getAccessToken();
              if (newToken != null) {
                final requestOptions = error.requestOptions;
                requestOptions.extra['retried'] = true;
                requestOptions.headers['Authorization'] = 'Bearer $newToken';
                try {
                  final response = await dio.fetch(requestOptions);
                  return handler.resolve(response);
                } catch (retryError) {
                  return handler.reject(retryError as DioException);
                }
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final TokenStorage _tokenStorage;
  final Dio dio;

  static const _authExemptPaths = {
    '/auth/login',
    '/auth/refresh',
    '/auth/signup/step1',
    '/auth/signup/step2',
    '/auth/signup/step3',
  };

  Future<bool> _refreshTokens() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _tokenStorage.clear();
      return false;
    }

    final refreshClient = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    try {
      final response = await refreshClient.post('/auth/refresh', data: {
        'refreshToken': refreshToken,
      });
      final data = response.data as Map<String, dynamic>;
      final tokens = data['tokens'] as Map<String, dynamic>;
      final accessToken = tokens['accessToken'] as String?;
      final newRefreshToken = tokens['refreshToken'] as String?;
      if (accessToken == null || newRefreshToken == null) {
        await _tokenStorage.clear();
        return false;
      }
      await _tokenStorage.saveTokens(accessToken: accessToken, refreshToken: newRefreshToken);
      return true;
    } on DioException {
      await _tokenStorage.clear();
      return false;
    }
  }
}
