/// Custom domain exceptions for graceful error handling.
abstract class AppException implements Exception {
  final String message;
  final String? details;

  const AppException(this.message, [this.details]);

  @override
  String toString() => details == null ? message : '$message: $details';
}

class ValidationException extends AppException {
  const ValidationException(super.message, [super.details]);
}

class LocalDatabaseException extends AppException {
  const LocalDatabaseException(super.message, [super.details]);
}

class NetworkSyncException extends AppException {
  const NetworkSyncException(super.message, [super.details]);
}

class LocationException extends AppException {
  const LocationException(super.message, [super.details]);
}
