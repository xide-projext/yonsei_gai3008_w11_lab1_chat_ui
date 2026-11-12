import 'package:flutter/material.dart';

import '../models/chat_message.dart';

/// 말풍선 3종 — 사용자(오른쪽) · AI(왼쪽) · 오류(왼쪽, 다시 시도).
class Bubble extends StatelessWidget {
  const Bubble({super.key, required this.message, this.onRetry});

  final ChatMessage message;

  /// 오류 말풍선 안의 "다시 시도". null이면 버튼을 그리지 않는다.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    final (Color bg, Color fg) = switch (message) {
      ChatMessage(isError: true) => (scheme.errorContainer, scheme.onErrorContainer),
      ChatMessage(role: Role.user) => (scheme.primaryContainer, scheme.onPrimaryContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurface),
    };

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isUser ? 16 : 4),
      bottomRight: Radius.circular(isUser ? 4 : 16),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.sizeOf(context).width * 0.78).clamp(0, 520),
        ),
        decoration: BoxDecoration(color: bg, borderRadius: radius),
        child: Semantics(
          label: message.isError
              ? '오류'
              : (isUser ? '내 메시지' : 'AI 답변'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.isError)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 18, color: fg),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(message.text,
                          style: TextStyle(color: fg, height: 1.4)),
                    ),
                  ],
                )
              else
                Text(message.text,
                    style: TextStyle(color: fg, height: 1.4)),
              if (message.isError && onRetry != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton.icon(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: fg,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('다시 시도'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
