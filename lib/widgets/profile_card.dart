import 'package:flutter/material.dart';

class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    const double cardWidth = 480;
    const radius = 22.0;

    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            offset: Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: name / handle / rating
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with video badge
              _AvatarWithBadge(
                size: 72,
                imageProvider: const NetworkImage(
                  'https://images.unsplash.com/photo-1502685104226-ee32379fefbe?w=512&q=80',
                ),
              ),
              const SizedBox(width: 16),
              // Name + handle + stats card
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top line: Name and rating on the far right
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'David Green',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              height: 1.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFB400),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '5.0',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(7 Reviews)',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#dadiogreen',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Stats pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFEDEDED)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _StatItem(value: '2', label: 'Events'),
                          _DividerDot(),
                          _StatItem(value: '214', label: 'Followers'),
                          _DividerDot(),
                          _StatItem(value: '323', label: 'Following'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Tabs
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(6),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PillTab(
                    icon: Icons.info_outline_rounded,
                    label: 'About',
                    selected: false,
                  ),
                  SizedBox(width: 8),
                  _PillTab(
                    icon: Icons.card_giftcard_rounded, // looks like events bag
                    label: 'Events',
                    selected: true, // selected in screenshot
                  ),
                  SizedBox(width: 8),
                  _PillTab(
                    icon: Icons.star_border_rounded,
                    label: 'Reviews',
                    selected: false,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarWithBadge extends StatelessWidget {
  final double size;
  final ImageProvider imageProvider;
  const _AvatarWithBadge({required this.size, required this.imageProvider});

  @override
  Widget build(BuildContext context) {
    final badgeSize = size * 0.28;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.videocam_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ],
    );
  }
}

class _DividerDot extends StatelessWidget {
  const _DividerDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade400,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _PillTab({
    required this.icon,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Colors.black : Colors.transparent;
    final fg = selected ? Colors.white : Colors.black87;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
