// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nagar_sewa/app/theme.dart';

import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Project Integrity Checks', () {
    test('AppTheme defines light and dark modes', () {
      expect(AppTheme.lightTheme.brightness, Brightness.light);
      expect(AppTheme.darkTheme.brightness, Brightness.dark);
    });

    testWidgets('Basic widget rendering smoke test', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Nagar Sewa Ready')),
          ),
        ),
      );
      expect(find.text('Nagar Sewa Ready'), findsOneWidget);
    });
  });
}
