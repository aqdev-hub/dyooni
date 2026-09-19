import 'package:flutter_test/flutter_test.dart';

import 'package:dyooni/core/utils/attachment_storage.dart';

void main() {
  group('AttachmentStorage.buildDestinationPath', () {
    test('places the file under an attachments/ subfolder of the given documents path', () {
      final path = AttachmentStorage.buildDestinationPath('/docs', '/cache/pick123.jpg', idOverride: 'fixed-id');

      expect(path, '/docs/attachments/fixed-id.jpg');
    });

    test("preserves the source file's extension", () {
      final path = AttachmentStorage.buildDestinationPath('/docs', '/cache/pick123.png', idOverride: 'fixed-id');

      expect(path, endsWith('.png'));
    });

    test('falls back to .jpg when the source path has no extension at all', () {
      final path = AttachmentStorage.buildDestinationPath('/docs', '/cache/pick123', idOverride: 'fixed-id');

      expect(path, endsWith('.jpg'));
    });

    test('two calls with no id override never collide (each gets a fresh UUID)', () {
      final first = AttachmentStorage.buildDestinationPath('/docs', '/cache/a.jpg');
      final second = AttachmentStorage.buildDestinationPath('/docs', '/cache/a.jpg');

      expect(first, isNot(equals(second)));
    });
  });
}
