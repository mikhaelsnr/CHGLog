import 'package:chglog/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('signs in and finds a valid CHG', (tester) async {
    await tester.pumpWidget(const ChgLogApp());

    expect(find.text('Welcome to CHGLog'), findsOneWidget);
    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pumpAndSettle();

    expect(find.text('Find an active change'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('chgField')), 'CHG0012345');
    await tester.tap(find.byKey(const Key('searchButton')));
    await tester.pumpAndSettle();

    expect(find.text('Active change found'), findsOneWidget);
    expect(find.byKey(const Key('resultChangeNumber')), findsOneWidget);
    expect(find.text('Sample change title'), findsOneWidget);
    expect(find.text('Sample objective shown only in widget tests.'), findsOneWidget);
    expect(find.text('Sample proponent'), findsOneWidget);
    expect(find.text('Not checked in'), findsOneWidget);
  });

  testWidgets('rejects an invalid CHG format', (tester) async {
    await tester.pumpWidget(const ChgLogApp());
    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('chgField')), '123');
    await tester.tap(find.byKey(const Key('searchButton')));
    await tester.pump();

    expect(
      find.text('Use the format CHG followed by 7 digits.'),
      findsOneWidget,
    );
  });
}
