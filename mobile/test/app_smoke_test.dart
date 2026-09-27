import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megamek_mobile/app.dart';

void main() {
  testWidgets('shows the connect screen before any session is established', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MegaMekMobileApp()));

    expect(find.text('MegaMek Mobile'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
