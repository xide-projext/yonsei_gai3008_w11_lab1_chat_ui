import 'chat_message.dart';

/// 챗봇의 상태 기계 (1.1).
///
/// | 상태    | 화면                     |
/// |---------|--------------------------|
/// | idle    | 입력 대기 · 전송 가능    |
/// | sending | 전송 중 · 입력 잠금      |
/// | typing  | 응답 대기 · 점 3개       |
/// | done    | 말풍선 삽입 · 스크롤     |
/// | error   | 오류 말풍선 · 재시도     |
enum ChatStatus { idle, sending, typing, done, error }

/// 화면이 그려지는 근거가 되는 상태 묶음 (부록 A.2).
///
/// 불변 객체로 두고 [copyWith]로만 바꾼다 — 14주차 Provider로 옮길 때
/// 이 클래스를 그대로 가져가면 된다.
class ChatState {
  const ChatState({
    this.messages = const [],
    this.status = ChatStatus.idle,
    this.error,
  });

  final List<ChatMessage> messages;
  final ChatStatus status;

  /// 마지막 오류 문구. status == error일 때만 의미가 있다.
  final String? error;

  /// sending·typing — 응답을 기다리는 동안은 새 전송을 막는다.
  bool get busy =>
      status == ChatStatus.sending || status == ChatStatus.typing;

  bool get sending => status == ChatStatus.sending;
  bool get typing => status == ChatStatus.typing;

  ChatState copyWith({
    List<ChatMessage>? messages,
    ChatStatus? status,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
