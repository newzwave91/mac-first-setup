#!/bin/bash
# shellcheck disable=SC1091  # helpers.sh는 동적 상대경로라 정적 분석 불가(의도된 소스)
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
# shellcheck disable=SC2034  # setup.sh 함수(install_one)가 소싱된 셸의 전역으로 읽음
APP_CATALOG='fin|유틸리티|cask|fin-cask|파인더테스트|테스트용|office|.'
# shellcheck disable=SC2034  # setup.sh 함수(install_one)가 소싱된 셸의 전역으로 읽음
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
# shellcheck disable=SC2034  # setup.sh 함수(install_one)가 소싱된 셸의 전역으로 읽음
APP_CATALOG='bad|유틸리티|cask|bad-cask|배드|테스트용|office|ZZZBad.app'
install_one bad
assert_contains "bad" "$FAILED_ITEMS" "실패 목록 기록"
echo "test-05 pass"
