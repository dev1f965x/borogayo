import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:borogayo/models/models.dart';
import 'package:borogayo/screens/widgets/criterion_editor.dart';
import 'package:borogayo/screens/widgets/name_dialog.dart';
import 'package:borogayo/screens/widgets/toast.dart';
import 'package:borogayo/theme.dart';

/// These widgets don't touch the database, so they run without sqflite.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    // Widgets read the app palette (ThemeExtension), so use the real theme.
    MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(body: child),
    ),
  );

  group('NameDialog', () {
    Widget dialog(NameCheck check) => NameDialog(
      title: '새 목록',
      hint: '2026 봄 이사',
      confirmLabel: '만들기',
      check: check,
    );

    testWidgets('an empty name shows a hint and keeps the dialog open', (
      tester,
    ) async {
      await pump(tester, dialog((_) async => null));

      await tester.tap(find.widgetWithText(FilledButton, '만들기'));
      await tester.pumpAndSettle();

      expect(find.text('이름을 입력해 주세요'), findsOneWidget);
    });

    testWidgets('a taken name is rejected in place', (tester) async {
      await pump(tester, dialog((_) async => '같은 이름의 목록이 있어요'));

      await tester.enterText(find.byType(TextField), '2026 봄 이사');
      await tester.tap(find.widgetWithText(FilledButton, '만들기'));
      await tester.pumpAndSettle();

      expect(find.text('같은 이름의 목록이 있어요'), findsOneWidget);
    });
  });

  group('CriterionComposer', () {
    final added = <CriterionDraft>[];

    Widget composer() => Padding(
      padding: const EdgeInsets.all(16),
      child: CriterionComposer(
        scope: CriterionScope.room,
        takenNames: const {'채광'},
        onAdd: added.add,
      ),
    );

    IconButton addButton(WidgetTester tester) =>
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add));

    testWidgets('add stays disabled until a name is typed', (tester) async {
      await pump(tester, composer());

      expect(addButton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '옥상');
      await tester.pump();

      expect(addButton(tester).onPressed, isNotNull);
    });

    testWidgets('a taken name is flagged while typing', (tester) async {
      await pump(tester, composer());

      await tester.enterText(find.byType(TextField), '채광');
      await tester.pump();

      expect(find.text('이미 있어요'), findsOneWidget);
      expect(addButton(tester).onPressed, isNull);
    });

    testWidgets('choosing a type adds the criterion', (tester) async {
      added.clear();
      await pump(tester, composer());

      await tester.enterText(find.byType(TextField), '옥상');
      await tester.pump();
      await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('‘옥상’ 평가 기준을 추가할게요'), findsOneWidget);

      await tester.tap(find.text('예·아니오'));
      await tester.pumpAndSettle();

      expect(added.single.name, '옥상');
      expect(added.single.type, CriterionType.binary);
      expect(added.single.scope, CriterionScope.room);
    });
  });

  group('Toasts', () {
    Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        navigatorObservers: [Toasts.instance.observer],
        builder: (context, child) => ToastHost(child: child!),
        home: Scaffold(
          floatingActionButton: MainActionButton(
            icon: Icons.add,
            label: '새 목록',
            onPressed: () {},
          ),
        ),
      ),
    );

    testWidgets('an undo toast sits left of the main button', (tester) async {
      await pumpApp(tester);
      await tester.pump();

      var undone = false;
      showUndo('이름을 바꿨어요', onUndo: () async => undone = true);
      await tester.pumpAndSettle();

      final toast = tester.getRect(
        find
            .ancestor(
              of: find.text('이름을 바꿨어요'),
              matching: find.byType(Material),
            )
            .first,
      );
      final button = tester.getRect(find.byType(FloatingActionButton));
      expect(toast.right, lessThan(button.left));
      expect(toast.bottom, moreOrLessEquals(button.bottom));

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(undone, isTrue);
      expect(find.text('이름을 바꿨어요'), findsNothing);
    });

    testWidgets('a short drag springs back, a long one dismisses', (
      tester,
    ) async {
      await pumpApp(tester);

      var closed = false;
      Toasts.instance.show('복사했어요', onClosed: (_) => closed = true);
      await tester.pumpAndSettle();

      await tester.drag(find.text('복사했어요'), const Offset(-40, 0));
      await tester.pumpAndSettle();
      expect(find.text('복사했어요'), findsOneWidget);
      expect(closed, isFalse);

      await tester.drag(find.text('복사했어요'), const Offset(-250, 0));
      await tester.pumpAndSettle();
      expect(find.text('복사했어요'), findsNothing);
      expect(closed, isTrue);
    });

    testWidgets('a toast leaves on its own', (tester) async {
      await pumpApp(tester);

      showToast('복사했어요');
      await tester.pumpAndSettle();
      expect(find.text('복사했어요'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('복사했어요'), findsNothing);
    });
  });
}
