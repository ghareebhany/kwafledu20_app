import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/errors/failures.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_widget.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/qna.dart';
import '../../domain/entities/assignment.dart';
import '../../domain/entities/quiz_attempt.dart';
import '../providers/courses_provider.dart';
import '../providers/di_providers.dart';
import '../providers/profile_provider.dart';
import '../providers/qna_provider.dart';
import '../providers/assignment_provider.dart';
import '../providers/quiz_attempts_provider.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final int courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _enrolling = false;

  // FIX: local state بسيط بدون أي provider magic
  // يُحدَّث فوراً بعد التسجيل ويبقى حتى يُغلق المستخدم الشاشة أو يُؤكد الـ server
  bool _enrolledLocally = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // الـ enrollment الفعلي = server value OR local override
  bool _effectiveEnrolled(Course course) => course.isEnrolled || _enrolledLocally;

  Future<void> _enroll(Course course) async {
    setState(() => _enrolling = true);

    final result = await ref.read(enrollCourseUseCaseProvider).call(course.id);
    if (!mounted) return;

    setState(() => _enrolling = false);

    result.fold(
      (f) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(f.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      },
      (_) {
        // FIX: حدّث الـ UI فوراً عبر local state — لا race conditions
        setState(() => _enrolledLocally = true);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'تم التسجيل بنجاح! ',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ));

        // FIX: أعد تحميل بعد 800ms — يُعطي الـ DB وقتاً للاستقرار
        // لا نستدعي invalidate فوراً لأن الـ backend قد يُعيد is_enrolled: false
        // بسبب الـ cache أو latency
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          // امسح الـ cache المحلي أولاً
          ref.read(courseRepositoryProvider); // warm provider
          // أعد تحميل الـ topics (الآن الـ server يُعيد البيانات بشكل صحيح)
          ref.invalidate(topicsProvider(widget.courseId));
          // أعد تحميل الكورس من الـ server للمزامنة (skipLoadingOnRefresh يحميه من الوميض)
          ref.invalidate(courseDetailProvider(widget.courseId));
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final courseAsync = ref.watch(courseDetailProvider(widget.courseId));

    return courseAsync.when(
      // FIX: لا تُظهر loading أثناء refresh — يحمي من وميض الـ UI
      skipLoadingOnRefresh: true,
      skipLoadingOnReload:  true,
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: AppErrorWidget(
          message: e.toString().replaceAll('Exception: ', ''),
          onRetry: () => ref.invalidate(courseDetailProvider(widget.courseId)),
        ),
      ),
      data: (course) {
        // FIX: لما يُؤكد الـ server التسجيل — نُزيل الـ local flag
        // لأن course.isEnrolled أصبح true من الـ server مباشرة
        if (course.isEnrolled && _enrolledLocally) {
          // ScheduleMicrotask لتجنب setState أثناء build
          Future.microtask(() {
            if (mounted) setState(() => _enrolledLocally = false);
          });
        }
        return _buildScaffold(course);
      },
    );
  }

  Widget _buildScaffold(Course course) {
    final theme    = Theme.of(context);
    final enrolled = _effectiveEnrolled(course);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: course.thumbnail.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: course.thumbnail,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          Container(color: theme.colorScheme.primaryContainer),
                    )
                  : Container(color: theme.colorScheme.primaryContainer),
            ),
            title: Text(course.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16)),
          ),
          SliverToBoxAdapter(child: _courseHeader(course, theme)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor:
                    theme.colorScheme.onSurface.withValues(alpha: 0.6),
                indicatorColor: theme.colorScheme.primary,
                tabs: const [
                  Tab(text: 'عن الدورة'),
                  Tab(text: 'المحتوى'),
                  Tab(text: 'التقييمات'),
                  Tab(text: 'الأسئلة'),
                  Tab(text: 'الواجبات'),
                  Tab(text: 'محاولات الاختبار'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _AboutTab(course: course),
            _ContentTab(courseId: course.id, isEnrolled: enrolled),
            _ReviewsTab(courseId: course.id),
            _QnaTab(courseId: course.id, isEnrolled: enrolled),
            _AssignmentsTab(courseId: course.id, isEnrolled: enrolled),
            _QuizAttemptsTab(courseId: course.id, isEnrolled: enrolled),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(course, theme, enrolled),
    );
  }

  Widget _courseHeader(Course course, ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ النص الأساسي: onSurface + weight 800
          Text(
            course.title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          // Stats chips
          Wrap(spacing: 8, runSpacing: 8, children: [
            _InfoChip(
              icon: Icons.star_rounded,
              label: '${course.rating.toStringAsFixed(1)} (${course.ratingCount})',
              color: const Color(0xFFF59E0B),
            ),
            _InfoChip(
              icon: Icons.people_rounded,
              label: '${course.totalEnrolled} طالب',
              color: const Color(0xFF3B82F6),
            ),
            _InfoChip(
              icon: Icons.menu_book_rounded,
              label: '${course.totalLessons} درس',
              color: AppTheme.brandGold,
            ),
            if (course.isFree)
              _InfoChip(
                icon: Icons.card_giftcard_rounded,
                label: 'مجاني',
                color: AppTheme.brandRed,
                filled: true,
              ),
          ]),
          const SizedBox(height: 14),
          // Instructor card
          GestureDetector(
            onTap: () => context.push('/instructor/${course.instructorId}'),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFFFE4E5),
                  backgroundImage: course.instructorAvatar.isNotEmpty
                      ? CachedNetworkImageProvider(course.instructorAvatar)
                      : null,
                  child: course.instructorAvatar.isEmpty
                      ? const Icon(Icons.person_rounded, size: 20, color: AppTheme.brandRed)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ النص الأساسي: onSurface + weight 700
                      Text(
                        course.instructorName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      // ✅ النص الثانوي: onSurfaceVariant
                      Text(
                        'المحاضر',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_back_ios_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
              ]),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ✅ تحسين 2 و 3 و 4: Bottom Bar مع Material surface وتأثيرات نظيفة
  Widget _buildBottomBar(Course course, ThemeData theme, bool enrolled) {
    return enrolled
        ? Material(
            color: theme.colorScheme.surface,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => context.push('/lessons/${course.id}'),
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text(
                      'ابدأ التعلم الآن',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.brandRed,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0, // ✅ إلغاء elevation لأن داخل bottom bar
                    ),
                  ),
                ),
              ),
            ),
          )
        : Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(children: [
                  if (!course.isFree) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ✅ النص الثانوي: onSurfaceVariant
                        Text(
                          'السعر',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          course.price,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.brandRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _enrolling ? null : () => _enroll(course),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.brandRed,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _enrolling
                            ? const SizedBox(height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                course.isFree ? 'التسجيل مجاناً 🎓' : 'التسجيل الآن',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          );
  }
}

// ── Tab: About ────────────────────────────────────────────────────────────────

class _AboutTab extends StatelessWidget {
  final Course course;
  const _AboutTab({required this.course});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Html(
        data: course.description.isNotEmpty
            ? course.description
            : '<p>لا يوجد وصف متاح</p>',
      ),
    );
  }
}

// ── Tab: Content ──────────────────────────────────────────────────────────────

class _ContentTab extends ConsumerWidget {
  final int courseId;
  final bool isEnrolled;

  const _ContentTab({required this.courseId, required this.isEnrolled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicsProvider(courseId));
    final theme = Theme.of(context);

    return topicsAsync.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) {
        if (e is EnrollmentFailure && isEnrolled) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جارٍ تحميل المحتوى...'),
              ],
            ),
          );
        }
        if (e is EnrollmentFailure) {
          return _EnrollmentPlaceholder(onGoToEnroll: () {
            DefaultTabController.maybeOf(context)?.animateTo(0);
          });
        }
        return AppErrorWidget(
          message: e.toString().replaceAll('Exception: ', ''),
          onRetry: () => ref.invalidate(topicsProvider(courseId)),
        );
      },
      data: (topics) {
        if (topics.isEmpty) {
          return Center(
            child: Text(
              'لا يوجد محتوى بعد',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: topics.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final topic = topics[i];
            return Card(
              margin: EdgeInsets.zero,
              child: ExpansionTile(
                initiallyExpanded: i == 0,
                title: Text(
                  topic.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  '${topic.lessons.length} درس',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                children: topic.lessons
                    .map((lesson) => _LessonTile(
                          lesson:     lesson,
                          courseId:   courseId,
                          isEnrolled: isEnrolled,
                          allLessons: topic.lessons,
                        ))
                    .toList(),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Enrollment placeholder ────────────────────────────────────────────────────

class _EnrollmentPlaceholder extends StatelessWidget {
  final VoidCallback onGoToEnroll;
  const _EnrollmentPlaceholder({required this.onGoToEnroll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'سجّل في الدورة لعرض المحتوى',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onGoToEnroll,
              child: const Text('اذهب للتسجيل'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Lesson Tile ───────────────────────────────────────────────────────────────

class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  final int courseId;
  final bool isEnrolled;
  final List<Lesson> allLessons;

  const _LessonTile({
    required this.lesson,
    required this.courseId,
    required this.isEnrolled,
    required this.allLessons,
  });

  void _onTap(BuildContext context) {
    if (!isEnrolled) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('سجّل في الدورة للوصول إلى هذا المحتوى'),
        action: SnackBarAction(
          label: 'التسجيل',
          onPressed: () =>
              DefaultTabController.maybeOf(context)?.animateTo(0),
        ),
      ));
      return;
    }

    if (lesson.isVideo) {
      context.push('/lesson/${lesson.id}', extra: {
        'lesson'    : lesson,
        'courseId'  : courseId,
        'allLessons': allLessons,
      });
    } else if (lesson.isQuiz) {
      context.push('/lesson/${lesson.id}', extra: {
        'lesson'    : lesson,
        'courseId'  : courseId,
        'allLessons': allLessons,
      });
    } else if (lesson.isAssignment) {
      context.push('/lesson/${lesson.id}', extra: {
        'lesson'    : lesson,
        'courseId'  : courseId,
        'allLessons': allLessons,
      });
    } else {
      context.push('/lesson/${lesson.id}', extra: {
        'lesson'    : lesson,
        'courseId'  : courseId,
        'allLessons': allLessons,
      });
    }
  }

  IconData get _icon {
    if (lesson.isCompleted)   return Icons.check_rounded;
    if (!isEnrolled)          return Icons.lock_outline_rounded;
    if (lesson.isQuiz)        return Icons.quiz_rounded;
    if (lesson.isAssignment)  return Icons.assignment_rounded;
    if (lesson.isVideo)       return Icons.play_arrow_rounded;
    return Icons.article_outlined;
  }

  Color _iconColor(ThemeData t) {
    if (lesson.isCompleted)  return Colors.green;
    if (!isEnrolled)         return t.colorScheme.onSurfaceVariant;
    if (lesson.isQuiz)       return t.colorScheme.secondary;
    if (lesson.isAssignment) return t.colorScheme.tertiary;
    return t.colorScheme.primary;
  }

  Color _bgColor(ThemeData t) {
    if (lesson.isCompleted)  return Colors.green.withValues(alpha: 0.12);
    if (!isEnrolled)         return t.colorScheme.surfaceContainerHighest;
    if (lesson.isQuiz)       return t.colorScheme.secondaryContainer;
    if (lesson.isAssignment) return t.colorScheme.tertiaryContainer;
    return t.colorScheme.primaryContainer;
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final locked = !isEnrolled;

    return ListTile(
      onTap: () => _onTap(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(shape: BoxShape.circle, color: _bgColor(theme)),
        child: Icon(_icon, size: 18, color: _iconColor(theme)),
      ),
      title: Text(
        lesson.title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: locked
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onSurface,
          decoration: lesson.isCompleted ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: _buildSubtitle(theme),
      trailing: locked
          ? null
          : Icon(Icons.chevron_left_rounded, color: theme.colorScheme.onSurfaceVariant),
    );
  }

  Widget? _buildSubtitle(ThemeData theme) {
    final isSpecial = lesson.isQuiz || lesson.isAssignment;
    final duration  = lesson.videoDuration;
    if (!isSpecial && duration.isEmpty) return null;

    return Wrap(spacing: 6, children: [
      if (isSpecial)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: lesson.isQuiz
                ? theme.colorScheme.secondaryContainer
                : theme.colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            lesson.isQuiz ? 'اختبار' : 'واجب',
            style: theme.textTheme.labelSmall?.copyWith(
              color: lesson.isQuiz
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.tertiary,
            ),
          ),
        ),
      if (duration.isNotEmpty)
        Text(
          duration,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
    ]);
  }
}

// ── Tab: Reviews ──────────────────────────────────────────────────────────────

class _ReviewsTab extends ConsumerWidget {
  final int courseId;
  const _ReviewsTab({required this.courseId});

  void _openWriteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WriteReviewSheet(courseId: courseId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(reviewsProvider(courseId));
    final theme = Theme.of(context);

    final writeButton = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _openWriteSheet(context),
          icon: const Icon(Icons.rate_review_outlined, size: 18),
          label: const Text('اكتب تقييمك'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            side: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );

    final body = reviewsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorWidget(
          message: e.toString().replaceAll('Exception: ', '')),
      data: (reviews) {
        if (reviews.isEmpty) {
          return Center(
              child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('لا توجد تقييمات بعد — كن أول من يقيّم!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          ));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (_, i) => _ReviewTile(review: reviews[i]),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        writeButton,
        Expanded(child: body),
      ],
    );
  }
}

class _WriteReviewSheet extends ConsumerStatefulWidget {
  final int courseId;
  const _WriteReviewSheet({required this.courseId});

  @override
  ConsumerState<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<_WriteReviewSheet> {
  final _controller = TextEditingController();
  int _rating = 5;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اختر عدد النجوم أولاً')));
      return;
    }
    setState(() => _submitting = true);
    final ok = await ref.read(submitReviewProvider.notifier).submit(
          courseId: widget.courseId,
          rating: _rating.toDouble(),
          review: _controller.text.trim(),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('شكراً لك! تم حفظ تقييمك')));
    } else {
      final err = ref.read(submitReviewProvider).error ??
          'تعذّر حفظ التقييم، حاول مرة أخرى';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('قيّم هذا الكورس',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return IconButton(
                  onPressed:
                      _submitting ? null : () => setState(() => _rating = i + 1),
                  iconSize: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? Colors.amber : theme.colorScheme.outline,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'اكتب رأيك (اختياري)...',
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Review review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundImage: review.authorAvatar.isNotEmpty
                ? CachedNetworkImageProvider(review.authorAvatar)
                : null,
            child: review.authorAvatar.isEmpty
                ? Text(review.authorName.isNotEmpty ? review.authorName[0] : '?')
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  // ✅ اسم المراجع: onSurface + bold
                  Text(
                    review.authorName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: i < review.rating.round()
                            ? Colors.amber
                            : theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                // ✅ ✅ تصحيح: النص الثانوي يجب أن يكون onSurfaceVariant (ليس onSurface)
                Text(
                  review.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab: Q&A ───────────────────────────────────────────────────────────────

class _QnaTab extends ConsumerWidget {
  final int courseId;
  final bool isEnrolled;
  const _QnaTab({required this.courseId, required this.isEnrolled});

  void _openAskSheet(BuildContext context, {int parentId = 0, String? replyTo}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AskQuestionSheet(
        courseId: courseId,
        parentId: parentId,
        replyTo: replyTo,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (!isEnrolled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'سجّل في الكورس أولاً لعرض الأسئلة والأجوبة',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    final qnaAsync = ref.watch(qnaProvider(courseId));

    final askButton = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _openAskSheet(context),
          icon: const Icon(Icons.help_outline_rounded, size: 18),
          label: const Text('اطرح سؤالاً'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            side: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );

    final body = qnaAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorWidget(
        message: e.toString().replaceAll('Exception: ', ''),
      ),
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(qnaProvider(courseId)),
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
                  child: Text(
                    'لا توجد أسئلة بعد — كن أول من يسأل!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(qnaProvider(courseId)),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 28),
            itemBuilder: (_, i) => _QnaCard(
              item: items[i],
              onReply: () => _openAskSheet(
                context,
                parentId: items[i].id,
                replyTo: items[i].authorName,
              ),
            ),
          ),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [askButton, Expanded(child: body)],
    );
  }
}

class _QnaCard extends StatelessWidget {
  final QnaItem item;
  final VoidCallback onReply;
  const _QnaCard({required this.item, required this.onReply});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QnaBubble(item: item),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: onReply,
            icon: const Icon(Icons.reply_rounded, size: 16),
            label: const Text('رد'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }
}

class _QnaBubble extends StatelessWidget {
  final QnaItem item;
  const _QnaBubble({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAnswer = item.parentId > 0;
    final bubbleColor = isAnswer
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surface;
    return Container(
      margin: EdgeInsetsDirectional.only(
        start: isAnswer ? 36 : 0,
        end: 0,
        top: 6,
        bottom: 6,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: item.authorAvatar.isNotEmpty
                    ? CachedNetworkImageProvider(item.authorAvatar)
                    : null,
                child: item.authorAvatar.isEmpty
                    ? Text(item.authorName.isNotEmpty ? item.authorName[0] : '?')
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (item.isInstructor) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'مدرّس',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.content),
          if (!isAnswer && item.answers.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...item.answers.map((a) => _QnaBubble(item: a)),
          ],
        ],
      ),
    );
  }
}

class _AskQuestionSheet extends ConsumerStatefulWidget {
  final int courseId;
  final int parentId;
  final String? replyTo;
  const _AskQuestionSheet({
    required this.courseId,
    this.parentId = 0,
    this.replyTo,
  });

  @override
  ConsumerState<_AskQuestionSheet> createState() => _AskQuestionSheetState();
}

class _AskQuestionSheetState extends ConsumerState<_AskQuestionSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  bool get isReply => widget.parentId > 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await ref.read(postQnaProvider.notifier).post(
          courseId: widget.courseId,
          content: txt,
          parentId: widget.parentId,
        );

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        _loading = false;
        _error = ref.read(postQnaProvider).error ?? 'تعذر الإرسال';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: padding),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isReply
                    ? 'رد على: ${widget.replyTo ?? ''}'
                    : 'اطرح سؤالاً',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'اكتب هنا...',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(isReply ? 'إرسال الرد' : 'إرسال السؤال'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tab: Assignments ───────────────────────────────────────────────────────

class _AssignmentsTab extends ConsumerWidget {
  final int courseId;
  final bool isEnrolled;
  const _AssignmentsTab({required this.courseId, required this.isEnrolled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (!isEnrolled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_outlined,
                  size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              const Text('تظهر الواجبات بعد التسجيل في الدورة',
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final async = ref.watch(assignmentsProvider(courseId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorWidget(
        message: e.toString().replaceAll('Exception: ', ''),
        onRetry: () => ref.invalidate(assignmentsProvider(courseId)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_turned_in_outlined,
                      size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  const Text('لا توجد واجبات في هذه الدورة حتى الآن'),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(assignmentsProvider(courseId)),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) =>
                _AssignmentCard(assignment: items[i], courseId: courseId),
          ),
        );
      },
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final int courseId;
  const _AssignmentCard({required this.assignment, required this.courseId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = assignment;

    late final Color statusColor;
    late final String statusText;
    late final IconData statusIcon;
    if (a.isEvaluated) {
      statusColor = const Color(0xFF4A7C59);
      statusText = a.mark == null ? 'تم التقييم' : 'الدرجة: ${a.mark} / ${a.totalMark}';
      statusIcon = Icons.grade_rounded;
    } else if (a.isSubmitted) {
      statusColor = theme.colorScheme.primary;
      statusText = 'بانتظار التقييم';
      statusIcon = Icons.hourglass_top_rounded;
    } else {
      statusColor = const Color(0xFFE26D5C);
      statusText = 'لم يُسلّم بعد';
      statusIcon = Icons.upload_file_rounded;
    }

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _AssignmentSheet(
            assignmentId: a.id,
            courseId: courseId,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    a.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Icon(Icons.chevron_left_rounded,
                    color: theme.colorScheme.onSurfaceVariant),
              ]),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(statusIcon, size: 18, color: statusColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      statusText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignmentSheet extends ConsumerStatefulWidget {
  final int assignmentId;
  final int courseId;
  const _AssignmentSheet({required this.assignmentId, required this.courseId});

  @override
  ConsumerState<_AssignmentSheet> createState() => _AssignmentSheetState();
}

class _AssignmentSheetState extends ConsumerState<_AssignmentSheet> {
  final _answerCtrl = TextEditingController();

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = MediaQuery.of(context).viewInsets.bottom;
    final async = ref.watch(assignmentDetailProvider(widget.assignmentId));
    final submit = ref.watch(submitAssignmentProvider);

    ref.listen(submitAssignmentProvider, (_, next) {
      if (!mounted) return;
      if (next.error != null && next.error!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!.replaceAll('Exception: ', ''))),
        );
      }
    });

    return Padding(
      padding: EdgeInsets.only(bottom: padding),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: AppErrorWidget(
              message: e.toString().replaceAll('Exception: ', ''),
              onRetry: () => ref.invalidate(
                assignmentDetailProvider(widget.assignmentId),
              ),
            ),
          ),
          data: (a) {
            final sub = a.submission;
            if (sub != null && sub.submitted && _answerCtrl.text.isEmpty) {
              _answerCtrl.text = sub.answer;
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    a.title,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  if (a.content.isNotEmpty)
                    Text(a.content,
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _answerCtrl,
                    minLines: 4,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'إجابتك',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: submit.loading
                        ? null
                        : () async {
                            final ok = await ref
                                .read(submitAssignmentProvider.notifier)
                                .submit(
                                  assignmentId: widget.assignmentId,
                                  courseId: widget.courseId,
                                  answer: _answerCtrl.text.trim(),
                                  files: const [],
                                );
                            if (!mounted) return;
                            if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم إرسال الواجب')),
                              );
                              Navigator.pop(context);
                            }
                          },
                    icon: submit.loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded),
                    label: const Text('إرسال'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Tab: Quiz Attempts ───────────────────────────────────────────────────────

class _QuizAttemptsTab extends ConsumerWidget {
  final int courseId;
  final bool isEnrolled;
  const _QuizAttemptsTab({required this.courseId, required this.isEnrolled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (!isEnrolled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.quiz_outlined,
                  size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              const Text('تظهر محاولات الاختبار بعد التسجيل في الدورة',
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    final async = ref.watch(quizAttemptsProvider(courseId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorWidget(
        message: e.toString().replaceAll('Exception: ', ''),
        onRetry: () => ref.invalidate(quizAttemptsProvider(courseId)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fact_check_outlined,
                      size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  const Text('لا توجد محاولات اختبار حتى الآن',
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(quizAttemptsProvider(courseId)),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _QuizAttemptCard(attempt: items[i]),
          ),
        );
      },
    );
  }
}

class _QuizAttemptCard extends StatelessWidget {
  final QuizAttempt attempt;
  const _QuizAttemptCard({required this.attempt});

  String _fmtDate(String raw) {
    if (raw.isEmpty) return '';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} - ${two(d.hour)}:${two(d.minute)}';
  }

  String _num(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

  Widget _miniInfo(IconData icon, String text, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = attempt;
    final Color statusColor;
    final String statusText;
    final IconData statusIcon;
    if (a.isPassed == true) {
      statusColor = const Color(0xFF4A7C59);
      statusText = 'ناجح';
      statusIcon = Icons.check_circle_rounded;
    } else if (a.isPassed == false) {
      statusColor = const Color(0xFFB83232);
      statusText = 'لم يجتَز';
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = theme.colorScheme.primary;
      statusText = 'مكتمل';
      statusIcon = Icons.check_circle_outline_rounded;
    }
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.quizTitle.isEmpty ? 'اختبار' : a.quizTitle,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(statusText,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: statusColor,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                Text('${_num(a.percent)}%',
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: statusColor, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _miniInfo(Icons.grade_rounded,
                    'الدرجة: ${_num(a.earnedMarks)} / ${_num(a.totalMarks)}', theme),
                _miniInfo(Icons.list_alt_rounded,
                    'الأسئلة: ${a.answered} / ${a.totalQuestions}', theme),
                if (a.endedAt.isNotEmpty)
                  _miniInfo(Icons.event_rounded, _fmtDate(a.endedAt), theme)
                else if (a.startedAt.isNotEmpty)
                  _miniInfo(Icons.event_rounded, _fmtDate(a.startedAt), theme),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Persistent TabBar ─────────────────────────────────────────────────────────

// ── Info Chip ─────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  const _InfoChip({required this.icon, required this.label, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: filled ? Colors.white : color),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700).copyWith(
              color: filled ? Colors.white : color,
            ),
          ),
        ]),
      );
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: TabBarTheme(
          data: TabBarThemeData(
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            indicatorColor: Theme.of(context).colorScheme.primary,
            dividerColor: Theme.of(context).dividerColor,
          ),
          child: tabBar,
        ),
      );

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}
