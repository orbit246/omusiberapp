import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omusiber/backend/post_view.dart';
import 'package:omusiber/backend/view/community_post_model.dart';
import 'package:omusiber/backend/view/news_view.dart';
import 'package:omusiber/pages/new_view/community_post_detail_page.dart';
import 'package:omusiber/pages/new_view/controllers/community_tab_controller.dart';
import 'package:omusiber/pages/new_view/controllers/events_tab_controller.dart';
import 'package:omusiber/pages/new_view/controllers/news_tab_controller.dart';
import 'package:omusiber/pages/news_item_page.dart';
import 'package:omusiber/pages/removed/event_details_page.dart';
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

  @override
  void initState() {
    super.initState();
    _newsController = NewsTabController()..addListener(_handleDataChanged);
    _eventsController = EventsTabController()..addListener(_handleDataChanged);
    _communityController = CommunityTabController()
      ..addListener(_handleDataChanged);

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
    await Future.wait([
      _newsController.refreshFromUser(),
      _eventsController.refresh(),
      _communityController.refresh(),
    ]);
  }

  List<NewsView> get _recentNews {
    final items = [..._newsController.articles];
    items.sort((a, b) => _dateOfNews(b).compareTo(_dateOfNews(a)));
    return items.take(3).toList();
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
      return aUpcoming
          ? aDate.compareTo(bDate)
          : bDate.compareTo(aDate);
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

  String _dateLabel() {
    return DateFormat('d MMMM EEEE', 'tr').format(DateTime.now());
  }

  void _openNews(NewsView item) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NewsItemPage(view: item)),
    );
  }

  void _openEvent(PostView event) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EventDetailsPage(event: event)),
    );
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
    super.dispose();
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
            'Kampüste bugün neler var, tek ekranda.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          _TodaySummaryCard(
            dateLabel: _dateLabel(),
            event: closestEvents.isEmpty ? null : closestEvents.first,
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
            _TodayNewsCard(news: recentNews.first, onTap: () => _openNews(recentNews.first)),
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

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({required this.dateLabel, required this.event});

  final String dateLabel;
  final PostView? event;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(Icons.calendar_today_rounded, color: cs.onPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event == null
                      ? 'Günün akışı burada.'
                      : 'Sıradaki: ${event?.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 16, color: cs.primary),
        ],
      ),
    );
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'EN YENİ',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      news.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      news.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                        Icon(Icons.schedule_rounded, size: 15, color: cs.primary),
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
                      backgroundColor: cs.primaryContainer,
                      backgroundImage: post.authorImage == null
                          ? null
                          : NetworkImage(post.authorImage!),
                      child: post.authorImage == null
                          ? Text(
                              post.authorName.isEmpty
                                  ? '?'
                                  : post.authorName[0].toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        post.authorName,
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

class _TodayEventSkeleton extends StatelessWidget {
  const _TodayEventSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 2,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, __) => const SizedBox(
        width: 220,
        child: AppSkeleton(height: 230),
      ),
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
      itemBuilder: (_, __) => const SizedBox(
        width: 230,
        child: AppSkeleton(height: 150),
      ),
    );
  }
}
