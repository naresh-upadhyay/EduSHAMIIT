// This is a basic Flutter widget test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_ai/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EduShamiitApp());

    // Verify that the app builds successfully
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}