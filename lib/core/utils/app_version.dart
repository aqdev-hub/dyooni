/// Embedded in Drive backup metadata (see drive_backup_repository_impl.dart) purely as
/// diagnostic info — never read back or relied on for any logic. Kept as a hand-maintained
/// constant instead of adding `package_info_plus` as a new dependency solely for one metadata
/// string: the worst case of this drifting out of sync with `pubspec.yaml`'s `version:` field is
/// a slightly stale value in old backup files' metadata, never a functional bug.
///
/// Keep this in sync with pubspec.yaml's `version:` field when bumping releases.
const String kAppVersion = '0.1.0+1';
