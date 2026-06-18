class ApiConstants {
  ApiConstants._();

  // ── Base URLs ─────────────────────────────────────────────────────────────
  // قابل للتغيير عبر: flutter build apk --dart-define=SITE_URL=https://...
  static const String siteUrl = String.fromEnvironment(
    'SITE_URL',
    defaultValue: 'https://kwafledu.com',
  );
  static const String baseUrl = '$siteUrl/wp-json';

  // ── Auth: JWT Auth Plugin ─────────────────────────────────────────────────
  static const String loginEndpoint         = '/jwt-auth/v1/token';
  static const String validateTokenEndpoint = '/jwt-auth/v1/token/validate';

  // ── Kwafledu App API Plugin (app/v1) ──────────────────────────────────────
  // هذه الـ endpoints من الإضافة المخصصة — تعمل بـ JWT فقط بدون Nonce
  // وهي أكثر استقراراً من Tutor LMS Pro endpoints

  // Register (public — لا يحتاج JWT)
  static const String registerEndpoint       = '/app/v1/register';
  static const String registerFieldsEndpoint = '/app/v1/register-fields';

  // Nonce (مطلوب لبعض Tutor Pro operations)
  static const String nonceEndpoint = '/app/v1/nonce';

  // Courses (public — لا تتطلب تسجيل دخول)
  static const String coursesEndpoint             = '/app/v1/courses';
  static String       courseDetailEndpoint(int id) => '/app/v1/courses/$id';

  // Dashboard (يعمل بـ JWT فقط — لا يحتاج Nonce)
  static const String dashboardEndpoint = '/app/v1/dashboard';

  // My Courses
  static const String myCoursesEndpoint = '/app/v1/my-courses';

  // Profile
  static const String profileMeEndpoint   = '/app/v1/profile/me';
  static const String updateProfileEndpoint = '/app/v1/profile/update';

  // WebView cookie login (JWT in header)
  static const String appLoginEndpoint = '/app/v1/app-login';

  // Instructor (public)
  static String instructorEndpoint(int id) => '/app/v1/instructor/$id';
  static String instructorCoursesEndpoint(int id) => '/app/v1/instructor/$id/courses';

  // Enrollment
  static const String enrollmentEndpoint       = '/app/v1/enroll';
  static String enrollmentStatusEndpoint(int courseId) =>
      '/app/v1/enrollment-status/$courseId';

  // Progress
  static const String markLessonCompleteEndpoint = '/app/v1/lesson/complete';
  static const String markCourseCompleteEndpoint = '/app/v1/course/complete';

  // Lesson View HTML Player
  static String lessonViewUrl(int lessonId) =>
      '$baseUrl/app/v1/lesson-view/$lessonId';

  // TVVL: حالة المشاهدات (JSON)
  static String lessonViewsStatusUrl(int lessonId) =>
      '$baseUrl/app/v1/lesson-views/$lessonId';

  // TVVL: تسجيل مشاهدة جديدة
  static String lessonViewIncrementUrl(int lessonId) =>
      '/app/v1/lesson-views/$lessonId/increment';

  // ── Topics & Lessons (عبر الإضافة — تعمل بـ JWT بدون Nonce) ─────────────
  static const String topicsEndpoint   = '/app/v1/topics';
  static const String lessonsEndpoint  = '/app/v1/lessons';
  static String lessonDetailEndpoint(int id) => '/app/v1/lesson/$id';

  // Course Content (Tutor LMS مباشرة — لا مقابل في الإضافة حالياً)
  static String courseContentEndpoint(int courseId) =>
      '/tutor/v1/course-contents/$courseId';

  // Ratings & Reviews
  static String courseRatingEndpoint(int courseId) =>
      '/tutor/v1/course-rating/$courseId';
  static const String reviewsEndpoint = '/app/v1/reviews';
  static const String reviewsSubmitEndpoint = '/app/v1/reviews/submit';

  // Quiz
  static String quizEndpoint(int quizId)    => '/tutor/v1/quiz/$quizId';
  static const String quizAttemptsEndpoint  = '/app/v1/quiz-attempts';
  static String quizAttemptEndpoint(int id) => '/tutor/v1/quiz-attempts/$id';

  // Q&A (Tutor-native)
  static const String qnaEndpoint = '/app/v1/qna';

  // Assignments (Tutor-native)
  static const String assignmentsEndpoint = '/app/v1/assignments';
  static String assignmentDetailEndpoint(int id) => '/app/v1/assignment/$id';
  static String assignmentSubmitEndpoint(int id) => '/app/v1/assignment/$id/submit';

  // Notifications
  static const String notificationsEndpoint = '/app/v1/notifications';
  static const String markNotificationsReadEndpoint = '/app/v1/notifications/read';

  // ── App Mode Player (legacy rewrite rule) ─────────────────────────────────
  static String appModeUrl(String lessonUrl, String token) {
    final separator = lessonUrl.contains('?') ? '&' : '?';
    return '$lessonUrl${separator}app=1&token=${Uri.encodeComponent(token)}';
  }

  static String appPlayerUrl(int lessonId, String token) =>
      '$siteUrl/app-player/$lessonId/?token=${Uri.encodeComponent(token)}';

  // ── Pagination ────────────────────────────────────────────────────────────
  static const int defaultPerPage = 20;
}
