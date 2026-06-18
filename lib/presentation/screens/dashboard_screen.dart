import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_widget.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/notifications_provider.dart';
import 'notifications_screen.dart';

/// رسالة الترحيب حسب الوقت
String _greeting() {
  final h = DateTime.now().hour;
  if (h >= 5 && h < 12) return 'صباح الخير';
  if (h >= 12 && h < 17) return 'مساء النور';
  if (h >= 17 && h < 21) return 'مساء الخير';
  return 'تصبح على خير';
}

/// أيقونة الوقت
IconData _greetingIcon() {
  final h = DateTime.now().hour;
  if (h >= 5 && h < 12) return Icons.wb_sunny_rounded;
  if (h >= 12 && h < 17) return Icons.light_mode_rounded;
  if (h >= 17 && h < 21) return Icons.nights_stay_rounded;
  return Icons.bedtime_rounded;
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final dashAsync = ref.watch(dashboardProvider);
    final unread = ref.watch(notificationsProvider).maybeWhen(
          data: (b) => b.unreadCount,
          orElse: () => 0,
        );

    // ✅ الحصول على المستخدم مباشرة من authState
    final currentUser = authState is AuthAuthenticated ? authState.user : null;
    
    // ✅ اسم المستخدم مع منطق قوي
    String getDisplayName() {
      final name = (currentUser?.displayName ?? '').trim();
      if (name.isNotEmpty) return name;

      final email = (currentUser?.email ?? '').trim();
      if (email.isNotEmpty) {
        final atIndex = email.indexOf('@');
        if (atIndex > 0) return email.substring(0, atIndex);
        return email;
      }

      return 'أهلاً بك';
    }
    
    final String displayName = getDisplayName();
    final userId = currentUser?.id ?? 0;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          ref.invalidate(notificationsProvider);
          if (userId > 0) {
            ref.invalidate(profileProvider(userId));
          }
        },
        child: CustomScrollView(
          slivers: [
            // ── SliverAppBar ────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 135,
              pinned: true,
              elevation: 0,
              backgroundColor: AppTheme.brandRed,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE52027),
                        Color(0xFFBF1219),
                        Color(0xFF8B0D12),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // ── Top Row: Avatar + Greeting + Actions ─────────────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // ✅ Avatar مستقلة - لا تسبب إعادة بناء الـ AppBar
                              if (userId > 0)
                                Consumer(
                                  builder: (context, ref, _) {
                                    final profileAsync = ref.watch(profileProvider(userId));

                                    return profileAsync.when(
                                      loading: () => const _AvatarPlaceholder(initials: ''),
                                      error: (_, __) => const _AvatarPlaceholder(initials: '?'),
                                      data: (user) {
                                        final avatarUrl = user.avatarUrl;

                                        if (avatarUrl.isNotEmpty) {
                                          return _NetworkAvatar(url: avatarUrl);
                                        }

                                        final name = user.displayName.trim();
                                        final email = currentUser?.email.trim() ?? '';

                                        final initials = name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : email.isNotEmpty
                                                ? email[0].toUpperCase()
                                                : '؟';

                                        return _AvatarPlaceholder(initials: initials);
                                      },
                                    );
                                  },
                                )
                              else
                                const _AvatarPlaceholder(initials: ''),

                              // ✅ زيادة المسافة بين الصورة والنص
                              const SizedBox(width: 14),

                              // ── Greeting text (محسن الخط والمسافات) ───────────────
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // وقت اليوم - خط Bold وحجم أكبر
                                    Row(
                                      children: [
                                        Icon(
                                          _greetingIcon(),
                                          color: Colors.white70,
                                          size: 16,  // ✅ تكبير الأيقونة قليلاً
                                        ),
                                        const SizedBox(width: 6),  // ✅ زيادة المسافة قليلاً
                                        Text(
                                          _greeting(),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 15,  // ✅ من 12 إلى 15 (أكبر)
                                            fontWeight: FontWeight.w700,  // ✅ من w500 إلى w700 (Bold)
                                            letterSpacing: 0.3,  // ✅ إضافة تباعد بسيط للحروف
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),  // ✅ زيادة المسافة قليلاً بين التحية والاسم
                                    // اسم المستخدم
                                    Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,  // ✅ من 17 إلى 18 (أكبر قليلاً)
                                        fontWeight: FontWeight.w800,  // ✅ أقوى من التحية بقليل
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ── Actions ──────────────────────────────────────────
                              IconButton(
                                icon: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Icon(Icons.notifications_none_rounded,
                                        color: Colors.white),
                                    if (unread > 0)
                                      Positioned(
                                        top: -4,
                                        right: -4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE26D5C),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                                color: Colors.white, width: 1),
                                          ),
                                          child: Text(
                                            unread > 99 ? '99+' : '$unread',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                onPressed: () {
                                  Navigator.of(context)
                                      .push(
                                    MaterialPageRoute(
                                      builder: (_) => const NotificationsScreen(),
                                    ),
                                  )
                                      .then((_) {
                                    // after marking read inside screen
                                    ref.invalidate(notificationsProvider);
                                  });
                                },
                                tooltip: 'الإشعارات',
                              ),
                              IconButton(
                                icon: const Icon(Icons.logout_rounded,
                                    color: Colors.white),
                                onPressed: () async {
                                  final ok = await _confirmLogout(context);
                                  if (ok == true) {
                                    await ref.read(authProvider.notifier).logout();
                                  }
                                },
                                tooltip: 'تسجيل الخروج',
                              ),
                            ],
                          ),

                          // ── Bottom subtitle ──────────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              'تابع تقدمك اليوم واستمر في التعلم 🎯',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Stats ───────────────────────────────────────────────────
            dashAsync.when(
              loading: () => const SliverToBoxAdapter(
                  child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()))),
              error: (e, _) => SliverToBoxAdapter(
                  child: AppErrorWidget(
                      message: e.toString().replaceAll('Exception: ', ''),
                      onRetry: () => ref.invalidate(dashboardProvider))),
              data: (stats) => SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text('إحصائياتك',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      Expanded(
                          child: _StatCard(
                              icon: Icons.book_outlined,
                              label: 'مسجّل فيها',
                              value: '${stats.enrolledCount}',
                              color: theme.colorScheme.primary)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _StatCard(
                              icon: Icons.play_circle_outline,
                              label: 'قيد التعلم',
                              value: '${stats.activeCount}',
                              color: Colors.orange)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _StatCard(
                              icon: Icons.check_circle_outline,
                              label: 'مكتملة',
                              value: '${stats.completedCount}',
                              color: Colors.green)),
                    ]),
                  ),

                  if (stats.inProgress.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
                      child: Row(children: [
                        Text('استكمل تعلمك',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => context.push('/my-courses'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.brandRed.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('عرض الكل',
                                style: TextStyle(
                                    color: AppTheme.brandRed,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ]),
                    ),
                    ...stats.inProgress.map((c) => _InProgressCard(item: c)),
                    const SizedBox(height: 8),
                  ],

                  if (stats.enrolledCount == 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 4))
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppTheme.brandRed.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.school_rounded,
                                  size: 36, color: AppTheme.brandRed),
                            ),
                            const SizedBox(height: 16),
                            const Text('ابدأ رحلتك التعليمية',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text('لم تسجّل في أي دورة بعد',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    height: 1.5)),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: () => context.go('/courses'),
                              icon: const Icon(Icons.explore_rounded),
                              label: const Text('تصفح الدورات'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmLogout(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل تريد تسجيل الخروج؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('خروج'),
            ),
          ],
        ),
      );
}

// ── بطاقة إحصاء ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.9), color],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 10),
        Text(value,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ── بطاقة كورس قيد التقدم ────────────────────────────────────────────────────

class _InProgressCard extends StatelessWidget {
  final InProgressCourse item;
  const _InProgressCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => context.push('/course/${item.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(16)),
            child: item.thumbnail.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: item.thumbnail,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                        width: 90,
                        height: 90,
                        color: theme.colorScheme.primaryContainer,
                        child: Icon(Icons.play_circle_outline,
                            color: theme.colorScheme.primary)),
                  )
                : Container(
                    width: 90,
                    height: 90,
                    color: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.play_circle_outline,
                        color: theme.colorScheme.primary)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: item.completedPercent / 100,
                      minHeight: 7,
                      backgroundColor: const Color(0xFFFFDADB),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.brandRed),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text(
                      '${item.completedLessons}/${item.totalLessons} درس',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9A9490)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.brandRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${item.completedPercent}%',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brandRed),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
        ]),
      ),
    );
  }
}

// ── Avatar: صورة من الشبكة ────────────────────────────────────────────────────
class _NetworkAvatar extends StatelessWidget {
  final String url;
  const _NetworkAvatar({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => const _AvatarPlaceholder(initials: ''),
          errorWidget: (_, __, ___) => const _AvatarPlaceholder(initials: '?'),
        ),
      ),
    );
  }
}

// ── Avatar: حرف أولي (fallback) ───────────────────────────────────────────────
class _AvatarPlaceholder extends StatelessWidget {
  final String initials;
  const _AvatarPlaceholder({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
      ),
      alignment: Alignment.center,
      child: initials.isEmpty
          ? const Icon(Icons.person_rounded, color: Colors.white, size: 24)
          : Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}
