import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// Stores images as base64 in Firestore (workaround for Storage API issue)
class StorageRepository {
  /// Only set when a caller injected one. Resolved lazily via [_firestore]
  /// rather than in the constructor: `FirebaseFirestore.instance` throws when
  /// no Firebase app has been initialized, which would make it impossible to
  /// construct this class for the methods that never touch Firestore at all
  /// (uploadChatImage just base64-encodes).
  final FirebaseFirestore? _injectedFirestore;
  final _uuid = const Uuid();

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  StorageRepository({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  // Upload profile photo -> store base64 in user document
  Future<String> uploadProfilePhoto(String userId, File file) async {
    final bytes = await file.readAsBytes();
    final base64Str = base64Encode(bytes);
    final dataUrl = 'data:image/jpeg;base64,$base64Str';

    await _firestore.collection('users').doc(userId).update({
      'fotoPerfil': dataUrl,
    });

    return dataUrl;
  }

  // Upload service photos -> store in subcollection
  Future<List<String>> uploadServicePhotos(
    String serviceId,
    List<File> files,
  ) async {
    final urls = <String>[];
    final batch = _firestore.batch();
    final photosRef = _firestore
        .collection('servicios')
        .doc(serviceId)
        .collection('fotos');

    for (final file in files) {
      final bytes = await file.readAsBytes();
      final base64Str = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64Str';
      final docId = _uuid.v4();

      batch.set(photosRef.doc(docId), {
        'data': dataUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
      urls.add(dataUrl);
    }

    await batch.commit();

    // Also update the service document with the data URLs
    await _firestore.collection('servicios').doc(serviceId).update({
      'fotos': urls,
    });

    return urls;
  }

  // Upload single service photo
  Future<String> uploadServicePhoto(
    String serviceId,
    File file, {
    void Function(double)? onProgress,
  }) async {
    onProgress?.call(0.3);
    final bytes = await file.readAsBytes();
    final base64Str = base64Encode(bytes);
    final dataUrl = 'data:image/jpeg;base64,$base64Str';
    onProgress?.call(0.7);

    final docId = _uuid.v4();
    await _firestore
        .collection('servicios')
        .doc(serviceId)
        .collection('fotos')
        .doc(docId)
        .set({
      'data': dataUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    onProgress?.call(1.0);
    return dataUrl;
  }

  // Upload chat image -> returns base64 data URL stored inline in the message
  Future<String> uploadChatImage(File file) async {
    final bytes = await file.readAsBytes();
    final base64Str = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64Str';
  }

  // Delete file (no-op for base64 stored in Firestore)
  Future<void> deleteFile(String url) async {
    // Base64 data URLs are stored inline, deletion handled by document deletion
  }
}
