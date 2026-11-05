import 'package:dyooni/logic/updates/app_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses installed version', () {
    final v = InstalledVersion.parse('0.1.0+7');
    expect(v.name, '0.1.0');
    expect(v.build, 7);
    expect(InstalledVersion.parse('1.0.0').build, 0);
  });

  RemoteRelease rel(int build, {int min = 0}) => RemoteRelease.tryParse({
        'version': '1.0.0',
        'build': build,
        'minSupportedBuild': min,
        'notes_ar': ['أ', ' '],
        'notes_en': ['a'],
        'url': 'https://x.y',
      })!;

  test('no update when same or older', () {
    const inst = InstalledVersion('0.1.0', 5);
    expect(decideUpdate(inst, rel(5)).kind, UpdateKind.none);
    expect(decideUpdate(inst, rel(4)).kind, UpdateKind.none);
    expect(decideUpdate(inst, null).kind, UpdateKind.none);
  });

  test('optional vs required', () {
    const inst = InstalledVersion('0.1.0', 5);
    expect(decideUpdate(inst, rel(6)).kind, UpdateKind.optional);
    expect(decideUpdate(inst, rel(9, min: 6)).kind, UpdateKind.required);
    expect(decideUpdate(inst, rel(9, min: 5)).kind, UpdateKind.optional);
  });

  test('parsing is defensive', () {
    expect(RemoteRelease.tryParse('x'), isNull);
    expect(RemoteRelease.tryParse({'version': '1'}), isNull);
    final r = rel(2);
    expect(r.notesAr, ['أ']);
    expect(r.notesFor('ar'), ['أ']);
    expect(r.notesFor('en'), ['a']);
  });
}
