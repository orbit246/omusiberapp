import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/backend/post_view.dart';
import 'package:omusiber/backend/schedule_service.dart';
import 'package:omusiber/backend/user_profile_service.dart';
import 'package:omusiber/backend/view/community_post_model.dart';
import 'package:omusiber/backend/view/news_view.dart';
import 'package:omusiber/backend/view/schedule_model.dart';
import 'package:omusiber/pages/new_view/community_post_detail_page.dart';
import 'package:omusiber/pages/new_view/controllers/community_tab_controller.dart';
import 'package:omusiber/pages/new_view/controllers/events_tab_controller.dart';
import 'package:omusiber/pages/new_view/controllers/news_tab_controller.dart';
import 'package:omusiber/pages/news_item_page.dart';
import 'package:omusiber/pages/removed/event_details_page.dart';
import 'package:omusiber/pages/schedule_page.dart';
import 'package:omusiber/pages/new_view/events_tab_view.dart';
import 'package:omusiber/widgets/shared/app_skeleton.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key, required this.onOpenPage});

  final ValueChanged<int> onOpenPage;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  late final NewsTabController _newsController;
  late final EventsTabController _eventsController;
  late final CommunityTabController _communityController;
  final UserProfileService _profileService = UserProfileService();
  late Future<_TodayScheduleData> _todayScheduleFuture;
  final PageController _newsPageController = PageController();
  final PageController _schedulePageController = PageController();
  Timer? _newsCarouselTimer;
  Timer? _scheduleClockTimer;
  Timer? _scheduleCarouselTimer;
  int _schedulePageIndex = 0;
  int _newsPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _newsController = NewsTabController()..addListener(_handleDataChanged);
    _eventsController = EventsTabController()..addListener(_handleDataChanged);
    _communityController = CommunityTabController()
      ..addListener(_handleDataChanged);
    _todayScheduleFuture = _loadTodaySchedule();
    _scheduleClockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _scheduleCarouselTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || !_schedulePageController.hasClients) return;
      unawaited(_advanceScheduleCarousel());
    });
    _newsCarouselTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_newsPageController.hasClients) return;
      final count = _recentNews.length;
      if (count < 2) return;
      final nextPage = _newsPageIndex + 1;
      _newsPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadInitialData());
    });
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _newsController.loadInitialData(),
      _eventsController.loadInitialData(),
      _communityController.loadInitialData(),
    ]);
  }

  void _handleDataChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    setState(() {
      _todayScheduleFuture = _loadTodaySchedule();
    });
    await Future.wait([
      _newsController.refreshFromUser(),
      _eventsController.refresh(),
      _communityController.refresh(),
    ]);
  }

  List<NewsView> get _recentNews {
    final items = [..._newsController.articles];
    items.sort((a, b) => _dateOfNews(b).compareTo(_dateOfNews(a)));
    return items.take(5).toList();
  }

  List<PostView> get _closestEvents {
    final now = DateTime.now();
    final items = [..._eventsController.events];
    items.sort((a, b) {
      final aDate = a.eventDate;
      final bDate = b.eventDate;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      final aUpcoming = !aDate.isBefore(now);
      final bUpcoming = !bDate.isBefore(now);
      if (aUpcoming != bUpcoming) return aUpcoming ? -1 : 1;
      return aUpcoming ? aDate.compareTo(bDate) : bDate.compareTo(aDate);
    });
    return items.take(6).toList();
  }

  List<CommunityPost> get _recentPosts {
    final posts = [..._communityController.posts]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts.take(4).toList();
  }

  DateTime _dateOfNews(NewsView item) {
    return item.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Günaydın!';
    if (hour < 18) return 'İyi günler!';
    return 'İyi akşamlar!';
  }

  void _openNews(NewsView item) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => NewsItemPage(view: item)));
  }

  void _openEvent(PostView event) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EventDetailsPage(event: event)));
  }

  void _openPost(CommunityPost post) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CommunityPostDetailPage(post: post)),
    );
  }

  @override
  void dispose() {
    _newsController.removeListener(_handleDataChanged);
    _eventsController.removeListener(_handleDataChanged);
    _communityController.removeListener(_handleDataChanged);
    _newsController.dispose();
    _eventsController.dispose();
    _communityController.dispose();
    _newsCarouselTimer?.cancel();
    _scheduleClockTimer?.cancel();
    _scheduleCarouselTimer?.cancel();
    _newsPageController.dispose();
    _schedulePageController.dispose();
    super.dispose();
  }

  Future<void> _advanceScheduleCarousel() async {
    final data = await _todayScheduleFuture;
    final count = data.carouselLessons.length;
    if (!mounted || count < 2 || !_schedulePageController.hasClients) return;
    final nextPage = (_schedulePageIndex + 1) % count;
    await _schedulePageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<_TodayScheduleData> _loadTodaySchedule() async {
    try {
      final user = AppStartupController.instance.isFirebaseReady
          ? FirebaseAuth.instance.currentUser
          : null;
      final profile = user == null
          ? null
          : await _profileService.fetchUserProfile(
              user.uid,
              includeBadges: false,
            );
      final schedules = await ScheduleService().fetchSchedules(
        departmentKey: profile?.departmentKey,
      );

      if (schedules.isEmpty) return const _TodayScheduleData();

      final program = schedules.firstWhere(
        (schedule) => schedule.academicContext?.hasScheduleMatch == true,
        orElse: () => schedules.first,
      );
      final preferredKeys = <String>[
        if (program.academicContext?.classKey case final key?) key,
        if (profile?.gradeKey case final key?) key,
        ...program.preferredClassKeys,
      ];
      String? classKey;
      for (final key in preferredKeys) {
        if (program.hasLessonsForClassKey(key)) {
          classKey = key;
          break;
        }
      }
      classKey ??= program.classesByKey.keys.firstOrNull;
      if (classKey == null) return const _TodayScheduleData();

      final classSchedule = program.scheduleForClassKey(classKey);
      final todayKey = _todayDayKey();
      final lessons = _lessonsForDay(
        classSchedule,
        todayKey,
        dayLabel: 'Bugün',
      );
      final upcomingLessons = _findUpcomingLessons(classSchedule);
      final nextUpcoming = _findNextUpcomingLesson(classSchedule);

      return _TodayScheduleData(
        lessons: lessons,
        upcomingLessons: upcomingLessons,
        nextUpcoming: nextUpcoming,
      );
    } catch (error) {
      debugPrint('Today schedule load failed: $error');
      return const _TodayScheduleData(hasError: true);
    }
  }

  String _todayDayKey() {
    const keys = <String>[
      'PAZARTESI',
      'SALI',
      'CARSAMBA',
      'PERSEMBE',
      'CUMA',
      'CUMARTESI',
      'PAZAR',
    ];
    return keys[DateTime.now().weekday - 1];
  }

  List<_TodayLesson> _lessonsForDay(
    Map<String, List<ScheduleLesson>> classSchedule,
    String dayKey, {
    required String dayLabel,
    int dayOffset = 0,
  }) {
    final rawLessons = <ScheduleLesson>[];
    for (final entry in classSchedule.entries) {
      if (_normalizeDayKey(entry.key) == dayKey) {
        rawLessons.addAll(entry.value);
      }
    }
    final lessons = rawLessons
        .map(
          (lesson) => _TodayLesson.fromScheduleLesson(
            lesson,
            dayLabel: dayLabel,
            dayOffset: dayOffset,
          ),
        )
        .whereType<_TodayLesson>()
        .toList();
    lessons.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return lessons;
  }

  _TodayLesson? _findNextUpcomingLesson(
    Map<String, List<ScheduleLesson>> classSchedule,
  ) {
    const dayKeys = <String>[
      'PAZARTESI',
      'SALI',
      'CARSAMBA',
      'PERSEMBE',
      'CUMA',
      'CUMARTESI',
      'PAZAR',
    ];
    const dayLabels = <String>[
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];
    final todayIndex = DateTime.now().weekday - 1;
    for (var offset = 1; offset <= dayKeys.length; offset++) {
      final index = (todayIndex + offset) % dayKeys.length;
      final lessons = _lessonsForDay(
        classSchedule,
        dayKeys[index],
        dayLabel: dayLabels[index],
        dayOffset: offset,
      );
      if (lessons.isNotEmpty) return lessons.first;
    }
    return null;
  }

  List<_TodayLesson> _findUpcomingLessons(
    Map<String, List<ScheduleLesson>> classSchedule,
  ) {
    const dayKeys = <String>[
      'PAZARTESI',
      'SALI',
      'CARSAMBA',
      'PERSEMBE',
      'CUMA',
      'CUMARTESI',
      'PAZAR',
    ];
    const dayLabels = <String>[
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];
    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    final todayIndex = DateTime.now().weekday - 1;
    final upcoming = <_TodayLesson>[];

    for (var offset = 0; offset < dayKeys.length; offset++) {
      final index = (todayIndex + offset) % dayKeys.length;
      final dayLessons = _lessonsForDay(
        classSchedule,
        dayKeys[index],
        dayLabel: offset == 0 ? 'Bugün' : dayLabels[index],
        dayOffset: offset,
      );
      upcoming.addAll(
        dayLessons.where(
          (lesson) => offset > 0 || lesson.endMinutes > nowMinutes,
        ),
      );
    }

    upcoming.sort((left, right) {
      final dayDifference = left.dayOffset.compareTo(right.dayOffset);
      return dayDifference == 0
          ? left.startMinutes.compareTo(right.startMinutes)
          : dayDifference;
    });
    return upcoming.take(5).toList(growable: false);
  }

  String _normalizeDayKey(String value) {
    return value
        .toUpperCase()
        .replaceAll('İ', 'I')
        .replaceAll('Ş', 'S')
        .replaceAll('Ç', 'C')
        .replaceAll('Ü', 'U')
        .replaceAll('Ö', 'O')
        .replaceAll('Ğ', 'G')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final recentNews = _recentNews;
    final closestEvents = _closestEvents;
    final recentPosts = _recentPosts;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: cs.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 132),
        children: [
          Text(
            _greeting(),
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kampüste bugün neler var?',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          _TodaySectionHeader(
            title: 'Ders Programı',
            actionLabel: 'Programı Gör',
            onAction: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SchedulePage()));
            },
          ),
          const SizedBox(height: 10),
          FutureBuilder<_TodayScheduleData>(
            future: _todayScheduleFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _TodayScheduleCard.loading();
              }
              return _TodayScheduleCard(
                data: snapshot.data ?? const _TodayScheduleData(hasError: true),
                controller: _schedulePageController,
                activeIndex: _schedulePageIndex,
                onPageChanged: (index) {
                  if (mounted) setState(() => _schedulePageIndex = index);
                },
              );
            },
          ),
          const SizedBox(height: 24),
          _TodaySectionHeader(
            title: 'Son Haberler',
            actionLabel: 'Tümünü Gör',
            onAction: () => widget.onOpenPage(1),
          ),
          const SizedBox(height: 10),
          if (_newsController.isNewsLoading && recentNews.isEmpty)
            const _TodayNewsSkeleton()
          else if (recentNews.isEmpty)
            const _TodayEmptyCard(message: 'Henüz haber bulunamadı.')
          else
            Column(
              children: [
                SizedBox(
                  height: 154,
                  child: PageView.builder(
                    controller: _newsPageController,
                    itemCount: null,
                    onPageChanged: (index) {
                      if (mounted) setState(() => _newsPageIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final news = recentNews[index % recentNews.length];
                      return _TodayNewsCard(
                        news: news,
                        onTap: () => _openNews(news),
                      );
                    },
                  ),
                ),
                if (recentNews.length > 1) ...[
                  const SizedBox(height: 10),
                  _TodayNewsDots(
                    count: recentNews.length,
                    activeIndex: _newsPageIndex % recentNews.length,
                  ),
                ],
              ],
            ),
          const SizedBox(height: 26),
          _TodaySectionHeader(
            title: 'Bugün Öne Çıkan Etkinlikler',
            actionLabel: 'Tümünü Gör',
            onAction: () => widget.onOpenPage(2),
          ),
          const SizedBox(height: 10),
          if (_eventsController.isInitialLoading && closestEvents.isEmpty)
            const SizedBox(height: 230, child: _TodayEventSkeleton())
          else if (closestEvents.isEmpty)
            const _TodayEmptyCard(message: 'Yaklaşan etkinlik bulunamadı.')
          else
            SizedBox(
              height: 244,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: closestEvents.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final event = closestEvents[index];
                  return _TodayEventCard(
                    event: event,
                    onTap: () => _openEvent(event),
                  );
                },
              ),
            ),
          const SizedBox(height: 26),
          _TodaySectionHeader(
            title: 'Topluluktan Son Paylaşımlar',
            actionLabel: 'Topluluğa Git',
            onAction: () => widget.onOpenPage(3),
          ),
          const SizedBox(height: 10),
          if (_communityController.isLoading && recentPosts.isEmpty)
            const SizedBox(height: 144, child: _TodayCommunitySkeleton())
          else if (recentPosts.isEmpty)
            const _TodayEmptyCard(message: 'Henüz topluluk paylaşımı yok.')
          else
            SizedBox(
              height: 158,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recentPosts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final post = recentPosts[index];
                  return _TodayCommunityCard(
                    post: post,
                    onTap: () => _openPost(post),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TodayScheduleCard extends StatelessWidget {
  const _TodayScheduleCard({
    required this.data,
    required this.controller,
    required this.activeIndex,
    required this.onPageChanged,
  }) : _loading = false;

  const _TodayScheduleCard.loading()
    : data = const _TodayScheduleData(),
      controller = null,
      activeIndex = 0,
      onPageChanged = null,
      _loading = true;

  final _TodayScheduleData data;
  final PageController? controller;
  final int activeIndex;
  final ValueChanged<int>? onPageChanged;
  final bool _loading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = data.status;
    final accent = status.isBreak ? const Color(0xFF8B5CF6) : cs.primary;
    final lessons = data.carouselLessons;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(20),
          ),
          child: _loading
              ? Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: cs.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Ders programı yükleniyor...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              : lessons.isEmpty
              ? _TodayScheduleLessonTile(status: status, accent: accent)
              : SizedBox(
                  height: 112,
                  child: PageView.builder(
                    controller: controller,
                    itemCount: lessons.length,
                    onPageChanged: onPageChanged,
                    itemBuilder: (context, index) {
                      final lesson = lessons[index];
                      final lessonStatus = data.statusForLesson(lesson);
                      final lessonAccent = lessonStatus.isBreak
                          ? const Color(0xFF8B5CF6)
                          : cs.primary;
                      return _TodayScheduleLessonTile(
                        status: lessonStatus,
                        accent: lessonAccent,
                      );
                    },
                  ),
                ),
        ),
        if (lessons.length > 1) ...[
          const SizedBox(height: 10),
          _TodayNewsDots(
            count: lessons.length,
            activeIndex: activeIndex.clamp(0, lessons.length - 1),
          ),
        ],
      ],
    );
  }
}

class _TodayScheduleLessonTile extends StatelessWidget {
  const _TodayScheduleLessonTile({required this.status, required this.accent});

  final _TodayScheduleStatus status;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(status.icon, color: accent, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        status.label,
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (status.timeLabel != null)
                      Text(
                        status.timeLabel!,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  status.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (status.lecturer != null &&
                    status.lecturer!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    status.lecturer!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.82),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayScheduleData {
  const _TodayScheduleData({
    this.lessons = const [],
    this.upcomingLessons = const [],
    this.nextUpcoming,
    this.hasError = false,
  });

  final List<_TodayLesson> lessons;
  final List<_TodayLesson> upcomingLessons;
  final _TodayLesson? nextUpcoming;
  final bool hasError;

  List<_TodayLesson> get carouselLessons {
    if (upcomingLessons.isNotEmpty) return upcomingLessons;
    if (lessons.isEmpty) {
      return nextUpcoming == null ? const [] : [nextUpcoming!];
    }

    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    final remaining = lessons.any((lesson) => lesson.endMinutes > nowMinutes);
    if (!remaining && nextUpcoming != null) return [nextUpcoming!];

    final sorted = [...lessons];
    sorted.sort((left, right) {
      int phase(_TodayLesson lesson) {
        if (nowMinutes >= lesson.startMinutes &&
            nowMinutes < lesson.endMinutes) {
          return 0;
        }
        if (lesson.startMinutes > nowMinutes) return 1;
        return 2;
      }

      final phaseDifference = phase(left).compareTo(phase(right));
      return phaseDifference == 0
          ? left.startMinutes.compareTo(right.startMinutes)
          : phaseDifference;
    });
    return sorted;
  }

  _TodayScheduleStatus statusForLesson(_TodayLesson lesson) {
    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    if (lesson.dayOffset > 0) {
      return _TodayScheduleStatus(
        title: lesson.name,
        subtitle:
            '${lesson.dayLabel} • ${lesson.classroom.isEmpty ? 'Ders' : lesson.classroom}',
        timeLabel: lesson.startLabel,
        icon: Icons.menu_book_rounded,
        label: _relativeDayLabel(lesson.dayOffset),
        lecturer: lesson.instructor,
      );
    }

    final isCurrent =
        nowMinutes >= lesson.startMinutes && nowMinutes < lesson.endMinutes;
    final isUpcoming = nowMinutes < lesson.startMinutes;
    final isNextUpcoming =
        isUpcoming &&
        lessons.every(
          (item) => item == lesson || item.startMinutes <= nowMinutes,
        );
    return _TodayScheduleStatus(
      title: lesson.name,
      subtitle: lesson.classroom.isEmpty
          ? 'Ders ${lesson.startLabel}–${lesson.endLabel}'
          : '${lesson.startLabel}–${lesson.endLabel} • ${lesson.classroom}',
      timeLabel: '${lesson.startLabel}–${lesson.endLabel}',
      icon: isCurrent
          ? Icons.menu_book_rounded
          : isUpcoming
          ? Icons.menu_book_rounded
          : Icons.check_circle_outline_rounded,
      label: isCurrent
          ? 'Şimdi'
          : isNextUpcoming
          ? 'Sıradaki'
          : isUpcoming
          ? 'Daha sonra'
          : 'Tamamlandı',
      lecturer: lesson.instructor,
    );
  }

  _TodayScheduleStatus get status {
    if (hasError) {
      return const _TodayScheduleStatus(
        title: 'Ders programı hazır değil',
        subtitle: 'Ders programını görmek için daha sonra tekrar deneyin.',
        icon: Icons.schedule_outlined,
      );
    }
    if (lessons.isEmpty) {
      if (nextUpcoming != null) {
        return _TodayScheduleStatus(
          title: nextUpcoming!.name,
          subtitle:
              '${nextUpcoming!.dayLabel} • ${nextUpcoming!.classroom.isEmpty ? 'Ders' : nextUpcoming!.classroom}',
          timeLabel: nextUpcoming!.startLabel,
          icon: Icons.menu_book_rounded,
          label: _relativeDayLabel(nextUpcoming!.dayOffset),
        );
      }
      return const _TodayScheduleStatus(
        title: 'Bugün ders yok',
        subtitle: 'Bugünün geri kalanında planlanmış ders görünmüyor.',
        icon: Icons.event_available_rounded,
      );
    }

    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    for (var index = 0; index < lessons.length; index++) {
      final lesson = lessons[index];
      final next = index + 1 < lessons.length ? lessons[index + 1] : null;
      if (nowMinutes >= lesson.startMinutes && nowMinutes < lesson.endMinutes) {
        return _TodayScheduleStatus(
          title: lesson.name,
          subtitle: next == null
              ? 'Ders ${lesson.endLabel} itibarıyla bitiyor.'
              : 'Sonraki ders ${next.startLabel} • ${next.name}',
          timeLabel: '${lesson.startLabel}–${lesson.endLabel}',
          icon: Icons.menu_book_rounded,
          label: 'Şimdi',
        );
      }
      if (nowMinutes < lesson.startMinutes) {
        if (index > 0) {
          return _TodayScheduleStatus(
            title: 'Teneffüs zamanı',
            subtitle: 'Sıradaki: ${lesson.name}',
            timeLabel: lesson.startLabel,
            icon: Icons.free_breakfast_rounded,
            label: 'Teneffüs',
            isBreak: true,
          );
        }
        return _TodayScheduleStatus(
          title: lesson.name,
          subtitle: lesson.classroom.isEmpty
              ? 'Ders ${lesson.startLabel} itibarıyla başlıyor.'
              : '${lesson.startLabel} • ${lesson.classroom}',
          timeLabel: lesson.startLabel,
          icon: Icons.menu_book_rounded,
          label: 'Sıradaki',
        );
      }
    }

    if (nextUpcoming != null) {
      return _TodayScheduleStatus(
        title: nextUpcoming!.name,
        subtitle:
            '${nextUpcoming!.dayLabel} • ${nextUpcoming!.classroom.isEmpty ? 'Ders' : nextUpcoming!.classroom}',
        timeLabel: nextUpcoming!.startLabel,
        icon: Icons.menu_book_rounded,
        label: _relativeDayLabel(nextUpcoming!.dayOffset),
      );
    }

    return const _TodayScheduleStatus(
      title: 'Bugünkü dersler bitti',
      subtitle: 'Günün geri kalanında planlanmış ders bulunmuyor.',
      icon: Icons.check_circle_outline_rounded,
    );
  }
}

String _relativeDayLabel(int dayOffset) {
  if (dayOffset <= 0) return 'Sıradaki';
  if (dayOffset == 1) return 'Yarın';
  return '$dayOffset gün sonra';
}

class _TodayScheduleStatus {
  const _TodayScheduleStatus({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.label = 'Bugün',
    this.timeLabel,
    this.isBreak = false,
    this.lecturer,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String label;
  final String? timeLabel;
  final bool isBreak;
  final String? lecturer;
}

class _TodayLesson {
  const _TodayLesson({
    required this.name,
    required this.startMinutes,
    required this.endMinutes,
    required this.startLabel,
    required this.endLabel,
    required this.classroom,
    required this.instructor,
    required this.dayLabel,
    required this.dayOffset,
  });

  final String name;
  final int startMinutes;
  final int endMinutes;
  final String startLabel;
  final String endLabel;
  final String classroom;
  final String instructor;
  final String dayLabel;
  final int dayOffset;

  static _TodayLesson? fromScheduleLesson(
    ScheduleLesson lesson, {
    required String dayLabel,
    int dayOffset = 0,
  }) {
    final parts = lesson.time.trim().split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute > 59) {
      return null;
    }
    final startMinutes = hour * 60 + minute;
    final endMinutes = startMinutes + 50;
    return _TodayLesson(
      name: lesson.courseName.trim(),
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      startLabel: _formatMinutes(startMinutes),
      endLabel: _formatMinutes(endMinutes),
      classroom: lesson.classroom.trim(),
      instructor: lesson.instructor.trim(),
      dayLabel: dayLabel,
      dayOffset: dayOffset,
    );
  }

  static String _formatMinutes(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _TodaySectionHeader extends StatelessWidget {
  const _TodaySectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: cs.primary,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _TodayNewsCard extends StatelessWidget {
  const _TodayNewsCard({required this.news, required this.onTap});

  final NewsView news;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            if (news.heroImage != null && news.heroImage!.isNotEmpty)
              SizedBox(
                width: 124,
                height: 154,
                child: CachedNetworkImage(
                  imageUrl: news.heroImage!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => ColoredBox(
                    color: cs.primaryContainer,
                    child: Icon(Icons.article_outlined, color: cs.primary),
                  ),
                ),
              )
            else
              SizedBox(
                width: 124,
                height: 154,
                child: ColoredBox(
                  color: cs.primaryContainer,
                  child: Icon(Icons.article_outlined, color: cs.primary),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'EN YENİ',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      news.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      news.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            news.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded, color: cs.primary),
                      ],
                    ),
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

class _TodayEventCard extends StatelessWidget {
  const _TodayEventCard({required this.event, required this.onTap});

  final PostView event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final imageUrl = eventImageUrl(event);
    final date = event.eventDate;
    final dateLabel = date == null
        ? 'Tarih yakında'
        : DateFormat('d MMM, HH:mm', 'tr').format(date);

    return SizedBox(
      width: 220,
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 112,
                width: double.infinity,
                child: imageUrl.isEmpty
                    ? ColoredBox(
                        color: cs.primaryContainer,
                        child: Icon(Icons.event_rounded, color: cs.primary),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => ColoredBox(
                          color: cs.primaryContainer,
                          child: Icon(Icons.event_rounded, color: cs.primary),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.tags.isEmpty ? 'Etkinlik' : event.tags.first,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 15,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            dateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _TodayCommunityCard extends StatelessWidget {
  const _TodayCommunityCard({required this.post, required this.onTap});

  final CommunityPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SizedBox(
      width: 230,
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: const Color(0xFF4C1D95),
                      backgroundImage: post.displayAuthorImage == null
                          ? null
                          : NetworkImage(post.displayAuthorImage!),
                      child: post.displayAuthorImage == null
                          ? const Icon(
                              Icons.notifications_none_rounded,
                              color: Color(0xFFE9D5FF),
                              size: 17,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        post.displayAuthorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(Icons.forum_outlined, size: 17, color: cs.primary),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  post.content.replaceAll(RegExp(r'[*_#`>\\n]'), ' ').trim(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                ),
                const Spacer(),
                Text(
                  DateFormat('d MMM, HH:mm', 'tr').format(post.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayEmptyCard extends StatelessWidget {
  const _TodayEmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
    );
  }
}

class _TodayNewsSkeleton extends StatelessWidget {
  const _TodayNewsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 154,
      child: Row(
        children: [
          AppSkeleton(
            width: 124,
            height: 154,
            borderRadius: BorderRadius.horizontal(left: Radius.circular(22)),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppSkeleton(width: 72, height: 12),
                SizedBox(height: 12),
                AppSkeleton(height: 14),
                SizedBox(height: 8),
                AppSkeleton(width: 160, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayNewsDots extends StatelessWidget {
  const _TodayNewsDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? primary : primary.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

class _TodayEventSkeleton extends StatelessWidget {
  const _TodayEventSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 2,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, __) =>
          const SizedBox(width: 220, child: AppSkeleton(height: 230)),
    );
  }
}

class _TodayCommunitySkeleton extends StatelessWidget {
  const _TodayCommunitySkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 2,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, __) =>
          const SizedBox(width: 230, child: AppSkeleton(height: 150)),
    );
  }
}
