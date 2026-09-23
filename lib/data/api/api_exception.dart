/// A failure returned by (or while reaching) the healthcare platform API.
///
/// [code] mirrors the backend's typed error envelope
/// (`{"error": {"code": ..., "message": ...}}`) so the UI can react to a
/// specific condition — a taken slot, a cancellation window, an expired
/// session — instead of pattern-matching on English strings. [message] is
/// the backend's own user-safe sentence; screens may substitute a friendlier
/// one for codes they know well.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.status,
    this.sessionExpired = false,
  });

  /// Backend error code (`NOT_FOUND`, `APPOINTMENT_SLOT_TAKEN`, …) or one of
  /// the client-side codes [network], [timeout] and [malformedResponse].
  final String code;

  final String message;

  /// HTTP status, when the request actually reached the server.
  final int? status;

  /// True when the stored session is no longer usable (refresh failed or was
  /// refused) — callers should send the user back to sign-in.
  final bool sessionExpired;

  /// Client-side: the request never reached the server.
  factory ApiException.network([String? detail]) => ApiException(
    code: 'NETWORK',
    message:
        detail ??
        'We could not reach the clinic network. Check your internet connection and try again.',
  );

  /// Client-side: the server did not answer in time.
  factory ApiException.timeout() => const ApiException(
    code: 'TIMEOUT',
    message: 'The server is taking too long to answer. Please try again.',
  );

  /// Client-side: the response body was not the JSON shape we expect.
  factory ApiException.malformedResponse(int? status) => ApiException(
    code: 'MALFORMED_RESPONSE',
    message: 'We received an unexpected response. Please try again.',
    status: status,
  );

  bool get isUnauthenticated =>
      code == 'NOT_AUTHENTICATED' || code == 'TOKEN_EXPIRED' || status == 401;

  bool get isNetworkIssue => code == 'NETWORK' || code == 'TIMEOUT';

  /// The slot was taken between showing it and confirming it.
  bool get isSlotTaken =>
      code == 'APPOINTMENT_SLOT_TAKEN' || code == 'CONFLICT';

  @override
  String toString() => 'ApiException($code${status == null ? '' : ' $status'}): $message';
}
