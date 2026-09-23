import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config/platform_api_config.dart';
import 'api_exception.dart';
import 'token_store.dart';

/// How a request should be authenticated.
enum AuthMode {
  /// No credentials sent, no session required (public discovery).
  none,

  /// Credentials sent when a session exists, but anonymous access is fine.
  optional,

  /// A session is required; fails fast with [ApiException] when absent.
  required,
}

/// A JSON object as returned by the platform API.
typedef JsonMap = Map<String, dynamic>;

/// Thin, testable HTTP client for the healthcare platform.
///
/// Responsibilities, in one place so no widget ever builds a URL:
///  * bearer tokens + the `X-Client: app` header the API uses to decide
///    between cookie sessions (web) and token responses (mobile);
///  * transparent, single-flight refresh-then-retry on an expired access
///    token;
///  * turning every failure — transport, envelope, HTTP status — into an
///    [ApiException].
class ApiClient {
  ApiClient({
    required this.tokenStore,
    http.Client? httpClient,
    String Function()? baseUrl,
    Duration timeout = const Duration(seconds: 20),
  }) : _http = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? (() => PlatformApiConfig.baseUrl),
       _timeout = timeout;

  final TokenStore tokenStore;
  final http.Client _http;
  final String Function() _baseUrl;
  final Duration _timeout;

  /// De-duplicates concurrent refreshes: a burst of 401s triggers exactly
  /// one rotation. Refresh tokens are one-shot server-side, so a parallel
  /// second attempt would invalidate the session.
  Future<bool>? _refreshInFlight;

  /// `GET` a single object.
  Future<JsonMap> getObject(
    String path, {
    Map<String, String>? query,
    AuthMode auth = AuthMode.optional,
  }) async {
    final decoded = await _send('GET', path, query: query, auth: auth);
    if (decoded is JsonMap) return decoded;
    throw ApiException.malformedResponse(null);
  }

  /// `GET` a `{ data: [...] }` collection.
  Future<List<JsonMap>> getList(
    String path, {
    Map<String, String>? query,
    AuthMode auth = AuthMode.optional,
  }) async {
    final decoded = await _send('GET', path, query: query, auth: auth);
    if (decoded is JsonMap) {
      final data = decoded['data'];
      if (data is List) {
        return data.whereType<JsonMap>().toList(growable: false);
      }
    }
    throw ApiException.malformedResponse(null);
  }

  /// `POST` with an optional JSON body.
  Future<JsonMap> post(
    String path, {
    JsonMap? body,
    AuthMode auth = AuthMode.required,
  }) async {
    final decoded = await _send('POST', path, body: body, auth: auth);
    if (decoded is JsonMap) return decoded;
    throw ApiException.malformedResponse(null);
  }

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    required AuthMode auth,
    bool allowRefresh = true,
  }) async {
    final tokens = await tokenStore.read();
    if (auth == AuthMode.required && tokens == null) {
      throw const ApiException(
        code: 'NOT_AUTHENTICATED',
        message: 'Please sign in to continue.',
        status: 401,
      );
    }

    final uri = _uri(path, query);
    final headers = <String, String>{
      // Tells the platform this is a mobile client: token JSON instead of a
      // web session cookie.
      'X-Client': 'app',
      'Accept': 'application/json',
    };
    if (tokens != null && auth != AuthMode.none) {
      headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    if (body != null) headers['Content-Type'] = 'application/json';

    http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _http.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw ApiException.timeout();
    } on SocketException catch (e) {
      developer.log('Network unreachable', name: 'PlatformApi', error: e);
      throw ApiException.network(
        'We could not reach the clinic network (${uri.host}). '
        'Check your internet connection and try again.',
      );
    } on http.ClientException catch (e) {
      developer.log('HTTP client error', name: 'PlatformApi', error: e);
      throw ApiException.network();
    }

    final decoded = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (response.statusCode == 401 && allowRefresh && tokens != null) {
      final refreshed = await _refresh();
      if (refreshed) {
        return _send(
          method,
          path,
          query: query,
          body: body,
          auth: auth,
          allowRefresh: false,
        );
      }
      throw const ApiException(
        code: 'NOT_AUTHENTICATED',
        message: 'Your session has ended. Please sign in again.',
        status: 401,
        sessionExpired: true,
      );
    }

    throw _envelopeError(response, decoded);
  }

  Uri _uri(String path, Map<String, String>? query) {
    final base = _baseUrl();
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$base$normalized');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(
      queryParameters: {...uri.queryParameters, ...query},
    );
  }

  Object? _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        throw ApiException.malformedResponse(response.statusCode);
      }
      return null;
    }
  }

  ApiException _envelopeError(http.Response response, Object? decoded) {
    if (decoded is JsonMap) {
      final error = decoded['error'];
      if (error is JsonMap) {
        final code = error['code'];
        final message = error['message'];
        return ApiException(
          code: code is String && code.isNotEmpty ? code : 'HTTP_${response.statusCode}',
          message: message is String && message.isNotEmpty
              ? message
              : 'Something went wrong. Please try again.',
          status: response.statusCode,
        );
      }
    }
    return ApiException(
      code: 'HTTP_${response.statusCode}',
      message: response.statusCode >= 500
          ? 'The clinic network is having trouble. Please try again in a moment.'
          : 'Something went wrong. Please try again.',
      status: response.statusCode,
    );
  }

  /// Rotates the refresh token. Returns false (and forgets the session) when
  /// the refresh is refused, so the UI can route back to sign-in.
  Future<bool> _refresh() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final future = _doRefresh();
    _refreshInFlight = future;
    return future.whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _doRefresh() async {
    final tokens = await tokenStore.read();
    if (tokens == null) return false;

    final uri = _uri('/auth/refresh', null);
    try {
      final response = await _http
          .post(
            uri,
            headers: {
              'X-Client': 'app',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refreshToken': tokens.refreshToken}),
          )
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = _decode(response);
        final rotated = PlatformTokens.fromJson(decoded);
        if (rotated != null) {
          await tokenStore.write(rotated);
          return true;
        }
      }
    } catch (e) {
      developer.log('Token refresh failed', name: 'PlatformApi', error: e);
    }

    await tokenStore.clear();
    return false;
  }

  /// Best-effort server-side sign-out; the local session is cleared either
  /// way by the caller.
  Future<void> revokeSession() async {
    final tokens = await tokenStore.read();
    if (tokens == null) return;
    try {
      await _http
          .post(
            _uri('/auth/logout', null),
            headers: {
              'X-Client': 'app',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${tokens.accessToken}',
            },
            body: jsonEncode({'refreshToken': tokens.refreshToken}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      developer.log('Sign-out call failed', name: 'PlatformApi', error: e);
    }
  }

  void dispose() => _http.close();
}
