import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:borogayo/screens/project_form_screen.dart';
import 'package:borogayo/theme.dart';

/// 목록 만들기 화면은 저장 전까지 DB를 건드리지 않으므로
/// sqflite 없이 그대로 테스트할 수 있다.
void main() {
  Future<void> pumpForm(WidgetTester tester) async {
    // 화면이 앱 팔레트(ThemeExtension)를 읽으므로 실제 테마로 띄운다.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const ProjectFormScreen(),
      ),
    );
  }

  testWidgets('건물 기준이 미리 채워져 있다', (tester) async {
    await pumpForm(tester);

    expect(find.text('교통'), findsOneWidget);
    // 있음/없음 기준은 칩에 그 사실이 함께 표시된다.
    expect(find.textContaining('주차 가능'), findsOneWidget);
  });

  testWidgets('방 기준도 건물 기준과 따로 채워져 있다', (tester) async {
    await pumpForm(tester);

    // 방 기준 섹션은 건물 기준 아래에 있어 스크롤해야 보인다.
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('채광'), findsOneWidget);
    expect(find.text('수압'), findsOneWidget);
  });

  testWidgets('이름을 넣기 전에는 만들 수 없다', (tester) async {
    await pumpForm(tester);

    FilledButton createButton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, '만들기'));

    expect(createButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, '2026 봄 이사');
    await tester.pump();

    expect(createButton().onPressed, isNotNull);
  });

  testWidgets('필요 없는 기준은 지울 수 있다', (tester) async {
    await pumpForm(tester);
    expect(find.text('교통'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, '교통'),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('교통'), findsNothing);
  });
}
