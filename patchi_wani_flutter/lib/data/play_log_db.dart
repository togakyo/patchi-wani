import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DayScore {
  final String date; // 'YYYY-MM-DD'
  final int score;
  const DayScore({required this.date, required this.score});
}

class PlayLogDb {
  static final PlayLogDb instance = PlayLogDb._();
  PlayLogDb._();

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'play_log.db'),
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE play_log ('
        '  id INTEGER PRIMARY KEY AUTOINCREMENT,'
        '  date TEXT NOT NULL,'
        '  score INTEGER NOT NULL,'
        '  created_at INTEGER NOT NULL'
        ')',
      ),
    );
    return _db!;
  }

  Future<void> insert(int score) async {
    if (kIsWeb) return;
    final db = await _open();
    final now = DateTime.now();
    final date = '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    await db.insert('play_log', {
      'date': date,
      'score': score,
      'created_at': now.millisecondsSinceEpoch,
    });
  }

  Future<List<DayScore>> getLast30Days() async {
    if (kIsWeb) return [];
    final db = await _open();
    final rows = await db.rawQuery(
      "SELECT date, MAX(score) AS score FROM play_log "
      "WHERE date >= date('now', '-29 days') "
      "GROUP BY date ORDER BY date ASC",
    );
    return rows
        .map((r) => DayScore(
              date: r['date'] as String,
              score: (r['score'] as num).toInt(),
            ))
        .toList();
  }
}
