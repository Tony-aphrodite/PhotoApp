import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:servitec_app/data/repositories/storage_repository.dart';

void main() {
  group('StorageRepository.uploadChatImage', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('servitec_chat_img_test_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('returns a JPEG data URL containing the base64 of the file bytes',
        () async {
      // Arrange — write known bytes to a temp file.
      final bytes = List<int>.generate(64, (i) => i % 256);
      final file = File('${tmp.path}/sample.jpg')..writeAsBytesSync(bytes);

      // Act
      final repo = StorageRepository();
      final dataUrl = await repo.uploadChatImage(file);

      // Assert — well-formed data URL with the original bytes.
      expect(dataUrl.startsWith('data:image/jpeg;base64,'), isTrue,
          reason: 'should be a JPEG data URL');
      final b64 = dataUrl.split(',').last;
      final decoded = base64Decode(b64);
      expect(decoded, equals(bytes));
    });

    test('empty file produces a valid empty-payload data URL', () async {
      final file = File('${tmp.path}/empty.jpg')..writeAsBytesSync([]);
      final repo = StorageRepository();
      final dataUrl = await repo.uploadChatImage(file);

      expect(dataUrl, equals('data:image/jpeg;base64,'));
    });
  });
}
