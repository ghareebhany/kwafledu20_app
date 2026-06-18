import '../../domain/entities/notification.dart';

class NotificationModel extends AppNotification {
  const NotificationModel({
    required super.id,
    required super.type,
    required super.title,
    required super.message,
    required super.courseId,
    required super.courseTitle,
    required super.relatedId,
    required super.date,
    required super.isRead,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    int toI(dynamic v) => v == null
        ? 0
        : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      courseId: toI(json['course_id']),
      courseTitle: json['course_title'] as String? ?? '',
      relatedId: toI(json['related_id']),
      date: json['date'] as String? ?? '',
      isRead: json['is_read'] == true,
    );
  }
}
