// Pure update logic (no network, no Flutter): parsing the installed version, reading the
// published release description, and deciding whether an update is on offer.

/// The installed app version: `0.1.0+1` → name `0.1.0`, build `1`.
class InstalledVersion {
  const InstalledVersion(this.name, this.build);
  final String name;
  final int build;

  factory InstalledVersion.parse(String raw) {
    final parts = raw.split('+');
    return InstalledVersion(parts.first.trim(), parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0);
  }

  @override
  String toString() => '$name+$build';
}

/// What the published `version.json` says about the newest release.
class RemoteRelease {
  const RemoteRelease({
    required this.version,
    required this.build,
    this.minSupportedBuild = 0,
    this.notesAr = const [],
    this.notesEn = const [],
    this.url,
  });

  final String version;
  final int build;

  /// Installed builds below this must update (the dialog can't be dismissed).
  final int minSupportedBuild;
  final List<String> notesAr;
  final List<String> notesEn;
  final String? url;

  /// Returns null when the JSON isn't a usable release description.
  static RemoteRelease? tryParse(Object? json) {
    if (json is! Map) return null;
    final build = json['build'];
    final version = json['version'];
    if (build is! num || version is! String) return null;
    List<String> notes(Object? v) => v is List ? [for (final e in v) if (e is String && e.trim().isNotEmpty) e.trim()] : const [];
    final min = json['minSupportedBuild'];
    final url = json['url'];
    return RemoteRelease(
      version: version,
      build: build.toInt(),
      minSupportedBuild: min is num ? min.toInt() : 0,
      notesAr: notes(json['notes_ar']),
      notesEn: notes(json['notes_en']),
      url: url is String && url.trim().startsWith('http') ? url.trim() : null,
    );
  }

  List<String> notesFor(String languageCode) {
    final primary = languageCode == 'ar' ? notesAr : notesEn;
    return primary.isNotEmpty ? primary : (languageCode == 'ar' ? notesEn : notesAr);
  }
}

enum UpdateKind { none, optional, required }

class UpdateDecision {
  const UpdateDecision(this.kind, this.release);
  final UpdateKind kind;
  final RemoteRelease? release;
  bool get available => kind != UpdateKind.none;
}

/// Compares BUILD numbers (a plain integer that only goes up) rather than the version text, so
/// there is no semver parsing to get wrong.
UpdateDecision decideUpdate(InstalledVersion installed, RemoteRelease? release) {
  if (release == null || release.build <= installed.build) return const UpdateDecision(UpdateKind.none, null);
  final forced = installed.build < release.minSupportedBuild;
  return UpdateDecision(forced ? UpdateKind.required : UpdateKind.optional, release);
}
