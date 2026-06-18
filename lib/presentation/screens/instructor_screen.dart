import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/error_widget.dart';
import '../providers/profile_provider.dart';
import '../widgets/course_card.dart';

class InstructorScreen extends ConsumerWidget {
  final int instructorId;
  const InstructorScreen({super.key, required this.instructorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instructorAsync = ref.watch(instructorProvider(instructorId));
    final theme = Theme.of(context);

    return Scaffold(
      body: instructorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: AppErrorWidget(
            message: e.toString().replaceAll('Exception: ', ''),
            onRetry: () => ref.invalidate(instructorProvider(instructorId)),
          ),
        ),
        data: (instructor) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    instructor.avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: instructor.avatarUrl,
                            fit: BoxFit.cover,
                          )
                        : Container(color: theme.colorScheme.primaryContainer),
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                title: Text(
                  instructor.displayName,
                  style: const TextStyle(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + email
                    Text(
                      instructor.displayName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold),
                    ),
                    if (instructor.email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.email_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                        const SizedBox(width: 6),
                        Text(instructor.email,
                            style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6))),
                      ]),
                    ],
                    if (instructor.website.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.link,
                            size: 16,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(instructor.website,
                            style: TextStyle(
                                color: theme.colorScheme.primary)),
                      ]),
                    ],
                    if (instructor.bio.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('نبذة عن المدرب',
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              )),
                      const SizedBox(height: 8),
                      Text(
                        instructor.bio,
                        style: const TextStyle(
                            fontSize: 15,
                            height: 1.8),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text('كورسات المحاضر',
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _InstructorCourses(instructorId: instructorId),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _InstructorCourses extends ConsumerWidget {
  final int instructorId;
  const _InstructorCourses({required this.instructorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final coursesAsync = ref.watch(instructorCoursesProvider(instructorId));

    return coursesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'تعذّر تحميل الكورسات',
          style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
      ),
      data: (page) {
        if (page.courses.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'لا توجد كورسات لهذا المحاضر حاليًا',
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: page.courses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (_, i) {
            final course = page.courses[i];
            return CourseCard(
              course: course,
              onTap: () => context.push('/course/${course.id}'),
            );
          },
        );
      },
    );
  }
}
