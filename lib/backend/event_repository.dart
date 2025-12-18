import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:omusiber/backend/post_view.dart';

class EventRepository {
  EventRepository({
    FirebaseFirestore? firestore,
    String collectionPath = 'events',
    Duration minRefreshDelay = const Duration(milliseconds: 600),
    Duration cacheTtl = const Duration(seconds: 30),
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _collectionPath = collectionPath,
        _minRefreshDelay = minRefreshDelay,
        _cacheTtl = cacheTtl;

  final FirebaseFirestore _firestore;
  final String _collectionPath;

  /// Minimum time a refresh call should take (prevents UI flicker).
  final Duration _minRefreshDelay;

  /// In-memory cache TTL.
  final Duration _cacheTtl;

  List<PostView>? _cache;
  DateTime? _cacheAt;

  Future<List<PostView>>? _inFlight;

  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection(_collectionPath);

  /// Fetch events with:
  /// - basic in-memory cache (TTL)
  /// - request coalescing (concurrent callers share one Future)
  /// - minimum refresh delay (optional UX smoothing)
  ///
  /// Set [forceRefresh] to bypass cache.
  Future<List<PostView>> fetchEvents({bool forceRefresh = false}) {
    final now = DateTime.now();

    if (!forceRefresh && _cache != null && _cacheAt != null) {
      final age = now.difference(_cacheAt!);
      if (age <= _cacheTtl) {
        return Future.value(_cache);
      }
    }

    // If a fetch is already running, reuse it.
    final existing = _inFlight;
    if (existing != null) return existing;

    final future = _fetchAndCache();
    _inFlight = future;

    // Clear in-flight when done.
    future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });

    return future;
  }

  /// Clears in-memory cache (useful after writes, logout, etc).
  void clearCache() {
    _cache = null;
    _cacheAt = null;
  }

  Future<List<PostView>> _fetchAndCache() async {
    final start = DateTime.now();

    try {
      // Optional: try cache first then server by using Source.serverAndCache.
      // This still obeys security rules; it just uses local persistence when available.
      final querySnapshot = await _eventsRef.get(const GetOptions(source: Source.serverAndCache));

      final items = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return PostView.fromJson({
          'id': doc.id,
          ...data,
        });
      }).toList();

      _cache = items;
      _cacheAt = DateTime.now();

      await _enforceMinDelay(start);
      return items;
    } on FirebaseException catch (e) {
      await _enforceMinDelay(start);
      throw EventRepoException.fromFirebase(e, operation: 'fetchEvents');
    } catch (e) {
      await _enforceMinDelay(start);
      throw EventRepoException.unknown(e, operation: 'fetchEvents');
    }
  }

  Future<void> _enforceMinDelay(DateTime start) async {
    final elapsed = DateTime.now().difference(start);
    final remaining = _minRefreshDelay - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  Future<void> addEvent(PostView event) async {
    try {
      await _eventsRef.doc(event.id).set(event.toJson());
      // Cache is now potentially stale.
      clearCache();
    } on FirebaseException catch (e) {
      throw EventRepoException.fromFirebase(e, operation: 'addEvent');
    } catch (e) {
      throw EventRepoException.unknown(e, operation: 'addEvent');
    }
  }

  Future<void> deleteEvent(String eventId) async {
    try {
      await _eventsRef.doc(eventId).delete();
      clearCache();
    } on FirebaseException catch (e) {
      throw EventRepoException.fromFirebase(e, operation: 'deleteEvent');
    } catch (e) {
      throw EventRepoException.unknown(e, operation: 'deleteEvent');
    }
  }

  Future<void> updateEvent(String eventId, PostView updatedEvent) async {
    try {
      await _eventsRef.doc(eventId).update(updatedEvent.toJson());
      clearCache();
    } on FirebaseException catch (e) {
      throw EventRepoException.fromFirebase(e, operation: 'updateEvent');
    } catch (e) {
      throw EventRepoException.unknown(e, operation: 'updateEvent');
    }
  }
}

/// Typed exception you can handle in UI.
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
  final String? code;
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
