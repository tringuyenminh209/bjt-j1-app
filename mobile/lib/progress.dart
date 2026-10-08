import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'content.dart';

class Progress extends ChangeNotifier {
  late Database db;
  final Map<String, Json> reviews = {};
  final Map<String, Json> sessions = {};
  DateTime start = DateTime.now();
  String? syncError;
  bool syncing = false;

  Future<void> init() async {
    db = await openDatabase(
      '${await getDatabasesPath()}/bjt_j1.db',
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE reviews (id TEXT PRIMARY KEY, body TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE sessions (id TEXT PRIMARY KEY, body TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE settings (id TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
      },
    );
    for (final table in ['reviews', 'sessions']) {
      for (final row in await db.query(table)) {
        final body = jsonDecode(row['body'] as String) as Json;
        (table == 'reviews' ? reviews : sessions)[row['id'] as String] = body;
      }
    }
    final settings = await db.query(
      'settings',
      where: 'id = ?',
      whereArgs: ['start'],
    );
    if (settings.isNotEmpty) {
      start = DateTime.parse(settings.first['value'] as String);
    } else {
      await db.insert('settings', {
        'id': 'start',
        'value': start.toIso8601String(),
      });
    }
  }

  Future<void> persist(String table, String id, Json body) async {
    await db.insert(table, {
      'id': id,
      'body': jsonEncode(body),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  int get week => (DateTime.now().difference(start).inDays ~/ 7).clamp(0, 7);
  int get answered =>
      sessions.values.fold(0, (n, s) => n + (s['total'] as int));
  int get correct =>
      sessions.values.fold(0, (n, s) => n + (s['correct'] as int));
  Set<String> get due => reviews.entries
      .where(
        (e) => !DateTime.parse(
          e.value['due_at'] as String,
        ).isAfter(DateTime.now()),
      )
      .map((e) => e.key)
      .toSet();

  Future<void> record(Question q, bool correct) async {
    final previous = reviews[q.id];
    final interval = nextInterval(
      previous?['interval_days'] as int? ?? 0,
      correct,
    );
    final now = DateTime.now().toUtc();
    final row = <String, dynamic>{
      'content_id': q.id,
      'interval_days': interval,
      'due_at': now.add(Duration(days: interval)).toIso8601String(),
      'wrong_count':
          (previous?['wrong_count'] as int? ?? 0) + (correct ? 0 : 1),
      'updated_at': now.toIso8601String(),
    };
    await persist('reviews', q.id, row);
    reviews[q.id] = row;
    notifyListeners();
  }

  Future<void> finish(int total, int correct, int seconds, String mode) async {
    final now = DateTime.now().toUtc();
    final id = now.microsecondsSinceEpoch.toString();
    final row = <String, dynamic>{
      'session_id': id,
      'total': total,
      'correct': correct,
      'seconds': seconds,
      'mode': mode,
      'updated_at': now.toIso8601String(),
    };
    await persist('sessions', id, row);
    sessions[id] = row;
    notifyListeners();
  }

  Future<void> sync(SupabaseClient client) async {
    if (syncing || client.auth.currentUser == null) return;
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      final uid = client.auth.currentUser!.id;
      for (final spec in [
        ('reviews', 'review_states', 'content_id'),
        ('sessions', 'study_sessions', 'session_id'),
      ]) {
        final local = spec.$1 == 'reviews' ? reviews : sessions;
        final remote = <Json>[];
        for (var offset = 0; ; offset += 500) {
          final page = await client
              .from(spec.$2)
              .select()
              .order(spec.$3)
              .range(offset, offset + 499);
          remote.addAll(page);
          if (page.length < 500) break;
        }
        for (final row in remote) {
          final id = row[spec.$3] as String;
          if (!local.containsKey(id) ||
              DateTime.parse(
                row['updated_at'] as String,
              ).isAfter(DateTime.parse(local[id]!['updated_at'] as String))) {
            final body = Map<String, dynamic>.from(row)
              ..remove('user_id')
              ..remove('id')
              ..remove('created_at');
            await persist(spec.$1, id, body);
            local[id] = body;
          }
        }
        final rows = local.values.toList();
        for (var offset = 0; offset < rows.length; offset += 500) {
          await client.from(spec.$2).upsert([
            for (final row in rows.skip(offset).take(500))
              {...row, 'user_id': uid},
          ], onConflict: 'user_id,${spec.$3}');
        }
      }
    } catch (e) {
      syncError = 'Chưa đồng bộ được. Dữ liệu vẫn lưu trên máy. $e';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }
}
