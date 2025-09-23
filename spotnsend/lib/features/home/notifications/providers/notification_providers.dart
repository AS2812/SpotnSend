import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotnsend/data/models/notification_models.dart';
import 'package:spotnsend/data/services/notifications_service.dart';

final notificationsControllerProvider = NotifierProvider<
    NotificationsController, AsyncValue<List<AppNotification>>>(() {
  return NotificationsController();
});

class NotificationsController
    extends Notifier<AsyncValue<List<AppNotification>>> {
  @override
  AsyncValue<List<AppNotification>> build() {
    final service = ref.watch(notificationsServiceProvider);
    _service = service;
    load();
    return const AsyncValue.loading();
  }

  late final NotificationsService _service;
  VoidCallback? _unsubscribe;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await _service.list();
      state = AsyncValue.data(data);

      // Start realtime after first successful load
      _unsubscribe ??= await _service.subscribe(onAnyChange: () async {
        // Keep it simple: re-pull the list on any change
        final fresh = await _service.list();
        state = AsyncValue.data(fresh);
      });
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> refresh() => load();

  Future<void> markRead(String id, {bool seen = true}) async {
    final res = await _service.markRead(id, seen: seen);
    if (res.isFailure) return;
    // optimistic local update
    state.whenData((items) {
      final next = [
        for (final n in items) n.id == id ? n.copyWith(seen: seen) : n
      ];
      state = AsyncValue.data(next);
    });
  }

  Future<void> delete(String id) async {
    final res = await _service.delete(id);
    if (res.isFailure) return;
    state.whenData((items) {
      state = AsyncValue.data(items.where((n) => n.id != id).toList());
    });
  }

  Future<void> markAll({bool seen = true}) async {
    final res = await _service.markAll(seen: seen);
    if (res.isFailure) return;
    state.whenData((items) {
      state = AsyncValue.data([for (final n in items) n.copyWith(seen: seen)]);
    });
  }

  Future<void> deleteAll() async {
    final res = await _service.deleteAll();
    if (res.isFailure) return;
    state = const AsyncValue.data(<AppNotification>[]);
  }

  void dispose() {
    _unsubscribe?.call();
    _service.dispose();
    _unsubscribe = null;
  }
}
