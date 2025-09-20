import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/auth_models.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/data/services/auth_service.dart';
import 'package:spotnsend/data/services/user_service.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final userService = ref.watch(userServiceProvider);
  return AuthController(ref: ref, authService: authService, userService: userService);
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
  AuthController({required this.ref, required this.authService, required this.userService}) : super(const AuthState());

  final Ref ref;
  final AuthService authService;
  final UserService userService;

  Future<void> login({required String username, required String password}) async {
    state = state.copyWith(isLoading: true, resetError: true);
    final keepSignedIn = state.keepSignedIn;

    final result = await authService.login(username: username, password: password, keepSignedIn: keepSignedIn);

    state = result.when(
      success: (user) {
        userService.setCurrentUser(user);
        return state.copyWith(user: user, isLoading: false);
      },
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
    final result = await authService.signupStep1(data);
    state = result.when(
      success: (_) => state.copyWith(isLoading: false),
      failure: (message) => state.copyWith(isLoading: false, error: message),
    );
  }

  Future<void> signupStep2(SignupStep2Data data) async {
    state = state.copyWith(isLoading: true, resetError: true);
    final result = await authService.signupStep2(data);
    state = result.when(
      success: (_) => state.copyWith(isLoading: false),
      failure: (message) => state.copyWith(isLoading: false, error: message),
    );
  }

  Future<void> signupStep3(SignupStep3Data data) async {
    state = state.copyWith(isLoading: true, resetError: true);
    final result = await authService.signupStep3(data);
    state = result.when(
      success: (user) {
        userService.setCurrentUser(user);
        return state.copyWith(user: user, isLoading: false);
      },
      failure: (message) => state.copyWith(isLoading: false, error: message),
    );
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, resetError: true);
    final result = await authService.logout();
    state = result.when(
      success: (_) {
        userService.setCurrentUser(const AppUser(
          id: 'user-guest',
          name: 'Guest User',
          username: 'guest',
          email: 'guest@spotnsend.com',
          phone: '+966500000000',
          idNumber: '1234567890',
          selfieUrl: '',
          status: VerificationStatus.pending,
          reportsSubmitted: 0,
          feedbackGiven: 0,
          savedSpots: [],
        ));
        return const AuthState();
      },
      failure: (message) => state.copyWith(isLoading: false, error: message),
    );
  }
}









