import 'package:flutter/material.dart';
import 'package:omusiber/widgets/test_widget.dart';
// Removed unused 'shimmer_animation' import

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

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: cs.surface,
        surfaceTintColor: cs.surface, // keep surface stable in M3
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          // This outer AnimatedSize handles the card's overall height change
          child: AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tags
                if (widget.tags.isNotEmpty)
                  Wrap(spacing: 6, runSpacing: 6, children: widget.tags.map((t) => TagChip(tag: t)).toList()),

                if (widget.tags.isNotEmpty) const SizedBox(height: 12),

                // Header row: image + info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image with soft shadow
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: cs.shadow.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(widget.imageAsset, height: 90, width: 120, fit: BoxFit.cover),
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

                // Use collection-if to show text only when collapsed
                if (!_expanded)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Detaylı bilgi için tıklayın",
                        style: tt.bodySmall?.copyWith(
                          color: const Color.fromARGB(255, 123, 117, 142),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                // Smooth expandable area (drawer effect)
                const SizedBox(height: 12),
                Center(
                  child: StackedPushingExpansionWidget(
                    header: const Text(
                      "Tap to Expand",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Item 1", style: TextStyle(fontSize: 16)),
                        Divider(),
                        Text("Item 2", style: TextStyle(fontSize: 16)),
                        Divider(),
                        Text("Item 3", style: TextStyle(fontSize: 16)),
                        SizedBox(height: 10),
                        Text("Some more descriptive text about the items..."),
                      ],
                    ),
                  ),
                ),

                AnimatedSize(
                  // This animates the height change
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: _expanded ? 1.0 : 0.0,
                      // AnimatedOpacity was removed from here
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(height: 1, color: cs.outlineVariant),
                          const SizedBox(height: 12),

                          // Use collection-if and spread operator for cleaner list
                          if (widget.durationText != null) _infoRow(context, Icons.schedule, widget.durationText!),

                          if (widget.ticketText != null) ...[
                            const SizedBox(height: 8),
                            _infoRow(context, Icons.confirmation_number_outlined, widget.ticketText!),
                          ],

                          if (widget.capacityText != null) ...[
                            const SizedBox(height: 8),
                            _infoRow(context, Icons.person, widget.capacityText!),
                          ],

                          if (widget.description != null) ...[
                            const SizedBox(height: 8),
                            _infoRow(context, Icons.info_outline, widget.description!, topAligned: true),
                          ],

                          const SizedBox(height: 12),

                          // Actions
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: widget.onJoin,
                                  icon: Icon(
                                    Icons.event_available,
                                    size: 20,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  label: Text("Katıl", style: Theme.of(context).textTheme.labelLarge),
                                  style: Theme.of(context).elevatedButtonTheme.style,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _squareAction(context, icon: Icons.bookmark_outline, onTap: widget.onBookmark),
                              // Consistent spacing
                              const SizedBox(width: 8),
                              _squareAction(context, icon: Icons.share_outlined, onTap: widget.onShare),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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

class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.tag});
  final EventTag tag;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bg = tag.color ?? cs.secondaryContainer;
    final fg = tag.color != null
        ? _contrastOn(bg) // Removed unused ColorScheme
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

  // Simple contrast helper. Removed unused ColorScheme parameter.
  Color _contrastOn(Color bg) {
    // luminance threshold heuristic
    return bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}
