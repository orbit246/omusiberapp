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
  });

  factory PostView.fromJson(Map<String, dynamic> json) {
    return PostView(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      tags: List<String>.from(json['tags'] as List),
      maxContributors: json['maxContributors'] as int,
      remainingContributors: json['remainingContributors'] as int,
      ticketPrice: (json['ticketPrice'] as num).toDouble(),
      location: json['location'] as String,
      thubnailUrl: json['thubnailUrl'] as String,
      imageLinks: List<String>.from(json['imageLinks'] as List),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
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
    };
  }
}
