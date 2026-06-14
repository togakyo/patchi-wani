// lib/game/engine_stub.dart
//
// Pure-Dart stub of EngineFFI for web and unsupported platforms.
// Simulates game logic without dart:ffi so the UI can be developed in Chrome.

import 'dart:convert';

enum GamePhase { idle, playing, gameOver }

class EngineFFI {
  EngineFFI._();
  static final EngineFFI instance = EngineFFI._();

  GamePhase _phase     = GamePhase.idle;
  int       _score     = 0;
  int       _timeLeft  = 60;
  int       _duration  = 60;
  int       _threshold1 = 8;
  int       _threshold2 = 15;

  int init({String? ruleJson}) {
    if (ruleJson != null) {
      try {
        final rule = jsonDecode(ruleJson) as Map<String, dynamic>;
        _duration   = (rule['duration_secs'] as num?)?.toInt() ?? 60;
        _threshold1 = (rule['threshold_1']   as num?)?.toInt() ?? 8;
        _threshold2 = (rule['threshold_2']   as num?)?.toInt() ?? 15;
      } catch (_) {
        return -1;
      }
    }
    _phase    = GamePhase.idle;
    _score    = 0;
    _timeLeft = _duration;
    return 0;
  }

  void start() {
    _phase    = GamePhase.playing;
    _score    = 0;
    _timeLeft = _duration;
  }

  int tick() {
    if (_phase != GamePhase.playing) return 0;
    _timeLeft--;
    if (_timeLeft <= 0) {
      _timeLeft = 0;
      _phase    = GamePhase.gameOver;
    }
    return 0;
  }

  int onHit() {
    if (_phase != GamePhase.playing) return _score;
    return ++_score;
  }

  int       getScore()      => _score;
  int       getTimeLeft()   => _timeLeft;
  GamePhase getPhase()      => _phase;
  int       getDifficulty() => _score >= _threshold2 ? 2 : _score >= _threshold1 ? 1 : 0;

  double getTargetSize() {
    switch (getDifficulty()) {
      case 2:  return 56.0;
      case 1:  return 72.0;
      default: return 96.0;
    }
  }

  String getRuleJson() => jsonEncode({
    'duration_secs': _duration,
    'appear_ms':     1500,
    'threshold_1':   _threshold1,
    'threshold_2':   _threshold2,
    'target_sizes':  [96, 72, 56],
  });
}
