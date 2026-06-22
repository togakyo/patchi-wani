// lib/screens/game_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../data/play_log_db.dart';
import '../game/web_beep_interop.dart';
import '../game/engine.dart';
import '../game/game_controller.dart';
import '../scratch/block_model.dart';
import 'block_editor_screen.dart';
import 'play_log_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _controller = GameController();
  BlockProgram _program = BlockProgram.defaultProgram();

  bool _trackingMode     = false;
  bool _figureGroundMode = false;
  bool _multiTargetMode  = false;
  bool _savedThisGame    = false;

  final _player = AudioPlayer();
  bool _hasHitSound = false;

  final _stackKey      = GlobalKey();
  final _hitEffectKey  = GlobalKey<_HitEffectOverlayState>();

  @override
  void initState() {
    super.initState();
    _loadHitSound();
    _controller.addListener(_onControllerChange);
  }

  void _onControllerChange() {
    if (_controller.phase == GamePhase.gameOver && !_savedThisGame) {
      _savedThisGame = true;
      PlayLogDb.instance.insert(_controller.score);
    }
    if (_controller.phase == GamePhase.playing) {
      _savedThisGame = false;
    }
  }

  Future<void> _loadHitSound() async {
    if (kIsWeb) return;
    try {
      await _player.setSource(AssetSource('audio/hit.mp3'));
      setState(() => _hasHitSound = true);
    } catch (_) {}
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

  void _addHitEffect(Offset globalPos) {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    _hitEffectKey.currentState?.addEffect(box.globalToLocal(globalPos));
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _player.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _startGame() {
    _controller.startGame(
      ruleJson: _program.toGameRuleJson(),
      trackingMode: _trackingMode,
      figureGroundMode: _figureGroundMode,
      multiTargetMode: _multiTargetMode,
    );
  }

  void _openEditor() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlockEditorScreen(
        initialProgram: _program,
        onSave: (p) => setState(() => _program = p),
      ),
    ));
  }

  void _openPlayLog() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const PlayLogScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(
        key: _stackKey,
        children: [
          // ── Main content ───────────────────────────
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return Column(
                children: [
                  if (_controller.phase == GamePhase.playing)
                    _HUD(controller: _controller),

                  Expanded(
                    child: Stack(
                      children: [
                        _GameArena(
                          controller: _controller,
                          onHitSound: _playHit,
                          onHitEffect: _addHitEffect,
                        ),

                        if (_controller.phase == GamePhase.idle)
                          _StartScreen(
                            onStart:   _startGame,
                            onEdit:    _openEditor,
                            onViewLog: _openPlayLog,
                            trackingMode:     _trackingMode,
                            figureGroundMode: _figureGroundMode,
                            multiTargetMode:  _multiTargetMode,
                            onTrackingChanged:     (v) => setState(() => _trackingMode = v),
                            onFigureGroundChanged: (v) => setState(() => _figureGroundMode = v),
                            onMultiTargetChanged:  (v) => setState(() => _multiTargetMode = v),
                          ),

                        if (_controller.phase == GamePhase.gameOver)
                          _GameOverScreen(
                            controller: _controller,
                            onRestart:  _startGame,
                            onEdit:     _openEditor,
                            onViewLog:  _openPlayLog,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Hit effect overlay (fullscreen, non-interactive) ──
          IgnorePointer(
            child: _HitEffectOverlay(key: _hitEffectKey),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Game arena
// ─────────────────────────────────────────────
class _GameArena extends StatelessWidget {
  final GameController controller;
  final VoidCallback onHitSound;
  final void Function(Offset globalPos) onHitEffect;

  const _GameArena({
    required this.controller,
    required this.onHitSound,
    required this.onHitEffect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      controller.setArenaSize(size);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        child: SizedBox.expand(
          child: Stack(
            children: [
              // Figure-ground distractors (below real targets)
              if (controller.figureGroundMode)
                ...controller.distractors.map((pos) => Positioned(
                      left: pos.x - controller.targetSize / 2,
                      top:  pos.y - controller.targetSize / 2,
                      child: _Distractor(size: controller.targetSize),
                    )),

              // Active targets
              ...controller.activeTargets.map((target) => Positioned(
                    left: target.pos.x - target.size / 2,
                    top:  target.pos.y - target.size / 2,
                    child: GestureDetector(
                      onTapDown: (details) {
                        final hit = controller.onHit(target.id, size);
                        if (hit) {
                          onHitSound();
                          onHitEffect(details.globalPosition);
                        }
                      },
                      child: _Target(size: target.size, color: target.color),
                    ),
                  )),

              // Multi-target hint: "🔴 あかをタップ！"
              if (controller.multiTargetMode &&
                  controller.activeTargets.isNotEmpty)
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF3B30),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('あかをタップ！',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
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
  final Color color;
  const _Target({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
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
//  Distractor widget (figure-ground mode)
// ─────────────────────────────────────────────
class _Distractor extends StatelessWidget {
  final double size;
  const _Distractor({required this.size});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.38,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFF882222),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text('🐊', style: TextStyle(fontSize: size * 0.44)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HUD
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
          Row(children: [
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
            if (controller.trackingMode) ...[
              const SizedBox(width: 8),
              const _HudBadge(label: '追跡', color: Color(0xFF7F77DD)),
            ],
            if (controller.figureGroundMode) ...[
              const SizedBox(width: 8),
              const _HudBadge(label: '迷彩', color: Color(0xFF00BFAD)),
            ],
            if (controller.multiTargetMode) ...[
              const SizedBox(width: 8),
              const _HudBadge(label: 'マルチ', color: Color(0xFFFF9500)),
            ],
          ]),
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

class _HudBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _HudBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _HudBox extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
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
              color: Color(0xFF4A90D9), fontSize: 11, letterSpacing: 1.0)),
      Text(value,
          style: TextStyle(
              color: valueColor,
              fontSize: 32,
              fontWeight: FontWeight.w600)),
    ]);
  }
}

// ─────────────────────────────────────────────
//  Start screen
// ─────────────────────────────────────────────
class _StartScreen extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onViewLog;
  final bool trackingMode;
  final bool figureGroundMode;
  final bool multiTargetMode;
  final ValueChanged<bool> onTrackingChanged;
  final ValueChanged<bool> onFigureGroundChanged;
  final ValueChanged<bool> onMultiTargetChanged;

  const _StartScreen({
    required this.onStart,
    required this.onEdit,
    required this.onViewLog,
    required this.trackingMode,
    required this.figureGroundMode,
    required this.multiTargetMode,
    required this.onTrackingChanged,
    required this.onFigureGroundChanged,
    required this.onMultiTargetChanged,
  });

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
                fontSize: 28,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('パッチをつけたら、ゲームスタート！\nパッチワニが出たらすぐタップ！',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFF8899AA), fontSize: 15, height: 1.7)),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            _ModeToggle(
              label: '追跡モード', icon: '👁',
              value: trackingMode, onChanged: onTrackingChanged,
            ),
            _ModeToggle(
              label: '迷彩モード', icon: '🎭',
              value: figureGroundMode, onChanged: onFigureGroundChanged,
            ),
            _ModeToggle(
              label: 'マルチ', icon: '🔴',
              value: multiTargetMode, onChanged: onMultiTargetChanged,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _BigButton(label: '▶ スタート！', onTap: onStart),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: onEdit,
              child: const Text('⚙ ルールをかえる',
                  style: TextStyle(color: Color(0xFF7F77DD), fontSize: 16)),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onViewLog,
              child: const Text('📊 きろく',
                  style: TextStyle(color: Color(0xFF556677), fontSize: 16)),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Mode toggle chip
// ─────────────────────────────────────────────
class _ModeToggle extends StatelessWidget {
  final String label;
  final String icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ModeToggle({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF7F77DD);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: value ? activeColor.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: value ? activeColor : const Color(0xFF334455),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: value ? activeColor : const Color(0xFF556677),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Game-over screen
// ─────────────────────────────────────────────
class _GameOverScreen extends StatelessWidget {
  final GameController controller;
  final VoidCallback onRestart;
  final VoidCallback onEdit;
  final VoidCallback onViewLog;
  const _GameOverScreen({
    required this.controller,
    required this.onRestart,
    required this.onEdit,
    required this.onViewLog,
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
                fontSize: 26,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('${controller.score} てん',
            style: const TextStyle(
                color: Color(0xFF00F2FE),
                fontSize: 52,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(info.msg,
            style: const TextStyle(
                color: Color(0xFF8899AA), fontSize: 15)),
        const SizedBox(height: 24),
        _BigButton(label: 'もういちど！', onTap: onRestart),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: onEdit,
              child: const Text('⚙ ルールをかえる',
                  style: TextStyle(color: Color(0xFF7F77DD), fontSize: 16)),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onViewLog,
              child: const Text('📊 きろく',
                  style: TextStyle(color: Color(0xFF556677), fontSize: 16)),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Shared overlay / button widgets
// ─────────────────────────────────────────────
class _OverlayScreen extends StatelessWidget {
  final List<Widget> children;
  const _OverlayScreen({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.95),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
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
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Hit effect overlay
// ─────────────────────────────────────────────

class _HitEffectData {
  final Offset center;
  final List<_Particle> particles;
  final AnimationController controller;
  double get t => controller.value;

  _HitEffectData({
    required this.center,
    required this.particles,
    required this.controller,
  });
}

class _Particle {
  final double angle;
  final double speed;
  final double radius;
  final Color color;
  const _Particle({
    required this.angle,
    required this.speed,
    required this.radius,
    required this.color,
  });
}

class _HitEffectOverlay extends StatefulWidget {
  const _HitEffectOverlay({super.key});

  @override
  State<_HitEffectOverlay> createState() => _HitEffectOverlayState();
}

class _HitEffectOverlayState extends State<_HitEffectOverlay>
    with TickerProviderStateMixin {
  final _effects = <_HitEffectData>[];
  final _rng = Random();

  static const _particleColors = [
    Color(0xFFFFCC00),
    Color(0xFFFF9500),
    Color(0xFFFF3B30),
    Color(0xFFFFFFFF),
    Color(0xFF00F2FE),
  ];

  void addEffect(Offset localPos) {
    final particles = List.generate(12, (_) => _Particle(
      angle:  _rng.nextDouble() * 2 * pi,
      speed:  70 + _rng.nextDouble() * 70,
      radius: 2.5 + _rng.nextDouble() * 3.5,
      color:  _particleColors[_rng.nextInt(_particleColors.length)],
    ));

    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    final effect = _HitEffectData(
        center: localPos, particles: particles, controller: ctrl);

    ctrl.addListener(() => setState(() {}));
    ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _effects.remove(effect);
        ctrl.dispose();
        if (mounted) setState(() {});
      }
    });

    setState(() => _effects.add(effect));
    ctrl.forward();
  }

  @override
  void dispose() {
    for (final e in List.of(_effects)) {
      e.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_effects.isEmpty) return const SizedBox.shrink();
    return CustomPaint(
      painter: _HitEffectPainter(effects: List.of(_effects)),
      child: const SizedBox.expand(),
    );
  }
}

class _HitEffectPainter extends CustomPainter {
  final List<_HitEffectData> effects;
  _HitEffectPainter({required this.effects});

  @override
  void paint(Canvas canvas, Size size) {
    for (final fx in effects) {
      final t    = fx.t;
      final dist = t * (2 - t); // ease-out distance factor

      // Expanding ring
      canvas.drawCircle(
        fx.center,
        58 * dist,
        Paint()
          ..color = const Color(0xFFFFCC00)
              .withValues(alpha: ((1 - t) * 0.65).clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      // Particles
      for (final p in fx.particles) {
        final px    = fx.center.dx + cos(p.angle) * p.speed * dist;
        final py    = fx.center.dy + sin(p.angle) * p.speed * dist;
        final alpha = (1 - t * 1.1).clamp(0.0, 1.0);
        final pr    = p.radius * (1 - t * 0.4);
        if (pr <= 0) continue;
        canvas.drawCircle(
          Offset(px, py),
          pr,
          Paint()
            ..color = p.color.withValues(alpha: alpha)
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HitEffectPainter old) => true;
}
