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

  // ── TODO 4 — 빈 상태 ────────────────────────────────────────────
  testWidgets('메시지가 있으면 빈 상태 문구가 보이지 않는다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    expect(find.text('무엇이든 물어보세요'), findsNothing);
    expect(bubbles(), findsNWidgets(4));
  });

  testWidgets('메시지가 없으면 가운데에 빈 상태 문구가 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChatPage(initialMessages: [])),
    );

    // 목록(ListView)은 그대로 있고, 그 위에 안내 문구가 겹쳐 보인다
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('무엇이든 물어보세요'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('무엇이든 물어보세요'),
        matching: find.byType(Center),
      ),
      findsWidgets,
    );
    expect(bubbles(), findsNothing);
  });

  testWidgets('빈 상태에서 첫 메시지를 보내면 안내가 사라지고 말풍선이 생긴다',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChatPage(initialMessages: [])),
    );

    await tester.enterText(find.byType(TextField), '첫 메시지');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('무엇이든 물어보세요'), findsNothing);
    expect(bubbles(), findsNWidgets(1));
    expect(find.text('첫 메시지'), findsOneWidget);
  });

  // ── TODO 5 — 키보드가 입력창을 가리지 않게 ──────────────────────
  testWidgets('키보드가 올라와도 입력창이 키보드 위에 있고 목록도 보인다',
      (WidgetTester tester) async {
    // 휴대폰 크기(논리 픽셀 400 x 800)로 맞춘다
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ChatLabApp());

    // 키보드가 아래에서 300px 올라온 상황을 흉내낸다
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    final fieldRect = tester.getRect(find.byType(TextField));
    final buttonRect = tester.getRect(find.byIcon(Icons.send));

    // 입력창과 전송 버튼이 키보드 영역(화면 아래 300px)보다 위에 있다
    expect(fieldRect.bottom, lessThanOrEqualTo(800 - 300));
    expect(buttonRect.bottom, lessThanOrEqualTo(800 - 300));

    // 화면 높이가 줄어도 대화 목록은 그대로 그려진다
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('오늘 뭐 배워?'), findsOneWidget);

    // 레이아웃 overflow 같은 예외가 없다
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 화면 + 키보드에서도 레이아웃 오류가 없다',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ChatLabApp());

    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
  });
}
