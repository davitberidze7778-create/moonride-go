import 'package:flutter_test/flutter_test.dart';
import 'package:moonride_go/moonride_app.dart';

void main() {
  testWidgets('Passenger shell keeps the agreed three-item navigation', (tester) async {
    await tester.pumpWidget(
      const MoonrideApp(
        role: MoonrideAppRole.passenger,
        backendConfigured: false,
      ),
    );

    expect(find.text('MOONRIDE GO'), findsOneWidget);
    expect(find.text('მთავარი'), findsOneWidget);
    expect(find.text('შეკვეთები'), findsOneWidget);
    expect(find.text('პროფილი'), findsOneWidget);
    expect(find.text('MOONRIDE Wallet'), findsNothing);
  });

  testWidgets('Driver shell is separate from Passenger shell', (tester) async {
    await tester.pumpWidget(
      const MoonrideApp(
        role: MoonrideAppRole.driver,
        backendConfigured: false,
      ),
    );

    expect(find.text('MOONRIDE GO Driver'), findsOneWidget);
    expect(find.text('მთავარი'), findsOneWidget);
    expect(find.text('შეკვეთები'), findsOneWidget);
  });

  testWidgets('Master Admin shell has its own title and navigation', (tester) async {
    await tester.pumpWidget(
      const MoonrideApp(
        role: MoonrideAppRole.masterAdmin,
        backendConfigured: false,
      ),
    );

    expect(find.text('MOONRIDE GO MASTER ADMIN'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('მართვა'), findsOneWidget);
  });
}
