#!/bin/bash
# shellcheck disable=SC1091  # helpers.sh는 동적 상대경로라 정적 분석 불가(의도된 소스)
. "$(dirname "$0")/helpers.sh"
source_setup
tmp=$(mktemp -d)
# shellcheck disable=SC2034  # setup.sh 함수(write_report)가 소싱된 셸의 전역으로 읽음
MFS_REPORT_FILE="$tmp/report.txt"
# shellcheck disable=SC2034  # setup.sh 함수(write_report)가 소싱된 셸의 전역으로 읽음
OK_ITEMS="chrome
설정:finder_ext
"
# shellcheck disable=SC2034  # setup.sh 함수(write_report)가 소싱된 셸의 전역으로 읽음
FAILED_ITEMS="kakaotalk
"
# shellcheck disable=SC2034  # setup.sh 함수(write_report)가 소싱된 셸의 전역으로 읽음
MANUAL_ITEMS="App Store 로그인
"
# shellcheck disable=SC2034  # setup.sh 함수(write_report)가 소싱된 셸의 전역으로 읽음
MFS_BACKUP_DIR="$tmp/backup"; mkdir -p "$tmp/backup"
write_report
rep=$(cat "$tmp/report.txt")
assert_contains "잘 끝난 것" "$rep" "성공 섹션"
assert_contains "Chrome" "$rep" "성공 항목"
assert_contains "실패한 것" "$rep" "실패 섹션"
assert_contains "카카오톡" "$rep" "실패 항목"
assert_contains "직접 해야 할 것" "$rep" "수동 섹션"
assert_contains "복구.sh" "$rep" "복구 스크립트 안내"
# 통합 dry-run: 전 단계 관통 + 리포트 생성
out=$(MFS_DRY_RUN=1 MFS_NO_UI=1 MFS_AUTO_PROFILE=dev MFS_AUTO_APPS="chrome,vscode" \
      MFS_AUTO_SETTINGS="tap_click,won_backtick" MFS_LOG_FILE="$tmp/l.txt" \
      MFS_REPORT_FILE="$tmp/rep2.txt" MFS_BACKUP_DIR="$tmp/b2" bash "$(dirname "$0")/../setup.sh")
assert_contains "[dry-run]" "$out" "dry-run 로그"
[ -f "$tmp/rep2.txt" ] || { echo "ASSERT FAIL: 통합 리포트 없음"; exit 1; }
echo "test-07 pass"
