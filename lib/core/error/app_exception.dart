abstract class AppException implements Exception {
  const AppException({required this.message});

  final String message;

  @override
  String toString() => message;
}

class Failure extends AppException {
  const Failure({required super.message});
}

class DatabaseException extends Failure {
  const DatabaseException([String message = 'Database error occurred'])
      : super(message: message);
}

class ValidationException extends Failure {
  const ValidationException([String message = 'Validation failed'])
      : super(message: message);
}

class UnknownException extends Failure {
  const UnknownException([String message = 'Unexpected error occurred'])
      : super(message: message);
}
