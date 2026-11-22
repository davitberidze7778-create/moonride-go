import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonride_passenger/main.dart';

void main() {
  testWidgets('MOONRIDE GO brand mark renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BrandMark()));
    expect(find.text('M'), findsOneWidget);
  });

  testWidgets('launch gate keeps the branded splash during its first seconds',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LaunchGate()));
    expect(find.byType(BrandMark), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(BrandMark), findsOneWidget);
  });

  testWidgets('sign-in screen exposes password recovery', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    expect(find.text('პაროლის აღდგენა'), findsOneWidget);
  });

  testWidgets('password recovery screen asks for a new password',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PasswordUpdateScreen()));
    expect(find.text('ახალი პაროლი'), findsOneWidget);
    expect(find.text('გაიმეორე ახალი პაროლი'), findsOneWidget);
  });
}
