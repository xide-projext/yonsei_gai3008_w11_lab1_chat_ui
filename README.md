# AI 챗봇 + 애니메이션 — 완성본 (GAI3008-01 · 11주차)

> AI가 답하는 동안, 움직이게 하자.
> 보내기 · 기다리기 · 도착 · 실패를 **상태**로 나누고, 그 상태를 **움직임**으로 보여 준다.

## 실행

```bash
flutter pub get

# ① 서버 없이 (가짜 AI) — 상태·애니메이션 확인용
flutter run -d chrome --dart-define=MOCK=true

# ② 프록시 연결 — 먼저 w12/ai 프록시를 켠다
#    cd w12/ai && MOCK=1 node server.js   (또는 .env에 키를 넣고 node server.js)
flutter run -d chrome
```

- 앱은 `http://localhost:8787/api/chat`만 안다. **API 키는 앱에 없다.**
- Android 에뮬레이터는 자동으로 `http://10.0.2.2:8787`을 쓴다.
- 다른 주소: `--dart-define=AI_BASE_URL=http://192.168.0.10:8787`

### MOCK 모드에서 오류 시험하기

| 입력 | 결과 |
|---|---|
| `/401` | "키/권한을 확인해 주세요" |
| `/429` | "잠시 후 다시 시도해 주세요" |
| `/500` | "응답을 받지 못했습니다" |
| `/timeout` | "응답이 너무 늦어요. 네트워크를 확인해 주세요" |
| `/slow` | 약 3.6초 뒤 답 (긴 대기 확인) |

실패 명령은 **다시 시도**를 누르면 성공한다. 이렇게 재시도가 실제로 동작하는지 확인할 수 있다.

## 상태 기계

```
idle ──보내기──▶ sending ──250ms──▶ typing ──200──▶ done
                    │                  │
                    └──────실패────────┴──▶ error ──다시 시도──▶ sending
```

| 상태 | 화면 | 코드 |
|---|---|---|
| idle | 빈 상태 문구 · 입력 대기 | `ChatStatus.idle` |
| sending | 내 말풍선 삽입 · 전송 버튼 잠금 | `ChatStatus.sending` |
| typing | 점 3개 (0.2초 간격 스태거) | `ChatStatus.typing` |
| done | 답 말풍선 250ms 삽입 · 맨 아래로 스크롤 | `ChatStatus.done` |
| error | 오류 말풍선 + 다시 시도 (SnackBar 아님) | `ChatStatus.error` |

앱바 아래 한 줄에 지금 상태가 늘 보인다(닐슨 1번: 시스템 상태의 가시성).

## 움직임 규칙

| 순간 | 애니메이션 | 시간 |
|---|---|---|
| 응답 대기 | 목록 맨 아래 "답 대기" 칸의 `TypingDots` | 오르기 200ms + 내리기 200ms · 간격 200ms · 최소 400ms 표시 |
| 답 도착 | 점 칸이 **같은 자리에서** 답 말풍선으로 바뀜 (`AnimatedSize` + `AnimatedSwitcher`) | 250ms |
| 내 메시지 | `AnimatedList.insertItem` (Size + Fade) | 250ms |
| 오류 줄 · 앱바 상태 | `AnimatedSwitcher` (왼쪽 정렬) | 200ms |
| 새 메시지 | `ScrollController.animateTo(0)` | 200ms |

- **한 번에 하나만 움직인다.** 위를 보고 있었다면 먼저 맨 아래로 스크롤한 뒤 삽입한다. 내 말풍선 삽입이 끝난 뒤(250ms) 점 칸이 들어오고, 답이 오면 그 칸이 제자리에서 답으로 자라므로 목록이 튀지 않는다.
- 점이 한 번 보이면 **최소 400ms** 유지한다(빠른 응답에서 깜빡임 방지). done("답이 도착했어요")은 1.5초 뒤 idle로 돌아간다.
- **Reduce Motion**(`MediaQuery.disableAnimations`)이 켜져 있으면 모든 시간이 0이 된다. 점은 멈춘 채 "답을 작성하는 중" 문구로 바뀌어 정보는 그대로 남는다(WCAG 2.3.3 · 2.2.2).
- 시간 상수는 `Motion.insert` · `Motion.change` 한 곳에만 둔다. 팀원 모두 같은 값을 쓴다.

## 오류 처리

| 응답 | 화면 | 동작 |
|---|---|---|
| 200 | 말풍선 + 스크롤 | — |
| 401/403 | 키/권한을 확인해 주세요 | 재시도 버튼 |
| 429 | 잠시 후 다시 시도해 주세요 | **자동 백오프 1s → 2s** 후에도 실패하면 표시 |
| 5xx | 응답을 받지 못했습니다 | 재시도 버튼 |
| timeout (30s) | 응답이 너무 늦어요… | 재시도 버튼 |
| 네트워크 | 네트워크를 확인해 주세요 | 재시도 버튼 |

다시 시도하면 오류 말풍선을 거두고 **마지막 질문을 다시** 보낸다. 내 말풍선은 다시 추가하지 않는다.

## 구조

```
lib/
  main.dart                 앱 · 테마(라이트/다크)
  models/chat_message.dart  Role · ChatMessage(isError)
  models/chat_state.dart    ChatStatus(5상태) · ChatState(불변, copyWith)
  services/ai_client.dart   AiClient · ProxyAiClient(:8787) · MockAiClient · AiException
  pages/chat_page.dart      상태 기계 · AnimatedList · 스크롤 · 입력창
  widgets/bubble.dart       말풍선 3종 (사용자 · AI · 오류)
  widgets/typing_dots.dart  점 3개 · Reduce Motion
assets/fonts/               Noto Sans KR (SIL OFL) — 웹에서 한글 □ 방지
test/
  widget_test.dart          빈 상태 · 4상태 흐름 · 연타 방지 · 오류→재시도 · Reduce Motion
  ai_client_test.dart       200 · 429 백오프 · 401 · timeout · 응답 파싱
docs/w11.md                 포트폴리오 5칸
```

## 확인

```bash
flutter analyze && flutter test
```

### 체크리스트 (3.8)

- [x] 메시지를 보내면 점 3개가 움직인다
- [x] 답이 부드럽게 삽입된다 (250ms)
- [x] 오류에서 재시도가 동작한다
- [x] 키보드가 입력창을 가리지 않는다 (`resizeToAvoidBottomInset` · `SafeArea` · Android `adjustResize`)
- [x] Reduce Motion에서 즉시 표시된다
- [ ] 1분 구술 녹음 · 커밋 2 · PR 1 ← 직접

---

ⓒ 2026 Baryon Labs · 연세대학교 GAI3008-01 응용모바일프로그래밍 교육자료
