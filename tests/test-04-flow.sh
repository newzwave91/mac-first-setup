#!/bin/bash
# shellcheck disable=SC1091  # helpers.sh는 동적 상대경로라 정적 분석 불가(의도된 소스)
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
