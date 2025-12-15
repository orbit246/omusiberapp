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

  Future<List<PostView>> fetchEvents() async {
    try {
      final querySnapshot = await _eventsRef.get();
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return PostView.fromJson({
          'id': doc.id,
          ...data,
        });
      }).toList();
    } on FirebaseException catch (e) {
      throw EventRepoException.fromFirebase(e, operation: 'fetchEvents');
    } catch (e) {
      throw EventRepoException.unknown(e, operation: 'fetchEvents');
    }
  }

  Future<void> addEvent(PostView event) async {
    try {
      await _eventsRef.doc(event.id).set(event.toJson());
    } on FirebaseException catch (e) {
      throw EventRepoException.fromFirebase(e, operation: 'addEvent');
    } catch (e) {
      throw EventRepoException.unknown(e, operation: 'addEvent');
    }
  }

  Future<void> deleteEvent(String eventId) async {
    try {
      await _eventsRef.doc(eventId).delete();
    } on FirebaseException catch (e) {
      throw EventRepoException.fromFirebase(e, operation: 'deleteEvent');
    } catch (e) {
      throw EventRepoException.unknown(e, operation: 'deleteEvent');
    }
  }

  Future<void> updateEvent(String eventId, PostView updatedEvent) async {
    try {
      await _eventsRef.doc(eventId).update(updatedEvent.toJson());
    } on FirebaseException catch (e) {
      throw EventRepoException.fromFirebase(e, operation: 'updateEvent');
    } catch (e) {
      throw EventRepoException.unknown(e, operation: 'updateEvent');
    }
  }
}

/// Typed exception you can handle in UI.
///
/// Typical UI usage:
/// try { await repo.addEvent(e); }
/// on EventRepoException catch (e) {
///   if (e.kind == EventRepoErrorKind.permissionDenied) ...
/// }
enum EventRepoErrorKind {
  permissionDenied,
  unauthenticated,
  notFound,
  alreadyExists,
  invalidArgument,
  quotaExceeded,
  unavailable,
  cancelled,
  unknown,
}

class EventRepoException implements Exception {
  EventRepoException({
    required this.kind,
    required this.operation,
    required this.message,
    this.code,
    this.original,
  });

  final EventRepoErrorKind kind;
  final String operation;
  final String message;
  final String? code; // firebase code
  final Object? original;

  factory EventRepoException.fromFirebase(
    FirebaseException e, {
    required String operation,
  }) {
    final kind = _mapFirebaseCode(e.code);
    return EventRepoException(
      kind: kind,
      operation: operation,
      code: e.code,
      message: _defaultMessage(kind, e.message),
      original: e,
    );
  }

  factory EventRepoException.unknown(
    Object e, {
    required String operation,
  }) {
    return EventRepoException(
      kind: EventRepoErrorKind.unknown,
      operation: operation,
      message: 'Unknown error during $operation',
      original: e,
    );
  }

  @override
  String toString() =>
      'EventRepoException(kind: $kind, op: $operation, code: $code, message: $message)';
}

EventRepoErrorKind _mapFirebaseCode(String code) {
  switch (code) {
    case 'permission-denied':
      return EventRepoErrorKind.permissionDenied;
    case 'unauthenticated':
      return EventRepoErrorKind.unauthenticated;
    case 'not-found':
      return EventRepoErrorKind.notFound;
    case 'already-exists':
      return EventRepoErrorKind.alreadyExists;
    case 'invalid-argument':
      return EventRepoErrorKind.invalidArgument;
    case 'resource-exhausted':
      return EventRepoErrorKind.quotaExceeded;
    case 'unavailable':
      return EventRepoErrorKind.unavailable;
    case 'cancelled':
      return EventRepoErrorKind.cancelled;
    default:
      return EventRepoErrorKind.unknown;
  }
}

String _defaultMessage(EventRepoErrorKind kind, String? firebaseMessage) {
  // Keep messages stable for UI; keep firebaseMessage as fallback.
  switch (kind) {
    case EventRepoErrorKind.permissionDenied:
      return 'Permission denied';
    case EventRepoErrorKind.unauthenticated:
      return 'You are not signed in';
    case EventRepoErrorKind.notFound:
      return 'Document not found';
    case EventRepoErrorKind.alreadyExists:
      return 'Document already exists';
    case EventRepoErrorKind.invalidArgument:
      return 'Invalid data sent to server';
    case EventRepoErrorKind.quotaExceeded:
      return 'Quota exceeded';
    case EventRepoErrorKind.unavailable:
      return 'Service unavailable or network issue';
    case EventRepoErrorKind.cancelled:
      return 'Request cancelled';
    case EventRepoErrorKind.unknown:
      return firebaseMessage ?? 'Unknown error';
  }
}
