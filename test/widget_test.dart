import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab1_chat_ui/main.dart';

void main() {
  testWidgets('앱이 뜨고 가짜 대화와 입력창이 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    // 제목
    expect(find.text('AI Chat — 실습 1'), findsOneWidget);

    // 할 일 1이 끝났다면 목록이 그려진다
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('오늘 뭐 배워?'), findsOneWidget);

    // 할 일 3이 끝났다면 입력창과 전송 버튼이 있다
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('전송'), findsOneWidget);

    // 입력한 메시지가 목록에 추가된다
    await tester.enterText(find.byType(TextField), '안녕하세요');
    await tester.tap(find.byTooltip('전송'));
    await tester.pump();

    expect(find.text('안녕하세요'), findsOneWidget);
  });
}
