import 'package:flutter_test/flutter_test.dart';
import 'package:servitec_app/core/constants/app_constants.dart';
import 'package:servitec_app/core/utils/category_catalog.dart';
import 'package:servitec_app/data/models/category_model.dart';
import 'package:servitec_app/data/repositories/category_repository.dart';

/// Categories moved from a hardcoded list to Firestore. These pin the two
/// things that must not regress: the defaults are exactly what the app shipped
/// with (so seeding changes nothing for users), and lookups degrade gracefully
/// for a key the catalogue does not know.
void main() {
  setUp(() => CategoryCatalog.resetForTest());

  test('defaults match the list that used to be hardcoded, in order', () {
    final d = CategoryRepository.defaults;
    expect(d.map((c) => c.key).toList(), AppConstants.serviceCategories);
    for (final c in d) {
      expect(c.label, AppConstants.categoryLabels[c.key]);
      expect(c.icon, AppConstants.categoryIcons[c.key]);
      expect(c.activo, isTrue);
    }
  });

  test('lookups work before Firestore has answered', () {
    expect(CategoryCatalog.label('plomeria'), 'Plomería');
    expect(CategoryCatalog.icon('plomeria'), '🔧');
    expect(CategoryCatalog.display('plomeria'), '🔧 Plomería');
  });

  test('an unknown key falls back to itself rather than crashing a card', () {
    // A service created under a category that was later renamed or removed
    // must still render.
    expect(CategoryCatalog.label('categoria_vieja'), 'categoria_vieja');
    expect(CategoryCatalog.icon('categoria_vieja'), '');
  });

  test('deactivated categories leave pickers but keep their label', () {
    CategoryCatalog.resetForTest([
      const CategoryModel(key: 'a', label: 'A', icon: '1', activo: true, orden: 0),
      const CategoryModel(key: 'b', label: 'B', icon: '2', activo: false, orden: 1),
    ]);
    expect(CategoryCatalog.activeKeys, ['a']);
    expect(CategoryCatalog.all.length, 2);
    expect(CategoryCatalog.label('b'), 'B');
  });

  test('model round-trips through Firestore', () {
    const c = CategoryModel(key: 'x', label: 'X', icon: '✨', activo: false, orden: 3);
    expect(CategoryModel.fromMap('x', c.toMap()), c);
  });
}
