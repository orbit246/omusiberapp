import 'package:flutter/material.dart';
import 'package:shimmer_animation/shimmer_animation.dart';

class EventTag {
  final String text;
  final IconData icon;
  final Color? color; // optional custom bg
  const EventTag(this.text, this.icon, {this.color});
}

class EventCard extends StatefulWidget {
  const EventCard({
    super.key,
    required this.title,
    required this.datetimeText,
    required this.location,
    required this.imageAsset,
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
  final String imageAsset;

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Shimmer(
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: cs.surface,
          surfaceTintColor: cs.surface, // keep surface stable in M3
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tags
                  if (widget.tags.isNotEmpty)
                    Wrap(spacing: 6, runSpacing: 6, children: widget.tags.map((t) => _TagChip(tag: t)).toList()),
      
                  const SizedBox(height: 12),
      
                  // Header row: image + info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image with soft shadow
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: cs.shadow.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topCenter,
                            child: Image.asset(
                              widget.imageAsset,
                              height: _expanded ? 180 : 90,
                              width: _expanded ? 240 : 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
      
                      const SizedBox(width: 8),
      
                      // Event info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.datetimeText,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 2)],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.title,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Divider(color: cs.outlineVariant, height: 1),
                          ],
                        ),
                      ),
                    ],
                  ),
      
                  const SizedBox(height: 12),
      
                  // Location row (tap to expand)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.location,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                          ),
                        ),
                        AnimatedRotation(
                          turns: _expanded ? 0.25 : 0.0, // 90°
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: Icon(Icons.arrow_forward_ios_outlined, size: 16, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
      
                  // Expanded details
                  if (_expanded) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, color: cs.outlineVariant),
                    const SizedBox(height: 12),
      
                    if (widget.durationText != null) _infoRow(context, Icons.schedule, widget.durationText!),
                    if (widget.ticketText != null) const SizedBox(height: 8),
                    if (widget.ticketText != null)
                      _infoRow(context, Icons.confirmation_number_outlined, widget.ticketText!),
                    if (widget.capacityText != null) const SizedBox(height: 8),
                    if (widget.capacityText != null) _infoRow(context, Icons.person, widget.capacityText!),
                    if (widget.description != null) const SizedBox(height: 8),
                    if (widget.description != null)
                      _infoRow(context, Icons.info_outline, widget.description!, topAligned: true),
      
                    const SizedBox(height: 12),
      
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: widget.onJoin,
                            icon: Icon(Icons.event_available, size: 20, color: Theme.of(context).colorScheme.onSurface),
                            label: Text("Katıl", style: Theme.of(context).textTheme.labelLarge),
                            style: Theme.of(context).elevatedButtonTheme.style,
                          ),
                        ),
      
                        const SizedBox(width: 8),
                        _squareAction(context, icon: Icons.bookmark_outline, onTap: widget.onBookmark),
                        const SizedBox(width: 6),
                        _squareAction(context, icon: Icons.share_outlined, onTap: widget.onShare),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text, {bool topAligned = false}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: topAligned ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: tt.bodyMedium?.copyWith(color: cs.onSurface)),
        ),
      ],
    );
  }

  Widget _squareAction(BuildContext context, {required IconData icon, VoidCallback? onTap}) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceVariant,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(width: 46, height: 46, child: Icon(icon, size: 24, color: cs.onSurface)),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});
  final EventTag tag;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bg = tag.color ?? cs.secondaryContainer; // default to a pleasant container tone from scheme
    final fg = tag.color != null
        ? _contrastOn(bg, cs) // compute a readable on-color if custom color passed
        : cs.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tag.icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            tag.text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // Simple contrast helper: falls back to onSurface if needed.
  Color _contrastOn(Color bg, ColorScheme cs) {
    // luminance threshold heuristic
    return bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}
