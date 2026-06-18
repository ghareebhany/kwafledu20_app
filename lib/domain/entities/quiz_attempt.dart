import 'package:equatable/equatable.dart';

/// محاولة اختبار منتهية للمستخدم الحالي.
class QuizAttempt extends Equatable {
  final int id;
  final int quizId;
  final String quizTitle;
  final int totalQuestions;
  final int answered;
  final double totalMarks;
  final double earnedMarks;
  final double percent;
  final int passingGrade;
  final bool? isPassed;
  final String status;
  final String startedAt;
  final String endedAt;

  const QuizAttempt({
    required this.id,
    required this.quizId,
    required this.quizTitle,
    required this.totalQuestions,
    required this.answered,
    required this.totalMarks,
    required this.earnedMarks,
    required this.percent,
    required this.passingGrade,
    required this.isPassed,
    required this.status,
    required this.startedAt,
    required this.endedAt,
  });

  @override
  List<Object?> get props => [id, quizId, earnedMarks, status];
}
