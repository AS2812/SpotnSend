import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/notification_models.dart';
import 'package:spotnsend/data/services/notifications_service.dart';

final notificationsControllerProvider = StateNotifierProvider<NotificationsController, AsyncValue<List<AppNotification>>>((ref) {
  final service = ref.watch(notificationsServiceProvider);
  return NotificationsController(service)..load();
});

class NotificationsController extends StateNotifier<AsyncValue<List<AppNotification>>> {
  NotificationsController(this.service) : super(const AsyncValue.loading());

  final NotificationsService service;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await service.list();
      state = AsyncValue.data(data);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> markRead(String id, {bool seen = true}) async {
    final result = await service.markRead(id, seen: seen);
    if (result.isFailure) {
      return;
    }
    await load();
  }

  Future<void> delete(String id) async {
    final result = await service.delete(id);
    if (result.isFailure) {
      return;
    }
    await load();
  }

  Future<void> markAll({bool seen = true}) async {
    final result = await service.markAll(seen: seen);
    if (result.isFailure) {
      return;
    }
    await load();
  }

  Future<void> deleteAll() async {
    final result = await service.deleteAll();
    if (result.isFailure) {
      return;
    }
    await load();
  }
}





