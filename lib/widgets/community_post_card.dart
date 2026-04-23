import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:omusiber/backend/share_service.dart';
import 'package:omusiber/backend/view/community_post_model.dart';
import 'package:omusiber/widgets/poll_widget.dart';
import 'package:omusiber/widgets/shared/app_markdown.dart';

class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onReact,
    this.onShare,
  });

  final CommunityPost post;
  final VoidCallback? onLike;
  final ValueChanged<String>? onReact;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = post.accentColor != null
        ? Color(post.accentColor!)
        : _categoryAccent(post.category, cs);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withValues(alpha: 0.65), width: 1.2),
      ),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: cs.primaryContainer,
                  backgroundImage: post.authorImage != null
                      ? NetworkImage(post.authorImage!)
                      : null,
                  child: post.authorImage == null
                      ? Text(
                          post.authorName.isNotEmpty ? post.authorName[0] : '?',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _buildMetaText(post),
                        style: GoogleFonts.inter(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.share_outlined,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed:
                      onShare ??
                      () => unawaited(
                        ShareService.shareCommunityPost(context, post),
                      ),
                  tooltip: 'Paylas',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (post.isPinned)
                  _PostBadge(
                    icon: Icons.push_pin_rounded,
                    label: 'Sabit',
                    color: accent,
                  ),
                _PostBadge(
                  icon: _categoryIcon(post.category),
                  label: _categoryLabel(post.category),
                  color: accent,
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppMarkdownBody(data: post.content),
            if (post.poll != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: PollWidget(postId: post.id, poll: post.poll!),
              ),
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      color: cs.surfaceContainerHighest,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: cs.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1),
            _EmojiReactionBar(post: post, accent: accent, onReact: onReact),
          ],
        ),
      ),
    );
  }

  String _buildMetaText(CommunityPost post) {
    final timeText = _formatTime(post.createdAt);
    final pollVotes = post.poll?.totalVotes;
    if (pollVotes == null) return timeText;
    return '$timeText • $pollVotes Kisi Oy Verdi';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return 'Simdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes}d once';
    if (diff.inHours < 24) return '${diff.inHours}s once';
    if (diff.inDays < 7) return '${diff.inDays} Gun once';
    return DateFormat('d MMM', 'tr').format(time);
  }

  String _categoryLabel(String category) {
    return switch (category) {
      'announcement' => 'Duyuru',
      'question' => 'Soru',
      'poll' => 'Anket',
      'campus' => 'Kampus',
      _ => 'Genel',
    };
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      'announcement' => Icons.campaign_rounded,
      'question' => Icons.help_outline_rounded,
      'poll' => Icons.poll_rounded,
      'campus' => Icons.location_city_rounded,
      _ => Icons.forum_rounded,
    };
  }

  Color _categoryAccent(String category, ColorScheme cs) {
    return switch (category) {
      'announcement' => const Color(0xFF2563EB),
      'question' => const Color(0xFF10B981),
      'poll' => const Color(0xFFF97316),
      'campus' => const Color(0xFFA855F7),
      _ => cs.primary,
    };
  }
}

class _EmojiReactionBar extends StatefulWidget {
  const _EmojiReactionBar({
    required this.post,
    required this.accent,
    this.onReact,
  });

  static const List<String> emojis = [
    '❤️',
    '🔥',
    '👀',
    '💀',
    '🫡',
    '🧐',
    '😒',
    '👏',
    '😂',
  ];

  final CommunityPost post;
  final Color accent;
  final ValueChanged<String>? onReact;

  @override
  State<_EmojiReactionBar> createState() => _EmojiReactionBarState();
}

class _EmojiReactionBarState extends State<_EmojiReactionBar> {
  late Map<String, int> _counts;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _counts = {...widget.post.reactionCounts};
    _selected = {...widget.post.selectedReactions};
  }

  @override
  void didUpdateWidget(covariant _EmojiReactionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.reactionCounts != widget.post.reactionCounts ||
        oldWidget.post.selectedReactions != widget.post.selectedReactions) {
      _counts = {...widget.post.reactionCounts};
      _selected = {...widget.post.selectedReactions};
    }
  }

  void _toggle(String emoji) {
    setState(() {
      final wasSelected = _selected.contains(emoji);
      if (wasSelected) {
        _selected.remove(emoji);
        _counts[emoji] = ((_counts[emoji] ?? 0) - 1).clamp(0, 1 << 30);
      } else {
        _selected.add(emoji);
        _counts[emoji] = (_counts[emoji] ?? 0) + 1;
      }
      _counts.removeWhere((_, count) => count <= 0);
    });
    widget.onReact?.call(emoji);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sortedEmojis = [..._EmojiReactionBar.emojis]
      ..sort((a, b) {
        final countCompare = (_counts[b] ?? 0).compareTo(_counts[a] ?? 0);
        if (countCompare != 0) return countCompare;
        return _EmojiReactionBar.emojis
            .indexOf(a)
            .compareTo(_EmojiReactionBar.emojis.indexOf(b));
      });

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: sortedEmojis.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final emoji = sortedEmojis[index];
            final selected = _selected.contains(emoji);
            final count = _counts[emoji] ?? 0;
            return Material(
              color: selected
                  ? widget.accent.withValues(alpha: 0.16)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: () => _toggle(emoji),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? widget.accent.withValues(alpha: 0.62)
                          : cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 16)),
                      if (count > 0) ...[
                        const SizedBox(width: 5),
                        Text(
                          '$count',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? widget.accent
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PostBadge extends StatelessWidget {
  const _PostBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
