import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapistock/theme.dart';

void main() {
  testWidgets('Tema Rapistock carga', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RapistockTheme.light,
        home: const Scaffold(body: Text('Rapistock')),
      ),
    );
    expect(find.text('Rapistock'), findsOneWidget);
  });
}