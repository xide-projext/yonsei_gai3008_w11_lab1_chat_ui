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
}
