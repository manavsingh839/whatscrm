import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whtsappcrm/features/webhooks/screens/webhooks_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'webhook_custom_url': 'http://localhost:3000/api/whatsapp/webhook',
    });
  });

  testWidgets('WebhooksScreen renders titles and credential controls', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WebhooksScreen(),
        ),
      ),
    );

    // Initial pump and settle
    await tester.pump();

    // Verify header text
    expect(find.text('Webhooks & Real-time Integration'), findsOneWidget);

    // Verify setup credentials card
    expect(find.text('Meta Webhook Setup Credentials'), findsOneWidget);
    expect(find.text('Callback URL'), findsOneWidget);
    expect(find.text('Verify Token'), findsOneWidget);

    // Verify simulator card
    expect(find.text('Simulate Incoming WhatsApp Message'), findsOneWidget);
    expect(find.text('Sender Phone Number'), findsOneWidget);

    // Verify guide
    expect(find.text('Meta Developer Console Setup Guide'), findsOneWidget);
  });
}
