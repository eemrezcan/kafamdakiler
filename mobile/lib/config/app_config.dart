/// Build-time configuration.
///
/// Override the API address with `--dart-define=API_URL=https://...`.
/// The default works on a phone via `adb reverse tcp:5051 tcp:5051`.
class AppConfig {
  const AppConfig._();

  static const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:5051',
  );
}
