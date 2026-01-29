import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wfmc/main.dart';

void main() {
  testWidgets('WFMC app boots', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(WfmcApp(prefs: prefs));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
