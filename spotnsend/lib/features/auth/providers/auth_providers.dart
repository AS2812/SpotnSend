import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:spotnsend/data/models/auth_models.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/data/services/supabase_user_service.dart';
import 'package:spotnsend/features/home/account/providers/account_providers.dart';
import 'package:spotnsend/main.dart';

const _authSentinel = Object();
const _keepSignedInKey = 'auth_keep_signed_in';

// Auth state model
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;
  final bool keepSignedIn;
  final bool isPendingVerification;
  final sb.User? user;
  final String? draftNationalId;
  final String? draftGender;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
    this.keepSignedIn = true,
    this.isPendingVerification = false,
    this.user,
    this.draftNationalId,
    this.draftGender,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
    bool? keepSignedIn,
    bool? isPendingVerification,
    sb.User? user,
    Object? draftNationalId = _authSentinel,
    Object? draftGender = _authSentinel,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      keepSignedIn: keepSignedIn ?? this.keepSignedIn,
      isPendingVerification:
          isPendingVerification ?? this.isPendingVerification,
      user: user ?? this.user,
      draftNationalId: identical(draftNationalId, _authSentinel)
          ? this.draftNationalId
          : draftNationalId as String?,
      draftGender: identical(draftGender, _authSentinel)
          ? this.draftGender
          : draftGender as String?,
    );
  }
}

// Use a NotifierProvider instead of StateNotifierProvider to avoid import issues
class AuthNotifier extends Notifier<AuthState> {
  bool _signingIn = false;
  bool _initialized = false;
  bool _accountListenerAttached = false;
  SignupStep1Data? _step1Data;
  SignupStep2Data? _step2Data;

  @override
  AuthState build() {
    if (!_accountListenerAttached) {
      _accountListenerAttached = true;
      ref.listen<AsyncValue<AppUser?>>(accountUserProvider,
          (previous, next) {
        next.whenData((user) {
          final pending = user == null ? false : !user.isVerified;
          if (state.isPendingVerification != pending) {
            state = state.copyWith(isPendingVerification: pending);
          }
        });
      });
    }
    _initialize();
    return const AuthState();
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final keepSignedIn = prefs.getBool(_keepSignedInKey) ?? true;
    state = state.copyWith(keepSignedIn: keepSignedIn);

    unawaited(_checkCurrentSession());
  }

  Future<void> _checkCurrentSession() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
  final session = supabase.auth.currentSession;
  final user = supabase.auth.currentUser;

      if (!state.keepSignedIn && session != null) {
        await supabase.auth.signOut();
        state = state.copyWith(
          isAuthenticated: false,
          isLoading: false,
          user: null,
          isPendingVerification: false,
        );
        return;
      }

      state = state.copyWith(
        isAuthenticated: session != null,
        isLoading: false,
        user: user,
        isPendingVerification: session == null
            ? false
            : state.isPendingVerification,
      );
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        error: 'Failed to check authentication status',
        isPendingVerification: false,
      );
    }
  }

  Future<void> setKeepSignedIn(bool value) async {
    state = state.copyWith(keepSignedIn: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepSignedInKey, value);

    if (!value && state.isAuthenticated) {
      await logout();
    }
  }

  Future<bool> signIn(String email, String password) async {
    if (_signingIn) {
      debugPrint('AuthController: signIn suppressed (already in progress)');
      return false;
    }
    _signingIn = true;
    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('AuthController: Attempting sign in with email: $email');

      // Single sign-in request
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final session = response.session;
      final user = response.user;

      if (session == null || user == null) {
        throw sb.AuthException('No session or user returned');
      }

      // Try to ensure user row after successful login
      try {
        await supabase.rpc('ensure_user_row');
      } catch (rpcError) {
        debugPrint('Error in ensure_user_row RPC: $rpcError');
      }

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        error: null,
        user: user,
      );

      return true;
    } on sb.AuthException catch (e) {
      debugPrint('AuthController: Auth exception: ${e.message}');
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        error: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('AuthController: Unexpected error: $e');
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        error: 'An unexpected error occurred',
      );
      return false;
    } finally {
      _signingIn = false;
    }
  }

  // Add signupStep1 method
  Future<bool> signupStep1(SignupStep1Data data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      _step1Data = data;
      state = state.copyWith(
        isLoading: false,
        error: null,
        draftNationalId: data.nationalId ?? state.draftNationalId,
        draftGender: data.gender ?? state.draftGender,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> signupStep2(SignupStep2Data data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      _step2Data = data;
      state = state.copyWith(
        isLoading: false,
        error: null,
        draftNationalId: data.idNumber ?? state.draftNationalId,
        draftGender: data.gender ?? state.draftGender,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> signupStep3(SignupStep3Data data) async {
    state = state.copyWith(isLoading: true, error: null);
    final step1 = _step1Data;
    final step2 = _step2Data;

    if (step1 == null || step2 == null) {
      state = state.copyWith(
        isLoading: false,
        error: 'Incomplete sign up information. Please restart the process.',
      );
      return false;
    }

    try {
      if (supabase.auth.currentSession != null) {
        await supabase.auth.signOut();
      }

      final metadata = <String, dynamic>{
        'full_name': step1.fullName,
        'username': step1.username,
        'phone_country_code': step1.phoneCountryCode,
        'phone_number': step1.phoneNumber,
        if (step1.nationalId?.isNotEmpty ?? false)
          'id_number': step1.nationalId,
        if (step1.gender?.isNotEmpty ?? false) 'gender': step1.gender,
        if (step2.idNumber?.isNotEmpty ?? false)
          'id_number_step2': step2.idNumber,
        if (step2.gender?.isNotEmpty ?? false) 'gender_step2': step2.gender,
      };

      final signUpResponse = await supabase.auth.signUp(
        email: step1.email,
        password: step1.password,
        data: metadata,
      );

      sb.User? user = signUpResponse.user;
      sb.Session? session = signUpResponse.session;

      if (session == null || user == null) {
        final signInResponse = await supabase.auth.signInWithPassword(
          email: step1.email,
          password: step1.password,
        );
        user = signInResponse.user ?? user;
        session = signInResponse.session ?? session;
      }

  if (user == null || session == null) {
    throw sb.AuthException(
    'Account created but email confirmation is required before login.');
  }

      try {
        final userService = ref.read(supabaseUserServiceProvider);
        final upsertResult = await userService.upsertCurrentUser(
          username: step1.username,
          fullName: step1.fullName,
          email: step1.email,
        );
        upsertResult.when(
          success: (_) {},
          failure: (message) {
            if (kDebugMode) {
              debugPrint('Upsert current user failed: $message');
            }
          },
        );

        final phoneResult = await userService.updatePhone(
          countryCode: step1.phoneCountryCode,
          phone: step1.phoneNumber,
        );
        phoneResult.when(
          success: (_) {},
          failure: (message) {
            if (kDebugMode) {
              debugPrint('Update phone failed: $message');
            }
          },
        );
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('Auth sign up profile bootstrap failed: $e');
          debugPrintStack(stackTrace: st);
        }
      }

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        error: null,
        user: user,
        isPendingVerification: true,
        draftNationalId:
            step2.idNumber ?? step1.nationalId ?? state.draftNationalId,
        draftGender: step2.gender ?? step1.gender ?? state.draftGender,
      );

      _clearSignupDrafts();
      ref.invalidate(accountUserProvider);
      return true;
    } on sb.AuthException catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        error: e.message,
      );
      return false;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Auth signup unexpected error: $e');
        debugPrintStack(stackTrace: st);
      }
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        error: 'Failed to complete sign up. Please try again.',
      );
      return false;
    }
  }

  // Add updateUser method
  Future<void> updateUser(dynamic user) async {
    // Implementation would go here
  }

  void _clearSignupDrafts() {
    _step1Data = null;
    _step2Data = null;
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await supabase.auth.signOut();
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        user: null,
        draftNationalId: null,
        draftGender: null,
        isPendingVerification: false,
      );
      _clearSignupDrafts();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to sign out',
      );
    }
  }
}

// Auth provider using NotifierProvider
final authControllerProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
