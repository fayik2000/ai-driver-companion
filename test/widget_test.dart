import 'package:ai_driver_companion/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Pill menampilkan teks', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Pill('Data Simulasi'))));
    expect(find.text('Data Simulasi'), findsOneWidget);
  });
}
