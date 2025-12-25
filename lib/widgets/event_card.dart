import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:omusiber/widgets/test_widget.dart';

// Components
import 'package:omusiber/widgets/event_components/event_tag.dart';
import 'package:omusiber/widgets/event_components/event_image.dart';
import 'package:omusiber/widgets/event_components/event_info_row.dart';
import 'package:omusiber/widgets/event_components/event_action_buttons.dart';

// Export for backward compatibility or easier imports
export 'package:omusiber/widgets/event_components/event_tag.dart';

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
    this.initialExpanded = false,
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
  final bool initialExpanded;
  final VoidCallback? onJoin;
  final VoidCallback? onBookmark;
  final VoidCallback? onShare;

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> with TickerProviderStateMixin {
  late bool _expanded = widget.initialExpanded;
  bool _isSaved = false;
  final GlobalKey<StackedPushingExpansionWidgetState> _expansionKey =
      GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _expanded = !_expanded;
          _expansionKey.currentState?.toggleExpansion();
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: cs.outlineVariant.withOpacity(isDark ? 0.2 : 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Tags ---
            if (widget.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.tags.map((t) => TagChip(tag: t)).toList(),
                ),
              ),

            // --- Main Content ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EventImageBlock(imageUrl: widget.imageUrl),
                  const SizedBox(width: 16),

                  // Text Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date label
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.datetimeText.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Title
                        Text(
                          widget.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Location
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
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

            // --- Expandable Section ---
            StackedPushingExpansionWidget(
              key: _expansionKey,
              header: _buildExpansionTrigger(context),
              content: _buildExpandedContent(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpansionTrigger(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withOpacity(0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _expanded ? "Gizle" : "Detaylar ve İşlemler",
            style: tt.labelMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          AnimatedRotation(
            turns: _expanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.durationText != null)
            EventInfoRow(icon: Icons.schedule, text: widget.durationText!),

          if (widget.ticketText != null) ...[
            const SizedBox(height: 12),
            EventInfoRow(
              icon: Icons.confirmation_number_outlined,
              text: widget.ticketText!,
            ),
          ],

          if (widget.capacityText != null) ...[
            const SizedBox(height: 12),
            EventInfoRow(
              icon: Icons.group_outlined,
              text: widget.capacityText!,
            ),
          ],

          if (widget.description != null) ...[
            const SizedBox(height: 12),
            EventInfoRow(
              icon: Icons.info_outline,
              text: widget.description!,
              topAligned: true,
            ),
          ],

          const SizedBox(height: 20),

          EventActionButtons(
            onJoin: widget.onJoin,
            isSaved: _isSaved,
            onBookmark: () {
              setState(() => _isSaved = !_isSaved);
              widget.onBookmark?.call();
              _toast(
                context,
                "Etkinlik ${_isSaved ? 'kaydedildi' : 'silindi'}",
              );
            },
            onShare: () {
              if (widget.onShare != null) {
                widget.onShare!.call();
              } else {
                SharePlus.instance.share(
                  ShareParams(text: '${widget.title}\n${widget.location}'),
                );
              }
            },
          ),
        ],
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
