/// Utility for mapping raw exceptions into user-friendly error messages.
class ErrorMessages {
  ErrorMessages._();

  /// Checks whether an exception is a network/connectivity error.
  static bool isNetworkError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('err_name_not_resolved') ||
        msg.contains('network_error') ||
        msg.contains('xmlhttprequest') ||
        msg.contains('failed to fetch') ||
        msg.contains('networkerror') ||
        msg.contains('connection refused') ||
        msg.contains('connection closed') ||
        msg.contains('connection reset') ||
        msg.contains('handshake') ||
        msg.contains('timed out') ||
        msg.contains('timeout') ||
        msg.contains('no internet') ||
        msg.contains('host lookup') ||
        msg.contains('errno = 7') || // POSIX network unreachable
        msg.contains('errno = 101') || // Linux ENETUNREACH
        msg.contains('errno = 111') || // Linux ECONNREFUSED
        msg.contains('clientexception');
  }

  /// Returns a user-friendly message for any exception.
  /// Use as a fallback in generic catch blocks.
  static String friendly(Object error) {
    if (isNetworkError(error)) {
      return 'No internet connection. Please check your network and try again.';
    }

    final msg = error.toString().toLowerCase();

    if (msg.contains('permission')) {
      return 'Permission denied. Please check your app permissions.';
    }
    if (msg.contains('server') || msg.contains('500')) {
      return 'Server error. Please try again later.';
    }

    return 'Something went wrong. Please try again.';
  }
}
