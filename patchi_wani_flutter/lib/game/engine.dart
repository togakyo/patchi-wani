// lib/game/engine.dart
//
// Platform-aware re-export.
// Native (iOS/Android/macOS/…) → engine_ffi.dart (Rust via dart:ffi)
// Web                          → engine_stub.dart (pure Dart simulation)
export 'engine_ffi.dart' if (dart.library.html) 'engine_stub.dart';
