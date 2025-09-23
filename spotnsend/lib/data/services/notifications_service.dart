// lib/data/services/notifications_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/notification_models.dart';
import 'package:spotnsend/main.dart';

final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  return NotificationsService(supabase);
});

class NotificationsService {
  NotificationsService(this._client);
  final sb.SupabaseClient _client;

  sb.RealtimeChannel? _channel;

  sb.SupabaseQueryBuilder _tbl() =>
      _client.schema('civic_app').from('notifications');

  dynamic _idValue(String id) => int.tryParse(id) ?? id; // bigint-safe

  /// List notifications for the logged-in user.
  /// IMPORTANT: exclude soft-deleted rows.
  Future<List<AppNotification>> list() async {
    // Not signed in → empty (avoids RLS errors)
    if (_client.auth.currentUser == null) return const [];

    final rows = await _tbl()
        .select()
        .filter('deleted_at', 'is', null) // ← hide deleted rows
        .order('created_at', ascending: false) as List<dynamic>;

    return rows
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList(growable: false);
  }

  /// Toggle a single notification read/unread via seen_at.
  Future<Result<void>> markRead(String id, {bool seen = true}) async {
    try {
      final patch = {
        'seen_at': seen ? DateTime.now().toUtc().toIso8601String() : null
      };
      final q = _tbl().update(patch).eq('notification_id', _idValue(id));
      await q;
      return const Success(null);
    } on sb.PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Mark all visible (non-deleted) notifications read/unread.
  Future<Result<void>> markAll({bool seen = true}) async {
    try {
      await _tbl().update({
        'seen_at': seen ? DateTime.now().toUtc().toIso8601String() : null
      }).filter('deleted_at', 'is', null); // only affect non-deleted
      return const Success(null);
    } on sb.PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Soft delete a single notification (set deleted_at).
  Future<Result<void>> delete(String id) async {
    try {
      await _tbl()
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq(
              'notification_id', _idValue(id));
      return const Success(null);
    } on sb.PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Soft delete all visible notifications.
  Future<Result<void>> deleteAll() async {
    try {
      await _tbl().update({
        'deleted_at': DateTime.now().toUtc().toIso8601String()
      }).filter('deleted_at', 'is', null);
      return const Success(null);
    } on sb.PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Realtime: call [onAnyChange] whenever the notifications table changes
  /// for the current user (INSERT/UPDATE/DELETE).
  Future<VoidCallback> subscribe({required VoidCallback onAnyChange}) async {
    // No user → no subscription
    if (_client.auth.currentUser == null) {
      return () {};
    }

    // Resolve app user_id (bigint) for server-side filter (nice-to-have)
    int? userId;
    try {
      final res =
          await _client.schema('civic_app').rpc('current_user_id');
      if (res is int) userId = res;
      if (res is num) userId = res.toInt();
    } catch (_) {
      // ignore; RLS will still protect reads
    }

    // Close previous channel
    await _channel?.unsubscribe();

    // Unique channel name per user
    _channel = _client.channel('realtime:notifications:${userId ?? 'all'}');

    final filter = userId == null
        ? null
        : sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId.toString(),
          );

    // Subscribe to all change types and simply trigger a reload callback.
    for (final ev in sb.PostgresChangeEvent.values) {
      _channel!.onPostgresChanges(
        event: ev,
        schema: 'civic_app',
        table: 'notifications',
        filter: filter,
        callback: (_) {
          // Small debounce prevents double reload bursts
          _debounced(onAnyChange);
        },
      );
    }

    await _channel!.subscribe();
    return () async {
      await _channel?.unsubscribe();
      _channel = null;
    };
  }

  Timer? _debounce;
  void _debounced(VoidCallback fn) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), fn);
  }

  Future<void> dispose() async {
    await _channel?.unsubscribe();
    _channel = null;
    _debounce?.cancel();
  }
}
