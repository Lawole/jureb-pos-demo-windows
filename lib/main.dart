import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pos_core/pos_core.dart';

import 'app/app.dart';
import 'services.dart';

Future<void> main() async {
  // Flutter needs this when you do async work before runApp().
  WidgetsFlutterBinding.ensureInitialized();

  // Find a folder to store the database file in (e.g. on Windows this is
  // somewhere under %APPDATA%), then open (or create) the database there.
  final appFolder = await getApplicationSupportDirectory();
  final db = PosDatabase.open(directoryPath: path.join(appFolder.path, 'db'));
  final services = Services(db);

  // First run only: create a default admin account so the app is never
  // unusable out of the box.
  await services.auth.seedDefaultAdminIfEmpty();

  runApp(JurebPosApp(services: services));
}
