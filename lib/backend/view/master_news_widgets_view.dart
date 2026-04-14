enum MasterNewsWidgetCardKind { event, news, community, lesson, unknown }

enum MasterNewsWidgetActionType { openTab, openSchedule, scrollNewsList, none }

class MasterNewsWidgetsView {
  final List<MasterNewsWidgetSection> sections;

  const MasterNewsWidgetsView({
    this.sections = const <MasterNewsWidgetSection>[],
  });

  factory MasterNewsWidgetsView.fromJson(Map<String, dynamic> json) {
    final rawSections = _resolveSections(json);
    final sections = rawSections is List
        ? rawSections
              .map((item) {
                if (item is Map<String, dynamic>) {
                  return MasterNewsWidgetSection.fromJson(item);
                }
                if (item is Map) {
                  return MasterNewsWidgetSection.fromJson(
                    Map<String, dynamic>.from(item),
                  );
                }
                return null;
              })
              .whereType<MasterNewsWidgetSection>()
              .toList(growable: false)
        : const <MasterNewsWidgetSection>[];

    return MasterNewsWidgetsView(sections: sections);
  }

  static Object? _resolveSections(Map<String, dynamic> json) {
    if (json['sections'] is List) {
      return json['sections'];
    }

    final data = json['data'];
    if (data is Map<String, dynamic> && data['sections'] is List) {
      return data['sections'];
    }
    if (data is Map && data['sections'] is List) {
      return data['sections'];
    }

    final inferredSections = <Map<String, dynamic>>[];
    for (final entry in json.entries) {
      final normalizedKey = _normalizeSectionId(entry.key);
      if (normalizedKey == null) {
        continue;
      }

      final value = entry.value;
      if (value is Map<String, dynamic>) {
        inferredSections.add({
          'id': value['id'] ?? normalizedKey,
          'title': value['title'] ?? _defaultTitleForSection(normalizedKey),
          'cards':
              value['cards'] ?? value['items'] ?? value['widgets'] ?? const [],
        });
      } else if (value is Map) {
        final mapped = Map<String, dynamic>.from(value);
        inferredSections.add({
          'id': mapped['id'] ?? normalizedKey,
          'title': mapped['title'] ?? _defaultTitleForSection(normalizedKey),
          'cards':
              mapped['cards'] ??
              mapped['items'] ??
              mapped['widgets'] ??
              const [],
        });
      } else if (value is List) {
        inferredSections.add({
          'id': normalizedKey,
          'title': _defaultTitleForSection(normalizedKey),
          'cards': value,
        });
      }
    }

    return inferredSections;
  }

  static String? _normalizeSectionId(String? raw) {
    final normalized = _normalizeToken(raw);
    switch (normalized) {
      case 'today':
      case 'bugun':
        return 'today';
      case 'week':
      case 'thisweek':
      case 'buhafta':
        return 'week';
      default:
        return null;
    }
  }

  static String _defaultTitleForSection(String sectionId) {
    switch (sectionId) {
      case 'today':
        return 'Bugün';
      case 'week':
        return 'Bu Hafta';
      default:
        return sectionId;
    }
  }

  static String _normalizeToken(String? value) {
    return (value ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  Map<String, dynamic> toJson() => {
    'sections': sections.map((section) => section.toJson()).toList(),
  };
}

class MasterNewsWidgetSection {
  final String id;
  final String title;
  final List<MasterNewsWidgetCard> cards;

  const MasterNewsWidgetSection({
    required this.id,
    required this.title,
    this.cards = const <MasterNewsWidgetCard>[],
  });

  factory MasterNewsWidgetSection.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'] ?? json['items'] ?? json['widgets'];
    final normalizedId =
        MasterNewsWidgetsView._normalizeSectionId(json['id']?.toString()) ??
        json['id']?.toString() ??
        '';
    final cards = rawCards is List
        ? rawCards
              .map((item) {
                if (item is Map<String, dynamic>) {
                  return MasterNewsWidgetCard.fromJson(item);
                }
                if (item is Map) {
                  return MasterNewsWidgetCard.fromJson(
                    Map<String, dynamic>.from(item),
                  );
                }
                return null;
              })
              .whereType<MasterNewsWidgetCard>()
              .toList(growable: false)
        : const <MasterNewsWidgetCard>[];

    return MasterNewsWidgetSection(
      id: normalizedId,
      title:
          json['title']?.toString() ??
          MasterNewsWidgetsView._defaultTitleForSection(normalizedId),
      cards: cards,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'cards': cards.map((card) => card.toJson()).toList(),
  };
}

class MasterNewsWidgetCard {
  final String id;
  final MasterNewsWidgetCardKind kind;
  final String subtitle;
  final String value;
  final String? trailingText;
  final MasterNewsWidgetActionType actionType;
  final int? targetTabIndex;

  const MasterNewsWidgetCard({
    required this.id,
    required this.kind,
    required this.subtitle,
    required this.value,
    this.trailingText,
    this.actionType = MasterNewsWidgetActionType.none,
    this.targetTabIndex,
  });

  bool get isInteractive => actionType != MasterNewsWidgetActionType.none;

  factory MasterNewsWidgetCard.fromJson(Map<String, dynamic> json) {
    final rawAction = json['action'];
    final action = rawAction is Map<String, dynamic>
        ? rawAction
        : rawAction is Map
        ? Map<String, dynamic>.from(rawAction)
        : const <String, dynamic>{};

    final rawActionType =
        action['type']?.toString() ?? json['actionType']?.toString();
    final rawTabIndex = action['targetTabIndex'] ?? json['targetTabIndex'];

    return MasterNewsWidgetCard(
      id: json['id']?.toString() ?? '',
      kind: _parseCardKind(
        json['kind']?.toString() ?? json['type']?.toString(),
      ),
      subtitle:
          json['subtitle']?.toString() ??
          json['title']?.toString() ??
          json['label']?.toString() ??
          '',
      value:
          json['value']?.toString() ??
          json['text']?.toString() ??
          json['count']?.toString() ??
          '',
      trailingText:
          json['trailingText']?.toString() ??
          json['trailing']?.toString() ??
          json['meta']?.toString(),
      actionType: _parseActionType(rawActionType),
      targetTabIndex: rawTabIndex is num
          ? rawTabIndex.toInt()
          : int.tryParse(rawTabIndex?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'subtitle': subtitle,
    'value': value,
    'trailingText': trailingText,
    'action': {'type': actionType.name, 'targetTabIndex': targetTabIndex},
  };

  static MasterNewsWidgetCardKind _parseCardKind(String? value) {
    switch (MasterNewsWidgetsView._normalizeToken(value)) {
      case 'event':
        return MasterNewsWidgetCardKind.event;
      case 'news':
        return MasterNewsWidgetCardKind.news;
      case 'community':
        return MasterNewsWidgetCardKind.community;
      case 'lesson':
      case 'lessons':
      case 'ders':
      case 'dersler':
        return MasterNewsWidgetCardKind.lesson;
      default:
        return MasterNewsWidgetCardKind.unknown;
    }
  }

  static MasterNewsWidgetActionType _parseActionType(String? value) {
    switch (MasterNewsWidgetsView._normalizeToken(value)) {
      case 'opentab':
        return MasterNewsWidgetActionType.openTab;
      case 'openschedule':
      case 'openschedulepage':
      case 'schedule':
        return MasterNewsWidgetActionType.openSchedule;
      case 'scrollnewslist':
        return MasterNewsWidgetActionType.scrollNewsList;
      default:
        return MasterNewsWidgetActionType.none;
    }
  }
}
