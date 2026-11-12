import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/chat_state.dart';
import '../services/ai_client.dart';
import '../widgets/bubble.dart';
import '../widgets/typing_dots.dart';

/// 애니메이션 시간 — 팀 전체가 같은 값을 쓴다 (2.1 "같은 애니메이션 시간").
abstract final class Motion {
  /// 말풍선 삽입 · 점 → 답으로 바뀌기.
  /// 0.1초(즉각)보다 길고 1초(새 대기)보다 짧은 실용값 (1.13).
  static const insert = Duration(milliseconds: 250);

  /// 상태 전환(AnimatedSwitcher) · 스크롤.
  static const change = Duration(milliseconds: 200);

  /// 점 3개가 한 번 보이면 최소 이만큼은 보인다 — 깜빡임 방지.
  static const minDots = Duration(milliseconds: 400);

  /// done("답이 도착했어요")을 보여 준 뒤 idle로 돌아가기까지.
  static const doneHold = Duration(milliseconds: 1500);
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.client});

  /// 테스트에서 가짜 AI를 넣을 수 있게 열어 둔다.
  final AiClient? client;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final AiClient _ai = widget.client ?? AiClient.fromEnvironment();

  final _listKey = GlobalKey<AnimatedListState>();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  ChatState _state = const ChatState();

  /// 재시도할 마지막 질문.
  String? _lastQuestion;

  /// 말풍선 id 발급기.
  int _nextId = 1;
  int _newId() => _nextId++;

  /// 목록 맨 아래의 "답 대기" 칸(점 3개) id. null이면 칸이 없다.
  /// 답이 오면 이 id 그대로 답 말풍선이 되어, 같은 자리에서 크기만 바뀐다.
  int? _slotId;

  /// sending → typing 으로 넘어가는 타이머.
  Timer? _typingTimer;

  /// 점 3개 최소 표시 시간 — 끝나야 답을 넣는다.
  Timer? _minDotsTimer;
  Completer<void>? _minDots;

  /// done → idle 타이머.
  Timer? _idleTimer;

  /// 긴 답의 첫 줄로 스크롤하는 타이머.
  Timer? _revealTimer;

  @override
  void dispose() {
    _revealTimer?.cancel();
    _typingTimer?.cancel();
    _minDotsTimer?.cancel();
    _idleTimer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    if (widget.client == null) _ai.close();
    super.dispose();
  }

  // ───────────────────────────── Reduce Motion ─────────────────────────────

  /// 시스템 "동작 줄이기"가 켜져 있으면 움직임만 끄고 결과는 즉시 보여 준다.
  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  Duration _d(Duration d) => _reduceMotion ? Duration.zero : d;

  // ───────────────────────────── 목록 조작 ─────────────────────────────
  //
  // _state.messages는 시간 순서(오래된 것 → 최신).
  // AnimatedList는 reverse: true라서 화면 index 0 = 맨 아래 = 최신.
  // "답 대기" 칸이 있으면 그 칸이 index 0이고, 메시지는 한 칸씩 위로 밀린다.

  int get _slotCount => _slotId == null ? 0 : 1;

  /// 새 메시지를 맨 아래에 삽입한다. setState 안에서 부른다.
  void _append(ChatMessage message) {
    _state = _state.copyWith(messages: [..._state.messages, message]);
    _listKey.currentState?.insertItem(0, duration: _d(Motion.insert));
  }

  /// 맨 아래(최신) 메시지를 애니메이션과 함께 지운다. setState 안에서 부른다.
  void _removeLast() {
    final removed = _state.messages.last;
    _state = _state.copyWith(
      messages: _state.messages.sublist(0, _state.messages.length - 1),
    );
    _listKey.currentState?.removeItem(
      0,
      // 사라지는 동안에도 화면에 보이던 모습 그대로(다시 시도 버튼 포함) 그린다.
      // 버튼을 빼면 첫 프레임에 버튼 높이만큼 툭 줄어든다.
      (context, animation) => _animated(
        animation,
        IgnorePointer(child: Bubble(message: removed, onRetry: () {})),
      ),
      duration: _d(Motion.change),
    );
  }

  Widget _animated(Animation<double> animation, Widget child) {
    // drive(CurveTween)은 따로 dispose할 객체를 만들지 않는다.
    final curved = animation.drive(CurveTween(curve: Curves.easeOut));
    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: curved, child: child),
    );
  }

  /// 맨 아래로 스크롤하고 끝날 때까지 기다린다 (1.12).
  /// 스크롤이 끝난 뒤에 삽입해야 두 움직임이 겹치지 않는다 — "한 번에 하나".
  Future<void> _scrollToBottom() async {
    if (!_scroll.hasClients || _scroll.offset <= 0) return;
    final d = _d(Motion.change);
    if (d == Duration.zero) {
      _scroll.jumpTo(0);
    } else {
      await _scroll.animateTo(0, duration: d, curve: Curves.easeOut);
    }
  }

  // ───────────────────────────── 상태 기계 ─────────────────────────────

  /// idle/done/error → sending → typing → done | error
  Future<void> _send({String? retryText}) async {
    if (_state.busy) return; // 연타해도 한 번만 전송
    final text = (retryText ?? _controller.text).trim();
    if (text.isEmpty) return;

    // 이번 질문 직전까지의 대화(오류 말풍선 제외)를 맥락으로 보낸다.
    final history = _state.messages.where((m) => !m.isError).toList();
    if (retryText != null &&
        history.isNotEmpty &&
        history.last.isUser &&
        history.last.text == text) {
      history.removeLast();
    }

    // ① sending — 입력 잠금. 요청은 바로 보내고, 화면은 순서대로 움직인다.
    _idleTimer?.cancel();
    _lastQuestion = text;
    setState(() {
      if (retryText == null) _controller.clear();
      _state = _state.copyWith(status: ChatStatus.sending, clearError: true);
    });
    final reply = _ai.chat(text, history: history).then<(String?, Object?)>(
          (answer) => (answer, null),
          onError: (Object e) => (null, e),
        );

    // 내 말풍선 — 위를 보고 있었다면 먼저 내려간 뒤 삽입한다.
    if (retryText == null) {
      await _scrollToBottom();
      if (!mounted) return;
      setState(() => _append(ChatMessage.user(text, id: _newId())));
    }

    // ② typing — 내 말풍선 삽입(250ms)이 끝난 뒤에 점 3개 칸을 넣는다.
    //    Reduce Motion이면 기다릴 애니메이션이 없으므로 바로.
    _typingTimer?.cancel();
    final wait = _d(Motion.insert);
    if (wait == Duration.zero) {
      _startTyping();
    } else {
      _typingTimer = Timer(wait, _startTyping);
    }

    final (answer, error) = await reply;
    _typingTimer?.cancel(); // 점이 나오기 전에 답이 왔으면 점은 생략
    if (!mounted) return;

    // ③ done / ④ error
    if (error == null) {
      await _deliver(
        (id) => ChatMessage.bot(answer!, id: id),
        ChatStatus.done,
      );
    } else {
      final message =
          (error is AiException ? error : AiException(null, '$error'))
              .userMessage;
      // 화면에 오류가 남는다 (SnackBar로 흘려보내지 않는다).
      await _deliver(
        (id) => ChatMessage.error(message, id: id),
        ChatStatus.error,
        error: message,
      );
    }
    if (mounted) _focus.requestFocus();
  }

  /// 목록 맨 아래에 "답 대기" 칸(점 3개)을 넣는다.
  Future<void> _startTyping() async {
    if (!mounted || !_state.sending) return;
    await _scrollToBottom();
    if (!mounted || !_state.sending) return;

    final done = Completer<void>();
    _minDots = done;
    _minDotsTimer?.cancel();
    _minDotsTimer = Timer(Motion.minDots, done.complete);

    setState(() {
      _slotId = _newId();
      _state = _state.copyWith(status: ChatStatus.typing);
      _listKey.currentState?.insertItem(0, duration: _d(Motion.insert));
    });
  }

  /// 답(또는 오류)을 화면에 넣는다.
  ///
  /// 점 3개 칸이 있으면 새 칸을 삽입하지 않고, 그 칸을 같은 id의 말풍선으로
  /// 바꾼다. 칸은 제자리에서 점 크기 → 답 크기로 자라므로 목록이 튀지 않는다.
  Future<void> _deliver(
    ChatMessage Function(int id) make,
    ChatStatus status, {
    String? error,
  }) async {
    // 점이 막 나왔다면 최소 표시 시간을 채운다 — 깜빡임 방지.
    if (_slotId != null) await _minDots?.future;
    if (!mounted) return;
    await _scrollToBottom();
    if (!mounted) return;

    final id = _slotId ?? _newId();
    setState(() {
      if (_slotId != null) {
        _slotId = null;
        _state = _state.copyWith(messages: [..._state.messages, make(id)]);
      } else {
        _append(make(id));
      }
      _state = _state.copyWith(
        status: status,
        error: error,
        clearError: error == null,
      );
    });

    // 긴 답은 끝이 아니라 첫 줄부터 보이게 (NN/g 7번 · 부록 C.3).
    // 점 → 답으로 자라는 애니메이션이 끝난 뒤에 움직인다 — 한 번에 하나.
    if (status == ChatStatus.done) {
      _revealTimer?.cancel();
      _revealTimer = Timer(_d(Motion.insert), () {
        WidgetsBinding.instance.addPostFrameCallback((_) => _revealStart(id));
        WidgetsBinding.instance.scheduleFrame();
      });
    }

    // ⑤ done은 잠시 보여 준 뒤 idle로 — "답이 도착했어요"가 계속 남지 않게.
    if (status == ChatStatus.done) {
      _idleTimer?.cancel();
      _idleTimer = Timer(Motion.doneHold, () {
        if (mounted && _state.status == ChatStatus.done) {
          setState(() => _state = _state.copyWith(status: ChatStatus.idle));
        }
      });
    }
  }

  /// 말풍선 [id]가 화면보다 길면, 그 말풍선의 첫 줄이 화면 위쪽에 오도록 스크롤한다.
  ///
  /// reverse 목록에서 offset 0(맨 아래)은 긴 답의 마지막 줄을 보여 준다.
  /// 그대로 두면 사용자는 끝부터 보고 위로 올려 읽어야 한다.
  void _revealStart(int id, [double? lastHeight]) {
    if (!mounted || !_scroll.hasClients) return;
    BuildContext? target;
    void visit(Element e) {
      if (target != null) return;
      final w = e.widget;
      if (w is Bubble && w.message.id == id) {
        target = e;
        return;
      }
      e.visitChildren(visit);
    }

    (_listKey.currentContext as Element?)?.visitChildren(visit);
    final box = target?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;

    // 점 → 답으로 자라는 중이면 다 자랄 때까지 한 프레임씩 기다린다.
    // (자라는 도중에 맞추면 남은 성장분만큼 첫 줄이 다시 위로 밀려난다.)
    final height = box.size.height;
    if (height != lastHeight) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _revealStart(id, height));
      WidgetsBinding.instance.scheduleFrame();
      return;
    }
    if (height <= _scroll.position.viewportDimension) return;

    // reverse(아래→위) 축에서 alignment 1.0 = 말풍선 윗변을 화면 윗변에 맞춤.
    Scrollable.ensureVisible(
      target!,
      alignment: 1.0,
      duration: _d(Motion.change),
      curve: Curves.easeOut,
    );
  }

  /// 오류 말풍선을 거두고 마지막 질문을 다시 보낸다.
  void _retry() {
    final question = _lastQuestion;
    if (_state.busy || question == null) return;
    if (_state.messages.isNotEmpty && _state.messages.last.isError) {
      setState(_removeLast);
    }
    _send(retryText: question);
  }

  // ───────────────────────────── 화면 ─────────────────────────────

  Widget _buildItem(BuildContext context, int index, Animation<double> animation) {
    final int id;
    final Widget content;
    if (_slotId != null && index == 0) {
      id = _slotId!;
      content = const TypingDots(key: ValueKey('dots'));
    } else {
      final messages = _state.messages;
      final message = messages[messages.length - 1 - (index - _slotCount)];
      // 재시도는 가장 최근 오류 말풍선에만 둔다.
      final canRetry = message.isError &&
          index == 0 &&
          _state.status == ChatStatus.error;
      id = message.id;
      content = Bubble(
        key: const ValueKey('bubble'),
        message: message,
        onRetry: canRetry ? _retry : null,
      );
    }
    // 같은 id면 같은 칸이다 — 점 → 답으로 바뀔 때 상태(크기)가 이어진다.
    return KeyedSubtree(
      key: ValueKey(id),
      child: _animated(
        animation,
        _Morph(duration: _d(Motion.insert), child: content),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      // 키보드가 올라오면 body가 줄어들어 입력창이 가려지지 않는다.
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Chat'),
            _StatusLabel(status: _state.status, duration: _d(Motion.change)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  AnimatedList(
                    key: _listKey,
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    initialItemCount: _state.messages.length,
                    itemBuilder: _buildItem,
                  ),
                  if (_state.messages.isEmpty)
                    const IgnorePointer(child: _EmptyState()),
                ],
              ),
            ),

            // 오류는 목록 안의 오류 말풍선(+ 다시 시도) 하나로만 보여 준다.
            // 입력창 위에 같은 문구를 또 띄우면 중복이고, 말풍선과 동시에
            // 움직여 "한 번에 하나" 원칙도 깨진다.
            _InputBar(
              controller: _controller,
              focusNode: _focus,
              busy: _state.busy,
              onSend: _send,
            ),
          ],
        ),
      ),
      backgroundColor: scheme.surface,
    );
  }
}

/// 한 칸의 내용이 바뀔 때(점 3개 → 답) 크기는 자라고, 내용은 겹쳐 바뀐다.
class _Morph extends StatelessWidget {
  const _Morph({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Reduce Motion(0ms)이면 감싸지 않는다. AnimatedSize는 0ms에서
    // "레이아웃 중 자기 자신을 다시 더럽힘" assert를 낸다.
    if (duration == Duration.zero) return child;
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        // 점은 빨리 빠지고 답이 들어온다.
        reverseDuration: duration ~/ 2,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topLeft,
          children: [...previous, ?current],
        ),
        child: child,
      ),
    );
  }
}

/// 빈 상태 — 무엇을 할 수 있는지 미리 알려 주는 피드포워드 (1.4).
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 40, color: scheme.primary),
            const SizedBox(height: 12),
            Text('무엇이든 물어보세요',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '보내면 점 3개가 움직이고, 답이 아래에 들어옵니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// 앱바의 상태 한 줄 — 닐슨 1번 "시스템 상태의 가시성" (1.5).
class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status, required this.duration});

  final ChatStatus status;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (String text, Color color) = switch (status) {
      ChatStatus.idle => ('입력 대기', scheme.onSurfaceVariant),
      ChatStatus.sending => ('보내는 중…', scheme.primary),
      ChatStatus.typing => ('AI가 답을 쓰는 중…', scheme.primary),
      ChatStatus.done => ('답이 도착했어요', scheme.onSurfaceVariant),
      ChatStatus.error => ('응답 실패 · 다시 시도할 수 있어요', scheme.error),
    };
    return AnimatedSwitcher(
      duration: duration,
      // 기본값(가운데 정렬)이면 길이가 다른 두 문구가 바뀌는 동안
      // 짧은 쪽이 가운데에 떴다가 끝나면 왼쪽으로 튄다. 왼쪽에 고정한다.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      child: Text(
        text,
        key: ValueKey(status),
        style: TextStyle(fontSize: 12, color: color),
      ),
    );
  }
}

/// 입력창 + 전송 버튼.
/// 비어 있거나 응답을 기다리는 동안 전송 버튼이 꺼진다 — 피드포워드.
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: busy ? '답을 기다리는 중…' : '메시지를 입력하세요',
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final canSend = !busy && value.text.trim().isNotEmpty;
              return IconButton.filled(
                tooltip: '보내기',
                onPressed: canSend ? onSend : null,
                icon: const Icon(Icons.send),
              );
            },
          ),
        ],
      ),
    );
  }
}
