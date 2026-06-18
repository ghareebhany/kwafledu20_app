import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repo_impl.dart';
import '../../data/repositories/course_repo_impl.dart';
import '../../data/repositories/profile_repo_impl.dart';
import '../../data/datasources/qna_remote_ds.dart';
import '../../data/datasources/assignment_remote_ds.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../domain/repositories/i_course_repository.dart';
import '../../domain/repositories/i_profile_repository.dart';
import '../../domain/usecases/usecases.dart';

// ── Repositories ──────────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<IAuthRepository>(
  (_) => AuthRepositoryImpl(),
);

final courseRepositoryProvider = Provider<ICourseRepository>(
  (_) => CourseRepositoryImpl(),
);

final profileRepositoryProvider = Provider<IProfileRepository>(
  (_) => ProfileRepositoryImpl(),
);

final qnaRemoteProvider = Provider<QnaRemoteDataSource>(
  (_) => QnaRemoteDataSource.instance,
);

final assignmentRemoteProvider = Provider<AssignmentRemoteDataSource>(
  (_) => AssignmentRemoteDataSource.instance,
);

// ── Use cases ─────────────────────────────────────────────────────────────────

final loginUseCaseProvider = Provider(
  (ref) => LoginUseCase(ref.read(authRepositoryProvider)),
);

final logoutUseCaseProvider = Provider(
  (ref) => LogoutUseCase(ref.read(authRepositoryProvider)),
);

final getCoursesUseCaseProvider = Provider(
  (ref) => GetCoursesUseCase(ref.read(courseRepositoryProvider)),
);

final getCourseDetailUseCaseProvider = Provider(
  (ref) => GetCourseDetailUseCase(ref.read(courseRepositoryProvider)),
);

final getTopicsUseCaseProvider = Provider(
  (ref) => GetTopicsUseCase(ref.read(courseRepositoryProvider)),
);

final getLessonsUseCaseProvider = Provider(
  (ref) => GetLessonsUseCase(ref.read(courseRepositoryProvider)),
);

final markLessonCompleteUseCaseProvider = Provider(
  (ref) => MarkLessonCompleteUseCase(ref.read(courseRepositoryProvider)),
);

final markCourseCompleteUseCaseProvider = Provider(
  (ref) => MarkCourseCompleteUseCase(ref.read(courseRepositoryProvider)),
);

final enrollCourseUseCaseProvider = Provider(
  (ref) => EnrollCourseUseCase(ref.read(courseRepositoryProvider)),
);

final getProfileUseCaseProvider = Provider(
  (ref) => GetProfileUseCase(ref.read(profileRepositoryProvider)),
);

final updateProfileUseCaseProvider = Provider(
  (ref) => UpdateProfileUseCase(ref.read(profileRepositoryProvider)),
);

final getInstructorInfoUseCaseProvider = Provider(
  (ref) => GetInstructorInfoUseCase(ref.read(profileRepositoryProvider)),
);

final getReviewsUseCaseProvider = Provider(
  (ref) => GetReviewsUseCase(ref.read(profileRepositoryProvider)),
);

final submitReviewUseCaseProvider = Provider(
  (ref) => SubmitReviewUseCase(ref.read(profileRepositoryProvider)),
);
