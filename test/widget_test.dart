import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:borogayo/screens/project_form_screen.dart';
import 'package:borogayo/screens/widgets/entry_dialog.dart';
import 'package:borogayo/theme.dart';

/// 목록 만들기 화면은 저장 전까지 DB를 건드리지 않으므로
/// sqflite 없이 그대로 테스트할 수 있다.
void main() {
  Future<void> pumpForm(WidgetTester tester) async {
    // 화면이 앱 팔레트(ThemeExtension)를 읽으므로 실제 테마로 띄운다.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const ProjectFormScreen(name: '2026 봄 이사'),
      ),
    );
  }

  /// 칩 이름 앞에 이모지가 붙으므로 부분 일치로 찾는다.
  Finder chip(String name) => find.ancestor(
    of: find.textContaining(name),
    matching: find.byType(InputChip),
  );

  Future<void> openRoomTab(WidgetTester tester) async {
    await tester.tap(find.textContaining('방 기준'));
    await tester.pumpAndSettle();
  }

  testWidgets('건물 기준이 미리 채워져 있다', (tester) async {
    await pumpForm(tester);

    expect(chip('교통'), findsOneWidget);
    expect(chip('주차 가능'), findsOneWidget);
  });

  testWidgets('여부형 기준은 칩에 유형이 함께 표시된다', (tester) async {
    await pumpForm(tester);

    expect(find.textContaining('엘리베이터 · 여부형'), findsOneWidget);
  });

  testWidgets('방 기준은 다른 탭에 따로 있다', (tester) async {
    await pumpForm(tester);

    // 건물 탭에 있는 동안에는 방 기준이 보이지 않는다.
    expect(chip('채광'), findsNothing);

    await openRoomTab(tester);

    expect(chip('채광'), findsOneWidget);
    expect(chip('수압'), findsOneWidget);
    expect(chip('교통'), findsNothing);
  });

  testWidgets('탭 이름에 기준 개수가 함께 나온다', (tester) async {
    await pumpForm(tester);

    expect(find.text('건물 기준 5'), findsOneWidget);
    expect(find.text('방 기준 7'), findsOneWidget);
  });

  testWidgets('필요 없는 기준은 지울 수 있다', (tester) async {
    await pumpForm(tester);
    expect(chip('교통'), findsOneWidget);

    await tester.tap(
      find.descendant(of: chip('교통'), matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();

    expect(chip('교통'), findsNothing);
    expect(find.text('건물 기준 4'), findsOneWidget);
  });

  testWidgets('기준이 하나도 없으면 만들 수 없다', (tester) async {
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

  testWidgets('기준을 추가하면 유형부터 고르게 한다', (tester) async {
    await pumpForm(tester);

    final addButton = find.byIcon(Icons.add).first;
    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '기준 직접 추가').first, '옥상');
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    // 이름을 적은 뒤에야 유형을 묻는다. 입력줄 옆에 늘 띄워두지 않는다.
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

    testWidgets('이름이 비면 안내하고 닫히지 않는다', (tester) async {
      await pumpDialog(tester, nameCheck: (_) async => null);

      await tester.tap(find.widgetWithText(FilledButton, '추가'));
      await tester.pumpAndSettle();

      expect(find.text('이름을 입력해주세요.'), findsOneWidget);
    });

    testWidgets('이미 있는 이름이면 그 자리에서 막는다', (tester) async {
      await pumpDialog(tester, nameCheck: (_) async => '같은 이름의 목록이 이미 있어요.');

      await tester.enterText(find.byType(TextField), '2026 봄 이사');
      await tester.tap(find.widgetWithText(FilledButton, '추가'));
      await tester.pumpAndSettle();

      expect(find.text('같은 이름의 목록이 이미 있어요.'), findsOneWidget);
    });
  });
}
