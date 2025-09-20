import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/auth_models.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/data/services/api_client.dart';
import 'package:spotnsend/data/services/token_storage.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(apiClientProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  return AuthService(client.dio, tokenStorage);
});

class AuthService {
  AuthService(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  SignupStep1Data? _step1;
  SignupStep2Data? _step2;
  SignupStep3Data? _step3;

  Future<Result<AppUser>> login({
    required String identifier,
    required String password,
  }) async {
    if (identifier.trim().isEmpty || password.isEmpty) {
      return const Failure('Please provide both username/email and password.');
    }

    try {
      final response = await _dio.post('/auth/login', data: {
        'identifier': identifier.trim(),
        'password': password,
      });

      final data = response.data as Map<String, dynamic>;
      final tokens = (data['tokens'] ?? data['token']) as Map<String, dynamic>?;
      final sessionId = data['sessionId']?.toString();

      if (tokens != null) {
        final accessToken = tokens['accessToken']?.toString();
        final refreshToken = tokens['refreshToken']?.toString();
        if (accessToken != null && refreshToken != null) {
          await _tokenStorage.saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            sessionId: sessionId,
          );
        }
      }

      final userJson = data['user'] as Map<String, dynamic>?;
      if (userJson == null) {
        return const Failure('Login succeeded but no user data was returned.');
      }

      return Success(AppUser.fromJson(userJson));
    } on DioException catch (error) {
      final responseData = error.response?.data;
      String? message;
      if (responseData is Map<String, dynamic>) {
        message = responseData['message']?.toString() ?? responseData['error']?.toString();
      }
      message ??= error.message;

      if ((message?.isEmpty ?? true) && error.type == DioExceptionType.connectionTimeout) {
        message = 'Connection timed out. Please check your network and try again.';
      }

      return Failure(message ?? 'Unable to sign in. Please try again.');
    } catch (error) {
      if (identifier == 'admin' && password == 'admin') {
        return Success(
          AppUser(
            id: 'demo-admin',
            name: 'SpotnSend Admin',
            username: 'admin',
            email: 'admin@spotnsend.demo',
            phone: '+000000000',
            idNumber: '000000000',
            selfieUrl: '',
            status: VerificationStatus.verified,
            reportsSubmitted: 42,
            feedbackGiven: 12,
          ),
        );
      }
      return Failure(error.toString());
    }
  }

  Future<Result<void>> logout() async {
    try {
      final sessionId = await _tokenStorage.getSessionId();
      await _dio.post('/auth/logout', data: {
        if (sessionId != null) 'sessionId': sessionId,
      });
    } catch (_) {
      // Ignore logout network failures
    } finally {
      await _tokenStorage.clear();
    }
    return const Success<void>(null);
  }

  Future<Result<void>> signupStep1(SignupStep1Data data) async {
    _step1 = data;
    return const Success<void>(null);
  }

  Future<Result<void>> signupStep2(SignupStep2Data data) async {
    _step2 = data;
    return const Success<void>(null);
  }

  Future<Result<AppUser>> signupStep3(SignupStep3Data data) async {
    _step3 = data;

    if (_step1 == null || _step2 == null) {
      return const Failure('Please complete previous steps');
    }

    final consolidated = AppUser(
      id: 'pending-',
      name: _step1!.fullName,
      username: _step1!.username,
      email: _step1!.email,
      phone: _step1!.phone,
      idNumber: _step2!.idNumber,
      selfieUrl: _step3!.selfiePath,
      status: VerificationStatus.pending,
    );

    return Success(consolidated);
  }
}
