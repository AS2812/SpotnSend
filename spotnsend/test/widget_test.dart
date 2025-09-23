import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/app.dart';

void main() {
  testWidgets('renders login screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SpotnSendApp()));
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsOneWidget);
  });
}
