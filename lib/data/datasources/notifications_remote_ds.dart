import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../../domain/entities/notification.dart';
import '../models/notification_model.dart';
import 'dio_helpers.dart';

class NotificationsRemoteDataSource {
  NotificationsRemoteDataSource._();
  static final NotificationsRemoteDataSource instance =
      NotificationsRemoteDataSource._();

  Dio get _dio => DioClient.instance.dio;

  Object? _unwrap(Object? body) {
    if (body is Map<String, dynamic>) {
      if (body['success'] == true && body.containsKey('data')) return body['data'];
      if (body['status'] == 'success' && body.containsKey('data')) return body['data'];
    }
    return body;
  }

  Future<NotificationsBundle> getNotifications() async {
    try {
      final res = await _dio.get(ApiConstants.notificationsEndpoint);
      final raw = _unwrap(res.data);
      if (raw is Map<String, dynamic>) {
        final list = (raw['items'] as List<dynamic>? ?? const [])
            .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
            .toList();
        final unread =
            raw['unread_count'] is num ? (raw['unread_count'] as num).toInt() : 0;
        return NotificationsBundle(items: list, unreadCount: unread);
      }
      return const NotificationsBundle(items: [], unreadCount: 0);
    } on DioException catch (e) {
      return handleDioError(e);
    }
  }

  Future<int> markRead() async {
    try {
      final res = await _dio.post(ApiConstants.markNotificationsReadEndpoint);
      final raw = _unwrap(res.data);
      if (raw is Map<String, dynamic> && raw['unread_count'] is num) {
        return (raw['unread_count'] as num).toInt();
      }
      return 0;
    } on DioException catch (e) {
      return handleDioError(e);
    }
  }
}
