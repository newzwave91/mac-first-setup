#!/bin/bash
# shellcheck disable=SC1091  # helpers.sh는 동적 상대경로라 정적 분석 불가(의도된 소스)
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
