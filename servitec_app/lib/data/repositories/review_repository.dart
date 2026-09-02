import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/review_model.dart';

/// Reads and moderates `resenas`.
///
/// The técnico's average rating is NOT recomputed here. firestore.rules block
/// every client — admin included — from writing `calificacionPromedio` and
/// `totalResenas` on a user, so the recompute lives in the `onReviewWritten`
/// Cloud Function, which fires on create and delete alike. Deleting a review
/// from the admin panel therefore corrects the técnico's score automatically.
class ReviewRepository {
  final FirebaseFirestore _firestore;

  ReviewRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('resenas');

  /// Newest first, across every técnico. Admin moderation view.
  Stream<List<ReviewModel>> streamAll({int limit = 200}) {
    return _ref
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ReviewModel.fromFirestore).toList());
  }

  /// Removes a review. Admin-only by rules.
  Future<void> delete(String reviewId) => _ref.doc(reviewId).delete();
}
