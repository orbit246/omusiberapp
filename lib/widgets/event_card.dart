import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:omusiber/widgets/event_components/event_tag.dart';
// Note: Removed test_widget import as it's no longer needed for expansion

class EventCard extends StatefulWidget {
  const EventCard({
    super.key,
    required this.title,
    required this.datetimeText,
    required this.location,
    required this.imageUrl,
    this.durationText,
    this.ticketText,
    this.capacityText,
    this.description,
    this.tags = const <EventTag>[],
    // initialExpanded removed as concept is static now
    this.onJoin,
    this.onBookmark,
    this.onShare,
  });

  final String title;
  final String datetimeText;
  final String location;
  final String imageUrl;
  final String? durationText;
  final String? ticketText;
  final String? capacityText;
  final String? description;
  final List<EventTag> tags;
  final VoidCallback? onJoin;
  final ValueChanged<bool>? onBookmark;
  final VoidCallback? onShare;

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  // Static card, no expansion state
  bool _isSaved = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 1. Top Image & Date Badge ---
            if (widget.imageUrl.isNotEmpty)
              Stack(
                children: [
                  // Image
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      widget.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: cs.surfaceContainerHighest,
                        child: const Center(
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                    ),
                  ),
                  // Gradient Overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.4],
                        ),
                      ),
                    ),
                  ),
                  // Date Badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.datetimeText,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

            // --- 2. Content Body (Everything visible) ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Conditional Date Row (if no image)
                  if (widget.imageUrl.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.datetimeText,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Title
                  Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Location
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.location,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Tags
                  if (widget.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: widget.tags
                          .map((t) => _ModernTag(tag: t))
                          .toList(),
                    ),
                  ],

                  // Description (if present)
                  if (widget.description != null &&
                      widget.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      widget.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withOpacity(0.8),
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Stats (Ticket, Capacity)
                  if (widget.ticketText != null ||
                      widget.capacityText != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (widget.ticketText != null)
                          Expanded(
                            child: _InfoItem(
                              icon: Icons.confirmation_number_outlined,
                              text: widget.ticketText!,
                            ),
                          ),
                        if (widget.capacityText != null)
                          Expanded(
                            child: _InfoItem(
                              icon: Icons.group_outlined,
                              text: widget.capacityText!,
                            ),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // --- 3. Actions ---
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: widget.onJoin,
                          icon: const Icon(Icons.bookmark_add_outlined),
                          label: const Text("Katıl / Kayıt Ol"),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        onPressed: () {
                          setState(() => _isSaved = !_isSaved);
                          widget.onBookmark?.call(_isSaved);
                          _toast(
                            context,
                            "Etkinlik ${_isSaved ? 'kaydedildi' : 'silindi'}",
                          );
                        },
                        icon: Icon(
                          _isSaved ? Icons.favorite : Icons.favorite_border,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () {
                          // Simple share
                          if (widget.onShare != null) {
                            widget.onShare!.call();
                          } else {
                            SharePlus.instance.share(
                              ShareParams(
                                text: '${widget.title}\n${widget.location}',
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.share_outlined),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    Fluttertoast.showToast(
      msg: msg,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
    );
  }
}

// --- Local Widgets ---

class _ModernTag extends StatelessWidget {
  final EventTag tag;
  const _ModernTag({required this.tag});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tag.text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
