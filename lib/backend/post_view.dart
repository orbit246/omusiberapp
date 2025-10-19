class PostView {
  final String id;
  final String title;
  final String description;
  final String tags;
  final int maxContributors;
  final double ticketPrice;
  final String location;
  final List<String> imageLinks;
  final Map<String, Object> metadata;

  PostView({  
    required this.id,
    required this.title,
    required this.description,
    required this.tags,
    required this.maxContributors,
    required this.ticketPrice,
    required this.location,
    required this.imageLinks,
    required this.metadata,
  });

  // Optional: Add fromJson factory constructor
  factory PostView.fromJson(Map<String, dynamic> json) {
    return PostView(
      title: json['title'] as String,
      description: json['description'] as String,
      tags: json['tags'] as String,
      maxContributors: json['maxContributors'] as int,
      ticketPrice: (json['ticketPrice'] as num).toDouble(),
      location: json['location'] as String,
      imageLinks: List<String>.from(json['imageLinks'] as List),
      id: json['id'] as String,
      metadata: Map<String, Object>.from(json['metadata'] as Map),
    );
  }

  // Optional: Add toJson method
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'tags': tags,
      'maxContributors': maxContributors,
      'ticketPrice': ticketPrice,
      'location': location,
      'imageLinks': imageLinks,
      'id': id,
      'metadata': metadata,
    };
  }
}