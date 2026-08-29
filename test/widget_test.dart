import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qataly/main.dart';

void main() {
  testWidgets('QatalyApp smoke test — renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const QatalyApp());
    // App should render at least one widget
    expect(find.byType(QatalyApp), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
