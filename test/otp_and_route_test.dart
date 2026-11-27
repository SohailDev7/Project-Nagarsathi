import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/widgets/ns_otp_input.dart';
import 'package:projectnagarsathi/widgets/ns_route.dart';

void main() {
  testWidgets('NsOtpInput supports paste and triggers onCompleted', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? completed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NsOtpInput(
            controller: controller,
            autofocus: false,
            onCompleted: (code) => completed = code,
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('otp-box-0')), '482910');
    await tester.pump();

    expect(controller.text, '482910');
    expect(completed, '482910');
  });

  testWidgets('NsOtpInput advances box by box when typing single digits', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? completed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NsOtpInput(
            controller: controller,
            autofocus: false,
            onCompleted: (code) => completed = code,
          ),
        ),
      ),
    );

    const digits = ['1', '2', '3', '4', '5', '6'];
    for (var i = 0; i < digits.length; i++) {
      await tester.enterText(find.byKey(Key('otp-box-$i')), digits[i]);
      await tester.pump();
    }

    expect(controller.text, '123456');
    expect(completed, '123456');
  });

  testWidgets('NsPageRoute transitions cleanly between routes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  NsPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('Next Screen')),
                  ),
                );
              },
              child: const Text('Go'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    expect(find.text('Next Screen'), findsOneWidget);
  });
}
