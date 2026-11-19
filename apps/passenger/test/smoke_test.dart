import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonride_passenger/main.dart';

void main() {
  testWidgets('MOONRIDE GO brand mark renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BrandMark()));
    expect(find.text('M'), findsOneWidget);
  });
}
