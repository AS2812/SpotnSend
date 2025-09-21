import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/data/models/auth_models.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/data/repositories/auth_repository.dart';
import 'package:spotnsend/data/services/user_service.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(() {
  return AuthController();
});

class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.keepSignedIn = false,
  });

  final AppUser? user;
  final bool isLoading;
  final String? error;
  final bool keepSignedIn;

  bool get isAuthenticated => user != null;
  bool get isPendingVerification => user?.status == VerificationStatus.pending;

  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    String? error,
    bool? resetError = false,
    bool? keepSignedIn,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: resetError == true ? null : error ?? this.error,
      keepSignedIn: keepSignedIn ?? this.keepSignedIn,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  late AuthRepository authRepository;
  late UserService userService;

  @override
  AuthState build() {
    authRepository = ref.watch(authRepositoryProvider);
    userService = ref.watch(userServiceProvider);
    return const AuthState();
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, resetError: true);
    final result = await authRepository.login(
      identifier: identifier,
      password: password,
      keepSignedIn: state.keepSignedIn,
    );
    state = result.when(
      success: (user) => state.copyWith(user: user, isLoading: false),
      failure: (message) => state.copyWith(isLoading: false, error: message),
    );
  }

  Future<void> loginTester() async {
    state = state.copyWith(isLoading: true, resetError: true);
    final result = await authRepository.loginTester();
    state = result.when(
      success: (user) => state.copyWith(user: user, isLoading: false),
      failure: (message) => state.copyWith(isLoading: false, error: message),
    );
  }

  void updateUser(AppUser user) {
    state = state.copyWith(user: user, resetError: true);
  }

  void setKeepSignedIn(bool value) {
    state = state.copyWith(keepSignedIn: value);
  }

  Future<void> signupStep1(SignupStep1Data data) async {
    state = state.copyWith(isLoading: true, resetError: true);
    final result = await authRepository.signupStep1(data);
    state = result.when(
      success: (_) => state.copyWith(isLoading: false),
      failure: (message) => state.copyWith(isLoading: false, error: message),
    );
  }

  Future<void> signupStep2(SignupStep2Data data) async {
    state = state.copyWith(isLoading: true, resetError: true);
    final result = await authRepository.signupStep2(data);
    state = result.when(
      success: (_) => state.copyWith(isLoading: false),
      failure: (message) => state.copyWith(isLoading: false, error: message),
    );
  }

  Future<void> signupStep3(SignupStep3Data data) async {
    state = state.copyWith(isLoading: true, resetError: true);
    final result = await authRepository.signupStep3(data);
    state = result.when(
      success: (user) => state.copyWith(user: user, isLoading: false),
      failure: (message) => state.copyWith(isLoading: false, error: message),
    );
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, resetError: true);
    final result = await authRepository.logout();
    state = result.when(
      success: (_) => const AuthState(),
      failure: (message) => state.copyWith(isLoading: false, error: message),
    );
  }
}
