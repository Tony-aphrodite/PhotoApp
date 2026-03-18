import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageRepository {
  final FirebaseStorage _storage;
  final _uuid = const Uuid();

  StorageRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  // Upload profile photo
  Future<String> uploadProfilePhoto(String userId, File file) async {
    final ext = file.path.split('.').last;
    final ref = _storage.ref('usuarios/$userId/perfil/profile.$ext');
    await ref.putFile(file, SettableMetadata(contentType: 'image/$ext'));
    return await ref.getDownloadURL();
  }

  // Upload service photos
  Future<List<String>> uploadServicePhotos(
    String serviceId,
    List<File> files,
  ) async {
    final urls = <String>[];
    for (final file in files) {
      final ext = file.path.split('.').last;
      final fileName = '${_uuid.v4()}.$ext';
      final ref = _storage.ref('servicios/$serviceId/$fileName');
      await ref.putFile(file, SettableMetadata(contentType: 'image/$ext'));
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  // Upload single service photo with progress
  Future<String> uploadServicePhoto(
    String serviceId,
    File file, {
    void Function(double)? onProgress,
  }) async {
    final ext = file.path.split('.').last;
    final fileName = '${_uuid.v4()}.$ext';
    final ref = _storage.ref('servicios/$serviceId/$fileName');

    final uploadTask = ref.putFile(
      file,
      SettableMetadata(contentType: 'image/$ext'),
    );

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        onProgress(progress);
      });
    }

    await uploadTask;
    return await ref.getDownloadURL();
  }

  // Delete file
  Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (_) {
      // File may already be deleted
    }
  }
}
