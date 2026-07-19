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

# ── 앱 카탈로그 ─────────────────────────────────────────────
# 형식: id|카테고리|method(cask/mas)|token|표시명|설명|profiles|appfile|tier(required/recommended/optional)
# 규칙: 설명에 쉼표 금지(다중선택 파싱). profiles는 쉼표 구분. tier 비어있으면 optional 취급.
# 출처: docs/research/app-curation.md (SSOT). cask 토큰은 formulae.brew.sh API로 전수 검증(tests/verify-casks.sh).
# 카카오톡은 Homebrew cask 미제공(404 확인)이라 mas 방식 — token은 App Store 숫자 ID(iTunes lookup API로 검증).
# gureumkim·karabiner-elements는 pkg 설치형이라 cask API에 app 아티팩트가 없어 appfile을 비워둠
# (brew list --cask로 설치여부를 정확히 판별하므로 기능상 문제 없음).
APP_CATALOG='
chrome|브라우저|cask|google-chrome|Chrome|가장 무난한 표준 웹 브라우저|office,student,creator,dev|Google Chrome.app|required
kakaotalk|메신저|mas|869223134|카카오톡|국민 메신저를 PC에서도 사용|office,student|KakaoTalk.app|required
bitwarden|보안|cask|bitwarden|Bitwarden|무료로 쓸 수 있는 오픈소스 비밀번호 관리자|office,dev|Bitwarden.app|recommended
1password|보안|cask|1password|1Password|가장 많이 쓰이는 구독형 비밀번호 관리자|creator|1Password.app|optional
notion|생산성|cask|notion|Notion|메모 문서 할일을 한 곳에서 관리|office,student,creator,dev|Notion.app|recommended
microsoft-office|생산성|cask|microsoft-office|Microsoft Office|워드 엑셀 파워포인트 통합 패키지|student|Microsoft Word.app|optional
typora|생산성|cask|typora|Typora|군더더기 없는 마크다운 편집기|student|Typora.app|optional
obsidian|생산성|cask|obsidian|Obsidian|로컬 저장 방식의 무료 마크다운 노트|student|Obsidian.app|optional
raycast|생산성|cask|raycast|Raycast|Spotlight보다 강력한 실행 도구|dev|Raycast.app|recommended
dropbox|클라우드|cask|dropbox|Dropbox|안정적이라는 평이 많은 파일 동기화 저장소|office,student,creator|Dropbox.app|recommended
rectangle|유틸리티|cask|rectangle|Rectangle|무료로 창을 단축키로 반반 배치|office,student,dev|Rectangle.app|required
maccy|유틸리티|cask|maccy|Maccy|가볍고 빠른 무료 클립보드 관리자|office,student|Maccy.app|recommended
keka|유틸리티|cask|keka|Keka|압축 해제까지 되는 만능 도구|office,student,creator|Keka.app|required
aldente|유틸리티|cask|aldente|AlDente|배터리 충전 상한을 정해 수명 연장|office|AlDente.app|recommended
gureumkim|유틸리티|cask|gureumkim|구름 입력기|오픈소스 한글 입력기|office,dev||recommended
cleanshot|유틸리티|cask|cleanshot|CleanShot X|주석과 스크롤 캡처까지 되는 고급 스크린샷|creator|CleanShot X.app|optional
karabiner-elements|유틸리티|cask|karabiner-elements|Karabiner-Elements|한영키 백틱 등 키 매핑 커스터마이징|dev||optional
iina|미디어|cask|iina|IINA|VLC보다 편하다는 평이 많은 동영상 플레이어|creator|IINA.app|optional
spotify|미디어|cask|spotify|Spotify|표준 음악 스트리밍 앱|creator|Spotify.app|optional
vscode|개발|cask|visual-studio-code|VS Code|대다수 개발자가 쓰는 무료 코드 편집기|dev|Visual Studio Code.app|optional
iterm2|개발|cask|iterm2|iTerm2|맥 개발자의 기본기로 불리는 터미널|dev|iTerm.app|optional
docker-desktop|개발|cask|docker-desktop|Docker Desktop|컨테이너 기반 개발 환경|dev|Docker.app|optional
figma|디자인|cask|figma|Figma|온라인 UI 디자인과 프로토타이핑 도구|creator|Figma.app|optional
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
catalog_tier() { # $1=레코드 한 줄 → tier(9번째 필드), 빈 값이면 optional
  local t; t=$(catalog_field "$1" 9)
  printf '%s' "${t:-optional}"
}
catalog_required_ids() { # tier=required인 id 목록
  catalog_lines "$APP_CATALOG" | while IFS='|' read -r id _c _m _t _n _d _p _a tier; do
    [ "$tier" = "required" ] && printf '%s\n' "$id"
  done
}

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
won_backtick|₩ 대신 백틱(`)|한글 자판에서도 백틱 입력(개발·마크다운용)|student,dev
battery_pct|배터리 퍼센트 표시|메뉴 막대에 배터리 잔량 %가 보임|office,student,creator,dev
display_sleep|화면 자동 꺼짐 최적화|배터리 5분 전원 15분에 화면만 끄기|office,student,creator,dev
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
  osascript -e "display dialog \"$(as_quote "$1")\" with title \"$MFS_TITLE\" buttons {\"취소\",\"계속\"} cancel button \"취소\" default button 2 with icon note" >/dev/null 2>&1
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

app_label_for_id() { # "[필수] 표시명 — 설명" / "[권고] 표시명 — 설명" / "표시명 — 설명"(optional)
  local line tier prefix
  line=$(catalog_line_by_id "$1")
  tier=$(catalog_tier "$line")
  case "$tier" in
    required) prefix="[필수] " ;;
    recommended) prefix="[권고] " ;;
    *) prefix="" ;;
  esac
  printf '%s%s — %s\n' "$prefix" "$(catalog_field "$line" 5)" "$(catalog_field "$line" 6)"
}
app_id_for_label() { # 라벨의 등급 접두([필수] /[권고] )를 벗기고 표시명 부분으로 역매핑
  local label="$1" name
  case "$label" in
    "[필수] "*) label="${label#"[필수] "}" ;;
    "[권고] "*) label="${label#"[권고] "}" ;;
  esac
  name="${label%% — *}"
  catalog_lines "$APP_CATALOG" | while IFS='|' read -r id _c _m _t n _rest; do
    if [ "$n" = "$name" ]; then printf '%s\n' "$id"; fi
  done
}

flow_pick_apps() {
  if [ -n "${MFS_AUTO_APPS+x}" ]; then
    local raw id valid=""
    raw=$(printf '%s' "$MFS_AUTO_APPS" | tr ',' ' ')
    for id in $raw; do
      if [ -n "$(catalog_line_by_id "$id")" ]; then valid="$valid $id"; else log "알 수 없는 앱 id 무시: $id"; fi
    done
    SELECTED_APPS="${valid# }"
  else
    local items="" defaults="" id picks default_ids
    for id in $(catalog_all_ids); do items="$items$(app_label_for_id "$id")
"; done
    # 기본 체크셋 = 프로필 기본 ∪ 필수(required) 전체, 중복 제거
    default_ids=$({ catalog_default_ids_for_profile "$SELECTED_PROFILE"; catalog_required_ids; } | sort -u)
    for id in $default_ids; do defaults="$defaults$(app_label_for_id "$id")
"; done
    picks=$(ui_choose_multi "설치할 앱을 고르세요 (추천 항목이 미리 선택되어 있어요)" "$items" "$defaults") || return 1
    SELECTED_APPS=$(printf '%s\n' "$picks" | while IFS= read -r l; do [ -n "$l" ] && app_id_for_label "$l"; done | tr '\n' ' ')
    SELECTED_APPS="${SELECTED_APPS% }"
  fi
  log "선택한 앱: $SELECTED_APPS"
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
  local waited=0
  until xcode-select -p >/dev/null 2>&1; do
    sleep 10
    waited=$((waited + 10))
    if [ "$waited" -ge 600 ]; then
      log "개발자 도구 설치가 확인되지 않아 계속 진행합니다 (10분 초과)"
      report_add_manual "Apple 개발자 도구가 설치되지 않았습니다 — 터미널에서 xcode-select --install 을 다시 실행해 주세요"
      return 1
    fi
  done
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
    # shellcheck disable=SC2016  # 의도적 리터럴 — .zprofile에 그대로 기록되어 새 셸 시작 시 평가됨
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

# ── 백업/복구 ───────────────────────────────────────────────
MFS_BACKED_DOMAINS=""   # 공백 구분 (bash 3.2 — 연관배열 금지)

ensure_backup_dir() {
  if [ -z "${MFS_BACKUP_DIR:-}" ]; then MFS_BACKUP_DIR="$HOME/맥세팅-백업-$(date +%Y%m%d-%H%M%S)"; fi
  [ -d "$MFS_BACKUP_DIR" ] && return 0
  mkdir -p "$MFS_BACKUP_DIR"
  cat >"$MFS_BACKUP_DIR/복구.sh" <<'EOF'
#!/bin/bash
# 맥 세팅 도우미 복구 스크립트 — 실행하면 변경했던 설정을 원래대로 되돌립니다.
# 일부 복구(전원 설정)는 관리자 암호를 물어볼 수 있습니다.
cd "$(dirname "$0")" || exit 1
EOF
  chmod +x "$MFS_BACKUP_DIR/복구.sh"
}

backup_domain() { # $1=도메인 [$2="-currentHost"] — 도메인×스코프당 1회 전체 백업
  local domain="$1" scope="${2:-}" key
  key="$domain${scope:+.currentHost}"
  case " $MFS_BACKED_DOMAINS " in *" $key "*) return 0 ;; esac
  ensure_backup_dir
  if [ "$scope" = "-currentHost" ]; then
    if defaults -currentHost export "$domain" "$MFS_BACKUP_DIR/$key.plist" 2>/dev/null; then
      printf 'defaults -currentHost import %s "%s.plist"\n' "$domain" "$key" >>"$MFS_BACKUP_DIR/복구.sh"
    else
      # 원래 도메인이 없었음 → 복구 = 도메인 삭제(원상태 재현)
      printf 'defaults -currentHost delete %s 2>/dev/null\n' "$domain" >>"$MFS_BACKUP_DIR/복구.sh"
    fi
  else
    if defaults export "$domain" "$MFS_BACKUP_DIR/$key.plist" 2>/dev/null; then
      printf 'defaults import %s "%s.plist"\n' "$domain" "$key" >>"$MFS_BACKUP_DIR/복구.sh"
    else
      printf 'defaults delete %s 2>/dev/null\n' "$domain" >>"$MFS_BACKUP_DIR/복구.sh"
    fi
  fi
  MFS_BACKED_DOMAINS="$MFS_BACKED_DOMAINS $key"
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
  local kb="$HOME/Library/KeyBindings/DefaultKeyBinding.dict"
  if [ -f "$kb" ]; then
    if grep -qs '₩' "$kb"; then log "₩→백틱 이미 설정됨(스킵)"; return 0; fi
    cp "$kb" "$MFS_BACKUP_DIR/DefaultKeyBinding.dict.bak"
    printf 'cp "DefaultKeyBinding.dict.bak" "%s"\n' "$kb" >>"$MFS_BACKUP_DIR/복구.sh"
    log "기존 KeyBindings 파일이 있어 건너뜁니다 — 리포트 참고"
    report_add_manual "₩→백틱: 기존 키바인딩 파일이 있어 자동 적용하지 않았습니다"
    return 0
  fi
  printf '{\n  "₩" = ("insertText:", "`");\n}\n' >"$kb"
  printf 'rm -f "%s"\n' "$kb" >>"$MFS_BACKUP_DIR/복구.sh"
}
setting_apply_battery_pct() {
  if [ "$MFS_DRY_RUN" = "1" ]; then
    log "[dry-run] defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true"
    return 0
  fi
  backup_domain com.apple.controlcenter -currentHost
  defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true
}
setting_apply_display_sleep() { # 백업: pmset -g custom에서 Battery/AC 섹션의 기존 displaysleep 값을 파싱해 복구라인 생성
  if [ "$MFS_DRY_RUN" = "1" ]; then
    log "[dry-run] pmset -b displaysleep 5 / pmset -c displaysleep 15"
    return 0
  fi
  ensure_backup_dir
  local custom old_b old_c
  custom=$(pmset -g custom 2>/dev/null)
  old_b=$(printf '%s\n' "$custom" | awk '
    /^Battery Power:/ { f=1; next }
    /^[A-Za-z][A-Za-z ]*:$/ { f=0 }
    f && /displaysleep/ { print $2; exit }
  ')
  old_c=$(printf '%s\n' "$custom" | awk '
    /^AC Power:/ { f=1; next }
    /^[A-Za-z][A-Za-z ]*:$/ { f=0 }
    f && /displaysleep/ { print $2; exit }
  ')
  if [ -n "$old_b" ] && [ -n "$old_c" ]; then
    printf 'sudo pmset -b displaysleep %s\n' "$old_b" >>"$MFS_BACKUP_DIR/복구.sh"
    printf 'sudo pmset -c displaysleep %s\n' "$old_c" >>"$MFS_BACKUP_DIR/복구.sh"
  else
    printf '# displaysleep 원값 확인 불가 — 시스템 설정에서 수동 조정\n' >>"$MFS_BACKUP_DIR/복구.sh"
    report_add_manual "화면 자동 꺼짐: 기존 값을 확인하지 못해 복구 스크립트에 자동 반영하지 못했습니다 — 되돌리려면 시스템 설정에서 직접 조정해 주세요"
  fi
  # sudo 타임스탬프는 main의 warm_sudo가 확보해둠 — 여기서 sudo -v 재호출 금지
  sudo pmset -b displaysleep 5
  local rc1=$?
  sudo pmset -c displaysleep 15
  local rc2=$?
  [ "$rc1" -eq 0 ] && [ "$rc2" -eq 0 ]
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
    killall ControlCenter >/dev/null 2>&1
    report_add_manual "일부 설정(트랙패드·키보드)은 로그아웃 후 다시 로그인해야 완전히 적용됩니다"
  fi
}

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

if [ "${MFS_SOURCED:-0}" != "1" ]; then
  main "$@"
fi
