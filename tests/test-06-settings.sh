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

# ── 배터리 퍼센트·화면 자동꺼짐: 카탈로그 등록 확인 ───────────
assert_contains "battery_pct" "$(settings_all_ids)" "설정 목록에 battery_pct"
assert_contains "display_sleep" "$(settings_all_ids)" "설정 목록에 display_sleep"

# (a) dry-run 통합 실행에 battery_pct·display_sleep 포함 → [dry-run] 로그 확인
out3=$(MFS_DRY_RUN=1 MFS_NO_UI=1 MFS_AUTO_PROFILE=office MFS_AUTO_APPS="" \
      MFS_AUTO_SETTINGS="battery_pct,display_sleep" MFS_LOG_FILE="$tmp/l3.txt" \
      MFS_REPORT_FILE="$tmp/r3.txt" MFS_BACKUP_DIR="$tmp/b3" bash "$(dirname "$0")/../setup.sh")
assert_contains "선택한 설정: battery_pct display_sleep" "$out3" "배터리·화면꺼짐 설정 선택 로그"
assert_contains "[dry-run] defaults -currentHost write com.apple.controlcenter BatteryShowPercentage" "$out3" "배터리 퍼센트 dry-run"
assert_contains "[dry-run] pmset -b displaysleep 5" "$out3" "화면 자동꺼짐 dry-run"

# (b) display_sleep 실적용 경로: pmset·sudo를 서브셸 안에서 스텁으로 대체(실 pmset/sudo 절대 미실행)
(
  # shellcheck disable=SC1091  # setup.sh는 동적 상대경로라 정적 분석 불가(의도된 소스)
  MFS_SOURCED=1 . "$(dirname "$0")/../setup.sh"
  PMSET_LOG="$tmp/pmset.log"; : >"$PMSET_LOG"
  # shellcheck disable=SC2329  # setting_apply_display_sleep(setup.sh, 소싱됨)이 간접 호출 — 정적분석 불가(의도된 스텁)
  pmset() {
    case "$1" in
      -g) printf 'Battery Power:\n displaysleep 5\nAC Power:\n displaysleep 10\n' ;;
      *) echo "pmset $*" >>"$PMSET_LOG" ;;
    esac
  }
  # shellcheck disable=SC2329  # setting_apply_display_sleep(setup.sh, 소싱됨)이 간접 호출 — 정적분석 불가(의도된 스텁, 실 sudo 회피)
  sudo() { "$@"; }
  # shellcheck disable=SC2034  # setup.sh 함수(setting_apply_display_sleep)가 소싱된 셸의 전역으로 읽음
  MFS_DRY_RUN=0
  # shellcheck disable=SC2034  # setup.sh 함수(ensure_backup_dir)가 소싱된 셸의 전역으로 읽음
  MFS_BACKUP_DIR="$tmp/b4"
  setting_apply_display_sleep
  rc=$?
  assert_eq "0" "$rc" "display_sleep 적용 rc"
  rec=$(cat "$MFS_BACKUP_DIR/복구.sh")
  assert_contains "pmset -b displaysleep 5" "$rec" "복구라인: battery 원값(5분) 보존"
  assert_contains "pmset -c displaysleep 10" "$rec" "복구라인: AC 원값(10분) 보존"
  pmlog=$(cat "$PMSET_LOG")
  assert_contains "pmset -b displaysleep 5" "$pmlog" "적용: battery 새 값 5분 기록"
  assert_contains "pmset -c displaysleep 15" "$pmlog" "적용: AC 새 값 15분 기록"
) || exit 1

echo "test-06 pass"
