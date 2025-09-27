import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

final supabaseUserServiceProvider = Provider<SupabaseUserService>((ref) {
  return SupabaseUserService(supabase);
});

class SupabaseUserService {
  SupabaseUserService(this._client);

  final SupabaseClient _client;
  AppUser? _cachedUser;
  bool _bootstrapEnsured = false;

  AppUser? get cachedUser => _cachedUser;

  Future<AppUser> me() async {
    if (_cachedUser != null) return _cachedUser!;
    return fetchProfile(forceRefresh: true);
  }

  Future<AppUser> fetchProfile({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedUser != null) return _cachedUser!;

    await _ensureBootstrap();

    final result = await _callRpc('profile_me');
    final payload = _unwrapSingleRow(result);

    if (payload == null) {
      throw const PostgrestException(message: 'No profile data found');
    }

    final enriched = await _injectSavedSpots(payload);
    final user = AppUser.fromJson(enriched);
    _cachedUser = user;
    return user;
  }

  Future<Result<AppUser>> updateEmail(String email) async {
    try {
      await _ensureBootstrap();
      final result = await _callRpc('update_profile_email', params: {
        'p_email': email,
      });
      final payload = _unwrapSingleRow(result);
      if (payload == null) {
        return const Failure('No profile data returned');
      }

      final enriched = await _injectSavedSpots(payload);
      final user = AppUser.fromJson(enriched);
      _cachedUser = user;
      return Success(user);
    } on PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return const Failure('Unexpected error occurred.');
    }
  }

  Future<Result<AppUser>> updatePhone({
    required String countryCode,
    required String phone,
  }) async {
    try {
      await _ensureBootstrap();
      final result = await _callRpc('update_profile_phone', params: {
        'p_country': countryCode,
        'p_number': phone,
      });
      final payload = _unwrapSingleRow(result);
      if (payload == null) {
        return const Failure('No profile data returned');
      }

      final enriched = await _injectSavedSpots(payload);
      final user = AppUser.fromJson(enriched);
      _cachedUser = user;
      return Success(user);
    } on PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return const Failure('Unexpected error occurred.');
    }
  }

  /// RLS scopes rows to the current user; no need to pass user_id.
  Future<List<SavedSpot>> listSavedSpots() async {
    final rows = await _client
        .from('favorite_spots')
        .select()
        .order('created_at', ascending: false) as List<dynamic>;

    return rows
        .whereType<Map<String, dynamic>>()
        .map(SavedSpot.fromJson)
        .toList();
  }

  /// Insert without user_id (DEFAULT public.current_user_id() handles it).
  Future<Result<List<SavedSpot>>> addSavedSpot({
    required String name,
    required double lat,
    required double lng,
    double? radiusMeters,
  }) async {
    try {
      await _client.from('favorite_spots').insert({
        'name': name,
        'latitude': lat,
        'longitude': lng,
        if (radiusMeters != null) 'radius_meters': radiusMeters.round(),
      });
      final spots = await listSavedSpots();
      if (_cachedUser != null) {
        _cachedUser = _cachedUser!.copyWith(savedSpots: spots);
      }
      return Success(spots);
    } on PostgrestException catch (e) {
      return Failure(e.message);
    } catch (_) {
      return const Failure('Unexpected error occurred.');
    }
  }

  /// Delete by id only; RLS prevents deleting other users' rows.
  Future<Result<List<SavedSpot>>> removeSavedSpot(String id) async {
    try {
      await _client.from('favorite_spots').delete().eq('favorite_spot_id', id);

      final spots = await listSavedSpots();
      if (_cachedUser != null) {
        _cachedUser = _cachedUser!.copyWith(savedSpots: spots);
      }
      return Success(spots);
    } on PostgrestException catch (e) {
      return Failure(e.message);
    } catch (_) {
      return const Failure('Unexpected error occurred.');
    }
  }

  void clearCache() {
    _cachedUser = null;
  }

  Future<Result<void>> submitVerification({
    required String idNumber,
    required String idFrontUrl,
    required String idBackUrl,
    required String selfieUrl,
  }) async {
    try {
      await _ensureBootstrap();
      await _callRpc('submit_verification', params: {
        'p_id_number': idNumber,
        'p_id_front_url': idFrontUrl,
        'p_id_back_url': idBackUrl,
        'p_selfie_url': selfieUrl,
      });
      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<AppUser>> upsertCurrentUser({
    required String username,
    required String fullName,
    required String email,
  }) async {
    try {
      await _ensureBootstrap();
      final result = await _callRpc('upsert_current_user', params: {
        'p_username': username,
        'p_full_name': fullName,
        'p_email': email,
      });

      final payload = _unwrapSingleRow(result) ?? <String, dynamic>{};
      final enriched = await _injectSavedSpots(payload);
      final user = AppUser.fromJson(enriched);
      _cachedUser = user;
      return Success(user);
    } on PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<String?> emailForUsername(String username) async {
    final result = await _callRpc('get_email_for_username', params: {
      'p_username': username,
    });

    if (result is String && result.isNotEmpty) return result;
    if (result is Map<String, dynamic>) {
      final value = result['email'] ?? result['p_email'];
      if (value is String && value.isNotEmpty) return value;
    } else if (result is List && result.isNotEmpty) {
      final first = result.first;
      if (first is Map<String, dynamic>) {
        final value = first['email'] ?? first.values.first;
        if (value is String && value.isNotEmpty) return value;
      } else if (first is String && first.isNotEmpty) {
        return first;
      }
    }
    return null;
  }

  Future<bool> isAdmin() async {
    final result = await _callRpc('is_admin');
    return _asBool(result);
  }

  Future<bool> isGovernment() async {
    final result = await _callRpc('is_government');
    return _asBool(result);
  }

  Future<bool> isContactVerified() async {
    final result = await _callRpc('is_contact_verified');
    return _asBool(result);
  }

  Future<int?> currentUserId() async {
    final result = await _callRpc('current_user_id');
    if (result is int) return result;
    if (result is num) return result.toInt();
    return int.tryParse(result?.toString() ?? '');
  }

  Future<dynamic> _callRpc(String fn, {Map<String, dynamic>? params}) {
    return _client.rpc(fn, params: params);
  }

  Map<String, dynamic>? _unwrapSingleRow(dynamic result) {
    if (result is Map<String, dynamic>) return result;
    if (result is List && result.isNotEmpty) {
      final first = result.first;
      if (first is Map<String, dynamic>) return first;
    }
    return null;
  }

  Future<Map<String, dynamic>> _injectSavedSpots(
      Map<String, dynamic> payload) async {
    final spots = await listSavedSpots();
    return {
      ...payload,
      'favoriteSpots': spots.map((e) => e.toJson()).toList(),
    };
  }

  Future<void> _ensureBootstrap() async {
    if (_bootstrapEnsured) return;
    try {
      await _callRpc('ensure_user');
      await _callRpc('ensure_user_row');
      await _callRpc('ensure_profile');
    } catch (_) {
      // Safe to ignore; these helpers are idempotent and best-effort.
    } finally {
      _bootstrapEnsured = true;
    }
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == 't' || lower == '1';
    }
    return false;
  }
}

extension PasswordApi on SupabaseUserService {
  /// Re-authenticate with the current password, then update to [newPassword].
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _client.auth.currentUser;
      final email = user?.email;
      if (email == null) {
        return const Failure('Not signed in.');
      }

      // 1) Verify the current password
      await _client.auth
          .signInWithPassword(email: email, password: currentPassword);

      // 2) Update to the new password
      await _client.auth.updateUser(
        sb.UserAttributes(password: newPassword),
      );

      // Optional: clear local cache if you keep any auth-derived state
      // clearCache();

      return const Success(null);
    } on sb.AuthException catch (e) {
      // Wrong current password, weak password, etc.
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }
}
