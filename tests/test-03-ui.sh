#!/bin/bash
# shellcheck disable=SC1091  # helpers.sh는 동적 상대경로라 정적 분석 불가(의도된 소스)
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
