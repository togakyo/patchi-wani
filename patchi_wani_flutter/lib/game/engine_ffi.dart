// lib/game/engine_ffi.dart
//
// Rust の patchi_wani_engine 共有ライブラリを dart:ffi で呼び出すブリッジ。
// すべての外部シンボルはここに集約し、他の Dart コードはこのクラスのみを参照する。

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// ─────────────────────────────────────────────
//  C ABI シグネチャの宣言
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
//  共有ライブラリのロード
// ─────────────────────────────────────────────
DynamicLibrary _openLib() {
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libpatchi_wani_engine.so');
  }
  if (Platform.isIOS) {
    // iOS は静的リンク（Runner.app に組み込み済み）
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
//  EngineFFI — シングルトン
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

  /// エンジン初期化。ruleJson が null なら Rust 側のデフォルト値を使用。
  /// 戻り値: 0=成功, -1=JSONパースエラー
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

  /// フェーズ: 0=Idle, 1=Playing, 2=GameOver
  GamePhase getPhase() => GamePhase.values[_getPhase()];

  double getTargetSize()  => _getSize();

  /// 難易度: 0=ふつう, 1=むずかしい, 2=すごい
  int    getDifficulty()  => _getDiff();

  /// 現在の GameRule JSON を返す
  String getRuleJson() {
    final ptr = _getRuleJson();
    final json = ptr.toDartString();
    _freeString(ptr);
    return json;
  }
}

/// Rust Phase と対応する Dart 列挙型
enum GamePhase { idle, playing, gameOver }
