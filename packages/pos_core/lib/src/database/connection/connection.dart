import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

/// Opens a native SQLite connection at [directoryPath]/[fileName]. Works on
/// Windows, macOS, and Linux desktop. WAL mode is enabled so a crash or
/// power cut mid-write (a real risk at Nigerian tills) can't corrupt the
/// database — SQLite replays the write-ahead log on next open.
QueryExecutor openConnection(String directoryPath, String fileName) {
  return LazyDatabase(() async {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File(p.join(directoryPath, fileName));
    return NativeDatabase.createInBackground(
      file,
      setup: (database) {
        database.execute('PRAGMA journal_mode=WAL;');
        database.execute('PRAGMA foreign_keys=ON;');
      },
    );
  });
}
