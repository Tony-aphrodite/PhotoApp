import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';

import '../models/stored_image.dart';

/// Image storage for the whole app.
///
/// Images live in Cloud Storage; Firestore keeps only the references in
/// [StoredImage]. The previous implementation base64-encoded every photo into
/// the Firestore document itself, which had three problems:
///
///  * **It broke.** Firestore caps a document at 1 MiB. A phone photo is
///    400–600 KB and base64 inflates it by a third, so two photos on one
///    service exceeded the limit and the write was rejected outright.
///  * **It was billed as database traffic.** Firestore storage costs about 7×
///    Cloud Storage, and an inline image is re-downloaded on every query that
///    touches the document — a list of ten services pulled every photo of all
///    ten, every time.
///  * **It could not be cached.** Storage objects are served with an immutable
///    cache header and a CDN in front; the second view of a photo costs nothing.
///
/// Every upload produces two objects: a full-size image sized for evidence and
/// a thumbnail for lists. Paths embed the uploader's uid so Storage rules can
/// authorise writes without a cross-service lookup into Firestore.
class StorageRepository {
  /// Long edge target for the full-size image. Large enough that a leaking
  /// pipe or a finished repair is legible as evidence; small enough that a
  /// técnico on mobile data can open it.
  static const int _fullSizePx = 1600;

  /// JPEG quality for the full-size image. Deliberately not lower — these are
  /// evidence photos, not avatars.
  static const int _fullQuality = 85;

  static const int _thumbSizePx = 400;
  static const int _thumbQuality = 75;

  /// Filenames are UUIDs and objects are never rewritten, so they can be
  /// cached for a year. This is what makes repeat views free.
  static const String _cacheControl = 'public, max-age=31536000, immutable';

  final FirebaseFirestore? _injectedFirestore;
  final FirebaseStorage? _injectedStorage;
  final _uuid = const Uuid();

  StorageRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _injectedFirestore = firestore,
        _injectedStorage = storage;

  // Resolved lazily: the Firebase singletons throw when no app is initialised,
  // which would make this class impossible to construct in a unit test.
  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;
  FirebaseStorage get _storage => _injectedStorage ?? FirebaseStorage.instance;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'anonimo';

  // ---------------------------------------------------------------- helpers

  Future<Uint8List> _resize(File file, int minPx, int quality) async {
    final bytes = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: minPx,
      minHeight: minPx,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    // Compression can return null for an unsupported or corrupt input. Falling
    // back to the original bytes keeps the upload working — it just costs more.
    return bytes ?? await file.readAsBytes();
  }

  Future<String> _putJpeg(String path, Uint8List bytes) async {
    final ref = _storage.ref(path);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: _cacheControl,
      ),
    );
    return ref.getDownloadURL();
  }

  /// Uploads [file] to [folder] at both sizes and returns the references.
  Future<StoredImage> _uploadPair(String folder, File file) async {
    final id = _uuid.v4();
    final fullPath = '$folder/$id.jpg';
    final thumbPath = '$folder/${id}_thumb.jpg';

    // Resize both before uploading either: if compression fails we want to
    // find out before half the pair is in the bucket.
    final full = await _resize(file, _fullSizePx, _fullQuality);
    final thumb = await _resize(file, _thumbSizePx, _thumbQuality);

    final urls = await Future.wait([
      _putJpeg(fullPath, full),
      _putJpeg(thumbPath, thumb),
    ]);

    return StoredImage(
      url: urls[0],
      thumbUrl: urls[1],
      path: fullPath,
      thumbPath: thumbPath,
    );
  }

  // ------------------------------------------------------------- public API

  /// Uploads the photos attached to a service request.
  ///
  /// [onProgress] reports completed-of-total so the UI can show real progress
  /// across five uploads rather than an indeterminate spinner.
  Future<List<StoredImage>> uploadServicePhotos(
    String servicioId,
    List<File> files, {
    void Function(int done, int total)? onProgress,
  }) async {
    final folder = 'servicios/$servicioId/$_uid';
    final result = <StoredImage>[];

    // Sequential on purpose. Five concurrent two-part uploads saturate a phone
    // uplink and make progress reporting meaningless.
    for (var i = 0; i < files.length; i++) {
      result.add(await _uploadPair(folder, files[i]));
      onProgress?.call(i + 1, files.length);
    }
    return result;
  }

  /// Single service photo, for callers that add one at a time.
  Future<StoredImage> uploadServicePhoto(String servicioId, File file) =>
      _uploadPair('servicios/$servicioId/$_uid', file);

  /// Image sent inside a service chat.
  Future<StoredImage> uploadChatImage(String servicioId, File file) =>
      _uploadPair('chat/$servicioId/$_uid', file);

  /// Profile photo. Also writes the URL onto the user document, which is what
  /// the rest of the app reads.
  Future<String> uploadProfilePhoto(String userId, File file) async {
    final image = await _uploadPair('usuarios/$userId/perfil', file);
    await _firestore
        .collection('users')
        .doc(userId)
        .update({'fotoPerfil': image.thumbUrl});
    return image.thumbUrl;
  }

  /// A técnico's identity or certification document.
  ///
  /// Returns the full-size URL — an admin reviewing an INE needs to be able to
  /// read the small print, so the thumbnail is not the right reference here.
  Future<StoredImage> uploadUserDocument(
    String userId,
    String documentKey,
    File file,
  ) =>
      _uploadPair('usuarios/$userId/documentos/$documentKey', file);

  /// Removes both objects of a stored image. Missing objects are ignored so a
  /// partially-uploaded pair can still be cleaned up.
  Future<void> deleteImage(StoredImage image) async {
    for (final path in [image.path, image.thumbPath]) {
      if (path.isEmpty) continue;
      try {
        await _storage.ref(path).delete();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') rethrow;
      }
    }
  }

  /// Deletes by download URL, for records that predate [StoredImage].
  /// Base64 data URLs are inline in Firestore and have nothing to delete.
  Future<void> deleteFile(String url) async {
    if (url.isEmpty || url.startsWith('data:')) return;
    try {
      await _storage.refFromURL(url).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}
