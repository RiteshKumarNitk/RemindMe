/// The healthcare-platform session credentials.
///
/// Access tokens are short-lived; refresh tokens rotate on every use (the
/// backend invalidates the old one), so the pair is always replaced as a
/// unit.
class PlatformTokens {
  const PlatformTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;

  Map<String, String> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
  };

  static PlatformTokens? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final access = raw['accessToken'];
    final refresh = raw['refreshToken'];
    if (access is! String || refresh is! String) return null;
    if (access.isEmpty || refresh.isEmpty) return null;
    return PlatformTokens(accessToken: access, refreshToken: refresh);
  }
}

/// Where the session is kept between launches.
///
/// Abstract so tests (and any future migration to a different vault) can
/// substitute an in-memory implementation.
abstract class TokenStore {
  Future<PlatformTokens?> read();

  Future<void> write(PlatformTokens tokens);

  Future<void> clear();
}

/// In-memory store — used by tests and as a last-resort fallback when the
/// platform keystore is unavailable.
class InMemoryTokenStore implements TokenStore {
  PlatformTokens? _tokens;

  @override
  Future<PlatformTokens?> read() async => _tokens;

  @override
  Future<void> write(PlatformTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
