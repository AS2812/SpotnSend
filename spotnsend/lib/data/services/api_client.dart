import 'dart:async';

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
            sendTimeout: const Duration(seconds: 20),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          final skipAuth = options.extra['skipAuth'] == true;
          if (_refreshCompleter != null) {
            try {
              final refreshed = await _refreshCompleter!.future;
              if (!refreshed) {
                return handler.next(options);
              }
            } catch (_) {}
          }
          if (!skipAuth) {
            final token = await _tokenStorage.getAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final response = error.response;
          final request = error.requestOptions;
          final skipAuth = request.extra['skipAuth'] == true;
          final alreadyRetried = request.extra['retried'] == true;

          if (response?.statusCode == 401 && !skipAuth && !alreadyRetried) {
            try {
              final refreshed = await _refreshTokens();
              if (refreshed) {
                final newToken = await _tokenStorage.getAccessToken();
                if (newToken != null && newToken.isNotEmpty) {
                  final retryResponse = await _retry(request, newToken);
                  return handler.resolve(retryResponse);
                }
              }
            } catch (_) {
              // ignore and fall through to propagate original error
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  final TokenStorage _tokenStorage;
  final Dio dio;
  Completer<bool>? _refreshCompleter;

  Future<Response<dynamic>> _retry(RequestOptions requestOptions, String token) {
    final options = Options(
      method: requestOptions.method,
      headers: Map<String, dynamic>.from(requestOptions.headers)
        ..update('Authorization', (_) => 'Bearer $token', ifAbsent: () => 'Bearer $token'),
      responseType: requestOptions.responseType,
      contentType: requestOptions.contentType,
      followRedirects: requestOptions.followRedirects,
      validateStatus: requestOptions.validateStatus,
      receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
      sendTimeout: requestOptions.sendTimeout,
      receiveTimeout: requestOptions.receiveTimeout,
      extra: Map<String, dynamic>.from(requestOptions.extra)..['retried'] = true,
    );

    return dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
      cancelToken: requestOptions.cancelToken,
      onReceiveProgress: requestOptions.onReceiveProgress,
      onSendProgress: requestOptions.onSendProgress,
    );
  }

  Future<bool> _refreshTokens() {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    () async {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await _tokenStorage.clear();
        completer.complete(false);
        return;
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
        final response = await refreshClient.post(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
          options: Options(extra: const {'skipAuth': true}),
        );
        final data = response.data as Map<String, dynamic>;
        final tokens = (data['tokens'] ?? data) as Map<String, dynamic>?;
        final accessToken = tokens?['accessToken']?.toString();
        final newRefreshToken = tokens?['refreshToken']?.toString();
        if (accessToken == null || newRefreshToken == null) {
          await _tokenStorage.clear();
          completer.complete(false);
          return;
        }
        await _tokenStorage.saveTokens(accessToken: accessToken, refreshToken: newRefreshToken, sessionId: (data['sessionId'] ?? tokens?['sessionId'])?.toString());
        completer.complete(true);
      } on DioException {
        await _tokenStorage.clear();
        completer.complete(false);
      } catch (_) {
        await _tokenStorage.clear();
        completer.complete(false);
      }
    }();

    return completer.future.whenComplete(() {
      _refreshCompleter = null;
    });
  }
}

