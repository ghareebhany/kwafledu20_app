import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/notifications_remote_ds.dart';
import '../../domain/entities/notification.dart';

final notificationsProvider =
    FutureProvider.autoDispose<NotificationsBundle>((ref) async {
  return NotificationsRemoteDataSource.instance.getNotifications();
});

final markNotificationsReadProvider =
    FutureProvider.autoDispose<int>((ref) async {
  return NotificationsRemoteDataSource.instance.markRead();
});
