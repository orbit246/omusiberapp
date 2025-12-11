import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:omusiber/backend/post_view.dart';

class EventRepository {
  EventRepository({
    FirebaseFirestore? firestore,
    String collectionPath = 'events',
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _collectionPath = collectionPath;

  final FirebaseFirestore _firestore;
  final String _collectionPath;

  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection(_collectionPath);

  /// READ: everyone can use this (with read-only rules)
  Future<List<PostView>> fetchEvents() async {
    final querySnapshot = await _eventsRef.get();
    return querySnapshot.docs.map((doc) {
      final data = doc.data();

      // Ensure `id` is in the json for PostView.fromJson
      return PostView.fromJson({
        'id': doc.id,
        ...data,
      });
    }).toList();
  }

  /// WRITE METHODS
  /// These will fail with `permission-denied` if you enforce read-only rules.
  /// Use them only from an admin/backend context (or change rules accordingly).

  Future<void> addEvent(PostView event) async {
    // If Firestore document ID should match `event.id`:
    await _eventsRef.doc(event.id).set(event.toJson());

    // If you want Firestore to auto-generate an ID:
    // final docRef = await _eventsRef.add(event.toJson());
    // You'd then have to manage syncing docRef.id back into your model.
  }

  Future<void> deleteEvent(String eventId) async {
    await _eventsRef.doc(eventId).delete();
  }

  Future<void> updateEvent(String eventId, PostView updatedEvent) async {
    // Option A: use full toJson (overwrites existing fields)
    await _eventsRef.doc(eventId).update(updatedEvent.toJson());

    // Option B: partial update:
    // await _eventsRef.doc(eventId).update({
    //   'title': updatedEvent.title,
    //   'description': updatedEvent.description,
    //   'tags': updatedEvent.tags,
    //   'maxContributors': updatedEvent.maxContributors,
    //   'remainingContributors': updatedEvent.remainingContributors,
    //   'ticketPrice': updatedEvent.ticketPrice,
    //   'location': updatedEvent.location,
    //   'thubnailUrl': updatedEvent.thubnailUrl,
    //   'imageLinks': updatedEvent.imageLinks,
    //   'metadata': updatedEvent.metadata,
    // });
  }
}