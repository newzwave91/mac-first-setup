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
