import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/quiz_attempts_remote_ds.dart';
import '../../domain/entities/quiz_attempt.dart';

final quizAttemptsProvider =
    FutureProvider.family<List<QuizAttempt>, int>((ref, courseId) async {
  return QuizAttemptsRemoteDataSource.instance.getAttempts(courseId);
});
