import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/error_widget.dart';
import '../../core/utils/cache_manager.dart';
import '../../data/datasources/notifications_remote_ds.dart';
import '../../domain/entities/notification.dart';
import '../providers/notifications_provider.dart';
// No DI usecases in this app; call remote DS via providers.

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _marked = false;

  @override
  void initState() {
    super.initState();
    // اجلب أحدث الإشعارات فور فتح الشاشة (قد تكون النسخة المخزّنة قديمة)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(notificationsProvider);
        // امسح الكاش المؤقت للأسئلة حتى تظهر ردود الإدارة فور فتح الكورس
        CacheManager.instance.invalidatePattern('qna_');
      }
    });
  }

  Future<void> _markRead() async {
    if (_marked) return;
    _marked = true;
    await NotificationsRemoteDataSource.instance.markRead();
    if (mounted) ref.invalidate(notificationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorWidget(
          message: e.toString().replaceAll('Exception: ', ''),
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (bundle) {
          if (bundle.unreadCount > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
          }
          if (bundle.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_off_outlined,
                        size: 60, color: theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    const Text('لا توجد إشعارات حتى الآن',
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bundle.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) =>
                  _NotificationCard(item: bundle.items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification item;
  const _NotificationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReply = item.type == 'qna_reply';
    final color =
        isReply ? const Color(0xFFE26D5C) : theme.colorScheme.primary;
    final icon =
        isReply ? Icons.question_answer_rounded : Icons.campaign_rounded;
    return Material(
      color: item.isRead
          ? theme.colorScheme.surface
          : theme.colorScheme.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: item.courseId > 0
            ? () => context.push('/course/${item.courseId}')
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.title,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE26D5C),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(item.message,
                        style: theme.textTheme.bodySmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    if (item.courseTitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.menu_book_rounded,
                              size: 13,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(item.courseTitle,
                                style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        theme.colorScheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
