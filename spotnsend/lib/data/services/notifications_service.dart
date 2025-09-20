import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/notification_models.dart';

final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  return NotificationsService();
});

class NotificationsService {
  List<AppNotification>? _cache;

  Future<List<AppNotification>> list() async {
    _cache ??= await _loadNotifications();
    return List<AppNotification>.from(_cache!);
  }

  Future<Result<void>> markRead(String id, {bool seen = true}) async {
    _cache ??= await _loadNotifications();
    _cache = _cache!
        .map((notification) => notification.id == id ? notification.copyWith(seen: seen) : notification)
        .toList();
    return const Success<void>(null);
  }

  Future<Result<void>> delete(String id) async {
    _cache ??= await _loadNotifications();
    _cache = _cache!.where((notification) => notification.id != id).toList();
    return const Success<void>(null);
  }

  Future<Result<void>> markAll({bool seen = true}) async {
    _cache ??= await _loadNotifications();
    _cache = _cache!.map((notification) => notification.copyWith(seen: seen)).toList();
    return const Success<void>(null);
  }

  Future<Result<void>> deleteAll() async {
    _cache = [];
    return const Success<void>(null);
  }

  Future<List<AppNotification>> _loadNotifications() async {
    final raw = await rootBundle.loadString('fixtures/notifications.json');
    final List<dynamic> jsonList = jsonDecode(raw) as List<dynamic>;
    return jsonList
        .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}


