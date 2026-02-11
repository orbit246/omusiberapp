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
  final bool isJoined;

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
    this.isJoined = false,
  });

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
    final imagesList = parseList(json['carouselImages']);
    final joinersList = parseList(json['joiners']);

    // Check if joined
    bool joined = false;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (joinersList.contains(user.uid)) {
        joined = true;
      }
    }

    // New API has maxJoiners
    final int maxJoiners = json['maxJoiners'] is num
        ? (json['maxJoiners'] as num).toInt()
        : (json['maxContributors'] as int? ?? 0);

    final int currentJoiners = joinersList.length;
    final int remaining = maxJoiners > 0 ? (maxJoiners - currentJoiners) : 0;

    // Handle date
    String dateStr = json['date'] as String? ?? '';
    if (dateStr.isEmpty) {
      dateStr = json['createdAt'] as String? ?? '';
    }

    // New stats
    final int views = json['views'] is int ? json['views'] : 0;
    final int likes = json['likes'] is int ? json['likes'] : 0;

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
      thubnailUrl: json['thumbnailUrl'] as String? ?? '',
      imageLinks: imagesList,
      metadata: {
        'datetimeText': dateStr, // You might want to format this
        'eventLength': json['eventLength'], // Keeps it raw if needed
        'views': views,
        'likes': likes,
        'joiners': joinersList,
        'createdAt': json['createdAt'],
      },
      isJoined: joined,
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
      'isJoined': isJoined,
    };
  }
}
