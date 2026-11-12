import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab1_chat_ui/main.dart';

void main() {
  testWidgets('앱이 뜨고 가짜 대화가 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    expect(find.text('AI Chat — 실습 1'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('오늘 뭐 배워?'), findsOneWidget);

    // 입력창과 전송 버튼이 있다
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);

    // 대화가 있으니 빈 상태 문구는 없다
    expect(find.text('무엇이든 물어보세요'), findsNothing);
  });

  testWidgets('입력하고 보내면 목록에 추가되고 입력창이 비워진다', (tester) async {
    await tester.pumpWidget(const ChatLabApp());

    await tester.enterText(find.byType(TextField), '안녕하세요');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('안녕하세요'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('빈 문자열은 보내지 않는다', (tester) async {
    await tester.pumpWidget(const ChatLabApp());
    final before = find.byType(Text).evaluate().length;

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.byType(Text).evaluate().length, before);
  });
}
