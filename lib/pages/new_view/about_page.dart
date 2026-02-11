import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutBottomSheet extends StatelessWidget {
  const AboutBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header info
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "OmuSiber",
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Version 0.2.0 Beta",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Description
          Text(
            "OmuSiber, Ondokuz Mayıs Üniversitesi Siber Güvenlik Topluluğu'nun resmi uygulamasıdır. Topluluğumuzdaki gelişmeleri takip edebilir ve etkinliklere katılabilirsiniz.",
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 24),

          // Footer
          Divider(color: colorScheme.outlineVariant.withOpacity(0.5)),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Built by",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    "NortixLabs",
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              IconButton.filledTonal(
                onPressed: () async {
                  final url = Uri.parse('https://nortixlabs.com/akademiz');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.public, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            "© 2024 NortixLabs. Tüm hakları saklıdır.",
            style: GoogleFonts.inter(
              fontSize: 10,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
