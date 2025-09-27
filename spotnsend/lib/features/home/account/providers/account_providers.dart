import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:spotnsend/main.dart';
import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/data/services/supabase_user_service.dart';

/// Waits until Supabase has a session (or times out).
final signedInSessionProvider = StreamProvider<sb.Session?>((ref) async* {
  yield supabase.auth.currentSession;

  await for (final authState in supabase.auth.onAuthStateChange) {
    switch (authState.event) {
      case sb.AuthChangeEvent.signedOut:
        yield null;
        break;
      default:
        yield authState.session ?? supabase.auth.currentSession;
    }
  }
});

/// Loads the profile. If missing, auto-creates then re-fetches.
final accountUserProvider = FutureProvider<AppUser?>((ref) async {
  final sessionAsync = ref.watch(signedInSessionProvider);
  final svc = ref.read(supabaseUserServiceProvider);

  Future<AppUser?> loadForSession(sb.Session? session) async {
    final authUser = supabase.auth.currentUser ?? session?.user;

    if (session == null && authUser == null) {
      svc.clearCache();
      return null;
    }

    try {
      return await svc.fetchProfile(forceRefresh: true);
    } catch (_) {
      final fallbackUser = authUser ?? supabase.auth.currentUser;
      if (fallbackUser == null) {
        rethrow;
      }

      try {
        await supabase.rpc('ensure_profile', params: {
          'p_full_name': (fallbackUser.userMetadata?['full_name'] as String?) ??
              fallbackUser.email ??
              '',
          'p_email': fallbackUser.email ?? '',
        });
      } catch (err, st) {
        if (kDebugMode) {
          debugPrint('ensure_profile failed: $err');
          debugPrintStack(stackTrace: st);
        }
      }

      try {
        return await svc.fetchProfile(forceRefresh: true);
      } catch (err, st) {
        if (kDebugMode) {
          debugPrint('accountUserProvider fallback: $err');
          debugPrintStack(stackTrace: st);
        }
      }

      return svc.fallbackFromAuthUser(fallbackUser);
    }
  }

  return await sessionAsync.when(
    data: (session) => loadForSession(session),
    loading: () async {
      final current = supabase.auth.currentSession;
      if (current != null) {
        return loadForSession(current);
      }
      final nextSession = await ref.watch(signedInSessionProvider.future);
      return loadForSession(nextSession);
    },
    error: (error, stack) async {
      if (kDebugMode) {
        debugPrint('signedInSessionProvider error: $error');
        debugPrintStack(stackTrace: stack);
      }
      final authUser = supabase.auth.currentUser;
      if (authUser == null) {
        svc.clearCache();
        return null;
      }
      return svc.fallbackFromAuthUser(authUser);
    },
  );
});

/// Derived verification helpers so other features can react to account status.
final accountVerificationStatusProvider = Provider<VerificationStatus>((ref) {
  final userAsync = ref.watch(accountUserProvider);
  return userAsync.when(
    data: (user) => user?.status ?? VerificationStatus.pending,
    loading: () => VerificationStatus.pending,
    error: (_, __) => VerificationStatus.pending,
  );
});

final isAccountVerifiedProvider = Provider<bool>((ref) {
  final status = ref.watch(accountVerificationStatusProvider);
  return status == VerificationStatus.verified;
});

/// Saved spots list (RLS + DEFAULT user_id = safe).
final accountSavedSpotsProvider = FutureProvider<List<SavedSpot>>((ref) async {
  final sessionAsync = ref.watch(signedInSessionProvider);
  final svc = ref.read(supabaseUserServiceProvider);

  return await sessionAsync.when(
    data: (session) {
      if (session == null) {
        svc.clearCache();
        return Future.value(const <SavedSpot>[]);
      }
      return svc.listSavedSpots();
    },
    loading: () async => const <SavedSpot>[],
    error: (_, __) async => const <SavedSpot>[],
  );
});

/// Controller used by the Account screen.
final accountControllerProvider = Provider<AccountController>((ref) {
  final svc = ref.read(supabaseUserServiceProvider);
  return AccountController(ref, svc);
});

class AccountController {
  AccountController(this._ref, this._svc);
  final Ref _ref;
  final SupabaseUserService _svc;

  Future<Result<void>> updateEmail(String email) async {
    final r = await _svc.updateEmail(email);
    return r.when(
      success: (_) {
        _ref.invalidate(accountUserProvider);
        return const Success(null);
      },
      failure: (error) => Failure(error),
    );
  }

  Future<Result<void>> updatePhone(String value) async {
    final parts = value.trim().split(RegExp(r'\s+'));
    final country = parts.length > 1 ? parts.first : '';
    final number = parts.length > 1 ? parts.sublist(1).join(' ') : parts.first;

    final r = await _svc.updatePhone(countryCode: country, phone: number);
    return r.when(
      success: (_) {
        _ref.invalidate(accountUserProvider);
        return const Success(null);
      },
      failure: (error) => Failure(error),
    );
  }

  Future<Result<void>> addSavedSpot(
    String name,
    double lat,
    double lng,
    double radiusKm,
  ) async {
    final r = await _svc.addSavedSpot(
      name: name,
      lat: lat,
      lng: lng,
      radiusMeters: radiusKm * 1000,
    );
    return r.when(
      success: (_) {
        _ref.invalidate(accountSavedSpotsProvider);
        _ref.invalidate(accountUserProvider); // refresh stats too
        return const Success(null);
      },
      failure: (error) => Failure(error),
    );
  }

  Future<Result<void>> removeSavedSpot(String id) async {
    final r = await _svc.removeSavedSpot(id);
    return r.when(
      success: (_) {
        _ref.invalidate(accountSavedSpotsProvider);
        _ref.invalidate(accountUserProvider);
        return const Success(null);
      },
      failure: (error) => Failure(error),
    );
  }
}
