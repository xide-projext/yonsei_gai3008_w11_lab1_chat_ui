/// 말풍선 한 개의 주인.
enum Role { user, bot }

/// 대화 한 줄 (부록 A.2).
///
/// [isError]가 true면 AI 답 대신 "오류 말풍선"으로 그린다.
/// [id]는 목록에서 말풍선을 구별하는 값이다. "답 대기" 칸이 같은 id의
/// 답 말풍선으로 바뀌어야 크기가 끊기지 않고 이어진다.
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.isError = false,
    this.id = 0,
  });

  const ChatMessage.user(this.text, {this.id = 0})
      : role = Role.user,
        isError = false;

  const ChatMessage.bot(this.text, {this.id = 0})
      : role = Role.bot,
        isError = false;

  const ChatMessage.error(this.text, {this.id = 0})
      : role = Role.bot,
        isError = true;

  final Role role;
  final String text;
  final bool isError;
  final int id;

  bool get isUser => role == Role.user;
}
