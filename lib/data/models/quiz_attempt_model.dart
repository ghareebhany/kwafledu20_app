import '../../domain/entities/quiz_attempt.dart';

class QuizAttemptModel extends QuizAttempt {
  const QuizAttemptModel({
    required super.id,
    required super.quizId,
    required super.quizTitle,
    required super.totalQuestions,
    required super.answered,
    required super.totalMarks,
    required super.earnedMarks,
    required super.percent,
    required super.passingGrade,
    required super.isPassed,
    required super.status,
    required super.startedAt,
    required super.endedAt,
  });

  factory QuizAttemptModel.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) => v == null
        ? 0.0
        : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
    int toI(dynamic v) => v == null
        ? 0
        : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);
    return QuizAttemptModel(
      id: toI(json['id']),
      quizId: toI(json['quiz_id']),
      quizTitle: json['quiz_title'] as String? ?? '',
      totalQuestions: toI(json['total_questions']),
      answered: toI(json['answered']),
      totalMarks: toD(json['total_marks']),
      earnedMarks: toD(json['earned_marks']),
      percent: toD(json['percent']),
      passingGrade: toI(json['passing_grade']),
      isPassed: json['is_passed'] == null ? null : json['is_passed'] == true,
      status: json['status'] as String? ?? '',
      startedAt: json['started_at'] as String? ?? '',
      endedAt: json['ended_at'] as String? ?? '',
    );
  }
}
