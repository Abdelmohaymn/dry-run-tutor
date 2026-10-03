/// Build flavor and the relay base URL that goes with it.
///
/// No provider base URL appears here or anywhere in `lib/` — the app speaks
/// to exactly one host, the relay, and never to a model provider directly.
/// That guarantee does not live in this file: `dio_client.dart` derives
/// `HostAllowlistInterceptor`'s allowed host from whatever [Flavor.baseUrl]
/// resolves to, so exactly one host is dialable no matter which value wins
/// below (FR-004).
///
/// Both URLs are declared in `config/dev.json` and `config/prod.json` and
/// arrive as `--dart-define-from-file`. Switching environments is one flag:
///
/// ```
/// flutter run --flavor dev --dart-define-from-file=config/dev.json
/// flutter build appbundle --flavor prod --dart-define-from-file=config/prod.json
/// ```
///
/// This is the backend axis. It is independent of the Android flavor
/// (`appFlavor`, `--flavor`), which only picks which app gets installed.
///
/// The constants on each enum value are the fallback for a build that passes
/// no config file at all (a bare `flutter test`, or `flutter run` with no
/// flags), so the app still has a host rather than an empty string.
enum Flavor {
  dev(fallbackBaseUrl: 'https://dry-run-tutor-dev.example.workers.dev'),
  prod(fallbackBaseUrl: 'https://dry-run-tutor.example.workers.dev');

  const Flavor({required this.fallbackBaseUrl});

  /// The compiled-in default, used when `RELAY_BASE_URL` is absent.
  final String fallbackBaseUrl;

  /// The relay origin this build talks to: `RELAY_BASE_URL` from the config
  /// file when present and well-formed, otherwise [fallbackBaseUrl].
  String get baseUrl => _resolvedBaseUrl(this);

  static Flavor fromDefine(String value) {
    return switch (value) {
      'prod' => Flavor.prod,
      'dev' => Flavor.dev,
      _ => Flavor.dev,
    };
  }
}

const String _flavorDefine = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

const String _relayBaseUrlDefine = String.fromEnvironment('RELAY_BASE_URL');

/// The flavor resolved once at compile time from `--dart-define=FLAVOR=...`.
final Flavor currentFlavor = Flavor.fromDefine(_flavorDefine);

/// A configured relay URL is accepted only as a bare `https` origin.
///
/// Not an arbitrary-string pass-through: `http` would put the whole wire
/// contract in the clear, and a path or a query would silently prefix every
/// endpoint the client builds. Anything else falls back rather than throwing
/// — a typo in a build config should not turn into a crash on launch with no
/// way to read the reason on a device.
bool isValidRelayBaseUrl(String value) {
  final Uri? uri = Uri.tryParse(value);
  if (uri == null) {
    return false;
  }
  return uri.isScheme('https') &&
      uri.host.isNotEmpty &&
      uri.hasEmptyPath &&
      !uri.hasQuery &&
      !uri.hasFragment;
}

String _resolvedBaseUrl(Flavor flavor) {
  if (_relayBaseUrlDefine.isEmpty || !isValidRelayBaseUrl(_relayBaseUrlDefine)) {
    return flavor.fallbackBaseUrl;
  }
  return _relayBaseUrlDefine;
}
