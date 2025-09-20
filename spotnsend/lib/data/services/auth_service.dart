import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/auth_models.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/data/services/api_client.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthService(client.dio);
});

class AuthService {
  AuthService(this._dio);

  final Dio _dio;

  SignupStep1Data? _step1;
  SignupStep2Data? _step2;
  SignupStep3Data? _step3;

  Future<Result<AppUser>> login({
    required String username,
    required String password,
    required bool keepSignedIn,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 1));

    if (username.isEmpty || password.isEmpty) {
      return const Failure('Please fill in all fields');
    }

    final isVerifiedUser = username.toLowerCase().contains('verified');

    final user = AppUser(
      id: 'user-001',
      name: isVerifiedUser ? 'Aisha Verified' : 'Omar Pending',
      username: username,
      email: isVerifiedUser ? 'aisha@spotnsend.com' : 'omar@spotnsend.com',
      phone: '+966500000000',
      idNumber: '1234567890',
      selfieUrl: '',
      status: isVerifiedUser ? VerificationStatus.verified : VerificationStatus.pending,
      reportsSubmitted: isVerifiedUser ? 12 : 0,
      feedbackGiven: isVerifiedUser ? 4 : 0,
      savedSpots: const [],
    );

    return Success(user);
  }

  Future<Result<void>> signupStep1(SignupStep1Data data) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (data.otp != '123456') {
      return const Failure('Invalid verification code. Try 123456');
    }
    _step1 = data;
    return const Success<void>(null);
  }

  Future<Result<void>> signupStep2(SignupStep2Data data) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (data.idNumber.length < 8) {
      return const Failure('Enter a valid national ID');
    }
    _step2 = data;
    return const Success<void>(null);
  }

  Future<Result<AppUser>> signupStep3(SignupStep3Data data) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
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
      reportsSubmitted: 0,
      feedbackGiven: 0,
      savedSpots: const [],
    );

    return Success(consolidated);
  }

  Future<Result<void>> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return const Success<void>(null);
  }
}


