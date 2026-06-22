// lib/screens/play_log_screen.dart

import 'package:flutter/material.dart';
import '../data/play_log_db.dart';

class PlayLogScreen extends StatefulWidget {
  const PlayLogScreen({super.key});

  @override
  State<PlayLogScreen> createState() => _PlayLogScreenState();
}

class _PlayLogScreenState extends State<PlayLogScreen> {
  List<DayScore>? _scores;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final scores = await PlayLogDb.instance.getLast30Days();
    if (mounted) setState(() => _scores = scores);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        foregroundColor: const Color(0xFFFFCC00),
        title: const Text('スコアの記録',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _scores == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFCC00)))
          : _scores!.isEmpty
              ? const Center(
                  child: Text(
                    'まだ記録がありません\nゲームをプレイしてみよう！',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Color(0xFF8899AA),
                        fontSize: 16,
                        height: 1.8),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: _ScoreChart(scores: _scores!),
                ),
    );
  }
}

// ─────────────────────────────────────────────
//  Bar chart (last 14 days, best score per day)
// ─────────────────────────────────────────────
class _ScoreChart extends StatelessWidget {
  final List<DayScore> scores;
  const _ScoreChart({required this.scores});

  @override
  Widget build(BuildContext context) {
    final recent =
        scores.length > 14 ? scores.sublist(scores.length - 14) : scores;
    return CustomPaint(
      painter: _ChartPainter(scores: recent),
      child: const SizedBox.expand(),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<DayScore> scores;
  _ChartPainter({required this.scores});

  static const _padL = 44.0;
  static const _padR = 12.0;
  static const _padT = 28.0;
  static const _padB = 40.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final chartW = size.width  - _padL - _padR;
    final chartH = size.height - _padT  - _padB;
    final maxScore = scores.map((s) => s.score).reduce((a, b) => a > b ? a : b);
    final yScale = maxScore > 0 ? chartH / maxScore : 1.0;

    final slotW = chartW / scores.length;
    final barW  = slotW * 0.55;

    final barPaint = Paint()
      ..color = const Color(0xFFFFCC00)
      ..style = PaintingStyle.fill;
    final axisPaint = Paint()
      ..color = const Color(0xFF334455)
      ..strokeWidth = 1;
    final gridPaint = Paint()
      ..color = const Color(0xFF1E2832)
      ..strokeWidth = 1;

    // Horizontal grid lines (0, 25%, 50%, 75%, 100% of maxScore)
    for (int i = 0; i <= 4; i++) {
      final y = _padT + chartH - (chartH * i / 4);
      canvas.drawLine(Offset(_padL, y), Offset(size.width - _padR, y),
          i == 0 ? axisPaint : gridPaint);
    }

    // Y axis
    canvas.drawLine(
        const Offset(_padL, _padT), Offset(_padL, _padT + chartH), axisPaint);

    const labelStyle = TextStyle(color: Color(0xFF8899AA), fontSize: 10);
    final tp = TextPainter(textDirection: TextDirection.ltr);

    void drawText(String text, Offset center, {TextAlign align = TextAlign.right}) {
      tp.text = TextSpan(text: text, style: labelStyle);
      tp.layout();
      final dx = align == TextAlign.right ? center.dx - tp.width : center.dx - tp.width / 2;
      tp.paint(canvas, Offset(dx, center.dy - tp.height / 2));
    }

    // Y-axis labels
    drawText('$maxScore', const Offset(_padL - 4, _padT));
    drawText('0',         Offset(_padL - 4, _padT + chartH));

    // Bars + X labels + score labels
    for (int i = 0; i < scores.length; i++) {
      final s    = scores[i];
      final cx   = _padL + slotW * i + slotW / 2;
      final barH = s.score * yScale;
      final barX = cx - barW / 2;
      final barY = _padT + chartH - barH;

      if (barH > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(barX, barY, barW, barH),
            topLeft:  const Radius.circular(3),
            topRight: const Radius.circular(3),
          ),
          barPaint,
        );

        // Score label above bar
        tp.text = TextSpan(
            text: '${s.score}',
            style: const TextStyle(
                color: Color(0xFFFFCC00), fontSize: 10, fontWeight: FontWeight.w600));
        tp.layout();
        tp.paint(canvas,
            Offset(cx - tp.width / 2, barY - tp.height - 2));
      }

      // Day label (just the day number, e.g. "22")
      final dayLabel = s.date.substring(8); // 'YYYY-MM-DD' → 'DD'
      drawText(dayLabel, Offset(cx, _padT + chartH + 14), align: TextAlign.center);
    }

    // Month header (top-left of chart area)
    if (scores.isNotEmpty) {
      final monthStr = scores.first.date.substring(0, 7).replaceAll('-', '/');
      final lastMonthStr = scores.last.date.substring(0, 7).replaceAll('-', '/');
      final header = monthStr == lastMonthStr ? monthStr : '$monthStr – $lastMonthStr';
      tp.text = TextSpan(
          text: header,
          style: const TextStyle(color: Color(0xFF556677), fontSize: 11));
      tp.layout();
      tp.paint(canvas, const Offset(_padL, 4));
    }
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) =>
      oldDelegate.scores != scores;
}
