import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/category_model.dart';
import '../../data/repositories/category_repository.dart';

/// Process-wide category lookup, backed by Firestore and kept live.
///
/// Every screen that used to read `AppConstants.categoryLabels[key]` now
/// reads [label], [icon] or [active] here. The static API is deliberate:
/// categories are referenced from a dozen widgets, most of them far from any
/// provider, and threading a repository through all of them for a lookup
/// table would have touched every one for no gain.
///
/// Starts from the hardcoded defaults so the first frame is never empty, then
/// subscribes to `configuracion/categorias`. When an admin edits the
/// catalogue every open picker rebuilds via [notifier]. Users on other
/// devices see the change on their next launch, which is what an
/// admin-managed lookup table needs.
class CategoryCatalog {
  CategoryCatalog._();

  static List<CategoryModel> _all = CategoryRepository.defaults;
  static Map<String, CategoryModel> _byKey = {
    for (final c in _all) c.key: c,
  };
  static StreamSubscription<List<CategoryModel>>? _sub;

  /// Bumps on every catalogue change. Wrap category pickers in a
  /// `ListenableBuilder(listenable: CategoryCatalog.notifier, ...)`.
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  /// Call once after Firebase is initialised. Idempotent.
  static void start(CategoryRepository repo) {
    _sub ??= repo.watch().listen((list) {
      // An empty document (not yet seeded) keeps the defaults rather than
      // wiping every picker.
      if (list.isEmpty) return;
      _all = list;
      _byKey = {for (final c in list) c.key: c};
      notifier.value++;
    });
  }

  /// Every category, including deactivated ones, in display order.
  static List<CategoryModel> get all => List.unmodifiable(_all);

  /// Categories a user may pick from today.
  static List<CategoryModel> get active =>
      List.unmodifiable(_all.where((c) => c.activo));

  /// Keys of [active], for code that only needs the identifiers.
  static List<String> get activeKeys => active.map((c) => c.key).toList();

  static String label(String key) => _byKey[key]?.label ?? key;
  static String icon(String key) => _byKey[key]?.icon ?? '';

  /// "⚡ Electricidad" — the form most screens render.
  static String display(String key) {
    final c = _byKey[key];
    return c == null ? key : '${c.icon} ${c.label}';
  }

  @visibleForTesting
  static void resetForTest([List<CategoryModel>? seed]) {
    _sub?.cancel();
    _sub = null;
    _all = seed ?? CategoryRepository.defaults;
    _byKey = {for (final c in _all) c.key: c};
  }
}
