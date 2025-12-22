import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:omusiber/widgets/test_widget.dart';

class EventTag {
  final String text;
  final IconData icon;
  final Color? color;
  const EventTag(this.text, this.icon, {this.color});
}

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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Modern "Elevated" container style
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
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000), // Very light black shadow
              blurRadius: 20,
              offset: Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- RESTORED: Tags ---
            if (widget.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.tags.map((t) => TagChip(tag: t)).toList(),
                ),
              ),

            // --- TOP CONTENT ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image - Larger and Squarish
                  _imageBlock(context),

                  const SizedBox(width: 16),

                  // Text Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Badge / Text
                        Text(
                          widget.datetimeText.toUpperCase(),
                          style: tt.labelSmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Title
                        Text(
                          widget.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Location
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodySmall?.copyWith(
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

            // --- EXPANSION CONTENT ---
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

  Widget _imageBlock(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: _NetworkThumb(url: widget.imageUrl, height: 100, width: 100),
    );
  }

  Widget _buildExpansionTrigger(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Text(
                  "Detaylar",
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!_expanded)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(
                "Detaylı bilgi için tıklayın",
                style: tt.bodySmall?.copyWith(color: cs.outline),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 12),

          if (widget.durationText != null)
            _infoRow(context, Icons.schedule, widget.durationText!),

          if (widget.ticketText != null) ...[
            const SizedBox(height: 8),
            _infoRow(
              context,
              Icons.confirmation_number_outlined,
              widget.ticketText!,
            ),
          ],

          if (widget.capacityText != null) ...[
            const SizedBox(height: 8),
            _infoRow(context, Icons.person, widget.capacityText!),
          ],

          if (widget.description != null) ...[
            const SizedBox(height: 8),
            _infoRow(
              context,
              Icons.info_outline,
              widget.description!,
              topAligned: true,
            ),
          ],

          const SizedBox(height: 12),

          // Action Buttons - Old Style
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onJoin,
                  icon: Icon(
                    Icons.event_available,
                    size: 20,
                    color: cs.onSurface,
                  ),
                  label: Text("Katıl", style: tt.labelLarge),
                  style: Theme.of(context).elevatedButtonTheme.style,
                ),
              ),
              const SizedBox(width: 8),
              _squareAction(
                context,
                icon: !_isSaved ? Icons.bookmark_outline : Icons.bookmark,
                onTap: () {
                  setState(() => _isSaved = !_isSaved);
                  try {
                    widget.onBookmark?.call();
                  } catch (_) {}
                  Fluttertoast.showToast(
                    msg: "Etkinlik ${_isSaved ? 'kaydedildi' : 'kaydedilmedi'}",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    timeInSecForIosWeb: 1,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    textColor: Colors.white,
                    fontSize: 16,
                  );
                },
              ),
              const SizedBox(width: 8),
              _squareAction(
                context,
                icon: Icons.share_outlined,
                onTap: () async {
                  if (widget.onShare != null) {
                    try {
                      widget.onShare!.call();
                    } catch (_) {}
                    return;
                  }
                  try {
                    await SharePlus.instance.share(
                      ShareParams(text: '${widget.title}\n${widget.location}'),
                    );
                  } catch (_) {}
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _squareAction(
    BuildContext context, {
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceVariant,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, size: 24, color: cs.onSurface),
        ),
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String text, {
    bool topAligned = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: topAligned
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: cs.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _toast(BuildContext context, String msg) {
    Fluttertoast.showToast(msg: msg);
  }
}

class _NetworkThumb extends StatelessWidget {
  const _NetworkThumb({
    required this.url,
    required this.height,
    required this.width,
  });
  final String url;
  final double height;
  final double width;

  bool get _validUrl => url.trim().startsWith('http');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!_validUrl) return _fallback(cs);
    return Image.network(
      url.trim(),
      height: height,
      width: width,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallback(cs),
    );
  }

  Widget _fallback(ColorScheme cs) {
    return Container(
      height: height,
      width: width,
      color: cs.surfaceContainerHighest,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}

class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.tag});
  final EventTag tag;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Lighter, more subtle tags
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tag.text == 'Ücretli')
            Icon(Icons.attach_money, size: 12, color: cs.onPrimaryContainer),
          // (Small logic for dynamic icons if needed inside)
          Text(
            tag.text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: cs.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
