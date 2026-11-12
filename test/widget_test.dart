import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab1_chat_ui/main.dart';

void main() {
  /// ListView 안에 그려진 말풍선(Text) 목록
  Finder bubbles() => find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Text),
      );

  testWidgets('앱이 뜨고 가짜 대화가 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    // 제목
    expect(find.text('AI Chat — 실습 1'), findsOneWidget);

    // 할 일 1이 끝났다면 목록이 그려진다
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('오늘 뭐 배워?'), findsOneWidget);

    // 할 일 3 — 입력창과 전송 버튼이 있다
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  testWidgets('메시지를 보내면 사용자 말풍선으로 추가되고 입력창이 비워진다',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());
    expect(bubbles(), findsNWidgets(4));

    await tester.enterText(find.byType(TextField), '안녕하세요');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    // 목록에 한 개 추가된다
    expect(bubbles(), findsNWidgets(5));
    expect(find.text('안녕하세요'), findsOneWidget);

    // 입력창은 비워진다
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '');

    // 사용자 메시지이므로 오른쪽 정렬이다
    final align = tester.widget<Align>(
      find.ancestor(of: find.text('안녕하세요'), matching: find.byType(Align)).first,
    );
    expect(align.alignment, Alignment.centerRight);
  });

  testWidgets('빈 메시지(공백만)는 전송되지 않는다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    // 말풍선 개수가 그대로 4개다
    expect(bubbles(), findsNWidgets(4));
  });
}
