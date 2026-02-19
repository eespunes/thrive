import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/design_system/components/thrive_primary_button.dart';
import 'package:thrive_app/core/design_system/components/thrive_surface_card.dart';
import 'package:thrive_app/core/design_system/design_tokens.dart';

void main() {
  testWidgets('ThrivePrimaryButton renders label and triggers callback', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ThrivePrimaryButton(
            label: 'Continue',
            onPressed: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('ThriveSurfaceCard renders a Card with expected padding', (
    tester,
  ) async {
    const child = Text('Card content');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ThriveSurfaceCard(child: child)),
      ),
    );

    expect(find.byType(Card), findsOneWidget);
    expect(find.text('Card content'), findsOneWidget);

    final surfacePaddingFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Padding &&
          widget.padding == const EdgeInsets.all(ThriveSpacing.lg),
    );
    expect(surfacePaddingFinder, findsOneWidget);

    final paddingWidget = tester.widget<Padding>(surfacePaddingFinder);
    expect(paddingWidget.padding, const EdgeInsets.all(ThriveSpacing.lg));
  });
}
