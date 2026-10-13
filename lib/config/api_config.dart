class ApiConfig {
  const ApiConfig._();

  static const String deployed = 'https://poletag-api-dev.wybr.net';
  static const String emulator = 'http://10.0.2.2:8000';

  /// This PC on the wifi. `ipconfig` for the current one; uvicorn needs
  /// `--host 0.0.0.0` to answer anything but itself.
  static const String wifi = 'http://192.168.254.113:8000';

  /// Over the USB cable, for a phone the wifi cannot route to. Needs
  /// `adb reverse tcp:8000 tcp:8000`, re-run after every unplug.
  static const String phone = 'http://localhost:8000';

  static const String _selected = deployed;
  // Run: adb reverse tcp:8000 tcp:8000
  // ! /c/Users/Roan/AppData/Local/Android/Sdk/platform-tools/adb.exe reverse tcp:8000 tcp:8000
  static const String _raw = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _selected,
  );

  /// Stripped so `'$baseUrl/auth/login'` can never produce `//auth/login`,
  /// which the server answers with a 404.
  static final String baseUrl = _raw.replaceAll(RegExp(r'/+$'), '');
}
