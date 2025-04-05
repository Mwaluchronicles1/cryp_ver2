// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cryp_pro_ver2/main.dart';

void main() {
  testWidgets('Document verification app test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DocumentVerificationApp());

    // This is just a basic test to ensure the app builds
    // As our app is more complex with blockchain integration, 
    // we'll need more specialized tests
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Document Verification Platform'), findsOneWidget);
  });
}
