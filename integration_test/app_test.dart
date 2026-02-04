import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:serviceprovider/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('smoke test: app starts', (WidgetTester tester) async {
    // Start the real app. This uses your existing main() entrypoint
    // and does not change any application logic.
    app.main();

    // Let the first frame build.
    await tester.pumpAndSettle();

    // Basic expectation: the app's root render view is available (no crash).
    expect(tester.binding.renderViewElement, isNotNull);
  });
}
