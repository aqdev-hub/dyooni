/// Localized messages belong in `core/l10n/` ARB files, mapped from `code` inside `view/`.
/// This keeps `core/`/`data/`/`logic/` reusable across languages — never a hardcoded string here.
sealed class AppException implements Exception {
  const AppException(this.code, {this.internalDetail});

  /// Maps to an l10n key, e.g. 'network_unreachable'.
  final String code;

  /// For logs only (redacted before logging) — NEVER shown to the user.
  final String? internalDetail;
}

class StorageException extends AppException {
  const StorageException({super.internalDetail}) : super('storage_unavailable');
}

class ValidationException extends AppException {
  const ValidationException(super.code, {super.internalDetail});
}

class UnexpectedException extends AppException {
  const UnexpectedException({super.internalDetail}) : super('unexpected_error');
}
