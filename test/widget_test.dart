import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_core/pos_core.dart';

import 'package:jureb_pos_demo/app/app.dart';
import 'package:jureb_pos_demo/services.dart';

void main() {
  testWidgets('app boots to the login screen', (WidgetTester tester) async {
    // In-memory database — widget tests shouldn't touch a real file on disk.
    final testDb = PosDatabase.forTesting(NativeDatabase.memory());
    final services = Services(testDb);
    await services.auth.seedDefaultAdminIfEmpty();

    await tester.pumpWidget(JurebPosApp(services: services));
    await tester.pumpAndSettle();

    expect(find.text('Jureb POS'), findsOneWidget);
    expect(find.text('Log in'), findsNothing); // PIN mode is the default
    expect(find.text('PIN'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
  });
}
