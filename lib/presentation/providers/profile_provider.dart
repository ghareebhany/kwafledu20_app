import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/course_page.dart';
import '../../data/datasources/courses_remote_ds.dart';
import 'auth_provider.dart';
import 'di_providers.dart';

// ── Profile Provider ──────────────────────────────────────────────────────────
// FIX: يراقب authProvider مباشرة — لا يُنفَّذ حتى تكتمل المصادقة.
// FIX: إذا فشل الـ API يرجع بيانات من SecureStorage بدل إبقاء الـ loading.

final profileProvider = FutureProvider.family<User, int>((ref, userId) async {
  // انتظر حتى تكتمل المصادقة
  final authState = ref.watch(authProvider);
  if (authState is! AuthAuthenticated) {
    throw Exception('يرجى تسجيل الدخول أولاً');
  }

  try {
    final result = await ref.read(getProfileUseCaseProvider).call(userId);
    return result.fold(
      (failure) {
        // FIX: إذا فشل API بـ EmptyResponseFailure أو ServerFailure
        // ارجع بيانات المستخدم المخزّنة في SecureStorage
        if (failure is EmptyResponseFailure || failure is ServerFailure) {
          return authState.user;
        }
        throw Exception(failure.message);
      },
      (user) => user,
    );
  } catch (e) {
    // FIX: أي خطأ غير متوقع → ارجع بيانات الجلسة الحالية بدل إبقاء loading
    return authState.user;
  }
});

// ── Instructor info ───────────────────────────────────────────────────────────

final instructorProvider =
    FutureProvider.family<User, int>((ref, instructorId) async {
  final result =
      await ref.read(getInstructorInfoUseCaseProvider).call(instructorId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (user) => user,
  );
});

// كورسات المحاضر — تُستخدم داخل InstructorScreen
final instructorCoursesProvider =
    FutureProvider.family<CoursePage, int>((ref, instructorId) async {
  return CoursesRemoteDataSource.instance.getInstructorCourses(instructorId);
});

// ── Reviews ───────────────────────────────────────────────────────────────────

final reviewsProvider =
    FutureProvider.family<List<Review>, int>((ref, courseId) async {
  final result = await ref
      .read(getReviewsUseCaseProvider)
      .call(courseId: courseId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (reviews) => reviews,
  );
});

// ── Submit review notifier ──────────────────────────────────────

class SubmitReviewState {
  final bool isLoading;
  final bool success;
  final String? error;
  const SubmitReviewState({
    this.isLoading = false,
    this.success = false,
    this.error,
  });
}

class SubmitReviewNotifier extends StateNotifier<SubmitReviewState> {
  final Ref _ref;
  SubmitReviewNotifier(this._ref) : super(const SubmitReviewState());

  Future<bool> submit({
    required int courseId,
    required double rating,
    String review = '',
  }) async {
    state = const SubmitReviewState(isLoading: true);
    final result = await _ref.read(submitReviewUseCaseProvider).call(
          courseId: courseId,
          rating: rating,
          review: review,
        );
    return result.fold(
      (f) {
        state = SubmitReviewState(error: f.message);
        return false;
      },
      (_) {
        state = const SubmitReviewState(success: true);
        _ref.invalidate(reviewsProvider(courseId));
        return true;
      },
    );
  }

  void reset() => state = const SubmitReviewState();
}

final submitReviewProvider =
    StateNotifierProvider<SubmitReviewNotifier, SubmitReviewState>(
  (ref) => SubmitReviewNotifier(ref),
);

// ── Update profile notifier ───────────────────────────────────────────────────

class UpdateProfileState {
  final bool isLoading;
  final bool success;
  final String? error;
  const UpdateProfileState({
    this.isLoading = false,
    this.success = false,
    this.error,
  });
}

class UpdateProfileNotifier extends StateNotifier<UpdateProfileState> {
  final Ref _ref;
  UpdateProfileNotifier(this._ref) : super(const UpdateProfileState());

  Future<void> update(Map<String, dynamic> data) async {
    state = const UpdateProfileState(isLoading: true);
    final result = await _ref.read(updateProfileUseCaseProvider).call(data);
    result.fold(
      (f) => state = UpdateProfileState(error: f.message),
      (_) => state = const UpdateProfileState(success: true),
    );
  }

  void reset() => state = const UpdateProfileState();
}

final updateProfileProvider =
    StateNotifierProvider<UpdateProfileNotifier, UpdateProfileState>(
  (ref) => UpdateProfileNotifier(ref),
);
