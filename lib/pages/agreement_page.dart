import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omusiber/backend/constants.dart';

class AgreementsPage extends StatefulWidget {
  const AgreementsPage({
    super.key,
    required this.onContinue,
    this.termsAssetPath = 'assets/agreements/terms_tr.md',
    this.privacyAssetPath = 'assets/agreements/privacy_tr.md',
    this.consentAssetPath = 'assets/agreements/consent_tr.md',
  });

  final Future<void> Function(AgreementsAcceptance acceptance) onContinue;

  final String termsAssetPath;
  final String privacyAssetPath;
  final String consentAssetPath;

  @override
  State<AgreementsPage> createState() => _AgreementsPageState();
}

class _AgreementsPageState extends State<AgreementsPage> {
  bool _termsOk = false;
  bool _privacyOk = false;
  bool _consentOk = false;

  bool _submitting = false;

  String? _termsText;
  String? _privacyText;
  String? _consentText;

  Object? _loadError;

  bool get _allOk => _termsOk && _privacyOk && _consentOk;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loadError = null);
    try {
      final results = await Future.wait<String>([
        rootBundle.loadString(widget.termsAssetPath),
        rootBundle.loadString(widget.privacyAssetPath),
        rootBundle.loadString(widget.consentAssetPath),
      ]);
      if (!mounted) return;
      setState(() {
        _termsText = results[0];
        _privacyText = results[1];
        _consentText = results[2];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final loading =
        _termsText == null || _privacyText == null || _consentText == null;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primaryContainer.withValues(alpha: 0.35),
              cs.surface,
              cs.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: loading
                    ? _LoadingState(error: _loadError, onRetry: _loadAll)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            elevation: 0,
                            color: cs.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(color: cs.outlineVariant),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                14,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: cs.primaryContainer,
                                    foregroundColor: cs.onPrimaryContainer,
                                    child: const Icon(
                                      Icons.verified_user_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Devam etmeden önce onay vermen gerekiyor',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Metinleri aç, oku ve her birini ayrı ayrı onayla.',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: cs.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          _AgreementTile(
                            title: 'Kullanım Şartları',
                            subtitle: _termsOk
                                ? 'Kabul edildi'
                                : 'Aç ve onayla',
                            icon: Icons.description_outlined,
                            accepted: _termsOk,
                            onTap: () async {
                              final ok = await _openAgreementSheet(
                                context,
                                title: 'Kullanım Şartları',
                                body: _termsText!,
                                initiallyAccepted: _termsOk,
                              );
                              if (ok != null) setState(() => _termsOk = ok);
                            },
                          ),
                          const SizedBox(height: 10),

                          _AgreementTile(
                            title: 'Gizlilik Politikası',
                            subtitle: _privacyOk
                                ? 'Kabul edildi'
                                : 'Aç ve onayla',
                            icon: Icons.privacy_tip_outlined,
                            accepted: _privacyOk,
                            onTap: () async {
                              final ok = await _openAgreementSheet(
                                context,
                                title: 'Gizlilik Politikası',
                                body: _privacyText!,
                                initiallyAccepted: _privacyOk,
                              );
                              if (ok != null) setState(() => _privacyOk = ok);
                            },
                          ),
                          const SizedBox(height: 10),

                          _AgreementTile(
                            title: 'Açık Rıza Metni',
                            subtitle: _consentOk
                                ? 'Kabul edildi'
                                : 'Aç ve onayla',
                            icon: Icons.public_outlined,
                            accepted: _consentOk,
                            onTap: () async {
                              final ok = await _openAgreementSheet(
                                context,
                                title: 'Açık Rıza Metni',
                                body: _consentText!,
                                initiallyAccepted: _consentOk,
                              );
                              if (ok != null) setState(() => _consentOk = ok);
                            },
                          ),

                          const SizedBox(height: 16),

                          FilledButton.icon(
                            onPressed: (!_allOk || _submitting)
                                ? null
                                : _handleContinue,
                            icon: _submitting
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: cs.onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward),
                            label: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                _submitting
                                    ? 'Kaydediliyor...'
                                    : 'Kabul Et ve Devam Et',
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),
                          Text(
                            'Kabul kaydı (sürüm ve tarih) güvenlik amacıyla saklanır.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleContinue() async {
    setState(() => _submitting = true);

    try {
      final acceptance = AgreementsAcceptance(
        terms: AgreementAcceptance(
          accepted: _termsOk,
          version: _extractVersion(_termsText!) ?? 'unknown',
        ),
        privacy: AgreementAcceptance(
          accepted: _privacyOk,
          version: _extractVersion(_privacyText!) ?? 'unknown',
        ),
        consent: AgreementAcceptance(
          accepted: _consentOk,
          version: _extractVersion(_consentText!) ?? 'unknown',
        ),
      );

      await widget.onContinue(acceptance);
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İşlem başarısız: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _AgreementTile extends StatelessWidget {
  const _AgreementTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accepted,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool accepted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.onSecondaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              accepted
                  ? Icon(Icons.check_circle, color: cs.primary)
                  : Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool?> _openAgreementSheet(
  BuildContext context, {
  required String title,
  required String body,
  required bool initiallyAccepted,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: cs.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      bool accepted = initiallyAccepted;

      return StatefulBuilder(
        builder: (ctx, setState) {
          final height = MediaQuery.of(ctx).size.height * 0.85;

          return SizedBox(
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: SelectableText(
                      body,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),

                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Card(
                    elevation: 0,
                    color: cs.surfaceContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => accepted = !accepted),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: accepted,
                              onChanged: (v) =>
                                  setState(() => accepted = v ?? false),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Okudum ve kabul ediyorum',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  child: FilledButton(
                    onPressed: accepted
                        ? () => Navigator.of(ctx).pop(true)
                        : null,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Onayla'),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Vazgeç'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (error == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: cs.primary),
          const SizedBox(height: 12),
          Text('Metinler yükleniyor...', style: theme.textTheme.bodyMedium),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 34, color: cs.error),
        const SizedBox(height: 10),
        Text('Metinler yüklenemedi:\n$error', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tekrar Dene'),
        ),
      ],
    );
  }
}

class AgreementsAcceptance {
  AgreementsAcceptance({
    required this.terms,
    required this.privacy,
    required this.consent,
  });

  final AgreementAcceptance terms;
  final AgreementAcceptance privacy;
  final AgreementAcceptance consent;

  Map<String, dynamic> toJson() => {
    'terms': terms.toJson(),
    'privacy': privacy.toJson(),
    'consent': consent.toJson(),
  };
}

class AgreementAcceptance {
  AgreementAcceptance({required this.accepted, required this.version});

  final bool accepted;
  final String version;

  Map<String, dynamic> toJson() => {'accepted': accepted, 'version': version};
}

String? _extractVersion(String text) {
  final lines = text.split('\n');
  for (final raw in lines.take(40)) {
    final line = raw.trim();
    final lower = line.toLowerCase();
    if (lower.startsWith('sürüm:') ||
        lower.startsWith('surum:') ||
        lower.startsWith('version:')) {
      final parts = line.split(':');
      if (parts.length >= 2) return parts.sublist(1).join(':').trim();
    }
  }
  return null;
}
