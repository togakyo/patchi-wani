// lib/game/game_controller.dart
//
// Controller that mediates between the Flutter UI and the Rust engine.
// Uses ChangeNotifier to propagate state changes to widgets.

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'engine.dart';

class TargetPosition {
  final double x;
  final double y;
  const TargetPosition(this.x, this.y);
}

class GameController extends ChangeNotifier {
  final _ffi = EngineFFI.instance;
  final _rng = Random();

  // ── Public state ──────────────────────────────────
  GamePhase   get phase      => _phase;
  int         get score      => _score;
  int         get timeLeft   => _timeLeft;
  double      get targetSize => _targetSize;
  int         get difficulty => _difficulty;
  bool        get targetVisible => _targetVisible;
  TargetPosition? get targetPos => _targetPos;

  // ── Internal state ───────────────────────────────
  GamePhase      _phase         = GamePhase.idle;
  int            _score         = 0;
  int            _timeLeft      = 60;
  double         _targetSize    = 96.0;
  int            _difficulty    = 0;
  bool           _targetVisible = false;
  TargetPosition? _targetPos;

  Timer? _timerTick;
  Timer? _timerHide;
  Timer? _timerSpawn;

  // ── Start game ───────────────────────────────────
  void startGame({String? ruleJson}) {
    _timerTick?.cancel();
    _timerHide?.cancel();
    _timerSpawn?.cancel();

    _ffi.init(ruleJson: ruleJson);
    _ffi.start();

    _syncFromEngine();

    // Tick the engine once per second
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      _ffi.tick();
      _syncFromEngine();
      if (_phase == GamePhase.gameOver) {
        _timerTick?.cancel();
        _timerHide?.cancel();
        _timerSpawn?.cancel();
        _targetVisible = false;
        notifyListeners();
      }
    });

    // 最初のターゲットを出す
    _scheduleNextTarget(delay: const Duration(milliseconds: 300));
  }

  // ── Target tap ───────────────────────────────────
  void onHit(Size arenaSize) {
    if (_phase != GamePhase.playing) return;
    _ffi.onHit();
    _syncFromEngine();
    _timerHide?.cancel();
    _targetVisible = false;
    _scheduleNextTarget(delay: const Duration(milliseconds: 80));
    notifyListeners();
  }

  // ── Target spawn management ──────────────────────
  Size? _arenaSize;

  void setArenaSize(Size size) => _arenaSize = size;

  void _scheduleNextTarget({required Duration delay}) {
    _timerHide?.cancel();
    _timerSpawn?.cancel();

    _timerSpawn = Timer(delay, () {
      if (_phase != GamePhase.playing) return;
      _targetVisible = false;
      notifyListeners();

      // Random delay 400–800 ms before the next target appears
      final waitMs = 400 + _rng.nextInt(400);
      _timerSpawn = Timer(Duration(milliseconds: waitMs), () {
        if (_phase != GamePhase.playing) return;
        _placeTarget();
      });
    });
  }

  void _placeTarget() {
    final size = _arenaSize;
    if (size == null) return;

    final ts = _ffi.getTargetSize();
    final margin = ts / 2 + 12;
    final rx = margin + _rng.nextDouble() * (size.width  - margin * 2);
    final ry = margin + _rng.nextDouble() * (size.height - margin * 2);

    _targetPos     = TargetPosition(rx, ry);
    _targetSize    = ts;
    _targetVisible = true;
    notifyListeners();

    // Auto-hide after 1500 ms
    _timerHide = Timer(const Duration(milliseconds: 1500), () {
      if (_phase != GamePhase.playing) return;
      _targetVisible = false;
      notifyListeners();
      _scheduleNextTarget(delay: const Duration(milliseconds: 100));
    });
  }

  // ── Sync state from engine ───────────────────────
  void _syncFromEngine() {
    _phase      = _ffi.getPhase();
    _score      = _ffi.getScore();
    _timeLeft   = _ffi.getTimeLeft();
    _targetSize = _ffi.getTargetSize();
    _difficulty = _ffi.getDifficulty();
    notifyListeners();
  }

  // ── Difficulty label ─────────────────────────────
  String get difficultyLabel {
    switch (_difficulty) {
      case 0: return 'かんたん';   // easy
      case 1: return 'むずかしい'; // normal
      default: return 'すごい！';  // hard
    }
  }

  // ── Result message ───────────────────────────────
  ({String emoji, String title, String msg}) get resultInfo {
    if (_score >= 25) return (emoji: '🏆', title: 'すごい！チャンピオン！', msg: 'めちゃくちゃ上手だよ！！');
    if (_score >= 15) return (emoji: '🌟', title: 'よくできました！',       msg: 'どんどん上手になってるよ！');
    if (_score >= 8)  return (emoji: '🎉', title: 'がんばったね！',         msg: 'えらかったよ！また挑戦してね！');
    return               (emoji: '💪', title: 'よくやったね！',            msg: '次はもっとできるよ！');
  }

  @override
  void dispose() {
    _timerTick?.cancel();
    _timerHide?.cancel();
    _timerSpawn?.cancel();
    super.dispose();
  }
}
