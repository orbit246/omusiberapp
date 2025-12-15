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

  /// ImageKit (or any CDN) URL. Can be empty.
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
  final GlobalKey<StackedPushingExpansionWidgetState> _expansionKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () {
        setState(() {
          _expanded = !_expanded;
          _expansionKey.currentState?.toggleExpansion();
        });
      },
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: cs.surface,
        surfaceTintColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 2),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: widget.tags.map((t) => TagChip(tag: t)).toList(),
                  ),
                if (widget.tags.isNotEmpty) const SizedBox(height: 12),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _imageBlock(context),

                    const SizedBox(width: 8),

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

                StackedPushingExpansionWidget(
                  key: _expansionKey,
                  header: Column(
                    children: [
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
                              turns: _expanded ? 0.25 : 0.0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              child: Icon(Icons.arrow_forward_ios_outlined, size: 16, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (!_expanded)
                        Center(
                          child: Text(
                            "Detaylı bilgi için tıklayın",
                            style: tt.bodySmall?.copyWith(
                              color: const Color.fromARGB(255, 123, 117, 142),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  content: ClipRect(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(height: 1, color: cs.outlineVariant),
                        const SizedBox(height: 12),

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

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: widget.onJoin,
                                icon: Icon(Icons.event_available, size: 20, color: cs.onSurface),
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

                                // Optional external handler
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
                                // Prefer provided callback, fallback to default SharePlus
                                if (widget.onShare != null) {
                                  try {
                                    widget.onShare!.call();
                                  } catch (_) {
                                    _toast(context, "Paylaşım başarısız");
                                  }
                                  return;
                                }

                                try {
                                  await SharePlus.instance.share(
                                    ShareParams(
                                      text: 'Etkinlik: ${widget.title}\nKonum: ${widget.location}',
                                    ),
                                  );
                                } catch (_) {
                                  _toast(context, "Paylaşım başarısız");
                                }
                              },
                            ),
                          ],
                        ),
                      ],
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

  Widget _imageBlock(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _NetworkThumb(
          url: widget.imageUrl,
          height: 90,
          width: 120,
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
        Expanded(child: Text(text, style: tt.bodyMedium?.copyWith(color: cs.onSurface))),
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

  void _toast(BuildContext context, String msg) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Theme.of(context).colorScheme.surface,
      textColor: Colors.white,
      fontSize: 16,
    );
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

  bool get _validUrl => url.trim().startsWith('http://') || url.trim().startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!_validUrl) {
      return _fallback(cs);
    }

    return Image.network(
      url.trim(),
      height: height,
      width: width,
      fit: BoxFit.cover,
      // Helps avoid huge in-memory images on list views.
      cacheHeight: (height * MediaQuery.of(context).devicePixelRatio).round(),
      cacheWidth: (width * MediaQuery.of(context).devicePixelRatio).round(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        final value = progress.expectedTotalBytes == null
            ? null
            : progress.cumulativeBytesLoaded / progress.expectedTotalBytes!;
        return SizedBox(
          height: height,
          width: width,
          child: Center(child: CircularProgressIndicator(value: value)),
        );
      },
      errorBuilder: (context, error, stack) => _fallback(cs),
    );
  }

  Widget _fallback(ColorScheme cs) {
    return Container(
      height: height,
      width: width,
      color: cs.surfaceVariant,
      child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
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
    final fg = tag.color != null ? _contrastOn(bg) : cs.onSecondaryContainer;

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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Color _contrastOn(Color bg) => bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}
