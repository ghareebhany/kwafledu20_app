import '../../domain/entities/qna.dart';

class QnaModel extends QnaItem {
  const QnaModel({
    required super.id,
    required super.courseId,
    required super.parentId,
    required super.content,
    required super.authorName,
    required super.authorAvatar,
    required super.isInstructor,
    required super.date,
    super.answers,
  });

  factory QnaModel.fromJson(Map<String, dynamic> json) {
    final answersJson = json['answers'] as List<dynamic>? ?? const [];
    return QnaModel(
      id: json['id'] as int? ?? 0,
      courseId: json['course_id'] as int? ?? 0,
      parentId: json['parent_id'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      authorName: json['author_name'] as String? ?? '',
      authorAvatar: json['author_avatar'] as String? ?? '',
      isInstructor: json['is_instructor'] == true,
      date: json['date'] as String? ?? '',
      answers: answersJson
          .map((e) => QnaModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
