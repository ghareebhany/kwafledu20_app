import 'package:equatable/equatable.dart';

class AppNotification extends Equatable {
  final String id;
  final String type; // qna_reply | announcement
  final String title;
  final String message;
  final int courseId;
  final String courseTitle;
  final int relatedId;
  final String date;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.courseId,
    required this.courseTitle,
    required this.relatedId,
    required this.date,
    required this.isRead,
  });

  @override
  List<Object?> get props => [id, isRead];
}

class NotificationsBundle extends Equatable {
  final List<AppNotification> items;
  final int unreadCount;

  const NotificationsBundle({required this.items, required this.unreadCount});

  @override
  List<Object?> get props => [items, unreadCount];
}
