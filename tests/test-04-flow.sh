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
# MFS_AUTO_APPS=""(빈 문자열이지만 set)는 "앱 0개 설치"를 의미 — 대화상자를 건너뛰어야 함
# 주의: flow_pick_apps 내부에서 picks=$(ui_choose_multi ...)로 stdout을 캡처하므로
# 대화상자 호출 여부 마커는 stderr로 내보내고 2>&1로 바깥에서 합쳐 캡처한다.
# MFS_LOG_FILE은 서브셸 안이 아니라 여기(최상위)에서 export해 SC2030/2031(서브셸 간
# 변경 유실 경고)을 피한다 — 두 서브셸 모두 이 값을 상속해서 읽기만 한다.
export MFS_LOG_FILE="$tmp/log34.txt"
(
  # shellcheck disable=SC1091  # setup.sh는 동적 상대경로라 정적 분석 불가(의도된 소스)
  MFS_SOURCED=1 . "$(dirname "$0")/../setup.sh"
  # shellcheck disable=SC2329  # ui_choose_multi(setup.sh, 소싱됨)이 간접 호출 — 정적분석 불가(의도된 스텁)
  ui_choose_multi() { echo "DIALOG_CALLED" >&2; return 1; }
  export MFS_AUTO_PROFILE=office
  export MFS_AUTO_APPS=""
  out3=$(flow_pick_apps 2>&1); rc3=$?
  assert_eq "0" "$rc3" "빈 MFS_AUTO_APPS: rc"
  assert_eq "" "$SELECTED_APPS" "빈 MFS_AUTO_APPS: SELECTED_APPS"
  assert_not_contains "DIALOG_CALLED" "$out3" "빈 MFS_AUTO_APPS: 대화상자 미호출"
) || exit 1
# 대칭 확인: MFS_AUTO_APPS가 아예 unset이면 대화상자(인터랙티브) 경로를 타야 함
(
  # shellcheck disable=SC1091  # setup.sh는 동적 상대경로라 정적 분석 불가(의도된 소스)
  MFS_SOURCED=1 . "$(dirname "$0")/../setup.sh"
  # shellcheck disable=SC2329  # ui_choose_multi(setup.sh, 소싱됨)이 간접 호출 — 정적분석 불가(의도된 스텁)
  ui_choose_multi() { echo "DIALOG_CALLED" >&2; return 1; }
  unset MFS_AUTO_APPS
  export MFS_NO_UI=1
  out4=$(flow_pick_apps 2>&1); rc4=$?
  assert_eq "1" "$rc4" "MFS_AUTO_APPS unset: 취소 경로 rc"
  assert_contains "DIALOG_CALLED" "$out4" "MFS_AUTO_APPS unset: 대화상자 호출"
) || exit 1
echo "test-04 pass"
