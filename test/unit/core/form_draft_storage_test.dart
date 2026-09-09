import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dyooni/core/utils/form_draft_storage.dart';

void main() {
  late SharedPreferences prefs;
  late FormDraftStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = FormDraftStorage(prefs, 'draft_test');
  });

  test('read() returns null when nothing was ever saved', () {
    expect(storage.read(), isNull);
  });

  test('save() then read() round-trips the same field values', () async {
    await storage.save({'name': 'أحمد محمد', 'amount': '500', 'attachmentPath': null});

    final result = storage.read();

    expect(result, isNotNull);
    expect(result!['name'], 'أحمد محمد');
    expect(result['amount'], '500');
    expect(result['attachmentPath'], isNull);
  });

  test('clear() removes the draft so a later read() returns null again', () async {
    await storage.save({'name': 'test'});
    await storage.clear();

    expect(storage.read(), isNull);
  });

  test('read() returns null (never throws) for corrupted/non-JSON stored content', () async {
    await prefs.setString('draft_test', 'not valid json at all {{{');

    expect(() => storage.read(), returnsNormally);
    expect(storage.read(), isNull);
  });

  test('two different keys never see each other\'s drafts', () async {
    final other = FormDraftStorage(prefs, 'draft_other');
    await storage.save({'field': 'A'});
    await other.save({'field': 'B'});

    expect(storage.read()!['field'], 'A');
    expect(other.read()!['field'], 'B');
  });
}
