import 'dart:convert';
import 'api_client.dart';

String mapApiError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is ApiException) {
    switch (error.statusCode) {
      case 400:
        return _messageFromBody(error.body) ?? 'Invalid request. Please check your input.';
      case 401:
        return 'Session expired. Please sign in again.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'Requested resource was not found.';
      case 409:
        return _messageFromBody(error.body) ?? 'Conflict detected. Please refresh and try again.';
      case 429:
        return 'Too many requests. Please wait a moment and try again.';
      default:
        if (error.statusCode >= 500) {
          return 'Server is temporarily unavailable. Please try again later.';
        }
        return _messageFromBody(error.body) ?? fallback;
    }
  }

  if (error is FormatException) {
    return 'Unexpected response format from server.';
  }

  return fallback;
}

String? _messageFromBody(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final err = decoded['error'];
      if (err is Map<String, dynamic>) {
        final message = err['message'];
        if (message is String && message.trim().isNotEmpty) return message;
      }
    }
  } catch (_) {}
  return null;
}
