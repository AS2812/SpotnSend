import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spotnsend/data/models/auth_models.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/data/repositories/auth_repository.dart';
import 'package:spotnsend/data/services/user_service.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final userService = ref.watch(userServiceProvider);
  return AuthController(ref: ref, authRepository: authRepository, userService: userService);
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
  bool get isVerified => user?.isVerified ?? false;
  bool get isPendingVerification => user != null && !isVerified;

  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    String? error,
    bool? keepSignedIn,
    bool resetError = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: resetError ? null : (error ?? this.error),
      keepSignedIn: keepSignedIn ?? this.keepSignedIn,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController({required this.ref, required this.authRepository, required this.userService}) : super(const AuthState());

  final Ref ref;
  final AuthRepository authRepository;
  final UserService userService;

  Future<void> login({required String identifier, required String password}) async {
    state = state.copyWith(isLoading: true, resetError: true);
    final result = await authRepository.login(
      identifier: identifier,
      password: password,
      keepSignedIn: state.keepSignedIn,
    );

    state = result.when(
      success: (user) {
        userService.cacheUser(user);
        return state.copyWith(user: user, isLoading: false);
      },
      failure: (message) => state.copyWith(isLoading: false, error: message),
    );
  }

  Future<void> loginTester() async {
    state = state.copyWith(isLoading: true, resetError: true);
    final result = await authRepository.loginTester();
    state = result.when(
      success: (user) {
        userService.cacheUser(user);
        return state.copyWith(user: user, isLoading: false);
      },
      failure: (message) => state.copyWith(isLoading: false, error: message),
    );
  }

  void updateUser(AppUser user) {
    userService.cacheUser(user);
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
      success: (user) {
        userService.cacheUser(user);
        return state.copyWith(user: user, isLoading: false);
      },
      failure: (message) => state.copyWith(isLoading: false, error: message),
    );
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, resetError: true);
    final result = await authRepository.logout();
    state = result.when(
      success: (_) {
        userService.clearCache();
        return const AuthState();
      },
      failure: (message) => state.copyWith(isLoading: false, error: message),
    );
  }
}



