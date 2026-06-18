import 'package:equatable/equatable.dart';

/// عنصر أسئلة وأجوبة: قد يكون سؤالاً (parentId = 0) أو إجابة (parentId > 0).
class QnaItem extends Equatable {
  final int id;
  final int courseId;
  final int parentId;
  final String content;
  final String authorName;
  final String authorAvatar;
  final bool isInstructor;
  final String date;
  final List<QnaItem> answers;

  const QnaItem({
    required this.id,
    required this.courseId,
    required this.parentId,
    required this.content,
    required this.authorName,
    required this.authorAvatar,
    required this.isInstructor,
    required this.date,
    this.answers = const [],
  });

  @override
  List<Object?> get props => [id, content, answers];
}
