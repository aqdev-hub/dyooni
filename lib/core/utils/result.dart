import 'app_exception.dart';

/// Sealed class instead of a nullable record — makes "both null / both non-null" unrepresentable.
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);
  final AppException error;
}

Future<Result<T>> safeCall<T>(Future<T> Function() call) async {
  try {
    return Success(await call());
  } on AppException catch (e) {
    return Failure(e);
  } catch (e) {
    return Failure(UnexpectedException(internalDetail: e.toString()));
  }
}
