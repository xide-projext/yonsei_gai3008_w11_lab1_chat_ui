import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lab1_chat_ui/services/mock_chat_service.dart';

void main() {
  late MockChatService service;

  setUp(() => service = MockChatService(random: Random(7)));

  test('같은 뜻의 질문과 대소문자, 공백을 인식한다', () {
    for (final question in ['Flutter가 뭐야?', 'Flutter 설명해 줘', 'Flutter란?', '  FLUTTER  란？']) {
      expect(service.reply(question), contains('Flutter'));
    }
  });

  test('모든 학습 주제에서 질문 유형별 답변을 제공한다', () {
    for (final topic in ['Flutter', 'Dart', '위젯', '애니메이션', 'API', '수업']) {
      final responses = [
        service.reply('$topic 설명해 줘'),
        service.reply('$topic 예시를 보여줘'),
        service.reply('$topic 어떻게 사용해?'),
        service.reply('$topic 왜 필요해?'),
      ];
      expect(responses.toSet(), hasLength(4));
      for (final response in responses) {
        expect(response, isNot(contains('이해하지 못했어요')));
        expect(response, isNot(contains('구체적으로 설명해')));
      }
    }
  });

  test('최근 주제의 후속 질문과 주제 변경을 처리한다', () {
    service.reply('Flutter가 뭐야?');
    expect(service.reply('예시를 보여줘'), contains('Flutter'));
    service.reply('Dart 설명해 줘');
    expect(service.reply('예시를 보여줘'), contains('Dart'));
    expect(service.reply('더 자세히 설명해 줘'), contains('Dart'));
  });

  test('준비된 답변을 바꾸며 직전 답변을 반복하지 않는다', () {
    var previous = service.reply('Flutter란?');
    for (var i = 0; i < 10; i++) {
      final current = service.reply('Flutter란?');
      expect(current, isNot(previous));
      previous = current;
    }
  });

  test('기억이 없거나 모르는 질문에는 재질문한다', () {
    expect(service.reply('예시를 보여줘'), anyOf(contains('어떤 주제'), contains('구체적으로')));
    for (final input in ['', '우주선 설계도', 'this is a ship', 'Flutter 출시일?']) {
      expect(service.reply(input), anyOf(contains('어떤 주제'), contains('구체적으로')));
    }
    service.reply('Flutter란?');
    expect(service.reply('피자 예시 보여줘'), anyOf(contains('어떤 주제'), contains('구체적으로')));
    service.reply('Flutter란?');
    service.reply('오늘 날씨는?');
    expect(service.reply('예시를 보여줘'), anyOf(contains('어떤 주제'), contains('구체적으로')));
  });

  test('여러 주제나 확인할 수 없는 정보는 추측하지 않는다', () {
    expect(service.reply('Flutter와 Dart 차이는?'), contains('어떤 주제'));
    expect(service.reply('수업 시험날짜 알려줘'), contains('확인할 수 없어요'));
    expect(service.reply('Flutter latest version?'), contains('확인할 수 없어요'));
  });

  test('영어와 중국어의 간단한 질문을 인식한다', () {
    for (final greeting in ['안녕하세요', 'Hello!', '你好！']) {
      expect(service.reply(greeting), anyOf(contains('안녕하세요'), contains('반가워요')));
    }
    expect(service.reply('What is Flutter?'), contains('Flutter'));
    expect(service.reply('show me an example'), contains('Flutter'));
    expect(service.reply('Dart是什么？'), contains('Dart'));
    expect(service.reply('举个例子'), contains('Dart'));
    expect(service.reply('动画是什么？'), anyOf(contains('애니메이션'), contains('타이핑')));
    expect(service.reply('How to use widgets?'), contains('위젯'));
  });

  test('일상 주제와 추천 의도 및 후속 질문을 지원한다', () {
    for (final topic in ['일상', '공부', '음식', '여행']) {
      expect(service.reply('$topic 추천해 줘'), isNot(contains('이해하지 못했어요')));
      expect(service.reply('예시를 보여줘'), isNot(contains('이해하지 못했어요')));
    }
  });

  test('대화 기억은 서비스 인스턴스 사이에 공유되지 않는다', () {
    service.reply('Flutter란?');
    expect(MockChatService().reply('예시를 보여줘'), anyOf(contains('어떤 주제'), contains('구체적으로')));
  });
}
