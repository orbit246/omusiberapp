enum MasterNewsWidgetCardKind { event, news, community, unknown }

enum MasterNewsWidgetActionType { openTab, scrollNewsList, none }

class MasterNewsWidgetsView {
  final List<MasterNewsWidgetSection> sections;

  const MasterNewsWidgetsView({this.sections = const <MasterNewsWidgetSection>[]});

  factory MasterNewsWidgetsView.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
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
    final rawCards = json['cards'];
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
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
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
      kind: _parseCardKind(json['kind']?.toString()),
      subtitle: json['subtitle']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      trailingText: json['trailingText']?.toString(),
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
    'action': {
      'type': actionType.name,
      'targetTabIndex': targetTabIndex,
    },
  };

  static MasterNewsWidgetCardKind _parseCardKind(String? value) {
    switch (value) {
      case 'event':
        return MasterNewsWidgetCardKind.event;
      case 'news':
        return MasterNewsWidgetCardKind.news;
      case 'community':
        return MasterNewsWidgetCardKind.community;
      default:
        return MasterNewsWidgetCardKind.unknown;
    }
  }

  static MasterNewsWidgetActionType _parseActionType(String? value) {
    switch (value) {
      case 'open_tab':
        return MasterNewsWidgetActionType.openTab;
      case 'scroll_news_list':
        return MasterNewsWidgetActionType.scrollNewsList;
      default:
        return MasterNewsWidgetActionType.none;
    }
  }
}
