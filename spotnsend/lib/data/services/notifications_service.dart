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

  /// List notifications for the logged-in user (RLS handles scoping).
  Future<List<AppNotification>> list() async {
    final rows = await _tbl().select().order('created_at', ascending: false)
        as List<dynamic>;

    return rows
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList(growable: false);
  }

  /// Mark a single notification as read/unread (soft toggle).
  Future<Result<void>> markRead(String id, {bool seen = true}) async {
    try {
      final idInt = int.tryParse(id);
      final patch = {
        'seen_at': seen ? DateTime.now().toUtc().toIso8601String() : null
      };

      final q = _tbl().update(patch);
      idInt != null
          ? q.eq('notification_id', idInt)
          : q.eq('notification_id', id);
      await q;
      return const Success(null);
    } on sb.PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Mark all as read/unread for the current user.
  Future<Result<void>> markAll({bool seen = true}) async {
    try {
      final patch = {
        'seen_at': seen ? DateTime.now().toUtc().toIso8601String() : null
      };
      await _tbl().update(patch);
      return const Success(null);
    } on sb.PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Soft-delete a single notification.
  Future<Result<void>> delete(String id) async {
    try {
      final idInt = int.tryParse(id);
      final q = _tbl()
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()});
      idInt != null
          ? q.eq('notification_id', idInt)
          : q.eq('notification_id', id);
      await q;
      return const Success(null);
    } on sb.PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Soft-delete all notifications.
  Future<Result<void>> deleteAll() async {
    try {
      await _tbl()
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()});
      return const Success(null);
    } on sb.PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Subscribe to realtime changes. Calls [onAnyChange] when anything changes.
  /// Returns a function you should call to stop listening.
  Future<VoidCallback> subscribe({required VoidCallback onAnyChange}) async {
    // civic_app user_id (bigint) – used to filter realtime
    int? userId;
    try {
      final res = await _client.rpc('civic_app.current_user_id');
      if (res is int) userId = res;
      if (res is num) userId = res.toInt();
    } catch (_) {
      // If RPC isn’t available we still subscribe without a filter (RLS usually OK),
      // but filtering is preferred.
    }

    // Close old channel if any
    await _channel?.unsubscribe();
    _channel = _client.channel('realtime:notifications:${userId ?? 'all'}');

    // Filter string works across SDK versions
    final filter = userId == null
        ? null
        : sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId.toString(),
          );

    for (final ev in sb.PostgresChangeEvent.values) {
      _channel!.onPostgresChanges(
        event: ev,
        schema: 'civic_app',
        table: 'notifications',
        filter: filter,
        callback: (_) => onAnyChange(),
      );
    }

    await _channel!.subscribe();
    return () {
      _channel?.unsubscribe();
      _channel = null;
    };
  }

  Future<void> dispose() async {
    await _channel?.unsubscribe();
    _channel = null;
  }
}
