import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omusiber/backend/share_service.dart';
import 'package:omusiber/backend/view/community_post_model.dart';
import 'package:omusiber/pages/new_view/controllers/community_tab_controller.dart';
import 'package:omusiber/widgets/community_post_card.dart';
import 'package:omusiber/widgets/shared/app_skeleton.dart';

class CommunityTabView extends StatefulWidget {
  const CommunityTabView({super.key});

  @override
  State<CommunityTabView> createState() => _CommunityTabViewState();
}

class _CommunityTabViewState extends State<CommunityTabView> {
  late final CommunityTabController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = CommunityTabController();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_controller.loadInitialData());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _controller.isLoadingMore ||
        !_controller.canLoadMore) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 320) {
      return;
    }

    unawaited(_controller.loadMorePosts());
  }

  void _toggleLike(CommunityPost post) {
    unawaited(
      _controller.toggleLike(post).catchError((error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Beğeni güncellenemedi.')));
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CommunityTabContent(
          posts: _controller.posts,
          isLoading: _controller.isLoading,
          isLoadingMore: _controller.isLoadingMore,
          scrollController: _scrollController,
          onRefresh: _controller.refresh,
          onLike: _toggleLike,
          onShare: (post) =>
              unawaited(ShareService.shareCommunityPost(context, post)),
        );
      },
    );
  }
}

class CommunityTabContent extends StatefulWidget {
  const CommunityTabContent({
    super.key,
    required this.posts,
    required this.isLoading,
    required this.isLoadingMore,
    required this.scrollController,
    required this.onRefresh,
    required this.onLike,
    required this.onShare,
  });

  final List<CommunityPost> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final ValueChanged<CommunityPost> onLike;
  final ValueChanged<CommunityPost> onShare;

  @override
  State<CommunityTabContent> createState() => _CommunityTabContentState();
}

class _CommunityTabContentState extends State<CommunityTabContent> {
  static const List<_CommunityFilter> _filters = [
    _CommunityFilter(id: 'all', label: 'Tümü'),
    _CommunityFilter(id: 'pinned', label: 'Sabit'),
    _CommunityFilter(id: 'announcement', label: 'Duyuru'),
    _CommunityFilter(id: 'question', label: 'Soru'),
    _CommunityFilter(id: 'poll', label: 'Anket'),
    _CommunityFilter(id: 'campus', label: 'Kampüs'),
  ];

  String _selectedFilter = 'all';

  List<CommunityPost> get _filteredPosts {
    final filtered = widget.posts.where((post) {
      return switch (_selectedFilter) {
        'all' => true,
        'pinned' => post.isPinned,
        _ => post.category == _selectedFilter,
      };
    }).toList();

    filtered.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const CommunityLoadingState();
    }

    if (widget.posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        displacement: 20,
        edgeOffset: 0,
        child: CustomScrollView(
          controller: widget.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('Henüz gönderi yok.')),
            ),
          ],
        ),
      );
    }

    final visiblePosts = _filteredPosts;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      displacement: 20,
      edgeOffset: 0,
      child: ListView.builder(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 16, bottom: 80),
        itemCount:
            (visiblePosts.isEmpty ? 2 : visiblePosts.length + 1) +
            (widget.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CommunityFilterBar(
              filters: _filters,
              selectedFilter: _selectedFilter,
              onSelected: (filter) {
                setState(() => _selectedFilter = filter.id);
              },
            );
          }

          final postIndex = index - 1;
          if (visiblePosts.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 42),
              child: Center(child: Text('Bu filtrede gönderi yok.')),
            );
          }

          if (postIndex >= visiblePosts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final post = visiblePosts[postIndex];
          return CommunityPostCard(
            post: post,
            onLike: () => widget.onLike(post),
            onShare: () => widget.onShare(post),
          );
        },
      ),
    );
  }
}

class _CommunityFilter {
  const _CommunityFilter({required this.id, required this.label});

  final String id;
  final String label;
}

class _CommunityFilterBar extends StatelessWidget {
  const _CommunityFilterBar({
    required this.filters,
    required this.selectedFilter,
    required this.onSelected,
  });

  final List<_CommunityFilter> filters;
  final String selectedFilter;
  final ValueChanged<_CommunityFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filters.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final filter = filters[index];
            final isSelected = filter.id == selectedFilter;
            return ChoiceChip(
              selected: isSelected,
              label: Text(filter.label),
              onSelected: (_) => onSelected(filter),
              showCheckmark: false,
              labelStyle: TextStyle(
                color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
              selectedColor: cs.primary,
              backgroundColor: cs.surfaceContainerHighest.withValues(
                alpha: 0.45,
              ),
              side: BorderSide(
                color: isSelected
                    ? cs.primary
                    : cs.outlineVariant.withValues(alpha: 0.7),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            );
          },
        ),
      ),
    );
  }
}

class CommunityLoadingState extends StatelessWidget {
  const CommunityLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppSkeleton(
                      height: 34,
                      width: 34,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeleton(
                          height: 10,
                          width: 96,
                          borderRadius: BorderRadius.all(Radius.circular(6)),
                        ),
                        SizedBox(height: 7),
                        AppSkeleton(
                          height: 9,
                          width: 64,
                          borderRadius: BorderRadius.all(Radius.circular(6)),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 14),
                AppSkeleton(
                  height: 10,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                SizedBox(height: 7),
                AppSkeleton(
                  height: 10,
                  width: 190,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                SizedBox(height: 14),
                AppSkeleton(
                  height: 148,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
