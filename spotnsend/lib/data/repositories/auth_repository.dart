import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/auth_models.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/data/services/api_client.dart';
import 'package:spotnsend/data/services/token_storage.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  return AuthRepository(apiClient, tokenStorage);
});

class AuthRepository {
  AuthRepository(this._apiClient, this._tokenStorage);

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Dio get _dio => _apiClient.dio;

  Future<Result<AppUser>> login({
    required String identifier,
    required String password,
    bool keepSignedIn = false,
  }) async {
    final trimmedIdentifier = identifier.trim();
    if (trimmedIdentifier.isEmpty || password.isEmpty) {
      return const Failure('Please provide both username/email and password.');
    }

    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'identifier': trimmedIdentifier,
          'password': password,
          if (keepSignedIn) 'keepSignedIn': true,
        },
        options: Options(extra: const {'skipAuth': true}),
      );

      final data = response.data as Map<String, dynamic>;
      final tokens = (data['tokens'] ?? data['token']) as Map<String, dynamic>?;
      final accessToken = tokens?['accessToken']?.toString();
      final refreshToken = tokens?['refreshToken']?.toString();
      final sessionId = (data['sessionId'] ?? tokens?['sessionId'])?.toString();

      if (accessToken != null && refreshToken != null) {
        await _tokenStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          sessionId: sessionId,
        );
      }

      final userJson = (data['user'] ?? data['profile'] ?? data) as Map<String, dynamic>?;
      if (userJson == null) {
        return const Failure('Login succeeded but no user data was returned.');
      }

      return Success(AppUser.fromJson(userJson));
    } on DioException catch (error) {
      if (_canUseDemoCredentials(trimmedIdentifier, password)) {
        return Success(await _issueDemoSession());
      }
      return Failure(_extractMessage(error));
    } catch (error) {
      if (_canUseDemoCredentials(trimmedIdentifier, password)) {
        return Success(await _issueDemoSession());
      }
      return Failure(error.toString());
    }
  }

  Future<Result<AppUser>> loginTester() async {
    if (!kDebugMode) {
      return const Failure('Tester account is available in debug builds only.');
    }
    final user = await _issueDemoSession();
    return Success(user);
  }

  Future<Result<void>> logout() async {
    try {
      final sessionId = await _tokenStorage.getSessionId();
      await _dio.post(
        '/auth/logout',
        data: {
          if (sessionId != null) 'sessionId': sessionId,
        },
      );
    } catch (_) {
      // best effort logout
    } finally {
      await _tokenStorage.clear();
    }
    return const Success<void>(null);
  }

  Future<Result<void>> signupStep1(SignupStep1Data data) async {
    _signupDraft['step1'] = data;
    return const Success<void>(null);
  }

  Future<Result<void>> signupStep2(SignupStep2Data data) async {
    _signupDraft['step2'] = data;
    return const Success<void>(null);
  }

  Future<Result<AppUser>> signupStep3(SignupStep3Data data) async {
    _signupDraft['step3'] = data;

    final step1 = _signupDraft['step1'] as SignupStep1Data?;
    final step2 = _signupDraft['step2'] as SignupStep2Data?;
    if (step1 == null || step2 == null) {
      return const Failure('Please complete previous steps');
    }

    final consolidated = AppUser(
      id: 'pending-${DateTime.now().millisecondsSinceEpoch}',
      name: step1.fullName,
      username: step1.username,
      email: step1.email,
      phone: step1.phone,
      idNumber: step2.idNumber,
      selfieUrl: data.selfiePath,
      status: VerificationStatus.pending,
    );

    return Success(consolidated);
  }

  final Map<String, dynamic> _signupDraft = {};

  bool _canUseDemoCredentials(String identifier, String password) {
    if (!kDebugMode) {
      return false;
    }
    final normalized = identifier.toLowerCase();
    return normalized == 'admin' && (password == 'admin' || password == 'admin12345');
  }

  Future<AppUser> _issueDemoSession() async {
    await _tokenStorage.saveTokens(
      accessToken: 'demo-access-token',
      refreshToken: 'demo-refresh-token',
      sessionId: 'demo-session',
    );
    return const AppUser(
      id: 'demo-admin',
      name: 'SpotnSend Admin',
      username: 'admin',
      email: 'admin@spotnsend.demo',
      phone: '+000000000',
      idNumber: '0000000000',
      selfieUrl: '',
      status: VerificationStatus.verified,
      reportsSubmitted: 42,
      feedbackGiven: 12,
    );
  }

  String _extractMessage(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      return responseData['message']?.toString() ?? responseData['error']?.toString() ?? 'Unable to sign in. Please try again.';
    }
    if (error.type == DioExceptionType.connectionTimeout || error.type == DioExceptionType.connectionError) {
      return 'Connection failed. Check your network and try again.';
    }
    return error.message ?? 'Unable to sign in. Please try again.';
  }
}




