import 'package:flutter_test/flutter_test.dart';
import 'package:smb_app/main.dart';

void main() {
  testWidgets('App launches login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('SMB Login'), findsOneWidget);
  });
}
