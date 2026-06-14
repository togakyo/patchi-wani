// lib/screens/game_screen.dart
//
// Main game screen. Manages the HUD, game arena,
// start overlay, and game-over overlay via GameController.

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../game/web_beep_interop.dart';
import '../game/engine.dart';
import '../game/game_controller.dart';
import '../scratch/block_model.dart';
import 'block_editor_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _controller = GameController();
  BlockProgram _program = BlockProgram.defaultProgram();

  final _player = AudioPlayer();
  bool _hasHitSound = false;

  @override
  void initState() {
    super.initState();
    _loadHitSound();
  }

  Future<void> _loadHitSound() async {
    if (kIsWeb) return; // audioplayers is not supported on web
    try {
      // Preload assets/audio/hit.mp3 — replace with any sound file you like.
      await _player.setSource(AssetSource('audio/hit.mp3'));
      setState(() => _hasHitSound = true);
    } catch (_) {
      // File not found — will fall back to system click sound.
    }
  }

  Future<void> _playHit() async {
    if (kIsWeb) { playWebBeep(); return; }
    if (_hasHitSound) {
      await _player.seek(Duration.zero);
      unawaited(_player.resume());
    } else {
      unawaited(SystemSound.play(SystemSoundType.click));
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _startGame() {
    _controller.startGame(ruleJson: _program.toGameRuleJson());
  }

  void _openEditor() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlockEditorScreen(
        initialProgram: _program,
        onSave: (p) => setState(() => _program = p),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Column(
            children: [
              // ── HUD (playing only) ────────────────
              if (_controller.phase == GamePhase.playing)
                _HUD(controller: _controller),

              // ── Game arena + overlays ─────────────
              // Arena is Expanded so its LayoutBuilder gives the correct
              // height excluding the HUD — targets never spawn behind it.
              Expanded(
                child: Stack(
                  children: [
                    _GameArena(controller: _controller, onHitSound: _playHit),

                    // ── Start overlay ─────────────────
                    if (_controller.phase == GamePhase.idle)
                      _StartScreen(
                        onStart: _startGame,
                        onEdit:  _openEditor,
                      ),

                    // ── Game-over overlay ─────────────
                    if (_controller.phase == GamePhase.gameOver)
                      _GameOverScreen(
                        controller: _controller,
                        onRestart: _startGame,
                        onEdit:    _openEditor,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Game arena (target display)
// ─────────────────────────────────────────────
class _GameArena extends StatelessWidget {
  final GameController controller;
  final VoidCallback onHitSound;
  const _GameArena({required this.controller, required this.onHitSound});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Pass the arena size to the controller
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      controller.setArenaSize(size);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        child: SizedBox.expand(
          child: Stack(
            children: [
              if (controller.targetVisible && controller.targetPos != null)
                Positioned(
                  left: controller.targetPos!.x - controller.targetSize / 2,
                  top:  controller.targetPos!.y - controller.targetSize / 2,
                  child: GestureDetector(
                    onTap: () {
                      controller.onHit(size);
                      onHitSound();
                    },
                    child: _Target(size: controller.targetSize),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────
//  Target widget
// ─────────────────────────────────────────────
class _Target extends StatelessWidget {
  final double size;
  const _Target({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF3B30).withValues(alpha: 0.5),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        // CUSTOMIZE: replace this emoji with any character your child likes
        child: Text('🐊', style: TextStyle(fontSize: size * 0.44)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HUD (heads-up display)
// ─────────────────────────────────────────────
class _HUD extends StatelessWidget {
  final GameController controller;
  const _HUD({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isWarning = controller.timeLeft <= 10;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        color: Colors.black.withValues(alpha: 0.7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _HudBox(label: 'スコア', value: '${controller.score}'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC00).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFFFCC00).withValues(alpha: 0.35)),
              ),
              child: Text(controller.difficultyLabel,
                  style: const TextStyle(
                      color: Color(0xFFFFCC00), fontSize: 13)),
            ),
            _HudBox(
              label: 'のこり',
              value: '${controller.timeLeft}',
              valueColor: isWarning
                  ? const Color(0xFFFF3B30)
                  : const Color(0xFFFFCC00),
            ),
          ],
        ),
    );
  }
}

class _HudBox extends StatelessWidget {
  final String label;
  final String value;
  final Color  valueColor;
  const _HudBox({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFFFFCC00),
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label,
          style: const TextStyle(
              color: Color(0xFF4A90D9), fontSize: 11,
              letterSpacing: 1.0)),
      Text(value,
          style: TextStyle(
              color: valueColor, fontSize: 32, fontWeight: FontWeight.w600)),
    ]);
  }
}

// ─────────────────────────────────────────────
//  Start screen overlay
// ─────────────────────────────────────────────
class _StartScreen extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onEdit;
  const _StartScreen({required this.onStart, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return _OverlayScreen(
      children: [
        const Text('🐊', style: TextStyle(fontSize: 72)),
        const SizedBox(height: 8),
        const Text('パッチワニを\n捕まえろ！',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFFFFCC00),
                fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('パッチをつけたら、ゲームスタート！\nパッチワニが出たらすぐタップ！',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8899AA), fontSize: 15, height: 1.7)),
        const SizedBox(height: 24),
        _BigButton(label: '▶ スタート！', onTap: onStart),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onEdit,
          child: const Text('⚙ ルールをかえる',
              style: TextStyle(color: Color(0xFF7F77DD), fontSize: 16)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Game-over screen overlay
// ─────────────────────────────────────────────
class _GameOverScreen extends StatelessWidget {
  final GameController controller;
  final VoidCallback   onRestart;
  final VoidCallback   onEdit;
  const _GameOverScreen({
    required this.controller,
    required this.onRestart,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final info = controller.resultInfo;
    return _OverlayScreen(
      children: [
        Text(info.emoji, style: const TextStyle(fontSize: 72)),
        const SizedBox(height: 8),
        Text(info.title,
            style: const TextStyle(
                color: Color(0xFFFFCC00),
                fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('${controller.score} てん',
            style: const TextStyle(
                color: Color(0xFF00F2FE),
                fontSize: 52, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(info.msg,
            style: const TextStyle(color: Color(0xFF8899AA), fontSize: 15)),
        const SizedBox(height: 24),
        _BigButton(label: 'もういちど！', onTap: onRestart),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onEdit,
          child: const Text('⚙ ルールをかえる',
              style: TextStyle(color: Color(0xFF7F77DD), fontSize: 16)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Shared widgets
// ─────────────────────────────────────────────
class _OverlayScreen extends StatelessWidget {
  final List<Widget> children;
  const _OverlayScreen({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.95),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const _BigButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFF3B30),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF3B30).withValues(alpha: 0.35),
              blurRadius: 12, spreadRadius: 2,
            ),
          ],
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
