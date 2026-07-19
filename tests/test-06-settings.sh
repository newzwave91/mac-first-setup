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
# 스코프 충돌: NSGlobalDomain(일반)과 NSGlobalDomain -currentHost는 별도 키로 백업되어야 함
backup_domain NSGlobalDomain
backup_domain NSGlobalDomain -currentHost
n=$(grep -c "^defaults import NSGlobalDomain " "$tmp/backup/복구.sh")
assert_eq "1" "$n" "NSGlobalDomain 일반 스코프 복구라인 1개"
grep -Eq "defaults -currentHost (import|delete) NSGlobalDomain" "$tmp/backup/복구.sh" ||
  { echo "ASSERT FAIL: NSGlobalDomain currentHost 스코프 복구라인 없음"; exit 1; }
# export 실패 시: plist 없이도 삭제 복구라인은 남아야 함
# 실측: 최신 macOS(26.5.2)의 `defaults export`는 존재하지 않는 도메인이어도
# rc=0 + 빈 dict plist를 만들어 "성공"으로 끝난다(defaults read는 여전히 rc=1).
# 즉 "존재하지 않는 도메인 → export 실패"라는 전제가 이 머신에서는 성립하지 않는다.
# (defaults read com.mfs.zzz.nonexistent.testdomain 는 실제로 rc=1 확인됨)
# 따라서 export 실패 분기는 `defaults`를 국소적으로 오버라이드해 결정적으로 재현한다
# — 실제 시스템에 어떤 write/delete도 가하지 않는 순수 함수 스텁이다.
if defaults read com.mfs.zzz.nonexistent.testdomain >/dev/null 2>&1; then
  echo "ASSERT FAIL: 테스트 전제 위반 — com.mfs.zzz.nonexistent.testdomain 도메인이 실재함"; exit 1
fi
(
  # shellcheck disable=SC2329  # backup_domain(setup.sh, 소싱됨)이 간접 호출 — 정적분석 불가(의도된 스텁)
  defaults() { case " $* " in *" export "*) return 1 ;; esac; command defaults "$@"; }
  backup_domain com.mfs.zzz.nonexistent.testdomain
  [ -f "$tmp/backup/com.mfs.zzz.nonexistent.testdomain.plist" ] &&
    { echo "ASSERT FAIL: export 실패인데 plist가 생성됨"; exit 1; }
  assert_contains "defaults delete com.mfs.zzz.nonexistent.testdomain" "$(cat "$tmp/backup/복구.sh")" "export 실패 시 삭제 복구라인"
) || exit 1
# 재호출 dedup: NSGlobalDomain(일반) 재백업해도 복구라인은 늘지 않음
backup_domain NSGlobalDomain
n=$(grep -c "^defaults import NSGlobalDomain " "$tmp/backup/복구.sh")
assert_eq "1" "$n" "NSGlobalDomain 재백업해도 복구라인 1개 유지"
# dry-run 적용 경로: 실제 defaults 미변경, 로그만
out=$(MFS_DRY_RUN=1 MFS_NO_UI=1 MFS_AUTO_PROFILE=office MFS_AUTO_APPS="" \
      MFS_AUTO_SETTINGS="tap_click,finder_ext" MFS_LOG_FILE="$tmp/l.txt" \
      MFS_REPORT_FILE="$tmp/r.txt" MFS_BACKUP_DIR="$tmp/b2" bash "$(dirname "$0")/../setup.sh")
assert_contains "선택한 설정: tap_click finder_ext" "$out" "설정 선택 로그"
assert_contains "[dry-run] defaults write NSGlobalDomain AppleShowAllExtensions" "$out" "확장자 설정 dry-run"
echo "test-06 pass"
