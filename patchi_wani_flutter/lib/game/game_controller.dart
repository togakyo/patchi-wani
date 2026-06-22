// lib/game/game_controller.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'engine.dart';

class TargetPosition {
  final double x;
  final double y;
  const TargetPosition(this.x, this.y);
}

class ActiveTarget {
  final int id;
  TargetPosition pos; // mutable for tracking mode
  final double size;
  final Color color;
  final bool isCorrect;

  ActiveTarget({
    required this.id,
    required this.pos,
    required this.size,
    required this.color,
    required this.isCorrect,
  });
}

class GameController extends ChangeNotifier {
  final _ffi = EngineFFI.instance;
  final _rng = Random();

  // ── Public state ──────────────────────────────────
  GamePhase get phase          => _phase;
  int       get score          => _score;
  int       get timeLeft       => _timeLeft;
  double    get targetSize     => _targetSize;
  int       get difficulty     => _difficulty;
  bool      get trackingMode     => _trackingMode;
  bool      get figureGroundMode => _figureGroundMode;
  bool      get multiTargetMode  => _multiTargetMode;

  List<ActiveTarget>   get activeTargets => List.unmodifiable(_activeTargets);
  List<TargetPosition> get distractors   => List.unmodifiable(_distractors);

  // ── Internal state ───────────────────────────────
  GamePhase _phase      = GamePhase.idle;
  int       _score      = 0;
  int       _timeLeft   = 60;
  double    _targetSize = 96.0;
  int       _difficulty = 0;

  bool _trackingMode     = false;
  bool _figureGroundMode = false;
  bool _multiTargetMode  = false;

  final _activeTargets    = <ActiveTarget>[];
  final _moveDestinations = <int, TargetPosition>{};
  List<TargetPosition> _distractors = [];
  int _nextId = 0;

  Timer? _timerTick;
  Timer? _timerHide;
  Timer? _timerSpawn;
  Timer? _timerMove;

  // ── Start game ───────────────────────────────────
  void startGame({
    String? ruleJson,
    bool trackingMode = false,
    bool figureGroundMode = false,
    bool multiTargetMode = false,
  }) {
    _timerTick?.cancel();
    _timerHide?.cancel();
    _timerSpawn?.cancel();
    _timerMove?.cancel();

    _trackingMode    = trackingMode;
    _figureGroundMode = figureGroundMode;
    _multiTargetMode  = multiTargetMode;
    _activeTargets.clear();
    _moveDestinations.clear();
    _distractors = [];
    _nextId = 0;

    _ffi.init(ruleJson: ruleJson);
    _ffi.start();
    _syncFromEngine();

    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      _ffi.tick();
      _syncFromEngine();
      if (_phase == GamePhase.gameOver) {
        _timerTick?.cancel();
        _timerHide?.cancel();
        _timerSpawn?.cancel();
        _timerMove?.cancel();
        _activeTargets.clear();
        _distractors = [];
        notifyListeners();
      }
    });

    if (_trackingMode) {
      _timerMove = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (_activeTargets.isNotEmpty && _arenaSize != null) _moveTargets();
      });
    }

    _scheduleNextTarget(delay: const Duration(milliseconds: 300));
  }

  // ── Target tap ──────────────────────────────────
  /// Returns true if the tap was a scoring hit (correct target).
  bool onHit(int targetId, Size arenaSize) {
    if (_phase != GamePhase.playing) return false;

    final idx = _activeTargets.indexWhere((t) => t.id == targetId);
    if (idx < 0) return false;

    final target = _activeTargets[idx];

    if (!_multiTargetMode || target.isCorrect) {
      _ffi.onHit();
      _syncFromEngine();
      _timerHide?.cancel();
      _activeTargets.clear();
      _moveDestinations.clear();
      _distractors = [];
      _scheduleNextTarget(delay: const Duration(milliseconds: 80));
      notifyListeners();
      return true;
    } else {
      // Wrong color in multi-target mode: remove it, no score change
      _activeTargets.removeAt(idx);
      _moveDestinations.remove(targetId);
      notifyListeners();
      return false;
    }
  }

  // ── Target spawn management ──────────────────────
  Size? _arenaSize;

  void setArenaSize(Size size) => _arenaSize = size;

  void _scheduleNextTarget({required Duration delay}) {
    _timerHide?.cancel();
    _timerSpawn?.cancel();

    _timerSpawn = Timer(delay, () {
      if (_phase != GamePhase.playing) return;
      _activeTargets.clear();
      _distractors = [];
      notifyListeners();

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

    _targetSize = _ffi.getTargetSize();
    final ts     = _targetSize;
    final margin = ts / 2 + 12;

    if (_multiTargetMode) {
      _placeMultiTargets(size, ts, margin);
    } else {
      _placeSingleTarget(size, ts, margin);
    }
  }

  void _placeSingleTarget(Size size, double ts, double margin) {
    final rx = margin + _rng.nextDouble() * (size.width  - margin * 2);
    final ry = margin + _rng.nextDouble() * (size.height - margin * 2);

    _activeTargets
      ..clear()
      ..add(ActiveTarget(
        id: _nextId++,
        pos: TargetPosition(rx, ry),
        size: ts,
        color: const Color(0xFFFF3B30),
        isCorrect: true,
      ));

    if (_figureGroundMode) _refreshDistractors(size, margin);

    notifyListeners();

    final hideDuration = _trackingMode
        ? const Duration(milliseconds: 2500)
        : const Duration(milliseconds: 1500);

    _timerHide = Timer(hideDuration, () {
      if (_phase != GamePhase.playing) return;
      _activeTargets.clear();
      _distractors = [];
      notifyListeners();
      _scheduleNextTarget(delay: const Duration(milliseconds: 100));
    });
  }

  static const _distractorColors = [
    Color(0xFFFFCC00), // yellow
    Color(0xFF4A90D9), // blue
    Color(0xFF00BCD4), // teal
  ];

  void _placeMultiTargets(Size size, double ts, double margin) {
    final positions = _nonOverlappingPositions(3, size, ts, margin);
    final correctIdx = _rng.nextInt(3);
    int colorIdx = 0;

    _activeTargets.clear();
    for (int i = 0; i < 3; i++) {
      _activeTargets.add(ActiveTarget(
        id: _nextId++,
        pos: positions[i],
        size: ts,
        color: i == correctIdx
            ? const Color(0xFFFF3B30)
            : _distractorColors[colorIdx++],
        isCorrect: i == correctIdx,
      ));
    }

    notifyListeners();

    final hideDuration = _trackingMode
        ? const Duration(milliseconds: 3000)
        : const Duration(milliseconds: 2000);

    _timerHide = Timer(hideDuration, () {
      if (_phase != GamePhase.playing) return;
      _activeTargets.clear();
      notifyListeners();
      _scheduleNextTarget(delay: const Duration(milliseconds: 100));
    });
  }

  List<TargetPosition> _nonOverlappingPositions(
      int count, Size size, double ts, double margin) {
    final out    = <TargetPosition>[];
    final minDist = ts * 1.6;

    for (int attempt = 0; attempt < 200 && out.length < count; attempt++) {
      final rx = margin + _rng.nextDouble() * (size.width  - margin * 2);
      final ry = margin + _rng.nextDouble() * (size.height - margin * 2);
      final tooClose = out.any((p) {
        final dx = p.x - rx;
        final dy = p.y - ry;
        return sqrt(dx * dx + dy * dy) < minDist;
      });
      if (!tooClose) out.add(TargetPosition(rx, ry));
    }

    while (out.length < count) {
      out.add(TargetPosition(
        margin + _rng.nextDouble() * (size.width  - margin * 2),
        margin + _rng.nextDouble() * (size.height - margin * 2),
      ));
    }
    return out;
  }

  // ── Figure-ground: distractor positions ──────────
  void _refreshDistractors(Size size, double margin) {
    _distractors = List.generate(8, (_) => TargetPosition(
      margin + _rng.nextDouble() * (size.width  - margin * 2),
      margin + _rng.nextDouble() * (size.height - margin * 2),
    ));
  }

  // ── Tracking mode: move all active targets ────────
  void _moveTargets() {
    final size = _arenaSize!;
    for (final target in _activeTargets) {
      final margin = target.size / 2 + 12;
      _moveDestinations[target.id] ??= TargetPosition(
        margin + _rng.nextDouble() * (size.width  - margin * 2),
        margin + _rng.nextDouble() * (size.height - margin * 2),
      );
      final dest = _moveDestinations[target.id]!;
      final dx = dest.x - target.pos.x;
      final dy = dest.y - target.pos.y;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < 8) {
        _moveDestinations.remove(target.id);
        continue;
      }
      const speed = 3.0;
      target.pos = TargetPosition(
        target.pos.x + dx / dist * speed,
        target.pos.y + dy / dist * speed,
      );
    }
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
