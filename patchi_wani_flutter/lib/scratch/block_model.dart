// lib/scratch/block_model.dart
//
// Data model for Scratch-style blocks and conversion to GameRule JSON.

import 'dart:convert';

// ─────────────────────────────────────────────
//  Block types
// ─────────────────────────────────────────────
enum BlockType {
  // Control blocks
  onGameStart,   // "when game starts"
  waitSeconds,   // "wait N seconds"
  // Action blocks
  spawnTarget,   // "show target"
  playSound,     // "play sound"
  // Value blocks
  setDuration,   // "set duration to N seconds"
  setTargetSize, // "set target size to N"
  setThreshold,  // "level up at N points"
}

// ─────────────────────────────────────────────
//  ブロックノード
// ─────────────────────────────────────────────
class Block {
  final BlockType type;
  final Map<String, dynamic> params; // block parameters

  const Block({required this.type, this.params = const {}});

  // Display label shown in the block editor UI
  String get label {
    switch (type) {
      case BlockType.onGameStart:
        return 'ゲームかいしたら';
      case BlockType.waitSeconds:
        return '${params['secs'] ?? 60} びょうまつ';
      case BlockType.spawnTarget:
        return 'ターゲットをだす';
      case BlockType.playSound:
        return 'おとをならす';
      case BlockType.setDuration:
        return 'じかんを ${params['secs'] ?? 60} びょうにする';
      case BlockType.setTargetSize:
        return 'サイズを ${params['size'] ?? 96} にする（レベル${params['level'] ?? 0}）';
      case BlockType.setThreshold:
        return 'レベルアップを ${params['score'] ?? 10} てんにする（レベル${params['level'] ?? 1}）';
    }
  }

  // 背景色（カテゴリ別）
  int get colorValue {
    switch (type) {
      case BlockType.onGameStart:
      case BlockType.waitSeconds:
        return 0xFF7F77DD; // purple: control
      case BlockType.spawnTarget:
      case BlockType.playSound:
        return 0xFF1D9E75; // green: action
      case BlockType.setDuration:
      case BlockType.setTargetSize:
      case BlockType.setThreshold:
        return 0xFFBA7517; // amber: value
    }
  }

  Map<String, dynamic> toJson() => {'type': type.name, 'params': params};
}

// ─────────────────────────────────────────────
//  BlockProgram — ordered list of blocks + conversion to GameRule JSON
// ─────────────────────────────────────────────
class BlockProgram {
  final List<Block> blocks;
  const BlockProgram(this.blocks);

  /// デフォルトプログラム（初期状態）
  factory BlockProgram.defaultProgram() {
    return const BlockProgram([
      Block(type: BlockType.onGameStart),
      Block(type: BlockType.setDuration,   params: {'secs': 60}),
      Block(type: BlockType.setTargetSize, params: {'level': 0, 'size': 96}),
      Block(type: BlockType.setTargetSize, params: {'level': 1, 'size': 68}),
      Block(type: BlockType.setTargetSize, params: {'level': 2, 'size': 50}),
      Block(type: BlockType.setThreshold,  params: {'level': 1, 'score': 10}),
      Block(type: BlockType.setThreshold,  params: {'level': 2, 'score': 20}),
      Block(type: BlockType.spawnTarget),
    ]);
  }

  /// Converts the block list to a GameRule JSON string for the Rust engine.
  String toGameRuleJson() {
    int    duration    = 60;
    int    appearMs    = 1500;
    int    threshold1  = 10;
    int    threshold2  = 20;
    double sizeEasy    = 96.0;
    double sizeNormal  = 68.0;
    double sizeHard    = 50.0;

    for (final block in blocks) {
      switch (block.type) {
        case BlockType.setDuration:
          duration = (block.params['secs'] as num?)?.toInt() ?? duration;
        case BlockType.setTargetSize:
          final level = (block.params['level'] as num?)?.toInt() ?? -1;
          final sz    = (block.params['size']  as num?)?.toDouble() ?? 96.0;
          if (level == 0) sizeEasy   = sz;
          if (level == 1) sizeNormal = sz;
          if (level == 2) sizeHard   = sz;
        case BlockType.setThreshold:
          final level = (block.params['level'] as num?)?.toInt() ?? -1;
          final sc    = (block.params['score'] as num?)?.toInt() ?? 10;
          if (level == 1) threshold1 = sc;
          if (level == 2) threshold2 = sc;
        default:
          break;
      }
    }

    final rule = {
      'duration_secs': duration,
      'appear_ms':     appearMs,
      'threshold_1':   threshold1,
      'threshold_2':   threshold2,
      'target_sizes':  [sizeEasy, sizeNormal, sizeHard],
    };
    return jsonEncode(rule);
  }
}
