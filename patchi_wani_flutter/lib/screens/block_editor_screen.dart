// lib/screens/block_editor_screen.dart
//
// Screen where children drag-and-drop blocks to
// customize game rules.

import 'package:flutter/material.dart';
import '../scratch/block_model.dart';

class BlockEditorScreen extends StatefulWidget {
  final BlockProgram initialProgram;
  final void Function(BlockProgram) onSave;

  const BlockEditorScreen({
    super.key,
    required this.initialProgram,
    required this.onSave,
  });

  @override
  State<BlockEditorScreen> createState() => _BlockEditorScreenState();
}

class _BlockEditorScreenState extends State<BlockEditorScreen> {
  late List<Block> _blocks;

  // Available blocks shown in the palette
  final _palette = const [
    Block(type: BlockType.setDuration,   params: {'secs': 60}),
    Block(type: BlockType.setDuration,   params: {'secs': 30}),
    Block(type: BlockType.setTargetSize, params: {'level': 0, 'size': 120}),
    Block(type: BlockType.setTargetSize, params: {'level': 0, 'size': 96}),
    Block(type: BlockType.setTargetSize, params: {'level': 1, 'size': 68}),
    Block(type: BlockType.setTargetSize, params: {'level': 2, 'size': 50}),
    Block(type: BlockType.setThreshold,  params: {'level': 1, 'score': 5}),
    Block(type: BlockType.setThreshold,  params: {'level': 1, 'score': 10}),
    Block(type: BlockType.setThreshold,  params: {'level': 2, 'score': 20}),
  ];

  @override
  void initState() {
    super.initState();
    _blocks = List.of(widget.initialProgram.blocks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('ブロックでカスタマイズ',
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('けってい！',
                style: TextStyle(color: Color(0xFFFFCC00), fontSize: 18)),
          ),
        ],
      ),
      body: Row(
        children: [
          // Left: program area (drop target)
          Expanded(
            flex: 3,
            child: _buildProgramArea(),
          ),
          // Right: block palette
          Container(
            width: 180,
            color: const Color(0xFF161B22),
            child: _buildPalette(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramArea() {
    return DragTarget<Block>(
      onAcceptWithDetails: (details) {
        setState(() => _blocks.add(details.data));
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isHovering
                ? const Color(0xFF1F2937)
                : const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovering
                  ? const Color(0xFF7F77DD)
                  : const Color(0xFF30363D),
            ),
          ),
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(12),
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _blocks.removeAt(oldIndex);
                _blocks.insert(newIndex, item);
              });
            },
            itemCount: _blocks.length,
            itemBuilder: (context, index) {
              final block = _blocks[index];
              return _BlockTile(
                key: ValueKey('$index-${block.type.name}'),
                block: block,
                onDelete: () => setState(() => _blocks.removeAt(index)),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPalette() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('ブロック',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        ..._palette.map((block) => Draggable<Block>(
          data: block,
          feedback: Material(
            color: Colors.transparent,
            child: _BlockChip(block: block, opacity: 0.85),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _BlockChip(block: block),
          ),
          child: _BlockChip(block: block),
        )),
      ],
    );
  }

  void _save() {
    final program = BlockProgram(_blocks);
    widget.onSave(program);
    Navigator.of(context).pop();
  }
}

// ─────────────────────────────────────────────
//  Internal widgets
// ─────────────────────────────────────────────
class _BlockChip extends StatelessWidget {
  final Block   block;
  final double  opacity;
  const _BlockChip({required this.block, this.opacity = 1.0});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Color(block.colorValue),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          block.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _BlockTile extends StatelessWidget {
  final Block    block;
  final VoidCallback onDelete;
  const _BlockTile({super.key, required this.block, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Color(block.colorValue),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.drag_handle, color: Colors.white54, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(block.label,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, color: Colors.white54, size: 20),
          ),
        ],
      ),
    );
  }
}
