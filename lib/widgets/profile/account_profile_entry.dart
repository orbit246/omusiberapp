import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum AccountProfileEntryVariant { standard, drawer }

class AccountProfileEntry extends StatelessWidget {
  const AccountProfileEntry({
    super.key,
    required this.user,
    required this.isAuthLoading,
    required this.onProfileTap,
    required this.onGuestTap,
    this.variant = AccountProfileEntryVariant.standard,
  });

  final User? user;
  final bool isAuthLoading;
  final VoidCallback onProfileTap;
  final VoidCallback onGuestTap;
  final AccountProfileEntryVariant variant;

  bool get _isGuest => user == null || user!.isAnonymous;

  String get _title {
    if (isAuthLoading || _isGuest) return 'Hoş Geldiniz';
    final displayName = user!.displayName?.trim();
    return displayName != null && displayName.isNotEmpty
        ? displayName
        : 'Kullanıcı';
  }

  String get _subtitle {
    if (isAuthLoading) return 'Hesap hazırlanıyor';
    if (_isGuest) return 'Misafir Hesabı';
    return user!.email ?? 'E-posta yok';
  }

  String get _actionLabel {
    if (isAuthLoading) return 'Yükleniyor';
    if (_isGuest) return 'Hesap bilgilerini düzenle';
    return 'Profilim';
  }

  IconData get _actionIcon {
    if (isAuthLoading) return Icons.hourglass_top_rounded;
    if (_isGuest) return Icons.manage_accounts_outlined;
    return Icons.person_outline_rounded;
  }

  VoidCallback? get _onTap {
    if (isAuthLoading) return null;
    return _isGuest ? onGuestTap : onProfileTap;
  }

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      AccountProfileEntryVariant.drawer => _buildDrawer(context),
      AccountProfileEntryVariant.standard => _buildStandard(context),
    };
  }

  Widget _buildStandard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: _onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: Icon(_isGuest ? Icons.person_outline : Icons.person),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (!isAuthLoading) ...[
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _actionIcon,
                            color: colorScheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _actionLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right_rounded, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    const drawerText = Color(0xFFE5EAF4);
    const drawerMuted = Color(0xFFB6C0D0);
    const drawerAccent = Color(0xFF4385F5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: drawerAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 29,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: drawerText,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: drawerMuted,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 58,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: drawerAccent,
              foregroundColor: Colors.white,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            onPressed: _onTap,
            icon: Icon(_actionIcon, size: 21),
            label: Text(_actionLabel),
          ),
        ),
      ],
    );
  }
}
