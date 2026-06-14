// lib/game/engine_ffi.dart
//
// dart:ffi bridge to the patchi_wani_engine Rust shared library.
// All external symbols are resolved here; other Dart code only imports EngineFFI.

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// ─────────────────────────────────────────────
//  C ABI type signatures
// ─────────────────────────────────────────────

// int engine_init(const char* rule_json)
typedef _EngineInitC    = Int32 Function(Pointer<Utf8>);
typedef _EngineInitDart = int   Function(Pointer<Utf8>);

// void engine_start()
typedef _VoidFunc = Void Function();

// int engine_tick()
// int engine_on_hit()
// int engine_get_score()
// int engine_get_time_left()
// int engine_get_phase()
// int engine_get_difficulty()
typedef _IntRetFunc     = Int32 Function();
typedef _IntRetFuncDart = int   Function();

// float engine_get_target_size()
typedef _FloatRetFunc     = Float Function();
typedef _FloatRetFuncDart = double Function();

// char* engine_get_rule_json()
typedef _CharPtrRetFunc     = Pointer<Utf8> Function();

// void engine_free_string(char*)
typedef _FreeStringC    = Void Function(Pointer<Utf8>);
typedef _FreeStringDart = void  Function(Pointer<Utf8>);

// ─────────────────────────────────────────────
//  Load the shared library
// ─────────────────────────────────────────────
DynamicLibrary _openLib() {
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libpatchi_wani_engine.so');
  }
  if (Platform.isIOS) {
    // iOS uses static linking (bundled inside Runner.app)
    return DynamicLibrary.process();
  }
  if (Platform.isMacOS) {
    return DynamicLibrary.open('libpatchi_wani_engine.dylib');
  }
  if (Platform.isLinux) {
    return DynamicLibrary.open('libpatchi_wani_engine.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('patchi_wani_engine.dll');
  }
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}

// ─────────────────────────────────────────────
//  EngineFFI — singleton wrapper
// ─────────────────────────────────────────────
class EngineFFI {
  EngineFFI._() {
    final lib = _openLib();

    _init        = lib.lookupFunction<_EngineInitC,        _EngineInitDart>('engine_init');
    _start       = lib.lookupFunction<_VoidFunc,           void Function()>('engine_start');
    _tick        = lib.lookupFunction<_IntRetFunc,         _IntRetFuncDart>('engine_tick');
    _onHit       = lib.lookupFunction<_IntRetFunc,         _IntRetFuncDart>('engine_on_hit');
    _getScore    = lib.lookupFunction<_IntRetFunc,         _IntRetFuncDart>('engine_get_score');
    _getTimeLeft = lib.lookupFunction<_IntRetFunc,         _IntRetFuncDart>('engine_get_time_left');
    _getPhase    = lib.lookupFunction<_IntRetFunc,         _IntRetFuncDart>('engine_get_phase');
    _getSize     = lib.lookupFunction<_FloatRetFunc,       _FloatRetFuncDart>('engine_get_target_size');
    _getDiff     = lib.lookupFunction<_IntRetFunc,         _IntRetFuncDart>('engine_get_difficulty');
    _getRuleJson = lib.lookupFunction<_CharPtrRetFunc,     _CharPtrRetFunc>('engine_get_rule_json');
    _freeString  = lib.lookupFunction<_FreeStringC,        _FreeStringDart>('engine_free_string');
  }

  static final EngineFFI instance = EngineFFI._();

  late final _EngineInitDart   _init;
  late final void Function()   _start;
  late final _IntRetFuncDart   _tick;
  late final _IntRetFuncDart   _onHit;
  late final _IntRetFuncDart   _getScore;
  late final _IntRetFuncDart   _getTimeLeft;
  late final _IntRetFuncDart   _getPhase;
  late final _FloatRetFuncDart _getSize;
  late final _IntRetFuncDart   _getDiff;
  late final _CharPtrRetFunc   _getRuleJson;
  late final _FreeStringDart   _freeString;

  /// Initialise the engine. Pass null to use Rust defaults.
  /// Returns 0 on success, -1 on JSON parse error.
  int init({String? ruleJson}) {
    if (ruleJson == null) {
      return _init(nullptr.cast<Utf8>());
    }
    final ptr = ruleJson.toNativeUtf8();
    final result = _init(ptr);
    malloc.free(ptr);
    return result;
  }

  void start()       => _start();
  int  tick()        => _tick();
  int  onHit()       => _onHit();
  int  getScore()    => _getScore();
  int  getTimeLeft() => _getTimeLeft();

  /// Phase: 0=Idle, 1=Playing, 2=GameOver
  GamePhase getPhase() => GamePhase.values[_getPhase()];

  double getTargetSize()  => _getSize();

  /// Difficulty: 0=easy, 1=normal, 2=hard
  int    getDifficulty()  => _getDiff();

  /// Returns the current GameRule as a JSON string.
  String getRuleJson() {
    final ptr = _getRuleJson();
    final json = ptr.toDartString();
    _freeString(ptr);
    return json;
  }
}

/// Dart enum mirroring the Rust Phase enum.
enum GamePhase { idle, playing, gameOver }
