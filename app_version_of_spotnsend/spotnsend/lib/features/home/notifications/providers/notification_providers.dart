// lib/features/home/notifications/providers/notification_providers.dart
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
  late final NotificationsService _service;
  VoidCallback? _unsubscribe;
  bool _loadedOnce = false;

  @override
  AsyncValue<List<AppNotification>> build() {
    _service = ref.watch(notificationsServiceProvider);

    // Ensure realtime + service are disposed when the provider is disposed
    ref.onDispose(() {
      _unsubscribe?.call();
      _unsubscribe = null;
      _service.dispose();
    });

    // Only kick off the first load a single time
    if (!_loadedOnce) {
      _loadedOnce = true;
      // schedule so build returns immediately
      Future.microtask(load);
    }

    return const AsyncValue.loading();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await _service.list();
      state = AsyncValue.data(data);

      // Start realtime after first successful load (idempotent)
      _unsubscribe ??= await _service.subscribe(onAnyChange: () async {
        // Re-fetch list on any DB change
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

    // Optimistic local update
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

    // Remove locally right away
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
}
