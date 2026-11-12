import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab1_chat_ui/main.dart';

void main() {
  testWidgets('앱이 뜨고 빈 상태와 입력창이 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    // 제목
    expect(find.text('AI Chat — 실습 1'), findsOneWidget);

    // 목록이 그려지고, 비어 있으면 빈 상태 문구가 보인다
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('무엇이든 물어보세요'), findsOneWidget);

    // 할 일 3: 입력창과 전송 버튼이 있다
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  testWidgets('보내면 내 말풍선 → AI 답이 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    await tester.enterText(find.byType(TextField), '안녕');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    expect(find.text('안녕'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('"안녕"에 대한 AI의 답입니다.'), findsOneWidget);
  });

  testWidgets('500 오류 → 오류 말풍선이 남고, 다시 시도가 동작한다',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    // 🐞 메뉴에서 500 서버 오류를 고른다
    await tester.tap(find.byIcon(Icons.bug_report_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('500 서버 오류').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '안녕');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // 오류가 화면에 남는다
    expect(find.text('응답을 받지 못했습니다'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);

    // 정상으로 바꾸고 다시 시도하면 답이 온다
    await tester.tap(find.byIcon(Icons.bug_report_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('정상 응답').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('다시 시도'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('응답을 받지 못했습니다'), findsNothing);
    expect(find.text('"안녕"에 대한 AI의 답입니다.'), findsOneWidget);
  });
}
