import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test placeholder', (WidgetTester tester) async {
    // Placeholder test — prevents flutter create's default test from
    // referencing the non-existent MyApp class during CI.
    expect(1 + 1, equals(2));
  });
}
