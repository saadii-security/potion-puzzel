import 'package:flutter_test/flutter_test.dart';
import 'package:potion_sort/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home shows continue', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const PotionSortApp());
      await tester.pump();
      expect(find.textContaining('CONTINUE'), findsOneWidget);
      expect(find.bySemanticsLabel('CONTINUE'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
