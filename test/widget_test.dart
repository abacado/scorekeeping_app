import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scorekeeping_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('plays a custom game with mixed scoring and a tie round', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ScorekeeperApp());
    await tester.pumpAndSettle();

    Future<void> tapText(String text, {int occurrence = 0}) async {
      final target = find.text(text).at(occurrence);
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Future<void> enter(String label, String value) async {
      final field = find.widgetWithText(TextFormField, label).first;
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }

    await tapText('2 players');
    await tapText('8 players');
    expect(find.text('Player 8 name'), findsOneWidget);
    await tapText('8 players');
    await tapText('2 players');
    await enter('Player 1 name', 'Ada');
    await enter('Player 2 name', 'Grace');
    await tapText('Custom');
    await enter('Points to win', '8');
    await tapText('Start game');
    await tapText('Add round');

    await tapText('Calculate');
    await enter('Cards played', '14');
    await enter('Blitz cards left', '3');
    expect(find.text('Round score: 8'), findsOneWidget);
    await enter('Round points', '8');
    await tapText('Save round');
    expect(
      find.textContaining('Play another round to break the tie.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const ScorekeeperApp());
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Ada, Grace are tied for first at 8'),
      findsOneWidget,
    );

    await tapText('Add round');
    await tester.enterText(find.byType(TextFormField).at(0), '0');
    await tester.enterText(find.byType(TextFormField).at(1), '-1');
    await tapText('Save round');
    expect(find.text('Ada wins!'), findsOneWidget);

    await tapText('Round 1');
    expect(find.text('Round score: 8'), findsOneWidget);
    await enter('Cards played', '13');
    await tapText('Save round');
    expect(find.text('Add round'), findsOneWidget);
  });
}
