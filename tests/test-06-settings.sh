#!/bin/bash
# shellcheck disable=SC1091  # helpers.sh는 동적 상대경로라 정적 분석 불가(의도된 소스)
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
