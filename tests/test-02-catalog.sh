#!/bin/bash
# shellcheck disable=SC1091  # helpers.sh는 동적 상대경로라 정적 분석 불가(의도된 소스)
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
