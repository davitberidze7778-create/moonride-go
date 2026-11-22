import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonride_core/moonride_core.dart';

void main() {
  testWidgets('Moonride Admin shared brand mark renders', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: moonrideTheme,
      home: const Scaffold(body: Center(child: MoonrideBrandMark())),
    ));
    expect(find.text('M'), findsOneWidget);
    expect(find.byIcon(Icons.location_pin), findsOneWidget);
  });
}
