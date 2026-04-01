sealed class AppError {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppError({required this.message, this.code, this.originalError});
}

class NetworkError extends AppError {
  const NetworkError({String? message, super.code, super.originalError})
    : super(message: message ?? 'No internet connection');
}

class AuthError extends AppError {
  const AuthError({String? message, super.code, super.originalError})
    : super(message: message ?? 'Authentication failed');
}

class ServerError extends AppError {
  final int? statusCode;
  const ServerError({
    String? message,
    this.statusCode,
    super.code,
    super.originalError,
  }) : super(message: message ?? 'Server error occurred');
}

class ValidationError extends AppError {
  const ValidationError({String? message, super.code, super.originalError})
    : super(message: message ?? 'Validation failed');
}

class NotFoundError extends AppError {
  const NotFoundError({String? message, super.code, super.originalError})
    : super(message: message ?? 'Resource not found');
}

class PermissionError extends AppError {
  const PermissionError({String? message, super.code, super.originalError})
    : super(message: message ?? 'Permission denied');
}

class UnknownError extends AppError {
  const UnknownError({String? message, super.originalError})
    : super(message: message ?? 'An unexpected error occurred');
}

AppError handleError(dynamic error) {
  final errorStr = error.toString().toLowerCase();

  if (errorStr.contains('socket') ||
      errorStr.contains('network') ||
      errorStr.contains('connection') ||
      errorStr.contains('timeout')) {
    return const NetworkError();
  }

  if (errorStr.contains('auth') ||
      errorStr.contains('login') ||
      errorStr.contains('session') ||
      errorStr.contains('jwt')) {
    return const AuthError();
  }

  if (errorStr.contains('permission') ||
      errorStr.contains('forbidden') ||
      errorStr.contains('denied')) {
    return const PermissionError();
  }

  if (errorStr.contains('not found') || errorStr.contains('404')) {
    return const NotFoundError();
  }

  if (errorStr.contains('validat')) {
    return const ValidationError();
  }

  if (errorStr.contains('500') ||
      errorStr.contains('502') ||
      errorStr.contains('503')) {
    return const ServerError();
  }

  return UnknownError(originalError: error);
}
