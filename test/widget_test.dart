import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:borogayo/screens/project_form_screen.dart';
import 'package:borogayo/screens/widgets/entry_dialog.dart';
import 'package:borogayo/theme.dart';

/// The project form doesn't touch the database until saving,
/// so it can be tested without sqflite.
void main() {
  Future<void> pumpForm(WidgetTester tester) async {
    // Screens read the app palette (ThemeExtension), so use the real theme.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const ProjectFormScreen(name: '2026 봄 이사'),
      ),
    );
  }

  /// Chip labels start with an emoji, so match partially.
  Finder chip(String name) => find.ancestor(
    of: find.textContaining(name),
    matching: find.byType(InputChip),
  );

  Future<void> openRoomTab(WidgetTester tester) async {
    await tester.tap(find.textContaining('방 기준'));
    await tester.pumpAndSettle();
  }

  testWidgets('building criteria are prefilled', (tester) async {
    await pumpForm(tester);

    expect(chip('교통'), findsOneWidget);
    expect(chip('주차 가능'), findsOneWidget);
  });

  testWidgets('binary criteria show their type on the chip', (tester) async {
    await pumpForm(tester);

    expect(find.textContaining('엘리베이터 · 여부형'), findsOneWidget);
  });

  testWidgets('room criteria are on a separate tab', (tester) async {
    await pumpForm(tester);

    // Room criteria stay hidden while the building tab is open.
    expect(chip('채광'), findsNothing);

    await openRoomTab(tester);

    expect(chip('채광'), findsOneWidget);
    expect(chip('수압'), findsOneWidget);
    expect(chip('교통'), findsNothing);
  });

  testWidgets('tab labels include the criterion count', (tester) async {
    await pumpForm(tester);

    expect(find.text('건물 기준 5'), findsOneWidget);
    expect(find.text('방 기준 7'), findsOneWidget);
  });

  testWidgets('unneeded criteria can be removed', (tester) async {
    await pumpForm(tester);
    expect(chip('교통'), findsOneWidget);

    await tester.tap(
      find.descendant(of: chip('교통'), matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();

    expect(chip('교통'), findsNothing);
    expect(find.text('건물 기준 4'), findsOneWidget);
  });

  testWidgets('cannot create a project without criteria', (tester) async {
    await pumpForm(tester);

    FilledButton createButton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, '만들기'));

    expect(createButton().onPressed, isNotNull);

    for (final name in ['교통', '주변 편의시설', '건물 관리 상태', '주차 가능', '엘리베이터']) {
      await tester.tap(
        find.descendant(of: chip(name), matching: find.byIcon(Icons.close)),
      );
      await tester.pumpAndSettle();
    }
    await openRoomTab(tester);
    for (final name in ['채광', '소음', '수압', '곰팡이', '방 크기', '가격', '풀옵션']) {
      await tester.tap(
        find.descendant(of: chip(name), matching: find.byIcon(Icons.close)),
      );
      await tester.pumpAndSettle();
    }

    expect(createButton().onPressed, isNull);
  });

  testWidgets('adding a criterion asks for its type', (tester) async {
    await pumpForm(tester);

    final addButton = find.byIcon(Icons.add).first;
    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '기준 직접 추가').first,
      '옥상',
    );
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    // The type is asked only after a name is entered, not shown next to the field.
    expect(find.textContaining('‘옥상’'), findsOneWidget);
    expect(find.text('점수형'), findsOneWidget);
    expect(find.text('여부형'), findsOneWidget);
  });

  group('EntryDialog', () {
    Future<void> pumpDialog(
      WidgetTester tester, {
      required Future<String?> Function(String) nameCheck,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(
            body: EntryDialog(
              title: '새 목록',
              nameHint: '예: 2026 봄 이사',
              nameCheck: nameCheck,
            ),
          ),
        ),
      );
    }

    testWidgets('an empty name shows a hint and keeps the dialog open', (
      tester,
    ) async {
      await pumpDialog(tester, nameCheck: (_) async => null);

      await tester.tap(find.widgetWithText(FilledButton, '추가'));
      await tester.pumpAndSettle();

      expect(find.text('이름을 입력해주세요.'), findsOneWidget);
    });

    testWidgets('a duplicate name is rejected in place', (tester) async {
      await pumpDialog(tester, nameCheck: (_) async => '같은 이름의 목록이 이미 있어요.');

      await tester.enterText(find.byType(TextField), '2026 봄 이사');
      await tester.tap(find.widgetWithText(FilledButton, '추가'));
      await tester.pumpAndSettle();

      expect(find.text('같은 이름의 목록이 이미 있어요.'), findsOneWidget);
    });
  });
}
