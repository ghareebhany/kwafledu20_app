import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/cache_manager.dart';
import '../../domain/entities/quiz_attempt.dart';
import '../../domain/repositories/i_quiz_attempts_repository.dart';
import '../datasources/quiz_attempts_remote_ds.dart';

class QuizAttemptsRepositoryImpl implements IQuizAttemptsRepository {
  final QuizAttemptsRemoteDataSource _remote;
  final CacheManager _cache;

  QuizAttemptsRepositoryImpl(
      {QuizAttemptsRemoteDataSource? remote, CacheManager? cache})
      : _remote = remote ?? QuizAttemptsRemoteDataSource.instance,
        _cache = cache ?? CacheManager.instance;

  @override
  Future<Either<Failure, List<QuizAttempt>>> getAttempts(int courseId) async {
    final key = 'quiz_attempts_$courseId';
    final cached = _cache.get<List<QuizAttempt>>(key);
    if (cached != null) return Right(cached);
    try {
      final models = await _remote.getAttempts(courseId);
      _cache.set(key, List<QuizAttempt>.from(models));
      return Right(models);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
