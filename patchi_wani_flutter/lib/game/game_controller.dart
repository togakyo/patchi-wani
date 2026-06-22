// lib/game/game_controller.dart
//
// Controller that mediates between the Flutter UI and the Rust engine.
// Uses ChangeNotifier to propagate state changes to widgets.

import 'dart:async';
import 'dart:math';
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
  GamePhase   get phase          => _phase;
  int         get score          => _score;
  int         get timeLeft       => _timeLeft;
  double      get targetSize     => _targetSize;
  int         get difficulty     => _difficulty;
  bool        get targetVisible  => _targetVisible;
  TargetPosition? get targetPos  => _targetPos;
  bool        get trackingMode     => _trackingMode;
  bool        get figureGroundMode => _figureGroundMode;
  List<TargetPosition> get distractors => List.unmodifiable(_distractors);

  // ── Internal state ───────────────────────────────
  GamePhase      _phase         = GamePhase.idle;
  int            _score         = 0;
  int            _timeLeft      = 60;
  double         _targetSize    = 96.0;
  int            _difficulty    = 0;
  bool           _targetVisible = false;
  TargetPosition? _targetPos;

  bool _trackingMode     = false;
  bool _figureGroundMode = false;
  List<TargetPosition> _distractors = [];
  TargetPosition? _moveDestination;

  Timer? _timerTick;
  Timer? _timerHide;
  Timer? _timerSpawn;
  Timer? _timerMove;

  // ── Start game ───────────────────────────────────
  void startGame({
    String? ruleJson,
    bool trackingMode = false,
    bool figureGroundMode = false,
  }) {
    _timerTick?.cancel();
    _timerHide?.cancel();
    _timerSpawn?.cancel();
    _timerMove?.cancel();

    _trackingMode     = trackingMode;
    _figureGroundMode = figureGroundMode;
    _distractors      = [];
    _moveDestination  = null;

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
        _timerMove?.cancel();
        _targetVisible = false;
        _distractors   = [];
        notifyListeners();
      }
    });

    // Tracking mode: move the target smoothly at ~20 fps
    if (_trackingMode) {
      _timerMove = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (_targetVisible && _targetPos != null && _arenaSize != null) {
          _moveTarget();
        }
      });
    }

    _scheduleNextTarget(delay: const Duration(milliseconds: 300));
  }

  // ── Target tap ───────────────────────────────────
  void onHit(Size arenaSize) {
    if (_phase != GamePhase.playing) return;
    _ffi.onHit();
    _syncFromEngine();
    _timerHide?.cancel();
    _targetVisible   = false;
    _distractors     = [];
    _moveDestination = null;
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

    _targetPos       = TargetPosition(rx, ry);
    _targetSize      = ts;
    _moveDestination = null;
    _targetVisible   = true;

    if (_figureGroundMode) _refreshDistractors(size, margin);

    notifyListeners();

    // Tracking mode: give a bit more time since the target moves around
    final hideDuration = _trackingMode
        ? const Duration(milliseconds: 2500)
        : const Duration(milliseconds: 1500);

    _timerHide = Timer(hideDuration, () {
      if (_phase != GamePhase.playing) return;
      _targetVisible = false;
      _distractors   = [];
      notifyListeners();
      _scheduleNextTarget(delay: const Duration(milliseconds: 100));
    });
  }

  // ── Figure-ground: generate distractor positions ─
  void _refreshDistractors(Size size, double margin) {
    _distractors = List.generate(8, (_) => TargetPosition(
      margin + _rng.nextDouble() * (size.width  - margin * 2),
      margin + _rng.nextDouble() * (size.height - margin * 2),
    ));
  }

  // ── Tracking mode: move target toward destination ─
  void _moveTarget() {
    final size = _arenaSize!;
    final margin = _targetSize / 2 + 12;

    _moveDestination ??= TargetPosition(
      margin + _rng.nextDouble() * (size.width  - margin * 2),
      margin + _rng.nextDouble() * (size.height - margin * 2),
    );

    final dest = _moveDestination!;
    final dx = dest.x - _targetPos!.x;
    final dy = dest.y - _targetPos!.y;
    final dist = sqrt(dx * dx + dy * dy);

    if (dist < 8) {
      _moveDestination = null;
      return;
    }

    const speed = 3.0; // pixels per frame (~60 px/s at 20 fps)
    _targetPos = TargetPosition(
      _targetPos!.x + dx / dist * speed,
      _targetPos!.y + dy / dist * speed,
    );
    notifyListeners();
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
      case 0: return 'かんたん';
      case 1: return 'むずかしい';
      default: return 'すごい！';
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
    _timerMove?.cancel();
    super.dispose();
  }
}
