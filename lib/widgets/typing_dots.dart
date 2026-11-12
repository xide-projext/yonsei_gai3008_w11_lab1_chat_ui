import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 점 3개가 0.2초 간격으로 차례로 떠오른다 (1.9 · 자료 5 스태거).
///
/// Reduce Motion(MediaQuery.disableAnimations)이면 움직임만 끄고
/// "답을 작성하는 중" 문구로 정보는 그대로 남긴다 (WCAG 2.3.3 · 2.2.2).
class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  /// 점 하나가 올라가는 시간. 내려오는 데도 같은 시간이 걸린다
  /// (점 하나가 움직이는 시간 = 200ms × 2 = 400ms).
  static const rise = Duration(milliseconds: 200);

  /// 점 사이 시작 간격 — 스태거. 앞 점이 꼭대기에 닿을 때 다음 점이 출발한다.
  static const stagger = Duration(milliseconds: 200);

  /// 한 주기. 마지막 점이 끝나는 800ms 뒤 200ms를 쉬고 다시 시작한다.
  static const period = Duration(milliseconds: 1000);

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  // 타임라인(ms): 점0 0–400 · 점1 200–600 · 점2 400–800 · 쉼 800–1000.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TypingDots.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 점 i의 세기 0..1 — 자기 차례 400ms 동안 200ms 올라갔다 200ms 내려온다(반원).
  /// 그 밖의 시간에는 0(바닥).
  double _intensity(int i) {
    final period = _controller.duration!.inMilliseconds;
    final start = TypingDots.stagger.inMilliseconds * i / period;
    final len = TypingDots.rise.inMilliseconds * 2 / period;
    final t = (_controller.value - start) / len;
    if (t < 0 || t > 1) return 0;
    return math.sin(t * math.pi);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduce = MediaQuery.disableAnimationsOf(context);

    Widget dot(double k) => Transform.translate(
          offset: Offset(0, -3 * k),
          child: Opacity(
            opacity: 0.35 + 0.65 * k,
            child: Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );

    final dots = reduce
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++) dot(1),
            const SizedBox(width: 8),
            Text('답을 작성하는 중',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ])
        : AnimatedBuilder(
            animation: _controller,
            builder: (_, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (var i = 0; i < 3; i++) dot(_intensity(i))],
            ),
          );

    return Semantics(
      label: 'AI가 답을 작성하고 있습니다',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: dots,
          ),
        ),
      ),
    );
  }
}
