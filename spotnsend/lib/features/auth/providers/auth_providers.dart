import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:spotnsend/main.dart';

const _authSentinel = Object();

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
  @override
  AuthState build() {
    _checkCurrentSession();
    return const AuthState();
  }

  Future<void> _checkCurrentSession() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final session = await supabase.auth.currentSession;
      final user = await supabase.auth.currentUser;
      state = state.copyWith(
        isAuthenticated: session != null,
        isLoading: false,
        user: user,
      );
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        error: 'Failed to check authentication status',
      );
    }
  }

  void setKeepSignedIn(bool value) {
    state = state.copyWith(keepSignedIn: value);
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
  Future<bool> signupStep1(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Implementation would go here
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // Add signupStep2 method
  Future<bool> signupStep2(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final idNumber = data['idNumber']?.toString().trim();
      final genderRaw = data['gender']?.toString().toLowerCase().trim();
      final gender =
          (genderRaw == 'male' || genderRaw == 'female') ? genderRaw : null;

      state = state.copyWith(
        isLoading: false,
        error: null,
        draftNationalId:
            (idNumber != null && idNumber.isEmpty) ? null : idNumber,
        draftGender: gender,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // Add signupStep3 method
  Future<bool> signupStep3(dynamic data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Implementation would go here
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // Add updateUser method
  Future<void> updateUser(dynamic user) async {
    // Implementation would go here
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
      );
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
