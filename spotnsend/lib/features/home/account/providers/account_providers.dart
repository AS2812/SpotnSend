import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:spotnsend/main.dart';
import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/data/services/supabase_user_service.dart';

/// Waits until Supabase has a session (or times out).
final signedInSessionProvider = FutureProvider<sb.Session?>((ref) async {
  final cur = supabase.auth.currentSession;
  if (cur != null) return cur;

  final completer = Completer<sb.Session?>();
  late final StreamSubscription sub;
  sub = supabase.auth.onAuthStateChange.listen((data) {
    final ev = data.event;
    if (ev == sb.AuthChangeEvent.signedIn ||
        ev == sb.AuthChangeEvent.tokenRefreshed) {
      completer.complete(supabase.auth.currentSession);
    }
  });

  try {
    return await completer.future
        .timeout(const Duration(seconds: 6), onTimeout: () => null);
  } finally {
    await sub.cancel();
  }
});

/// Loads the profile. If missing, auto-creates then re-fetches.
final accountUserProvider = FutureProvider<AppUser?>((ref) async {
  final session = await ref.watch(signedInSessionProvider.future);
  if (session == null) return null;

  final svc = ref.read(supabaseUserServiceProvider);

  try {
    return await svc.fetchProfile(forceRefresh: true);
  } catch (e) {
    final u = supabase.auth.currentUser;
    if (u == null) rethrow;

    try {
      await supabase.rpc('ensure_profile', params: {
        'p_username': (u.userMetadata?['username'] as String?) ?? '',
        'p_full_name':
            (u.userMetadata?['full_name'] as String?) ?? u.email ?? '',
        'p_email': u.email ?? '',
      });
    } catch (err, st) {
      if (kDebugMode) {
        debugPrint('ensure_profile failed: $err');
        debugPrintStack(stackTrace: st);
      }
    }

    return await svc.fetchProfile(forceRefresh: true);
  }
});

/// Saved spots list (RLS + DEFAULT user_id = safe).
final accountSavedSpotsProvider = FutureProvider<List<SavedSpot>>((ref) async {
  final session = await ref.watch(signedInSessionProvider.future);
  if (session == null) return const [];
  final svc = ref.read(supabaseUserServiceProvider);
  return svc.listSavedSpots();
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
  ) async {
    final r = await _svc.addSavedSpot(name: name, lat: lat, lng: lng);
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
