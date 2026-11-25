import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonride_passenger/main.dart';

void main() {
  test('passenger account access allows active status only', () {
    expect(isPassengerAccountActive('active'), isTrue);
    expect(isPassengerAccountActive(' ACTIVE '), isTrue);
    expect(isPassengerAccountActive('suspended'), isFalse);
    expect(isPassengerAccountActive('blocked'), isFalse);
    expect(isPassengerAccountActive(null), isFalse);
    expect(isPassengerAccountActive(''), isFalse);
    expect(isPassengerAccountActive('   '), isFalse);
  });

  test('booking requires an active passenger profile', () {
    expect(isPassengerProfileEligibleForBooking('passenger', 'active'), isTrue);
    expect(isPassengerProfileEligibleForBooking(' PASSENGER ', ' ACTIVE '), isTrue);
    expect(isPassengerProfileEligibleForBooking('driver', 'active'), isFalse);
    expect(isPassengerProfileEligibleForBooking('master_admin', 'active'), isFalse);
    expect(isPassengerProfileEligibleForBooking(null, 'active'), isFalse);
    expect(isPassengerProfileEligibleForBooking('passenger', 'suspended'), isFalse);
    expect(isPassengerProfileEligibleForBooking('passenger', null), isFalse);
  });

  testWidgets('MOONRIDE GO brand mark renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BrandMark()));
    expect(find.text('M'), findsOneWidget);
  });
}
