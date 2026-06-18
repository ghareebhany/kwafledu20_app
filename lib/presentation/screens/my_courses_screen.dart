import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_widget.dart';
import '../providers/dashboard_provider.dart';

class MyCoursesScreen extends ConsumerStatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  ConsumerState<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends ConsumerState<MyCoursesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  static const _tabs = [
    (label: 'الكل',      status: 'all'),
    (label: 'قيد التعلم', status: 'active'),
    (label: 'المكتملة',   status: 'completed'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'دوراتي',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        children: List.generate(_tabs.length, (i) {
                          final selected = _tabCtrl.index == i;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _tabCtrl.animateTo(i);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: selected ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                child: Text(
                                  _tabs[i].label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                                    color: selected ? AppTheme.brandRed : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: _tabs.map((t) => _CoursesList(status: t.status)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoursesList extends ConsumerStatefulWidget {
  final String status;
  const _CoursesList({required this.status});

  @override
  ConsumerState<_CoursesList> createState() => _CoursesListState();
}

class _CoursesListState extends ConsumerState<_CoursesList> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final filter   = MyCoursesFilter(status: widget.status, page: _page);
    final async    = ref.watch(myCourseItemsProvider(filter));
    final theme    = Theme.of(context);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorWidget(
        message: e.toString().replaceAll('Exception: ', ''),
        onRetry: () => ref.invalidate(myCourseItemsProvider(filter)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                Text(
                  widget.status == 'completed'
                      ? 'لم تكمل أي دورة بعد'
                      : widget.status == 'active'
                          ? 'لا توجد دورات قيد التعلم'
                          : 'لم تسجّل في أي دورة بعد',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
                if (widget.status == 'all') ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.go('/courses'),
                    icon: const Icon(Icons.explore_rounded),
                    label: const Text('تصفح الدورات'),
                  ),
                ],
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myCourseItemsProvider(filter)),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _MyCourseCard(item: items[i]),
          ),
        );
      },
    );
  }
}

// ── بطاقة الكورس (UX محسّن: Progress أولاً ثم CTA) ────────────────────────────

class _MyCourseCard extends StatelessWidget {
  final MyCourseItem item;
  const _MyCourseCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final course     = item.course;
    final completed  = item.isCourseCompleted;

    return GestureDetector(
      onTap: () => context.push('/course/${course.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ تحسين 3: صورة مع gradient overlay (Netflix style)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: course.thumbnail.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: course.thumbnail,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 250),
                            fadeOutDuration: const Duration(milliseconds: 150),
                            placeholder: (_, __) => Container(
                              color: const Color(0xFFF5F5F5),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFFFFE4E5),
                              child: const Icon(
                                Icons.school_rounded,
                                color: AppTheme.brandRed,
                                size: 48,
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFFFE4E5),
                            child: const Icon(
                              Icons.school_rounded,
                              color: AppTheme.brandRed,
                              size: 48,
                            ),
                          ),
                  ),
                ),
                // ✅ Gradient overlay للعمق (Netflix style)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                if (completed)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF111827),
                      height: 1.3,
                    ),
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // ✅ تحسين 2: اسم المعلم مع أيقونة محسنة
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: course.instructorId > 0
                        ? () => context.push('/instructor/${course.instructorId}')
                        : null,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          size: 14,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            course.instructorName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // ✅ تحسين 1: Progress bar أولاً (قبل CTA)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: completed 
                                  ? Colors.green.withValues(alpha: 0.08)
                                  : AppTheme.brandRed.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              completed ? 'مكتملة' : '${item.completedPercent}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: completed ? Colors.green : AppTheme.brandRed,
                              ),
                            ),
                          ),
                          Text(
                            '${item.completedLessons}/${course.totalLessons} درس',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: item.completedPercent / 100,
                          minHeight: 4,
                          backgroundColor: const Color(0xFFF0EAE0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            completed ? Colors.green : AppTheme.brandRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 14),
                  
                  // ✅ تحسين 4: CTA مختلف حسب الحالة (Filled / Outlined)
                  // ✅ تحسين 5: ElevatedButton بدل FilledButton
                  if (completed)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/lessons/${course.id}'),
                        icon: const Icon(Icons.replay_rounded, size: 18),
                        label: const Text(
                          'مراجعة الدورة',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/lessons/${course.id}'),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text(
                          'استكمال التعلم',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandRed,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
