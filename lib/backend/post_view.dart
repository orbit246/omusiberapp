import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';

class PostView {
  final String id;
  final String title;
  final String description;
  final List<String> tags;
  final int maxContributors;
  final int remainingContributors;
  final double ticketPrice;
  final String location;
  final String thubnailUrl;
  final List<String> imageLinks;
  final Map<String, dynamic> metadata;
  final DateTime? eventDate;
  final DateTime? registrationEndDate;
  final bool? _isJoined;
  final bool? _isLiked;
  final bool? _isRegistrationClosed;
  final String publisher;
  final bool allowAppSignups;
  final String? redirectTo;

  bool get isJoined => _isJoined ?? false;
  bool get isLiked => _isLiked ?? false;
  bool get isRegistrationClosed => _isRegistrationClosed ?? false;

  PostView({
    required this.id,
    required this.title,
    required this.description,
    required this.tags,
    required this.maxContributors,
    required this.remainingContributors,
    required this.ticketPrice,
    required this.location,
    required this.thubnailUrl,
    required this.imageLinks,
    required this.metadata,
    this.eventDate,
    this.registrationEndDate,
    bool? isJoined,
    bool? isLiked,
    bool? isRegistrationClosed,
    this.publisher = '',
    this.allowAppSignups = true,
    this.redirectTo,
  }) : _isJoined = isJoined,
       _isLiked = isLiked,
       _isRegistrationClosed = isRegistrationClosed;

  factory PostView.fromJson(Map<String, dynamic> json) {
    // Parse JSON strings if they are strings (New API), otherwise use as is (Backward compatibility)
    List<String> parseList(dynamic value) {
      if (value is String) {
        try {
          final decoded = (jsonDecode(value) as List)
              .map((e) => e.toString())
              .toList();
          return decoded;
        } catch (_) {
          return [];
        }
      } else if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    }

    final tagsList = parseList(json['tags']);

    // Check for new API carousel fields
    List<String> imagesList = parseList(json['carouselImageFullUrls']);
    if (imagesList.isEmpty) {
      imagesList = parseList(json['carouselImages']);
    }

    final joinersList = parseList(json['joiners']);

    // Check if joined - prioritize explicit field
    bool joined = json['isJoined'] as bool? ?? false;
    if (json['isJoined'] == null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (joinersList.contains(user.uid)) {
          joined = true;
        }
      }
    }

    final bool liked = json['isLiked'] as bool? ?? false;

    // New API has maxJoiners or maxContributors
    final int maxJoiners = json['maxJoiners'] is num
        ? (json['maxJoiners'] as num).toInt()
        : (json['maxContributors'] as int? ?? 0);

    final int currentJoiners = json['joinerCount'] is int
        ? json['joinerCount']
        : joinersList.length;
    final int remaining = maxJoiners > 0 ? (maxJoiners - currentJoiners) : 0;

    // Handle event date
    String dateStr = json['date'] as String? ?? '';
    if (dateStr.isEmpty) {
      dateStr = json['createdAt'] as String? ?? '';
    }
    final DateTime? parsedDate = DateTime.tryParse(dateStr);

    // Handle registration end date
    final String regEndDateStr = json['registrationEndDate'] as String? ?? '';
    final DateTime? parsedRegEndDate = DateTime.tryParse(regEndDateStr);

    // Handle isRegistrationClosed
    // Use explicit field if available, otherwise calculate locally if regEndDate is present
    bool registrationClosed = json['isRegistrationClosed'] as bool? ?? false;
    if (json['isRegistrationClosed'] == null && parsedRegEndDate != null) {
      registrationClosed = DateTime.now().isAfter(parsedRegEndDate);
    }

    // New stats
    final int views = json['views'] is int ? json['views'] : 0;
    final int likes = json['likes'] is int ? json['likes'] : 0;

    // Favor absolute URLs for mobile
    String thumb = json['thumbnailFullUrl'] as String? ?? '';
    if (thumb.isEmpty) {
      thumb = json['thumbnailUrl'] as String? ?? '';
    }

    return PostView(
      // API sends ID as int, we convert to String for consistency
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tags: tagsList,
      maxContributors: maxJoiners,
      remainingContributors: remaining,
      ticketPrice: 0.0, // New API events are free or price not specified yet
      location: json['location'] as String? ?? '',
      thubnailUrl: thumb,
      imageLinks: imagesList,
      metadata: {
        'datetimeText': dateStr, // You might want to format this
        'eventLength': json['eventLength'], // Keeps it raw if needed
        'views': views,
        'likes': likes,
        'joiners': joinersList,
        'joinerCount': currentJoiners,
        'createdAt': json['createdAt'],
      },
      eventDate: parsedDate,
      registrationEndDate: parsedRegEndDate,
      isJoined: joined,
      isLiked: liked,
      isRegistrationClosed: registrationClosed,
      publisher: json['publisher'] as String? ?? '',
      allowAppSignups: json['allowAppSignups'] as bool? ?? true,
      redirectTo: json['redirectTo'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'tags': tags,
      'maxContributors': maxContributors,
      'remainingContributors': remainingContributors,
      'ticketPrice': ticketPrice,
      'location': location,
      'thubnailUrl': thubnailUrl,
      'imageLinks': imageLinks,
      'metadata': metadata,
      'eventDate': eventDate?.toIso8601String(),
      'registrationEndDate': registrationEndDate?.toIso8601String(),
      'isJoined': _isJoined,
      'isLiked': _isLiked,
      'isRegistrationClosed': _isRegistrationClosed,
      'publisher': publisher,
      'allowAppSignups': allowAppSignups,
      'redirectTo': redirectTo,
    };
  }
}
