import 'dart:math';

/// 네트워크나 생성형 AI를 사용하지 않는 세션 단위 규칙 기반 챗봇.
class MockChatService {
  MockChatService({Random? random}) : _random = random ?? Random();

  final Random _random;
  String? _recentTopic;
  final Map<String, int> _lastAnswers = {};

  String reply(String message) {
    final text = message.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final compact = text.replaceAll(' ', '');
    if (text.isEmpty) {
      _recentTopic = null;
      return _clarify();
    }

    final topics = _keywords.entries
        .where((entry) => entry.value.any((keyword) =>
            RegExp(r'^[a-z]+$').hasMatch(keyword)
                ? RegExp('\\b$keyword\\b').hasMatch(text)
                : compact.contains(keyword)))
        .map((entry) => entry.key)
        .toList();
    if (topics.length > 1) {
      _recentTopic = null;
      return '여러 주제가 함께 나왔네요. ${topics.join(', ')} 중 어떤 주제를 먼저 설명할까요?';
    }

    if (RegExp(r'^(안녕(?:하세요|하십니까)?|반가워(?:요)?|hello|hi|hey|你好|您好)[!！?.。~\s]*$')
        .hasMatch(text)) {
      return _choose('greeting', [
        '안녕하세요! Flutter, Dart, 위젯이나 애니메이션 중 무엇이 궁금하세요?',
        '반가워요! 채팅 UI 실습을 함께 살펴볼까요? 궁금한 주제를 알려 주세요.',
        '안녕하세요! 저는 로컬 규칙 기반 챗봇이에요. 수업이나 API에 대해 질문해 보세요.',
      ]);
    }

    final intent = _intent(compact, text);
    final topic = topics.isNotEmpty
        ? topics.single
        : intent != null && _isFollowUp(compact, text) ? _recentTopic : null;
    if (topic == null) {
      _recentTopic = null;
      return _clarify();
    }

    // 알려진 주제라도 지원 범위를 벗어난 요청에는 내용을 지어내지 않는다.
    if (_containsAny(compact, ['날씨', '주가', '최신버전', '시험날짜', '시험범위', '교수님이름']) ||
        _containsAny(text, ['weather', 'stock price', 'latest version', '天气', '考试日期'])) {
      _recentTopic = null;
      return '그 정보는 제가 가진 실습 규칙으로 확인할 수 없어요. 개념 설명이나 간단한 예시를 질문해 주시겠어요?';
    }
    final isBareTopic = _keywords[topic]!.any((keyword) =>
        compact.replaceAll(RegExp(r'[?？!.。！]'), '') == keyword);
    if (intent == null && !isBareTopic) {
      _recentTopic = null;
      return _clarify();
    }
    _recentTopic = topic;
    final kind = intent ?? 'definition';
    final answers = _answers[topic]![kind]!;
    return _choose('$topic/$kind', answers);
  }

  String? _intent(String compact, String text) {
    if (_containsAny(compact, ['예시', '예제', '보여줘', '보여주세요', '코드', '例子', '示例', '举例']) ||
        RegExp(r'\b(example|examples|sample|code)\b').hasMatch(text)) {
      return 'example';
    }
    if (_containsAny(compact, ['어떻게', '방법', '만들', '사용법', '怎么', '如何']) ||
        RegExp(r'\bhow\b').hasMatch(text)) {
      return 'how';
    }
    if (_containsAny(compact, ['왜', '이유', '为什么']) ||
        RegExp(r'\bwhy\b').hasMatch(text)) {
      return 'why';
    }
    if (_containsAny(compact, ['추천', '고민', '힘들', '지쳐', '뭐', '무엇', '설명', '란', '알려', '자세히', '더말해', '是什么', '介绍', '解释']) ||
        RegExp(r'\b(recommend|what|explain|describe|more)\b').hasMatch(text)) {
      return 'definition';
    }
    return null;
  }

  // 주제 없는 후속 질문은 제한된 형태만 인정한다. 다른 대상의 질문에
  // 이전 주제를 억지로 적용하지 않는다 (예: “피자 예시 보여줘”).
  bool _isFollowUp(String compact, String text) {
    return RegExp(
      r'^(?:(?:그거|그것|이거|그럼)?(?:예시|예제|코드)(?:를)?(?:보여줘|보여주세요|알려줘|알려주세요)?|(?:더)?(?:자세히)?(?:설명해줘|설명해주세요|알려줘|알려주세요)|왜(?:필요해|필요해요)?|어떻게(?:사용해|사용해요)?|举个例子|举例|示例|详细解释|为什么|怎么用)[?？!.。！]*$',
    ).hasMatch(compact) || RegExp(
      r'^(?:(?:show me |give me )?(?:an? )?(?:example|examples|sample|code)|(?:explain|tell me) more|why|how)[?!.]*$',
    ).hasMatch(text);
  }

  bool _containsAny(String text, List<String> words) => words.any(text.contains);

  String _clarify() => _choose('clarify', [
    '질문을 정확히 이해하지 못했어요. 개발, 일상, 공부, 음식, 여행 중 어떤 주제인가요?',
    '조금 더 구체적으로 설명해 주시겠어요? 예를 들어 “Flutter가 뭐야?” 또는 “위젯 예시를 보여줘”라고 질문할 수 있어요.',
  ]);

  String _choose(String key, List<String> answers) {
    final previous = _lastAnswers[key];
    final candidates = List.generate(answers.length, (i) => i)
        .where((i) => i != previous).toList();
    final selected = candidates[_random.nextInt(candidates.length)];
    _lastAnswers[key] = selected;
    return answers[selected];
  }

  static const _keywords = {
    'Flutter': ['flutter', '플러터'],
    'Dart': ['dart', '다트'],
    '위젯': ['widget', 'widgets', '위젯', '组件', '控件'],
    '애니메이션': ['animation', 'animations', '애니메이션', '타이핑', 'typing', '动画'],
    'API': ['api', '에이피아이', '接口'],
    '일상': ['일상', '하루', '기분', '스트레스', 'daily', '心情'],
    '공부': ['공부', '학습', '집중', 'study', '学习'],
    '음식': ['음식', '메뉴', '점심', '저녁', '요리', 'food', '吃'],
    '여행': ['여행', '휴가', '관광', 'travel', '旅行'],
    '수업': ['수업', '실습', '강의', 'class', 'lesson', '课程', '上课', '오늘뭐배워'],
  };

  static const _answers = {
    '일상': {
      'definition': ['하루가 바빴나요? 잠깐 쉬면서 지금 기분을 정리해 보세요. 어떤 일이 있었나요?', '일상에서 작은 즐거움을 찾아보면 어때요? 산책이나 좋아하는 음악 중 무엇이 좋으세요?'],
      'example': ['일상 기록 예시예요: 오늘 좋았던 일 하나와 내일 하고 싶은 일 하나를 적어 보세요.', '잠깐의 휴식으로 창밖 보기, 가벼운 스트레칭, 음악 듣기 등을 시도할 수 있어요.'],
      'how': ['일상을 정리하려면 오늘 해야 할 일을 세 개만 적고, 가장 작은 일부터 시작해 보세요.', '기분을 정리하고 싶다면 지금 느끼는 감정을 한 문장으로 적어 보세요. 어떤 기분인가요?'],
      'why': ['일상에서 쉬는 시간은 다음 활동을 준비하는 데 도움이 될 수 있어요.', '작은 일상 습관은 하루를 정리하는 기준이 되어 줄 수 있어요.'],
    },
    '공부': {
      'definition': ['공부가 막힐 때는 목표를 작게 나눠 보세요. 어떤 과목이나 부분이 어렵나요?', '공부 계획은 할 수 있는 분량부터 잡는 게 좋아요. 오늘 끝내고 싶은 내용이 있나요?'],
      'example': ['공부 계획 예시: 개념 20분 읽기 → 책을 덮고 5분 설명하기 → 틀린 부분 확인하기.', '학습 예시로 쉬운 문제 세 개를 풀고, 틀린 이유를 한 줄씩 적어 보세요.'],
      'how': ['공부에 집중하려면 알림을 끄고 25분 공부 뒤 5분 쉬는 방법부터 시험해 보세요.', '학습한 내용을 자기 말로 설명하고, 기억나지 않는 부분만 다시 확인해 보세요.'],
      'why': ['공부 중 직접 떠올리는 연습은 이해하지 못한 부분을 찾는 데 도움이 돼요.', '공부를 여러 날에 나누면 한 번에 몰아서 할 때보다 부담을 줄일 수 있어요.'],
    },
    '음식': {
      'definition': ['음식 메뉴를 고르고 있나요? 한식, 면, 샐러드 중 무엇이 당기세요? 못 먹는 재료도 알려 주세요.', '가벼운 음식이라면 샌드위치, 따뜻한 한 끼라면 비빔밥은 어때요? 취향을 알려 주세요.'],
      'example': ['음식 예시로 비빔밥, 잔치국수, 샌드위치가 있어요. 원하는 조리 시간이나 재료가 있나요?', '간단한 메뉴 예시로 채소 볶음밥이나 토스트를 생각해 볼 수 있어요.'],
      'how': ['요리는 사용할 수 있는 재료와 시간을 먼저 정하면 고르기 쉬워요. 어떤 재료가 있나요?', '음식 선택이 어렵다면 따뜻한 음식인지, 가벼운 음식인지부터 정해 보세요.'],
      'why': ['음식 취향과 먹지 못하는 재료를 먼저 확인하면 알맞은 메뉴를 좁힐 수 있어요.', '메뉴를 미리 정하면 장보기와 조리 시간을 계획하기 편해요.'],
    },
    '여행': {
      'definition': ['여행을 계획 중인가요? 국내인지 해외인지, 며칠 정도인지 알려 주시면 준비 방향을 함께 정해 볼게요.', '여행은 휴식, 음식, 관광 중 우선순위를 정하면 계획하기 쉬워요. 어떤 여행을 원하세요?'],
      'example': ['여행 일정 예시: 오전에는 한 지역 산책, 오후에는 가까운 명소 한 곳, 저녁에는 충분한 휴식을 넣어 보세요.', '짧은 여행 예시로 근교 당일치기나 한 도시에서 이틀 머물기를 생각해 볼 수 있어요.'],
      'how': ['여행 계획은 기간과 예산을 정하고 이동 시간을 확인하는 순서로 시작해 보세요. 실제 운임은 별도로 확인해야 해요.', '여행 짐은 신분증, 충전기, 필요한 옷을 기본으로 준비하고 목적지 날씨는 따로 확인해 주세요.'],
      'why': ['여행 일정을 여유롭게 잡으면 이동 중 지연에도 대응하기 좋아요.', '여행에서 관심사를 먼저 정하면 명소를 너무 많이 넣지 않고 즐길 수 있어요.'],
    },
    'Flutter': {
      'definition': [
        'Flutter는 하나의 코드로 모바일과 웹 등의 UI를 만드는 프레임워크예요. 화면은 위젯을 조합해서 구성해요.',
        'Flutter는 Dart로 화면을 개발하는 도구예요. 지금 채팅 앱도 Flutter 위젯을 조합해 만들었어요.',
      ],
      'example': [
        "Flutter의 간단한 화면 예시예요: Scaffold(body: Center(child: Text('안녕하세요!'))).",
        "Flutter에서는 Row(children: [Icon(Icons.chat), Text('채팅')])처럼 위젯을 조합할 수 있어요.",
      ],
      'how': [
        'Flutter 화면은 작은 위젯부터 조합해 보세요. Text로 글자를 표시하고 Row나 Column으로 배치한 뒤 Scaffold에 넣으면 돼요.',
        'Flutter 프로젝트에서 build 메서드가 반환하는 위젯을 바꾸고 hot reload로 확인해 보세요. 이 앱에서는 말풍선부터 수정해 볼 수 있어요.',
      ],
      'why': [
        'Flutter는 여러 플랫폼에서 UI 코드를 공유할 수 있어요. hot reload로 화면 변경을 빠르게 확인하기도 좋아요.',
        'Flutter는 위젯을 조합해 화면을 만들기 때문에 채팅 목록과 입력창처럼 UI를 나눠 연습하기 좋아요.',
      ],
    },
    'Dart': {
      'definition': [
        'Dart는 이 앱의 로직과 화면 코드를 작성하는 프로그래밍 언어예요. 타입, 클래스, 비동기 처리를 지원해요.',
        'Dart는 변수와 함수, 클래스를 사용해 프로그램을 만드는 언어예요. 이 프로젝트의 .dart 파일에 사용되고 있어요.',
      ],
      'example': [
        "Dart 변수 예시예요: final message = '안녕'; print(message);",
        'Dart 함수 예시예요: int add(int a, int b) => a + b; 이렇게 반환 타입과 매개변수 타입을 적을 수 있어요.',
      ],
      'how': [
        'Dart는 final로 값을 선언하고 함수로 동작을 나누며 연습해 보세요. 먼저 메시지 문자열을 다루는 작은 함수를 만들어 보세요.',
        'Dart에서 여러 메시지를 관리하려면 List를 쓰고, 메시지의 속성을 묶으려면 클래스를 만들 수 있어요.',
      ],
      'why': [
        'Dart의 타입 검사는 잘못된 값 사용을 미리 찾는 데 도움을 줘요. null safety도 null 관련 오류를 줄여 줘요.',
        'Dart의 Future와 async/await는 시간이 걸리는 작업을 표현하기 좋아요. 이 앱은 네트워크 없이 Timer로 대기만 흉내 내요.',
      ],
    },
    '위젯': {
      'definition': [
        '위젯은 화면을 구성하는 기본 단위예요. Text, Row, Column 같은 위젯을 조합해 UI를 만들어요.',
        '위젯은 화면의 모양이나 배치를 설명해요. 상태가 바뀌는 화면에는 StatefulWidget을 사용할 수 있어요.',
      ],
      'example': [
        "위젯 예시로 Text('안녕하세요')는 글자를, Icon(Icons.send)는 전송 아이콘을 보여 줘요.",
        "Column(children: [Text('제목'), Text('내용')])은 두 Text 위젯을 세로로 배치하는 예시예요.",
      ],
      'how': [
        '위젯을 작게 나누고 build에서 조합해 보세요. 가로 배치는 Row, 세로 배치는 Column을 사용할 수 있어요.',
        '상태가 필요한 위젯에서는 setState로 변경을 알릴 수 있어요. 이 앱은 메시지 추가 시 목록을 다시 그려요.',
      ],
      'why': [
        '위젯을 나누면 같은 말풍선 모양을 여러 메시지에 재사용할 수 있고 코드도 읽기 쉬워져요.',
        '위젯으로 배치와 표시 역할을 나누면 화면을 수정하고 테스트하기 편해요.',
      ],
    },
    '애니메이션': {
      'definition': [
        '애니메이션은 시간에 따라 위치나 색 같은 값을 바꾸는 표현이에요. TypingDots는 세 점의 위치를 바꿔요.',
        '타이핑 애니메이션은 응답을 기다리고 있다는 시각적 표시예요. 이 앱에서는 세 점이 차례로 움직여요.',
      ],
      'example': [
        '애니메이션 예시로 AnimatedOpacity(opacity: visible ? 1 : 0, duration: Duration(milliseconds: 300), child: Text("안녕"))를 사용할 수 있어요.',
        'TypingDots는 AnimationController 값을 Transform.translate의 세로 위치에 적용해 점이 움직이게 해요.',
      ],
      'how': [
        '간단한 애니메이션은 AnimatedContainer로 시작해 보세요. 반복 동작은 AnimationController를 쓰고 dispose에서 정리해요.',
        'TypingDots처럼 애니메이션을 반복하려면 AnimationController.repeat()를 사용하고 AnimatedBuilder에서 위치를 계산할 수 있어요.',
      ],
      'why': [
        '타이핑 점은 기다리는 동안 앱이 멈추지 않았음을 알려 줘요. 이 앱은 약 1.5초 뒤 로컬 응답을 표시해요.',
        '애니메이션은 상태 변화를 눈에 보이게 전달해요. 움직임 줄이기 설정이 켜지면 이 앱의 점은 정지해요.',
      ],
    },
    'API': {
      'definition': [
        'API는 프로그램끼리 기능이나 데이터를 주고받기 위한 약속이에요. 이 앱에서는 외부 API를 호출하지 않아요.',
        'API는 다른 기능을 정해진 방식으로 사용하는 인터페이스예요. 지금 응답은 모두 앱 안의 규칙으로 선택해요.',
      ],
      'example': [
        'API 예시로 날씨 서비스에 도시를 요청하고 기온 데이터를 받는 흐름이 있어요. 이 앱은 그런 요청을 보내지 않아요.',
        '채팅 API라면 메시지를 보내고 응답 텍스트를 받는 형태일 수 있어요. 여기서는 로컬 reply 함수가 그 역할을 흉내 내요.',
      ],
      'how': [
        'API를 사용할 때는 요청과 응답 형식, 오류 처리를 확인해요. 현재 실습에서는 연결 대신 로컬 서비스의 reply를 호출해요.',
        'API 연동 전에는 UI와 응답 로직을 분리해 두면 좋아요. 이 앱의 MockChatService는 네트워크 없이 동작해요.',
      ],
      'why': [
        'API는 다른 시스템의 기능을 재사용하게 해 줘요. 지금은 비용이나 인증 없이 연습하도록 로컬 응답만 사용해요.',
        'API와 UI를 분리하면 서버가 없어도 화면을 테스트할 수 있어요. 이 프로젝트는 실제 API가 필요하지 않아요.',
      ],
    },
    '수업': {
      'definition': [
        '이번 수업 실습은 채팅 UI를 만드는 연습이에요. 말풍선, 입력창, 빈 상태와 타이핑 표시를 살펴볼 수 있어요.',
        '이 실습에서는 메시지 목록과 전송 흐름을 배워요. 응답은 실제 AI가 아니라 준비된 로컬 규칙으로 만들어요.',
      ],
      'example': [
        '수업 실습 예시로 빈 메시지 전송을 막고, 전송 후 입력창이 비워지는지 확인해 보세요.',
        '수업에서 “Flutter가 뭐야?” 다음 “예시를 보여줘”를 보내면 주제를 기억하는 흐름을 확인할 수 있어요.',
      ],
      'how': [
        '수업 실습은 메시지를 보내고 타이핑 점과 응답을 확인한 뒤, 위젯 테스트를 실행하는 순서로 진행해 보세요.',
        '실습할 때는 말풍선 배치, 공백 전송 방지, 빈 상태, 자동 스크롤을 하나씩 확인해 보세요.',
      ],
      'why': [
        '이 수업 실습은 네트워크 없이 UI와 상태 변화를 먼저 이해하는 데 목적이 있어요.',
        '실습용 로컬 응답을 쓰면 API 키나 서버 없이도 전송부터 응답까지의 흐름을 반복해서 연습할 수 있어요.',
      ],
    },
  };
}
