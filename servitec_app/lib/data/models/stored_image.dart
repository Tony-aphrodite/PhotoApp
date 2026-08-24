import 'package:equatable/equatable.dart';

/// One image held in Cloud Storage, at two sizes.
///
/// Firestore stores only these references — never the image bytes. Lists render
/// [thumbUrl] (~30 KB) and detail views render [url] (~250 KB), so browsing
/// "Mis Servicios" no longer pulls full-resolution photos for every card.
///
/// [path] and [thumbPath] are kept so the objects can actually be deleted when
/// a service is removed; a download URL alone is not enough to address them.
class StoredImage extends Equatable {
  /// Full-size download URL — evidence quality, used on detail screens.
  final String url;

  /// Thumbnail download URL — used by every list and card.
  final String thumbUrl;

  /// Storage object path of the full-size image.
  final String path;

  /// Storage object path of the thumbnail.
  final String thumbPath;

  const StoredImage({
    required this.url,
    required this.thumbUrl,
    required this.path,
    required this.thumbPath,
  });

  factory StoredImage.fromMap(Map<String, dynamic> map) => StoredImage(
        url: map['url'] as String? ?? '',
        thumbUrl: map['thumbUrl'] as String? ?? map['url'] as String? ?? '',
        path: map['path'] as String? ?? '',
        thumbPath: map['thumbPath'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'url': url,
        'thumbUrl': thumbUrl,
        'path': path,
        'thumbPath': thumbPath,
      };

  @override
  List<Object?> get props => [url, thumbUrl, path, thumbPath];
}
