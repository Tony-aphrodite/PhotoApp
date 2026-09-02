import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/category_model.dart';

/// Reads and writes the admin-editable category catalogue at
/// `configuracion/categorias`.
///
/// The document is a map of `key → {label, icon, activo, orden}`. Until an
/// admin first edits it the document does not exist, and [seedIfMissing]
/// writes the list that used to be hardcoded in AppConstants — so nothing
/// changes for anyone until the admin decides it should.
class CategoryRepository {
  final FirebaseFirestore _firestore;

  CategoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc => _firestore
      .collection(AppConstants.configCollection)
      .doc('categorias');

  static List<CategoryModel> _parse(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return const [];
    final list = data.entries
        .where((e) => e.value is Map)
        .map((e) => CategoryModel.fromMap(
              e.key,
              Map<String, dynamic>.from(e.value as Map),
            ))
        .toList();
    list.sort((a, b) => a.orden.compareTo(b.orden));
    return list;
  }

  /// The catalogue as it was hardcoded before this existed. Used both to seed
  /// Firestore and as the fallback while the first read is in flight.
  static List<CategoryModel> get defaults => [
        for (var i = 0; i < AppConstants.serviceCategories.length; i++)
          CategoryModel(
            key: AppConstants.serviceCategories[i],
            label: AppConstants.categoryLabels[AppConstants.serviceCategories[i]] ??
                AppConstants.serviceCategories[i],
            icon: AppConstants.categoryIcons[AppConstants.serviceCategories[i]] ?? '📋',
            orden: i,
          ),
      ];

  Stream<List<CategoryModel>> watch() =>
      _doc.snapshots().map((d) => _parse(d.data()));

  Future<List<CategoryModel>> fetch() async => _parse((await _doc.get()).data());

  /// Writes the hardcoded defaults if the document does not exist yet.
  /// Safe to call on every admin visit; it is a no-op once seeded.
  Future<void> seedIfMissing() async {
    final snap = await _doc.get();
    if (snap.exists && (snap.data()?.isNotEmpty ?? false)) return;
    await _doc.set({for (final c in defaults) c.key: c.toMap()});
  }

  Future<void> upsert(CategoryModel c) =>
      _doc.set({c.key: c.toMap()}, SetOptions(merge: true));

  /// Reorders by rewriting `orden` for the given keys, in order.
  Future<void> reorder(List<String> keys) => _doc.set(
        {for (var i = 0; i < keys.length; i++) keys[i]: {'orden': i}},
        SetOptions(merge: true),
      );
}
