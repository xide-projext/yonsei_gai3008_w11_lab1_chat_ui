/// 실제 HTTP 요청 없이도 동일한 오류 처리 흐름을 연습한다.
enum ChatError {
  unauthorized('401', '인증에 실패했어요. 설정을 확인한 뒤 다시 시도해 주세요.'),
  rateLimited('429', '요청이 너무 많아요. 잠시 후 다시 시도해 주세요.'),
  server('500', '응답 처리 중 문제가 발생했어요. 다시 시도해 주세요.'),
  timeout('timeout', '응답 시간이 초과되었어요. 다시 시도해 주세요.');

  const ChatError(this.code, this.message);
  final String code;
  final String message;
}

enum ReplyStatus { loading, success, error }

class ChatReply {
  ChatReply(this.prompt, this.simulatedError);

  final String prompt;
  final ChatError? simulatedError;
  ReplyStatus status = ReplyStatus.loading;
  ChatError? error;
  String text = '';
  int automaticRetries = 0;
}
