# 맥 처음 세팅 도우미 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 터미널 한 줄 실행 후 macOS 네이티브 팝업만으로 앱 설치·기본 설정·복구 스크립트·리포트까지 해주는 단일 파일 셸 도구 + 안내 웹페이지.

**Architecture:** 단일 `setup.sh`(bash 3.2 호환, 의존성 0)에 데이터 블록(앱/설정 카탈로그) + osascript UI 레이어 + 설치/설정 엔진 + 리포트를 담는다. 자동 테스트는 GUI 없는 로직만 순수 bash 하니스로 검증하고, UI는 최종 수동 스모크로 검증한다. 배포는 GitHub 공개 리포 + GitHub Pages 안내 페이지.

**Tech Stack:** bash 3.2, osascript(AppleScript), Homebrew/mas/dockutil(런타임 설치), shellcheck(개발), 정적 HTML.

## Global Constraints

- 스펙: `docs/superpowers/specs/2026-07-19-mac-first-setup-design.md` — 모든 태스크에 적용.
- **bash 3.2 호환**: 연관배열·`mapfile`·`${var,,}` 금지. 셔뱅은 `#!/bin/bash`.
- **전역 `set -e` 금지** — 항목별 오류 처리. 파괴적 작업(삭제·덮어쓰기) 금지.
- 사용자 노출 문구는 전부 한국어. 다이얼로그 타이틀은 `맥 세팅 도우미` 고정.
- 카탈로그 데이터의 설명 필드에 **쉼표(,) 금지** (osascript 다중선택 결과 파싱 규칙).
- 환경변수 접두 `MFS_`: `MFS_SOURCED`(1=source만, main 미실행), `MFS_DRY_RUN`, `MFS_NO_UI`, `MFS_AUTO_PROFILE`, `MFS_AUTO_APPS`, `MFS_AUTO_SETTINGS`, `MFS_LOG_FILE`, `MFS_REPORT_FILE`, `MFS_BACKUP_DIR`.
- 모든 태스크 완료 시: `bash tests/run-tests.sh` 전체 통과 + `shellcheck setup.sh` 클린(불가피한 예외는 라인 지시어 + 사유 주석) 후 커밋.
- 커밋 메시지 끝: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`

---

### Task 1: 리포 골격 + setup.sh 뼈대 + 테스트 하니스

**Files:**
- Create: `setup.sh`, `tests/run-tests.sh`, `tests/helpers.sh`, `tests/test-01-core.sh`, `.gitignore`

**Interfaces:**
- Produces: `MFS_VERSION`, `log()`, `detect_macos_major()`, `macos_supported()`, source 가드(`MFS_SOURCED=1`이면 main 미실행), `main()`(빈 껍데기)

- [ ] **Step 1: 테스트 하니스 작성**

`tests/helpers.sh`:
```bash
#!/bin/bash
# 공용 어서션. 실패 시 즉시 exit 1 (개별 테스트 파일 단위 실패).
assert_eq() { # $1=expected $2=actual $3=label
  [ "$1" = "$2" ] && return 0
  echo "ASSERT FAIL: $3"; echo "  expected: [$1]"; echo "  actual:   [$2]"; exit 1
}
assert_contains() { # $1=needle $2=haystack $3=label
  case "$2" in *"$1"*) return 0 ;; esac
  echo "ASSERT FAIL: $3 (missing: $1)"; exit 1
}
assert_not_contains() { # $1=needle $2=haystack $3=label
  case "$2" in *"$1"*) echo "ASSERT FAIL: $3 (should not contain: $1)"; exit 1 ;; esac
  return 0
}
source_setup() { MFS_SOURCED=1 . "$(dirname "$0")/../setup.sh"; }
```

`tests/run-tests.sh`:
```bash
#!/bin/bash
# tests/ 안의 test-*.sh 전부 실행, 실패 집계. verify-*.sh(네트워크 필요)는 제외.
cd "$(dirname "$0")" || exit 1
fail=0
for t in test-*.sh; do
  echo "== $t"
  if bash "$t"; then echo "   OK"; else echo "   FAIL"; fail=$((fail + 1)); fi
done
if [ "$fail" -eq 0 ]; then echo "ALL PASS"; else echo "FAILURES: $fail"; exit 1; fi
```

`.gitignore`:
```
.DS_Store
```

- [ ] **Step 2: 실패하는 테스트 작성** — `tests/test-01-core.sh`:
```bash
#!/bin/bash
. "$(dirname "$0")/helpers.sh"
source_setup
assert_eq "0.1.0" "$MFS_VERSION" "버전 상수"
major=$(detect_macos_major)
case "$major" in ''|*[!0-9]*) echo "ASSERT FAIL: major가 숫자 아님: [$major]"; exit 1 ;; esac
# 이 개발 맥은 Sonoma(14) 이상이므로 supported여야 한다
macos_supported || { echo "ASSERT FAIL: macos_supported"; exit 1; }
# source 모드에서는 main이 실행되지 않아야 함 (log 파일 미생성으로 간접 확인)
tmp=$(mktemp -d)
MFS_SOURCED=1 MFS_LOG_FILE="$tmp/log.txt" bash -c '. "'"$(dirname "$0")"'/../setup.sh"'
[ ! -f "$tmp/log.txt" ] || { echo "ASSERT FAIL: source 모드에서 main 실행됨"; exit 1; }
echo "test-01 pass"
```

- [ ] **Step 3: 실패 확인** — Run: `bash tests/run-tests.sh` → Expected: FAIL (setup.sh 없음)

- [ ] **Step 4: setup.sh 뼈대 구현**
```bash
#!/bin/bash
# 맥 처음 세팅 도우미 — 맥 입문자용 앱 설치·기본 설정 자동화
# bash 3.2 호환 / 단일 파일 / 파괴적 작업 없음 / 재실행 안전
# 사용: bash -c "$(curl -fsSL <RAW_URL>)"   (URL은 Task 10에서 확정)

MFS_VERSION="0.1.0"
MFS_DRY_RUN="${MFS_DRY_RUN:-0}"
MFS_NO_UI="${MFS_NO_UI:-0}"
MFS_LOG_FILE="${MFS_LOG_FILE:-$HOME/맥세팅-로그.txt}"
MFS_REPORT_FILE="${MFS_REPORT_FILE:-$HOME/맥세팅-리포트.txt}"

log() { # 화면+로그파일 동시 기록
  printf '%s\n' "$*"
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" >>"$MFS_LOG_FILE" 2>/dev/null
}

detect_macos_major() { sw_vers -productVersion | cut -d. -f1; }

macos_supported() { # Sonoma(14) 이상
  local major; major=$(detect_macos_major)
  case "$major" in ''|*[!0-9]*) return 1 ;; esac
  [ "$major" -ge 14 ]
}

main() {
  log "맥 세팅 도우미 v${MFS_VERSION} 시작"
}

if [ "${MFS_SOURCED:-0}" != "1" ]; then
  main "$@"
fi
```

- [ ] **Step 5: 통과 확인** — Run: `bash tests/run-tests.sh` → Expected: `ALL PASS`. Run: `shellcheck setup.sh tests/*.sh` (shellcheck 없으면 `brew install shellcheck`) → Expected: 경고 0 (helpers의 SC2034류는 지시어 처리)

- [ ] **Step 6: Commit** — `git add -A && git commit -m "chore: setup.sh 뼈대 + 테스트 하니스"`

---

### Task 2: 앱 카탈로그 데이터 블록 + 파서

**Files:**
- Modify: `setup.sh` (뼈대 아래에 카탈로그 섹션 추가)
- Create: `tests/test-02-catalog.sh`

**Interfaces:**
- Consumes: Task 1의 로깅/가드
- Produces: `APP_CATALOG`(8필드 `id|카테고리|method|token|표시명|설명|profiles|appfile`), `catalog_lines()`, `catalog_line_by_id(id)`, `catalog_field(line,n)`, `catalog_default_ids_for_profile(profile)`, `catalog_all_ids()`. 프로필 id: `office|student|creator|dev`

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test-02-catalog.sh`:
```bash
#!/bin/bash
. "$(dirname "$0")/helpers.sh"
source_setup
line=$(catalog_line_by_id chrome)
assert_eq "google-chrome" "$(catalog_field "$line" 4)" "chrome cask 토큰"
assert_eq "Google Chrome.app" "$(catalog_field "$line" 8)" "chrome appfile"
ids=$(catalog_default_ids_for_profile office)
assert_contains "chrome" "$ids" "office 기본셋에 chrome"
assert_contains "kakaotalk" "$ids" "office 기본셋에 카카오톡"
assert_not_contains "vscode" "$ids" "office 기본셋에 vscode 없어야"
dev_ids=$(catalog_default_ids_for_profile dev)
assert_contains "vscode" "$dev_ids" "dev 기본셋에 vscode"
all=$(catalog_all_ids)
assert_contains "iina" "$all" "전체 목록에 iina"
echo "test-02 pass"
```

- [ ] **Step 2: 실패 확인** — Run: `bash tests/test-02-catalog.sh` → Expected: FAIL (함수 없음)

- [ ] **Step 3: 구현** — setup.sh에 추가 (초기 카탈로그는 아래 8종 — Task 8에서 리서치 문서 기준으로 확정·확장):
```bash
# ── 앱 카탈로그 ─────────────────────────────────────────────
# 형식: id|카테고리|method(cask/mas)|token|표시명|설명|profiles|appfile
# 규칙: 설명에 쉼표 금지(다중선택 파싱). profiles는 쉼표 구분.
APP_CATALOG='
chrome|브라우저|cask|google-chrome|Chrome|익숙한 웹 브라우저|office,student,creator,dev|Google Chrome.app
kakaotalk|메신저|cask|kakaotalk|카카오톡|PC에서도 카톡|office,student,creator,dev|KakaoTalk.app
notion|생산성|cask|notion|Notion|메모·문서·할일 관리|office,student|Notion.app
raycast|생산성|cask|raycast|Raycast|Spotlight보다 강력한 실행 도구|office,student,creator,dev|Raycast.app
rectangle|유틸리티|cask|rectangle|Rectangle|창을 단축키로 반반 배치|office,student,creator,dev|Rectangle.app
keka|유틸리티|cask|keka|Keka|압축·해제 만능 도구|office,student,creator,dev|Keka.app
iina|미디어|cask|iina|IINA|맥에서 가장 편한 동영상 플레이어|office,student,creator|IINA.app
vscode|개발|cask|visual-studio-code|VS Code|코드 편집기|dev|Visual Studio Code.app
'

catalog_lines() { # $1=카탈로그 내용 → 빈 줄·주석 제거
  printf '%s\n' "$1" | grep -v '^[[:space:]]*$' | grep -v '^#'
}
catalog_field() { printf '%s' "$1" | cut -d'|' -f"$2"; }
catalog_line_by_id() { # $1=id → 해당 레코드 한 줄
  catalog_lines "$APP_CATALOG" | while IFS='|' read -r id rest; do
    if [ "$id" = "$1" ]; then printf '%s|%s\n' "$id" "$rest"; fi
  done
}
catalog_all_ids() { catalog_lines "$APP_CATALOG" | cut -d'|' -f1; }
catalog_default_ids_for_profile() { # $1=프로필 id
  catalog_lines "$APP_CATALOG" | while IFS='|' read -r id _c _m _t _n _d profiles _a; do
    case ",$profiles," in *",$1,"*) printf '%s\n' "$id" ;; esac
  done
}
```

- [ ] **Step 4: 통과 확인** — `bash tests/run-tests.sh` → `ALL PASS`, `shellcheck setup.sh` 클린
- [ ] **Step 5: Commit** — `git commit -am "feat: 앱 카탈로그 데이터 블록 + 파서"`

---

### Task 3: osascript UI 레이어

**Files:**
- Modify: `setup.sh`
- Create: `tests/test-03-ui.sh`

**Interfaces:**
- Produces: `as_quote(s)`, `as_list_from_lines()`(stdin 줄들→`{"a","b"}`), `ui_info(msg)`, `ui_confirm(msg)`(0=계속/1=취소), `ui_choose_one(prompt, items개행)`(선택 문자열 출력/취소=rc1), `ui_choose_multi(prompt, items개행, defaults개행)`(선택들 개행 출력/취소=rc1), `ui_alert(msg)`. 모든 `ui_*`는 `MFS_NO_UI=1`이면 아무것도 묻지 않고 rc0(choose류는 빈 출력).

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test-03-ui.sh` (GUI 미실행 — 순수 함수만):
```bash
#!/bin/bash
. "$(dirname "$0")/helpers.sh"
source_setup
assert_eq 'a\"b\\c' "$(as_quote 'a"b\c')" "AppleScript 이스케이프"
out=$(printf '항목 A\n항목 "B"\n' | as_list_from_lines)
assert_eq '{"항목 A","항목 \"B\""}' "$out" "리스트 변환"
assert_eq '{}' "$(printf '' | as_list_from_lines)" "빈 리스트"
# MFS_NO_UI 우회 동작
MFS_NO_UI=1 ui_confirm "테스트" || { echo "ASSERT FAIL: NO_UI confirm"; exit 1; }
assert_eq "" "$(MFS_NO_UI=1 ui_choose_one "p" "a")" "NO_UI choose 빈 출력"
echo "test-03 pass"
```

- [ ] **Step 2: 실패 확인** — Run: `bash tests/test-03-ui.sh` → FAIL

- [ ] **Step 3: 구현** — setup.sh에 추가:
```bash
# ── UI 레이어 (osascript) ────────────────────────────────────
MFS_TITLE="맥 세팅 도우미"

as_quote() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

as_list_from_lines() { # stdin 줄들 → AppleScript 리스트 리터럴
  local out="" line
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    out="$out\"$(as_quote "$line")\","
  done
  printf '{%s}' "${out%,}"
}

ui_info() {
  [ "$MFS_NO_UI" = "1" ] && return 0
  osascript -e "display dialog \"$(as_quote "$1")\" with title \"$MFS_TITLE\" buttons {\"확인\"} default button 1 with icon note" >/dev/null 2>&1
  return 0
}
ui_alert() {
  [ "$MFS_NO_UI" = "1" ] && return 0
  osascript -e "display alert \"$MFS_TITLE\" message \"$(as_quote "$1")\" as warning" >/dev/null 2>&1
  return 0
}
ui_confirm() { # 0=계속 1=취소
  [ "$MFS_NO_UI" = "1" ] && return 0
  osascript -e "display dialog \"$(as_quote "$1")\" with title \"$MFS_TITLE\" buttons {\"취소\",\"계속\"} default button 2 with icon note" >/dev/null 2>&1
}
ui_choose_one() { # $1=프롬프트 $2=항목들(개행) → 선택 출력 / 취소=rc1
  [ "$MFS_NO_UI" = "1" ] && return 0
  local items res
  items=$(printf '%s\n' "$2" | as_list_from_lines)
  res=$(osascript -e "choose from list $items with title \"$MFS_TITLE\" with prompt \"$(as_quote "$1")\"" 2>/dev/null) || return 1
  [ "$res" = "false" ] && return 1
  printf '%s\n' "$res"
}
ui_choose_multi() { # $1=프롬프트 $2=항목들(개행) $3=기본선택(개행) → 선택들 개행 출력 / 취소=rc1
  [ "$MFS_NO_UI" = "1" ] && return 0
  local items defs res
  items=$(printf '%s\n' "$2" | as_list_from_lines)
  defs=$(printf '%s\n' "$3" | as_list_from_lines)
  res=$(osascript -e "choose from list $items with title \"$MFS_TITLE\" with prompt \"$(as_quote "$1")\" default items $defs with multiple selections allowed" 2>/dev/null) || return 1
  [ "$res" = "false" ] && return 1
  printf '%s\n' "$res" | sed 's/, /\
/g'   # 항목 라벨에 쉼표 금지 전제 (Global Constraints)
}
```

- [ ] **Step 4: 통과 확인** — `bash tests/run-tests.sh` → `ALL PASS`, shellcheck 클린
- [ ] **Step 5: Commit** — `git commit -am "feat: osascript UI 레이어"`

---

### Task 4: 선택 플로우 + 실행 플랜 + dry-run

**Files:**
- Modify: `setup.sh` (flow 함수들 + main 확장)
- Create: `tests/test-04-flow.sh`

**Interfaces:**
- Consumes: 카탈로그 파서(T2), UI 레이어(T3)
- Produces: 전역 `SELECTED_PROFILE`, `SELECTED_APPS`(공백 구분 id들), `SELECTED_SETTINGS`(공백 구분 id들 — 설정 카탈로그는 T6에서 확장, 지금은 빈 값 허용), `flow_welcome()`, `flow_pick_profile()`, `flow_pick_apps()`, `run_or_log(설명, 명령...)`(dry-run이면 `[dry-run] 설명`만 로그). `main()`은 welcome→profile→apps 순 호출. 자동화 훅: `MFS_AUTO_PROFILE`(프로필 id), `MFS_AUTO_APPS`(id 쉼표 구분)

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test-04-flow.sh`:
```bash
#!/bin/bash
. "$(dirname "$0")/helpers.sh"
tmp=$(mktemp -d)
out=$(MFS_DRY_RUN=1 MFS_NO_UI=1 MFS_AUTO_PROFILE=office MFS_AUTO_APPS="chrome,kakaotalk" \
      MFS_LOG_FILE="$tmp/log.txt" MFS_REPORT_FILE="$tmp/report.txt" bash "$(dirname "$0")/../setup.sh")
assert_contains "프로필: office" "$out" "프로필 로그"
assert_contains "선택한 앱: chrome kakaotalk" "$out" "앱 선택 로그"
# 존재하지 않는 id는 무시되고 경고
out2=$(MFS_DRY_RUN=1 MFS_NO_UI=1 MFS_AUTO_PROFILE=office MFS_AUTO_APPS="chrome,nope" \
       MFS_LOG_FILE="$tmp/log2.txt" MFS_REPORT_FILE="$tmp/r2.txt" bash "$(dirname "$0")/../setup.sh")
assert_contains "알 수 없는 앱 id 무시: nope" "$out2" "무효 id 경고"
echo "test-04 pass"
```

- [ ] **Step 2: 실패 확인** — Run: `bash tests/test-04-flow.sh` → FAIL

- [ ] **Step 3: 구현** — setup.sh에 추가하고 main 교체:
```bash
# ── 선택 플로우 ─────────────────────────────────────────────
SELECTED_PROFILE=""
SELECTED_APPS=""
SELECTED_SETTINGS=""

run_or_log() { # $1=설명, 이후=명령. dry-run이면 로그만.
  local desc="$1"; shift
  if [ "$MFS_DRY_RUN" = "1" ]; then log "[dry-run] $desc"; return 0; fi
  "$@"
}

profile_label_to_id() {
  case "$1" in
    "사무·일반용") echo office ;;
    "학생·문서작업") echo student ;;
    "크리에이터") echo creator ;;
    "개발자") echo dev ;;
    *) echo "" ;;
  esac
}

flow_welcome() {
  ui_confirm "맥 처음 세팅 도우미입니다.

앞으로 뜨는 창에서 고르기만 하면
· 필요한 앱 설치
· 편리한 기본 설정
을 자동으로 해드립니다.

삭제·덮어쓰기는 하지 않고 모든 변경은 복구 스크립트로 되돌릴 수 있습니다." || return 1
}

flow_pick_profile() {
  if [ -n "${MFS_AUTO_PROFILE:-}" ]; then SELECTED_PROFILE="$MFS_AUTO_PROFILE"; log "프로필: $SELECTED_PROFILE"; return 0; fi
  local pick
  pick=$(ui_choose_one "어떤 용도로 쓰시나요?" "사무·일반용
학생·문서작업
크리에이터
개발자") || return 1
  SELECTED_PROFILE=$(profile_label_to_id "$pick")
  [ -n "$SELECTED_PROFILE" ] || return 1
  log "프로필: $SELECTED_PROFILE"
}

app_label_for_id() { # "표시명 — 설명"
  local line; line=$(catalog_line_by_id "$1")
  printf '%s — %s\n' "$(catalog_field "$line" 5)" "$(catalog_field "$line" 6)"
}
app_id_for_label() { # 라벨의 표시명 부분으로 역매핑
  local name="${1%% — *}"
  catalog_lines "$APP_CATALOG" | while IFS='|' read -r id _c _m _t n _rest; do
    if [ "$n" = "$name" ]; then printf '%s\n' "$id"; fi
  done
}

flow_pick_apps() {
  if [ -n "${MFS_AUTO_APPS:-}" ]; then
    local raw id valid=""
    raw=$(printf '%s' "$MFS_AUTO_APPS" | tr ',' ' ')
    for id in $raw; do
      if [ -n "$(catalog_line_by_id "$id")" ]; then valid="$valid $id"; else log "알 수 없는 앱 id 무시: $id"; fi
    done
    SELECTED_APPS="${valid# }"
  else
    local items="" defaults="" id picks
    for id in $(catalog_all_ids); do items="$items$(app_label_for_id "$id")
"; done
    for id in $(catalog_default_ids_for_profile "$SELECTED_PROFILE"); do defaults="$defaults$(app_label_for_id "$id")
"; done
    picks=$(ui_choose_multi "설치할 앱을 고르세요 (추천 항목이 미리 선택되어 있어요)" "$items" "$defaults") || return 1
    SELECTED_APPS=$(printf '%s\n' "$picks" | while IFS= read -r l; do [ -n "$l" ] && app_id_for_label "$l"; done | tr '\n' ' ')
    SELECTED_APPS="${SELECTED_APPS% }"
  fi
  log "선택한 앱: $SELECTED_APPS"
}

main() {
  log "맥 세팅 도우미 v${MFS_VERSION} 시작"
  if ! macos_supported; then
    ui_alert "이 도구는 macOS Sonoma(14) 이상에서 동작합니다. 현재 버전에서는 일부 설정이 적용되지 않을 수 있습니다."
    log "경고: 미지원 macOS 버전 $(sw_vers -productVersion)"
  fi
  flow_welcome || { log "사용자가 취소했습니다"; return 0; }
  flow_pick_profile || { log "사용자가 취소했습니다"; return 0; }
  flow_pick_apps || { log "사용자가 취소했습니다"; return 0; }
}
```

- [ ] **Step 4: 통과 확인** — `bash tests/run-tests.sh` → `ALL PASS`, shellcheck 클린
- [ ] **Step 5: Commit** — `git commit -am "feat: 선택 플로우 + dry-run 훅"`

---

### Task 5: 설치 엔진 (CLT / Homebrew / cask / mas)

**Files:**
- Modify: `setup.sh`
- Create: `tests/test-05-install.sh`

**Interfaces:**
- Consumes: `run_or_log`, 카탈로그, `SELECTED_APPS`
- Produces: `warm_sudo()`, `ensure_clt()`, `ensure_homebrew()`, `install_one(id)`, `install_apps()`, 결과 누적 전역 `OK_ITEMS`/`FAILED_ITEMS`/`MANUAL_ITEMS`(개행 구분 문자열)과 `report_add_ok/fail/manual(항목)`. `main()`에 설치 단계 연결.

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test-05-install.sh` (brew를 PATH 스텁으로 대체, 네트워크·실설치 없음):
```bash
#!/bin/bash
. "$(dirname "$0")/helpers.sh"
source_setup
stub=$(mktemp -d); export BREW_LOG="$stub/calls.log"
cat >"$stub/brew" <<'EOF'
#!/bin/bash
echo "$*" >>"$BREW_LOG"
case "$1" in list) exit 1 ;; esac   # "미설치" 상태 시뮬레이션
exit 0
EOF
chmod +x "$stub/brew"; PATH="$stub:$PATH"
# 테스트용 가짜 카탈로그 (실제 /Applications와 충돌 없는 앱)
APP_CATALOG='fake|유틸리티|cask|fake-cask|페이크|테스트용|office|ZZZFake.app'
install_one fake
assert_contains "install --cask fake-cask" "$(cat "$BREW_LOG")" "cask 설치 호출"
assert_contains "fake" "$OK_ITEMS" "성공 목록 기록"
# 이미 설치된 경우(앱 존재) 스킵 — /Applications 대신 존재하는 디렉터리로 시뮬레이션
APP_CATALOG='fin|유틸리티|cask|fin-cask|파인더테스트|테스트용|office|.'
MFS_APPS_DIR="$stub" ; mkdir -p "$stub/."
: >"$BREW_LOG"
install_one fin
assert_not_contains "install --cask fin-cask" "$(cat "$BREW_LOG")" "설치됨 스킵"
# 실패 처리: brew가 실패해도 함수는 계속(rc0)이고 FAILED_ITEMS에 기록
cat >"$stub/brew" <<'EOF'
#!/bin/bash
case "$1" in list) exit 1 ;; install) exit 1 ;; esac
exit 0
EOF
APP_CATALOG='bad|유틸리티|cask|bad-cask|배드|테스트용|office|ZZZBad.app'
install_one bad
assert_contains "bad" "$FAILED_ITEMS" "실패 목록 기록"
echo "test-05 pass"
```

- [ ] **Step 2: 실패 확인** — Run: `bash tests/test-05-install.sh` → FAIL

- [ ] **Step 3: 구현** — setup.sh에 추가:
```bash
# ── 결과 누적 ───────────────────────────────────────────────
OK_ITEMS=""; FAILED_ITEMS=""; MANUAL_ITEMS=""
report_add_ok()     { OK_ITEMS="$OK_ITEMS$1
"; }
report_add_fail()   { FAILED_ITEMS="$FAILED_ITEMS$1
"; }
report_add_manual() { MANUAL_ITEMS="$MANUAL_ITEMS$1
"; }

# ── 설치 엔진 ───────────────────────────────────────────────
MFS_APPS_DIR="${MFS_APPS_DIR:-/Applications}"   # 테스트 오버라이드용

warm_sudo() {
  [ "$MFS_DRY_RUN" = "1" ] && return 0
  log "관리자 암호가 필요합니다. 입력해도 화면에 표시되지 않지만 정상 입력되고 있습니다."
  sudo -v || return 1
  # 진행 동안 sudo 타임스탬프 유지 (스크립트 종료 시 자동 소멸)
  ( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
}

ensure_clt() {
  if xcode-select -p >/dev/null 2>&1; then log "개발자 도구 확인됨"; return 0; fi
  if [ "$MFS_DRY_RUN" = "1" ]; then log "[dry-run] Xcode Command Line Tools 설치 필요"; return 0; fi
  ui_info "먼저 Apple 기본 개발자 도구(무료)를 설치합니다.
잠시 후 설치 창이 뜨면 [설치]를 눌러주세요. 몇 분 걸릴 수 있습니다."
  xcode-select --install >/dev/null 2>&1
  until xcode-select -p >/dev/null 2>&1; do sleep 10; done
  log "개발자 도구 설치 완료"
}

ensure_homebrew() {
  if command -v brew >/dev/null 2>&1; then log "Homebrew 확인됨"; return 0; fi
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; log "Homebrew 경로 연결됨"; return 0; fi
  if [ "$MFS_DRY_RUN" = "1" ]; then log "[dry-run] Homebrew 설치 필요"; return 0; fi
  ui_info "앱 설치 도구(Homebrew)를 설치합니다. 터미널에 진행 상황이 표시됩니다."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty || return 1
  eval "$(/opt/homebrew/bin/brew shellenv)"
  # 다음 터미널에서도 brew가 잡히도록 (중복 추가 방지)
  if ! grep -qs 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
    printf '\neval "$(/opt/homebrew/bin/brew shellenv)"\n' >>"$HOME/.zprofile"
  fi
  log "Homebrew 설치 완료"
}

install_one() { # $1=앱 id — 실패해도 rc0 (누적 기록으로 처리)
  local line name token method appfile
  line=$(catalog_line_by_id "$1"); [ -n "$line" ] || return 0
  method=$(catalog_field "$line" 3); token=$(catalog_field "$line" 4)
  name=$(catalog_field "$line" 5); appfile=$(catalog_field "$line" 8)
  if [ -n "$appfile" ] && [ -e "$MFS_APPS_DIR/$appfile" ]; then
    log "$name — 이미 설치되어 있어 건너뜁니다"; report_add_ok "$1"; return 0
  fi
  if [ "$MFS_DRY_RUN" = "1" ]; then log "[dry-run] $method 설치: $token ($name)"; report_add_ok "$1"; return 0; fi
  case "$method" in
    cask)
      if brew list --cask "$token" >/dev/null 2>&1; then
        log "$name — 이미 설치됨(스킵)"; report_add_ok "$1"; return 0
      fi
      log "$name 설치 중..."
      if brew install --cask "$token" >/dev/null 2>&1; then
        report_add_ok "$1"; log "$name 설치 완료"
      else
        report_add_fail "$1"; log "$name 설치 실패 — 리포트에 기록합니다"
      fi ;;
    mas)
      if ! command -v mas >/dev/null 2>&1; then brew install mas >/dev/null 2>&1; fi
      if mas install "$token" >/dev/null 2>&1; then
        report_add_ok "$1"; log "$name 설치 완료"
      else
        report_add_fail "$1"
        report_add_manual "$name — App Store에 로그인한 뒤 App Store에서 직접 설치해 주세요"
        log "$name 설치 실패(App Store 로그인 필요할 수 있음)"
      fi ;;
  esac
  return 0
}

install_apps() {
  [ -n "$SELECTED_APPS" ] || { log "선택한 앱이 없습니다"; return 0; }
  ensure_clt
  ensure_homebrew || { log "Homebrew 설치 실패 — 앱 설치를 건너뜁니다"; report_add_fail "homebrew"; return 0; }
  local id
  for id in $SELECTED_APPS; do install_one "$id"; done
}
```
`main()`의 `flow_pick_apps` 다음에 추가:
```bash
  warm_sudo || { ui_alert "관리자 암호 확인에 실패해 종료합니다."; return 1; }
  install_apps
```

- [ ] **Step 4: 통과 확인** — `bash tests/run-tests.sh` → `ALL PASS` (test-04도 여전히 통과해야 함 — dry-run 경로), shellcheck 클린
- [ ] **Step 5: Commit** — `git commit -am "feat: 설치 엔진(CLT/Homebrew/cask/mas)"`

---

### Task 6: 설정 엔진 + 백업/복구 스크립트

**Files:**
- Modify: `setup.sh`
- Create: `tests/test-06-settings.sh`

**Interfaces:**
- Consumes: `run_or_log`, UI, 결과 누적
- Produces: `SETTINGS_CATALOG`(4필드 `id|표시명|설명|profiles`), `settings_all_ids()`, `settings_line_by_id()`, `flow_pick_settings()`(훅 `MFS_AUTO_SETTINGS`), `backup_domain(domain [,-currentHost])`(도메인 전체 plist 백업 + 복구 스크립트에 import 라인 추가, 도메인당 1회), `ensure_backup_dir()`, `apply_settings()`, 각 `setting_apply_<id>()`. 백업 위치 `MFS_BACKUP_DIR`(기본 `$HOME/맥세팅-백업-<날짜시각>`), 복구 스크립트 `$MFS_BACKUP_DIR/복구.sh`.

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test-06-settings.sh`:
```bash
#!/bin/bash
. "$(dirname "$0")/helpers.sh"
source_setup
# 카탈로그 파서
assert_contains "tap_click" "$(settings_all_ids)" "설정 목록"
line=$(settings_line_by_id finder_ext)
assert_eq "파일 확장자 항상 표시" "$(printf '%s' "$line" | cut -d'|' -f2)" "설정 표시명"
# 백업: 실재 도메인(com.apple.finder)을 임시 백업 디렉터리로 export
tmp=$(mktemp -d)
MFS_BACKUP_DIR="$tmp/backup" 
export MFS_BACKUP_DIR
backup_domain com.apple.finder
[ -f "$tmp/backup/com.apple.finder.plist" ] || { echo "ASSERT FAIL: plist 백업 없음"; exit 1; }
assert_contains "defaults import com.apple.finder" "$(cat "$tmp/backup/복구.sh")" "복구 라인"
# 같은 도메인 재백업은 1회만 (라인 중복 없음)
backup_domain com.apple.finder
n=$(grep -c "defaults import com.apple.finder" "$tmp/backup/복구.sh")
assert_eq "1" "$n" "도메인당 백업 1회"
# dry-run 적용 경로: 실제 defaults 미변경, 로그만
out=$(MFS_DRY_RUN=1 MFS_NO_UI=1 MFS_AUTO_PROFILE=office MFS_AUTO_APPS="" \
      MFS_AUTO_SETTINGS="tap_click,finder_ext" MFS_LOG_FILE="$tmp/l.txt" \
      MFS_REPORT_FILE="$tmp/r.txt" MFS_BACKUP_DIR="$tmp/b2" bash "$(dirname "$0")/../setup.sh")
assert_contains "선택한 설정: tap_click finder_ext" "$out" "설정 선택 로그"
assert_contains "[dry-run] defaults write NSGlobalDomain AppleShowAllExtensions" "$out" "확장자 설정 dry-run"
echo "test-06 pass"
```

- [ ] **Step 2: 실패 확인** — Run: `bash tests/test-06-settings.sh` → FAIL

- [ ] **Step 3: 구현** — setup.sh에 추가 (설정 목록은 초기 8종 — Task 8에서 리서치 반영):
```bash
# ── 설정 카탈로그 ───────────────────────────────────────────
# 형식: id|표시명|설명|profiles   (설명에 쉼표 금지)
SETTINGS_CATALOG='
tap_click|트랙패드 탭 클릭|꾹 누르지 않고 살짝 대면 클릭|office,student,creator,dev
three_finger_drag|세 손가락 드래그|세 손가락으로 창을 끌어서 이동|office,student,creator,dev
key_repeat|키보드 반응 빠르게|길게 눌렀을 때 반복 입력이 빨라짐|office,student,creator,dev
finder_ext|파일 확장자 항상 표시|.jpg .pdf 등 파일 종류 구분이 쉬워짐|office,student,creator,dev
finder_bars|Finder 경로·상태 막대|지금 어느 폴더인지 항상 보임|office,student,creator,dev
screenshot_dir|스크린샷 전용 폴더|바탕화면이 어질러지지 않음|office,student,creator,dev
dock_tidy|Dock 정리|최근 앱 자동 표시 끄기|office,student,creator,dev
won_backtick|₩ 대신 백틱(`)|한글 자판에서도 백틱 입력(개발·마크다운용)|dev
'

settings_all_ids() { catalog_lines "$SETTINGS_CATALOG" | cut -d'|' -f1; }
settings_line_by_id() {
  catalog_lines "$SETTINGS_CATALOG" | while IFS='|' read -r id rest; do
    if [ "$id" = "$1" ]; then printf '%s|%s\n' "$id" "$rest"; fi
  done
}
settings_default_ids_for_profile() {
  catalog_lines "$SETTINGS_CATALOG" | while IFS='|' read -r id _n _d profiles; do
    case ",$profiles," in *",$1,"*) printf '%s\n' "$id" ;; esac
  done
}

# ── 백업/복구 ───────────────────────────────────────────────
MFS_BACKED_DOMAINS=""   # 공백 구분 (bash 3.2 — 연관배열 금지)

ensure_backup_dir() {
  if [ -z "${MFS_BACKUP_DIR:-}" ]; then MFS_BACKUP_DIR="$HOME/맥세팅-백업-$(date +%Y%m%d-%H%M%S)"; fi
  [ -d "$MFS_BACKUP_DIR" ] && return 0
  mkdir -p "$MFS_BACKUP_DIR"
  cat >"$MFS_BACKUP_DIR/복구.sh" <<'EOF'
#!/bin/bash
# 맥 세팅 도우미 복구 스크립트 — 실행하면 변경했던 설정을 원래대로 되돌립니다.
cd "$(dirname "$0")" || exit 1
EOF
  chmod +x "$MFS_BACKUP_DIR/복구.sh"
}

backup_domain() { # $1=도메인 [$2="-currentHost"] — 도메인당 1회 전체 백업
  case " $MFS_BACKED_DOMAINS " in *" $1 "*) return 0 ;; esac
  ensure_backup_dir
  if [ "$2" = "-currentHost" ]; then
    defaults -currentHost export "$1" "$MFS_BACKUP_DIR/$1.currentHost.plist" 2>/dev/null &&
      printf 'defaults -currentHost import %s "%s.currentHost.plist"\n' "$1" "$1" >>"$MFS_BACKUP_DIR/복구.sh"
  else
    defaults export "$1" "$MFS_BACKUP_DIR/$1.plist" 2>/dev/null &&
      printf 'defaults import %s "%s.plist"\n' "$1" "$1" >>"$MFS_BACKUP_DIR/복구.sh"
  fi
  MFS_BACKED_DOMAINS="$MFS_BACKED_DOMAINS $1"
}

set_default() { # $1=도메인 $2=키 이후=defaults write 인자들 — 백업 후 적용(또는 dry-run 로그)
  local domain="$1" key="$2"; shift 2
  if [ "$MFS_DRY_RUN" = "1" ]; then log "[dry-run] defaults write $domain $key $*"; return 0; fi
  backup_domain "$domain"
  defaults write "$domain" "$key" "$@"
}

# ── 개별 설정 적용 ──────────────────────────────────────────
setting_apply_tap_click() {
  set_default com.apple.AppleMultitouchTrackpad Clicking -bool true
  set_default com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
  if [ "$MFS_DRY_RUN" = "1" ]; then log "[dry-run] defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior 1"
  else backup_domain NSGlobalDomain -currentHost; defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1; fi
}
setting_apply_three_finger_drag() {
  set_default com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
  set_default com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
}
setting_apply_key_repeat() {
  set_default NSGlobalDomain KeyRepeat -int 2
  set_default NSGlobalDomain InitialKeyRepeat -int 15
}
setting_apply_finder_ext() { set_default NSGlobalDomain AppleShowAllExtensions -bool true; }
setting_apply_finder_bars() {
  set_default com.apple.finder ShowPathbar -bool true
  set_default com.apple.finder ShowStatusBar -bool true
}
setting_apply_screenshot_dir() {
  run_or_log "mkdir 스크린샷 폴더" mkdir -p "$HOME/Pictures/스크린샷"
  set_default com.apple.screencapture location "$HOME/Pictures/스크린샷"
}
setting_apply_dock_tidy() { set_default com.apple.dock show-recents -bool false; }
setting_apply_won_backtick() {
  if [ "$MFS_DRY_RUN" = "1" ]; then log "[dry-run] KeyBindings: ₩→백틱"; return 0; fi
  ensure_backup_dir
  mkdir -p "$HOME/Library/KeyBindings"
  local kb="$HOME/Library/KeyBindings/DefaultkeyBinding.dict"
  if [ -f "$kb" ]; then
    if grep -qs '₩' "$kb"; then log "₩→백틱 이미 설정됨(스킵)"; return 0; fi
    cp "$kb" "$MFS_BACKUP_DIR/DefaultkeyBinding.dict.bak"
    printf 'cp "DefaultkeyBinding.dict.bak" "%s"\n' "$kb" >>"$MFS_BACKUP_DIR/복구.sh"
    log "기존 KeyBindings 파일이 있어 건너뜁니다 — 리포트 참고"
    report_add_manual "₩→백틱: 기존 키바인딩 파일이 있어 자동 적용하지 않았습니다"
    return 0
  fi
  printf '{\n  "₩" = ("insertText:", "`");\n}\n' >"$kb"
  printf 'rm -f "%s"\n' "$kb" >>"$MFS_BACKUP_DIR/복구.sh"
}

flow_pick_settings() {
  if [ -n "${MFS_AUTO_SETTINGS+x}" ]; then
    SELECTED_SETTINGS=$(printf '%s' "$MFS_AUTO_SETTINGS" | tr ',' ' ')
  else
    local items="" defs="" id line picks
    for id in $(settings_all_ids); do
      line=$(settings_line_by_id "$id")
      items="$items$(printf '%s' "$line" | cut -d'|' -f2) — $(printf '%s' "$line" | cut -d'|' -f3)
"
    done
    for id in $(settings_default_ids_for_profile "$SELECTED_PROFILE"); do
      line=$(settings_line_by_id "$id")
      defs="$defs$(printf '%s' "$line" | cut -d'|' -f2) — $(printf '%s' "$line" | cut -d'|' -f3)
"
    done
    picks=$(ui_choose_multi "적용할 기본 설정을 고르세요 (추천이 미리 선택되어 있어요)" "$items" "$defs") || return 1
    SELECTED_SETTINGS=$(printf '%s\n' "$picks" | while IFS= read -r l; do
      [ -z "$l" ] && continue
      local nm="${l%% — *}"
      catalog_lines "$SETTINGS_CATALOG" | while IFS='|' read -r id n _rest; do
        if [ "$n" = "$nm" ]; then printf '%s\n' "$id"; fi
      done
    done | tr '\n' ' ')
    SELECTED_SETTINGS="${SELECTED_SETTINGS% }"
  fi
  log "선택한 설정: $SELECTED_SETTINGS"
}

apply_settings() {
  [ -n "$SELECTED_SETTINGS" ] || { log "선택한 설정이 없습니다"; return 0; }
  local id
  for id in $SELECTED_SETTINGS; do
    if type "setting_apply_$id" >/dev/null 2>&1; then
      if "setting_apply_$id"; then report_add_ok "설정:$id"; else report_add_fail "설정:$id"; fi
    else
      log "알 수 없는 설정 id 무시: $id"
    fi
  done
  if [ "$MFS_DRY_RUN" != "1" ]; then
    killall Finder >/dev/null 2>&1
    killall Dock >/dev/null 2>&1
    report_add_manual "일부 설정(트랙패드·키보드)은 로그아웃 후 다시 로그인해야 완전히 적용됩니다"
  fi
}
```
`main()`의 `flow_pick_apps` 다음(warm_sudo 이전)에 `flow_pick_settings || { log "사용자가 취소했습니다"; return 0; }` 추가, `install_apps` 다음에 `apply_settings` 추가.

- [ ] **Step 4: 통과 확인** — `bash tests/run-tests.sh` → `ALL PASS`, shellcheck 클린
- [ ] **Step 5: Commit** — `git commit -am "feat: 설정 엔진 + 도메인 백업/복구 스크립트"`

---

### Task 7: Dock 구성 + 리포트 + main 완성

**Files:**
- Modify: `setup.sh`
- Create: `tests/test-07-report.sh`

**Interfaces:**
- Consumes: 결과 누적, 카탈로그(appfile), UI
- Produces: `configure_dock()`(설치된 앱을 dockutil로 Dock에 추가 — dockutil 설치 실패 시 수동 안내로 강등), `write_report()`(`MFS_REPORT_FILE`에 한국어 리포트 저장), `final_dialog()`(리포트 열기/마침). `main()` 완성: welcome→profile→apps→settings→sudo→install→apply→dock→report→final.

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test-07-report.sh`:
```bash
#!/bin/bash
. "$(dirname "$0")/helpers.sh"
source_setup
tmp=$(mktemp -d)
MFS_REPORT_FILE="$tmp/report.txt"
OK_ITEMS="chrome
설정:finder_ext
"
FAILED_ITEMS="kakaotalk
"
MANUAL_ITEMS="App Store 로그인
"
MFS_BACKUP_DIR="$tmp/backup"; mkdir -p "$tmp/backup"
write_report
rep=$(cat "$tmp/report.txt")
assert_contains "잘 끝난 것" "$rep" "성공 섹션"
assert_contains "chrome" "$rep" "성공 항목"
assert_contains "실패한 것" "$rep" "실패 섹션"
assert_contains "kakaotalk" "$rep" "실패 항목"
assert_contains "직접 해야 할 것" "$rep" "수동 섹션"
assert_contains "복구.sh" "$rep" "복구 스크립트 안내"
# 통합 dry-run: 전 단계 관통 + 리포트 생성
out=$(MFS_DRY_RUN=1 MFS_NO_UI=1 MFS_AUTO_PROFILE=dev MFS_AUTO_APPS="chrome,vscode" \
      MFS_AUTO_SETTINGS="tap_click,won_backtick" MFS_LOG_FILE="$tmp/l.txt" \
      MFS_REPORT_FILE="$tmp/rep2.txt" MFS_BACKUP_DIR="$tmp/b2" bash "$(dirname "$0")/../setup.sh")
assert_contains "[dry-run]" "$out" "dry-run 로그"
[ -f "$tmp/rep2.txt" ] || { echo "ASSERT FAIL: 통합 리포트 없음"; exit 1; }
echo "test-07 pass"
```

- [ ] **Step 2: 실패 확인** — Run: `bash tests/test-07-report.sh` → FAIL

- [ ] **Step 3: 구현** — setup.sh에 추가:
```bash
# ── Dock 구성 ───────────────────────────────────────────────
configure_dock() {
  [ -n "$SELECTED_APPS" ] || return 0
  if [ "$MFS_DRY_RUN" = "1" ]; then log "[dry-run] Dock에 설치 앱 추가"; return 0; fi
  if ! command -v dockutil >/dev/null 2>&1; then
    brew install dockutil >/dev/null 2>&1 || {
      report_add_manual "원하는 앱을 응용 프로그램 폴더에서 Dock으로 드래그해 고정하세요"
      return 0
    }
  fi
  local id line appfile
  for id in $SELECTED_APPS; do
    line=$(catalog_line_by_id "$id"); appfile=$(catalog_field "$line" 8)
    [ -n "$appfile" ] && [ -e "/Applications/$appfile" ] &&
      dockutil --add "/Applications/$appfile" --no-restart >/dev/null 2>&1
  done
  killall Dock >/dev/null 2>&1
}

# ── 리포트 ─────────────────────────────────────────────────
item_display_name() { # id → 사람이 읽는 이름 (앱/설정/기타)
  case "$1" in
    설정:*)
      local sid="${1#설정:}" line
      line=$(settings_line_by_id "$sid")
      if [ -n "$line" ]; then printf '%s' "$line" | cut -d'|' -f2; else printf '%s' "$1"; fi ;;
    *)
      local line; line=$(catalog_line_by_id "$1")
      if [ -n "$line" ]; then catalog_field "$line" 5; else printf '%s' "$1"; fi ;;
  esac
}
print_items() { # $1=개행 목록 $2=글머리
  printf '%s' "$1" | while IFS= read -r it; do
    [ -n "$it" ] && printf '%s %s\n' "$2" "$(item_display_name "$it")"
  done
}
write_report() {
  {
    echo "맥 세팅 도우미 결과 리포트 — $(date '+%Y-%m-%d %H:%M')"
    echo "================================================"
    echo ""
    echo "[잘 끝난 것]"
    print_items "$OK_ITEMS" "✓"
    echo ""
    echo "[실패한 것 — 나중에 다시 실행하면 이 항목만 다시 시도합니다]"
    if [ -n "$FAILED_ITEMS" ]; then print_items "$FAILED_ITEMS" "✗"; else echo "(없음)"; fi
    echo ""
    echo "[직접 해야 할 것]"
    printf '%s' "$MANUAL_ITEMS" | while IFS= read -r it; do [ -n "$it" ] && echo "· $it"; done
    echo ""
    if [ -n "${MFS_BACKUP_DIR:-}" ] && [ -d "${MFS_BACKUP_DIR:-/nonexistent}" ]; then
      echo "[되돌리고 싶을 때]"
      echo "· $MFS_BACKUP_DIR/복구.sh 를 더블클릭(또는 실행)하면 설정이 원래대로 돌아갑니다"
    fi
  } >"$MFS_REPORT_FILE"
  log "리포트 저장: $MFS_REPORT_FILE"
}
final_dialog() {
  [ "$MFS_NO_UI" = "1" ] && return 0
  local pick
  pick=$(osascript -e "display dialog \"세팅이 끝났습니다! 🎉\n\n결과와 '직접 해야 할 일'을 리포트에서 확인하세요.\" with title \"$MFS_TITLE\" buttons {\"마침\",\"리포트 열기\"} default button 2 with icon note" 2>/dev/null)
  case "$pick" in *"리포트 열기"*) open -e "$MFS_REPORT_FILE" ;; esac
  return 0
}
```
`main()` 최종형 (교체):
```bash
main() {
  log "맥 세팅 도우미 v${MFS_VERSION} 시작"
  if ! macos_supported; then
    ui_alert "이 도구는 macOS Sonoma(14) 이상에서 동작합니다. 일부 설정이 적용되지 않을 수 있습니다."
    log "경고: 미지원 macOS 버전 $(sw_vers -productVersion)"
  fi
  flow_welcome        || { log "사용자가 취소했습니다"; return 0; }
  flow_pick_profile   || { log "사용자가 취소했습니다"; return 0; }
  flow_pick_apps      || { log "사용자가 취소했습니다"; return 0; }
  flow_pick_settings  || { log "사용자가 취소했습니다"; return 0; }
  warm_sudo || { ui_alert "관리자 암호 확인에 실패해 종료합니다."; return 1; }
  install_apps
  apply_settings
  configure_dock
  write_report
  final_dialog
  log "완료"
}
```

- [ ] **Step 4: 통과 확인** — `bash tests/run-tests.sh` → `ALL PASS`, shellcheck 클린
- [ ] **Step 5: Commit** — `git commit -am "feat: Dock 구성 + 리포트 + main 완성"`

---

### Task 8: 리서치 반영 — 카탈로그 확정 + cask 전수 검증

**선행 조건:** `docs/research/app-curation.md` (리서치 에이전트 산출물) 존재.

**Files:**
- Modify: `setup.sh` (APP_CATALOG / SETTINGS_CATALOG 데이터만 — 코드 변경 금지)
- Create: `tests/verify-casks.sh`
- Modify: `tests/test-02-catalog.sh` (확정 목록 기준 보강)

**Interfaces:**
- Consumes: 카탈로그 형식(T2), 리서치 문서
- Produces: 확정된 APP_CATALOG(프로필당 기본 체크 8~15개, 전체 15~30개), 확정 SETTINGS_CATALOG

- [ ] **Step 1: 리서치 문서 정독** — `docs/research/app-curation.md`의 프로필별 기본 체크셋·카테고리 표·설정 표를 읽고, UNVERIFIED 표기 항목은 제외 원칙으로 선별
- [ ] **Step 2: cask 검증 스크립트 작성** — `tests/verify-casks.sh` (네트워크 필요 — run-tests.sh에는 미포함):
```bash
#!/bin/bash
# APP_CATALOG의 cask 토큰 전수 실재 검증 (formulae.brew.sh API)
MFS_SOURCED=1 . "$(dirname "$0")/../setup.sh"
fail=0
while IFS='|' read -r id _cat method token _rest; do
  [ "$method" = "cask" ] || continue
  code=$(curl -s -o /dev/null -w '%{http_code}' "https://formulae.brew.sh/api/cask/${token}.json")
  if [ "$code" != "200" ]; then echo "MISSING CASK: $id ($token) http=$code"; fail=1; fi
done <<EOF
$(catalog_lines "$APP_CATALOG")
EOF
if [ "$fail" -eq 0 ]; then echo "ALL CASKS OK"; else exit 1; fi
```
- [ ] **Step 3: 카탈로그 데이터 갱신** — 리서치 문서 기준으로 APP_CATALOG·SETTINGS_CATALOG 레코드 교체/확장. 규칙 유지: 설명 쉼표 금지, appfile 정확 기입(cask 페이지의 `Artifacts` 항목 참조), UNVERIFIED cask 제외
- [ ] **Step 4: 검증** — Run: `bash tests/verify-casks.sh` → `ALL CASKS OK`. Run: `bash tests/run-tests.sh` → `ALL PASS` (test-02가 새 목록과 어긋나면 목록 기준으로 테스트 보강)
- [ ] **Step 5: Commit** — `git commit -am "feat: 리서치 기반 앱/설정 카탈로그 확정"`

---

### Task 9: 안내 웹페이지 + README

**Files:**
- Create: `guide/index.html`, `README.md`

**Interfaces:**
- Consumes: 없음 (독립 — Task 1~8과 병렬 가능). 실행 명령 URL은 `RAW_URL_PLACEHOLDER` 문자열로 두고 Task 10에서 치환.

- [ ] **Step 1: guide/index.html 작성** — 정적 단일 파일, 외부 리소스 0:
```html
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>맥 처음 세팅 도우미</title>
<style>
  :root { --accent: #0071e3; --bg: #f5f5f7; --card: #fff; --ink: #1d1d1f; }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: "Apple SD Gothic Neo", -apple-system, sans-serif; background: var(--bg); color: var(--ink); line-height: 1.7; }
  .wrap { max-width: 680px; margin: 0 auto; padding: 48px 20px 80px; }
  h1 { font-size: 2rem; margin-bottom: 8px; }
  .sub { color: #6e6e73; margin-bottom: 40px; }
  .step { background: var(--card); border-radius: 16px; padding: 28px; margin-bottom: 20px; box-shadow: 0 1px 3px rgba(0,0,0,.06); }
  .step h2 { font-size: 1.15rem; margin-bottom: 10px; }
  .num { display: inline-block; width: 28px; height: 28px; border-radius: 50%; background: var(--accent); color: #fff; text-align: center; line-height: 28px; font-size: .95rem; margin-right: 8px; }
  .kbd { background: #e8e8ed; border-radius: 6px; padding: 2px 8px; font-family: ui-monospace, monospace; font-size: .9em; }
  .cmdbox { display: flex; gap: 8px; margin-top: 14px; }
  .cmdbox code { flex: 1; background: #1d1d1f; color: #4ade80; padding: 14px 16px; border-radius: 10px; font-size: .82rem; overflow-x: auto; white-space: nowrap; }
  .cmdbox button { background: var(--accent); color: #fff; border: 0; border-radius: 10px; padding: 0 22px; font-size: .95rem; cursor: pointer; }
  .cmdbox button:active { opacity: .7; }
  .note { background: #fff8e6; border-radius: 10px; padding: 12px 16px; margin-top: 14px; font-size: .9rem; }
</style>
</head>
<body>
<div class="wrap">
  <h1>🍎 맥 처음 세팅 도우미</h1>
  <p class="sub">아래 3단계만 따라 하면, 나머지는 화면에 뜨는 창에서 클릭만 하면 됩니다.</p>

  <div class="step">
    <h2><span class="num">1</span>터미널 열기</h2>
    <p>키보드에서 <span class="kbd">⌘ command</span> + <span class="kbd">스페이스바</span>를 함께 누르고,
    <b>터미널</b>이라고 입력한 뒤 <span class="kbd">return</span>을 누르세요.<br>
    까만(또는 하얀) 글자 입력 창이 하나 열립니다. 이게 터미널이에요.</p>
  </div>

  <div class="step">
    <h2><span class="num">2</span>아래 명령 복사하기</h2>
    <div class="cmdbox">
      <code id="cmd">bash -c "$(curl -fsSL RAW_URL_PLACEHOLDER)"</code>
      <button onclick="copyCmd()" id="btn">복사</button>
    </div>
  </div>

  <div class="step">
    <h2><span class="num">3</span>터미널에 붙여넣고 return</h2>
    <p>터미널 창을 클릭한 뒤 <span class="kbd">⌘ command</span> + <span class="kbd">V</span>로 붙여넣고
    <span class="kbd">return</span>을 누르세요. 잠시 후 <b>선택 창이 뜨면 이제 클릭만 하면 됩니다.</b></p>
    <div class="note">🔑 중간에 <b>암호를 물어보면</b> 맥에 로그인할 때 쓰는 암호를 입력하세요.
    입력해도 화면에 아무것도 표시되지 않지만 정상적으로 입력되고 있는 거예요.</div>
  </div>
</div>
<script>
function copyCmd() {
  const t = document.getElementById('cmd').textContent;
  navigator.clipboard.writeText(t).then(() => {
    const b = document.getElementById('btn');
    b.textContent = '복사됨 ✓'; setTimeout(() => { b.textContent = '복사'; }, 2000);
  });
}
</script>
</body>
</html>
```
- [ ] **Step 2: 눈 검증** — Run: `open guide/index.html` → 레이아웃·복사 버튼 동작 확인 (클립보드에 명령 들어가는지)
- [ ] **Step 3: README.md 작성**:
```markdown
# 맥 처음 세팅 도우미

맥을 처음 산 사람을 위해, 터미널에 **한 줄만 붙여넣으면** 이후 모든 과정을
macOS 팝업창 클릭만으로 진행하는 세팅 도구입니다.

- 추천 앱 설치 (프로필: 사무·일반 / 학생 / 크리에이터 / 개발자)
- 편리한 기본 설정 (트랙패드·키보드·Finder·스크린샷 등)
- 모든 설정 변경은 자동 백업 + `복구.sh`로 원상복구 가능
- 재실행 안전 (설치된 항목은 건너뜀)

## 사용법

👉 **안내 페이지**: RAW_PAGES_PLACEHOLDER (지인에게는 이 링크만 보내면 됩니다)

또는 터미널에서:

    bash -c "$(curl -fsSL RAW_URL_PLACEHOLDER)"

## 개발

    bash tests/run-tests.sh      # 자동 테스트 (GUI 미실행)
    bash tests/verify-casks.sh   # cask 토큰 전수 검증 (네트워크)
    shellcheck setup.sh
    MFS_DRY_RUN=1 bash setup.sh  # 실제 변경 없이 흐름 확인

앱/설정 목록의 근거: `docs/research/app-curation.md`
```
- [ ] **Step 4: Commit** — `git add -A && git commit -m "feat: 안내 웹페이지 + README"`

---

### Task 10: 최종 검증 + 배포 준비

**Files:**
- Modify: `guide/index.html`, `README.md` (URL 치환)

- [ ] **Step 1: 정적 전수 검증** — Run: `shellcheck setup.sh tests/*.sh` → 클린. Run: `bash tests/run-tests.sh` → `ALL PASS`. Run: `bash tests/verify-casks.sh` → `ALL CASKS OK`
- [ ] **Step 2: dry-run 매트릭스** — 4개 프로필 각각: `MFS_DRY_RUN=1 MFS_NO_UI=1 MFS_AUTO_PROFILE=<p> MFS_AUTO_APPS="<프로필 기본셋>" MFS_AUTO_SETTINGS="<기본 설정들>" bash setup.sh` → 오류 0, 리포트 생성 확인
- [ ] **Step 3: [사용자 확인 게이트] GitHub 공개 리포 생성** — 공개 배포이므로 사용자 승인 후: `gh repo create mac-first-setup --public --source . --push`, Pages 활성화(`gh api` 또는 웹). 이후 `RAW_URL_PLACEHOLDER` → 실제 raw URL, `RAW_PAGES_PLACEHOLDER` → Pages URL 치환 후 커밋·푸시
- [ ] **Step 4: [사용자 실기 테스트] 실제 실행** — 사용자 본인 맥에서 안내 페이지 절차 그대로 실행(GUI 다이얼로그 실동작·설치·리포트·복구 스크립트 확인). 가능하면 새 사용자 계정에서 1회 더
- [ ] **Step 5: 파일럿** — 지인 1명에게 안내 페이지 링크 전달 → 피드백 반영

---

## Self-Review 기록

- 스펙 커버리지: 단일 파일(T1~7), 하이브리드 UI(T3), 프로필/선택(T4), 설치(T5), 설정+백업/복구(T6), 리포트/Dock(T7), 리서치 SSOT(T8), 안내 페이지(T9), 검증·배포(T10) — 스펙 §3~6 전부 매핑됨
- dry-run이 스펙 요구(§4)대로 전 단계 관통(T4~7 테스트로 강제)
- 타입/이름 일관성: 카탈로그 8필드·설정 4필드·`MFS_*` 훅 이름을 Interfaces 블록에 고정
