import 'package:logger/logger.dart';

/// The `logger` package was added early in this project but never actually wired up until now —
/// every `AppException.internalDetail` was being captured and then going nowhere, so real
/// platform errors (like a Google Sign-In `PlatformException`) were invisible even to a
/// developer running `flutter run`. Call `appLogger.e(...)` at every catch site that wraps an
/// exception into an `AppException`, so `internalDetail` has somewhere real to go.
final appLogger = Logger(printer: PrettyPrinter(methodCount: 0, colors: false));
