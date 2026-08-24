import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servitec_app/data/models/service_model.dart';
import 'package:servitec_app/data/models/stored_image.dart';

/// Guards the Base64-to-Cloud-Storage migration.
///
/// The end-to-end upload of five photos needs a real device and a real bucket,
/// so it is a manual step. What is checked here is everything that can be
/// verified without one — and, importantly, that the old Base64 path cannot
/// quietly come back.
void main() {
  group('StoredImage', () {
    const image = StoredImage(
      url: 'https://firebasestorage.googleapis.com/full.jpg',
      thumbUrl: 'https://firebasestorage.googleapis.com/thumb.jpg',
      path: 'servicios/svc1/uid1/abc.jpg',
      thumbPath: 'servicios/svc1/uid1/abc_thumb.jpg',
    );

    test('round-trips through Firestore', () {
      expect(StoredImage.fromMap(image.toMap()), image);
    });

    test('falls back to the full URL when a record predates thumbnails', () {
      final legacy = StoredImage.fromMap({'url': 'https://x/full.jpg'});
      expect(legacy.thumbUrl, 'https://x/full.jpg');
    });

    test('keeps the storage paths so objects can actually be deleted', () {
      expect(image.path, isNotEmpty);
      expect(image.thumbPath, isNotEmpty);
    });
  });

  group('ServiceModel.fotoPreview — lists must not pull full-size images', () {
    ServiceModel build({
      List<String> fotos = const [],
      List<String> thumbs = const [],
    }) =>
        ServiceModel(
          id: 's1',
          clienteId: 'c1',
          clienteNombre: 'Ana',
          clienteTelefono: '',
          titulo: 'Fuga',
          descripcion: '',
          categoria: 'plomeria',
          urgencia: 'normal',
          ubicacion: const GeoPoint(0, 0),
          ubicacionTexto: '',
          fotos: fotos,
          fotosThumbs: thumbs,
          estado: 'pendiente',
          tipoAsignacion: 'automatica',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

    test('prefers the thumbnail', () {
      final s = build(fotos: ['https://x/full.jpg'], thumbs: ['https://x/t.jpg']);
      expect(s.fotoPreview, 'https://x/t.jpg');
    });

    test('falls back to the full photo on pre-migration services', () {
      final s = build(fotos: ['data:image/jpeg;base64,AAAA']);
      expect(s.fotoPreview, 'data:image/jpeg;base64,AAAA');
    });

    test('is null when there are no photos', () {
      expect(build().fotoPreview, isNull);
    });

    test('carries five photos and five thumbnails through Firestore', () {
      final s = build(
        fotos: List.generate(5, (i) => 'https://x/full$i.jpg'),
        thumbs: List.generate(5, (i) => 'https://x/thumb$i.jpg'),
      );
      final map = s.toFirestore();
      expect(map['fotos'], hasLength(5));
      expect(map['fotosThumbs'], hasLength(5));
      expect(s.fotoPreview, 'https://x/thumb0.jpg');
    });
  });

  group('no image bytes may be written back into Firestore', () {
    test('StorageRepository no longer base64-encodes anything', () {
      final src =
          File('lib/data/repositories/storage_repository.dart').readAsStringSync();
      expect(src.contains('base64Encode'), isFalse,
          reason: 'photos must go to Cloud Storage, not into a document');
      expect(src.contains("data:image"), isFalse);
      expect(src.contains('firebase_storage'), isTrue);
    });

    test('service photo uploads write URLs, never data URLs', () {
      final src = File('lib/features/client/screens/create_service_screen.dart')
          .readAsStringSync();
      expect(src.contains("'fotosThumbs':"), isTrue,
          reason: 'thumbnails must be persisted for the list views');
      expect(src.contains('base64'), isFalse);
    });

    test('service cards render the preview, not fotos.first', () {
      final src = File('lib/core/widgets/service_card.dart').readAsStringSync();
      expect(src.contains('service.fotoPreview'), isTrue);
      expect(src.contains('service.fotos.first'), isFalse,
          reason: 'a list must never load the full-resolution image');
    });
  });
}
