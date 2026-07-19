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

main() {
  log "맥 세팅 도우미 v${MFS_VERSION} 시작"
}

if [ "${MFS_SOURCED:-0}" != "1" ]; then
  main "$@"
fi
