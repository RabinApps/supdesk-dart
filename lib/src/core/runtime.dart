/// Whether this program was compiled by Flutter.
///
/// `dart:ui` only exists in a Flutter embedder, so this is `true` for every
/// Flutter target — mobile, desktop and web — and `false` on the Dart VM and in
/// plain `dart compile` output.
const bool isFlutterRuntime = bool.fromEnvironment('dart.library.ui');

/// Whether this program was compiled for the web.
///
/// `dart:js_interop` only exists on the JS and Wasm web targets, so this catches
/// a browser build even when Flutter is not involved.
const bool isWebRuntime = bool.fromEnvironment('dart.library.js_interop');

/// Whether the code is running somewhere an end user could read the API key.
///
/// Both inputs are compile-time constants, so this costs nothing at runtime.
bool defaultIsClientSideRuntime() => isFlutterRuntime || isWebRuntime;
