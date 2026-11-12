import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab1_chat_ui/main.dart';

void main() {
  testWidgets('앱이 뜨고 가짜 대화가 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    // 제목
    expect(find.text('AI Chat — 실습 1'), findsOneWidget);

    // 할 일 1이 끝났다면 목록이 그려진다
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('오늘 뭐 배워?'), findsOneWidget);

    // 할 일 3 — 입력창과 전송 버튼
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('보내기'), findsOneWidget);
  });

  testWidgets('보내면 내 말풍선 → 타이핑 점 → AI 답변이 차례로 붙는다',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    await tester.enterText(find.byType(TextField), '안녕');
    await tester.tap(find.byTooltip('보내기'));
    await tester.pump();

    // 1) 내 메시지가 즉시 붙는다
    expect(find.text('안녕'), findsOneWidget);

    // 2) 응답 전에는 전송 버튼이 잠긴다(중복 전송 방지)
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNull);

    // 3) 2초 뒤 타이핑 말풍선이 사라지고 AI 답변이 붙는다
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('실제 응답은 다음 실습에서'), findsOneWidget);
  });
}
