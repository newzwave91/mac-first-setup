#!/bin/bash
# shellcheck disable=SC1091  # helpers.sh는 동적 상대경로라 정적 분석 불가(의도된 소스)
. "$(dirname "$0")/helpers.sh"
source_setup

# ── 토큰 스팟체크 ────────────────────────────────────────────
line=$(catalog_line_by_id chrome)
assert_eq "google-chrome" "$(catalog_field "$line" 4)" "chrome cask 토큰"
assert_eq "Google Chrome.app" "$(catalog_field "$line" 8)" "chrome appfile"

line=$(catalog_line_by_id vscode)
assert_eq "visual-studio-code" "$(catalog_field "$line" 4)" "vscode cask 토큰"
assert_eq "Visual Studio Code.app" "$(catalog_field "$line" 8)" "vscode appfile"

# ── 카카오톡: cask 미제공 → mas, App Store 숫자 ID ───────────
line=$(catalog_line_by_id kakaotalk)
assert_eq "mas" "$(catalog_field "$line" 3)" "kakaotalk method는 mas"
assert_eq "869223134" "$(catalog_field "$line" 4)" "kakaotalk mas ID"
assert_eq "KakaoTalk.app" "$(catalog_field "$line" 8)" "kakaotalk appfile"

# ── pkg 설치형(appfile 비움: brew list --cask로 판별) ────────
line=$(catalog_line_by_id gureumkim)
assert_eq "cask" "$(catalog_field "$line" 3)" "gureumkim method는 cask"
assert_eq "" "$(catalog_field "$line" 8)" "gureumkim appfile은 비어있음(pkg 설치형)"

# ── 프로필 기본 체크셋 소속 확인 ─────────────────────────────
office_ids=$(catalog_default_ids_for_profile office)
assert_contains "chrome" "$office_ids" "office 기본셋에 chrome"
assert_contains "kakaotalk" "$office_ids" "office 기본셋에 카카오톡"
assert_contains "bitwarden" "$office_ids" "office 기본셋에 bitwarden"
assert_not_contains "vscode" "$office_ids" "office 기본셋에 vscode 없어야"
assert_not_contains "1password" "$office_ids" "office 기본셋에 1password 없어야(창작자 전용)"

student_ids=$(catalog_default_ids_for_profile student)
assert_contains "microsoft-office" "$student_ids" "student 기본셋에 Microsoft Office"
assert_contains "typora" "$student_ids" "student 기본셋에 Typora"
assert_contains "kakaotalk" "$student_ids" "student 기본셋에 카카오톡"

creator_ids=$(catalog_default_ids_for_profile creator)
assert_contains "figma" "$creator_ids" "creator 기본셋에 Figma"
assert_contains "1password" "$creator_ids" "creator 기본셋에 1password"
assert_not_contains "vscode" "$creator_ids" "creator 기본셋에 vscode 없어야"

dev_ids=$(catalog_default_ids_for_profile dev)
assert_contains "vscode" "$dev_ids" "dev 기본셋에 vscode"
assert_contains "karabiner-elements" "$dev_ids" "dev 기본셋에 karabiner-elements"
assert_contains "docker-desktop" "$dev_ids" "dev 기본셋에 docker-desktop"

# ── 프로필당 기본셋 크기 8~15 ────────────────────────────────
for p in office student creator dev; do
  n=$(catalog_default_ids_for_profile "$p" | grep -c .)
  if [ "$n" -lt 8 ] || [ "$n" -gt 15 ]; then
    echo "ASSERT FAIL: $p 기본셋 크기가 8~15 범위를 벗어남 (실제: $n)"; exit 1
  fi
done

# ── 전체 카탈로그 규모 15~30, LINE/Amphetamine 등 UNVERIFIED 제외 ─
all=$(catalog_all_ids)
assert_contains "iina" "$all" "전체 목록에 iina"
n_all=$(printf '%s\n' "$all" | grep -c .)
if [ "$n_all" -lt 15 ] || [ "$n_all" -gt 30 ]; then
  echo "ASSERT FAIL: 전체 카탈로그 규모가 15~30 범위를 벗어남 (실제: $n_all)"; exit 1
fi
assert_not_contains "line" "$all" "UNVERIFIED(LINE)는 카탈로그에서 제외"
assert_not_contains "amphetamine" "$all" "UNVERIFIED(Amphetamine mas ID)는 카탈로그에서 제외"

# ── 설명 필드에 쉼표·구분자(—) 미포함(라벨 파싱 규칙) ────────
# (파이프가 아닌 프로세스 치환 사용 — while이 서브셸에서 돌면 exit 1이 본 스크립트에 전파되지 않음)
while IFS='|' read -r id _c _m _t name desc _p _a; do
  case "$desc" in *,*) echo "ASSERT FAIL: $id 설명에 쉼표 포함"; exit 1 ;; esac
  case "$name" in *" — "*) echo "ASSERT FAIL: $id 표시명에 구분자(—) 포함"; exit 1 ;; esac
  case "$desc" in *" — "*) echo "ASSERT FAIL: $id 설명에 구분자(—) 포함"; exit 1 ;; esac
done < <(catalog_lines "$APP_CATALOG")

# ── SETTINGS_CATALOG: 구현된 8개 유지, won_backtick 프로필 확장 확인 ─
settings_ids=$(settings_all_ids)
for sid in tap_click three_finger_drag key_repeat finder_ext finder_bars screenshot_dir dock_tidy won_backtick; do
  assert_contains "$sid" "$settings_ids" "설정 목록에 $sid"
  if ! type "setting_apply_$sid" >/dev/null 2>&1; then
    echo "ASSERT FAIL: setting_apply_$sid 함수 없음"; exit 1
  fi
done
n_settings=$(printf '%s\n' "$settings_ids" | grep -c .)
assert_eq "8" "$n_settings" "설정 카탈로그는 구현된 8개만"

line=$(settings_line_by_id won_backtick)
profiles=$(printf '%s' "$line" | cut -d'|' -f4)
assert_contains "student" "$profiles" "won_backtick은 student(문서작업)에도 기본 추천"
assert_contains "dev" "$profiles" "won_backtick은 dev에도 기본 추천"

echo "test-02 pass"
