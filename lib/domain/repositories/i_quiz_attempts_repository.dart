import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/quiz_attempt.dart';

abstract class IQuizAttemptsRepository {
  Future<Either<Failure, List<QuizAttempt>>> getAttempts(int courseId);
}
