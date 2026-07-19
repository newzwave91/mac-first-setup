#!/bin/bash
# 공용 어서션. 실패 시 즉시 exit 1 (개별 테스트 파일 단위 실패).
assert_eq() { # $1=expected $2=actual $3=label
  [ "$1" = "$2" ] && return 0
  echo "ASSERT FAIL: $3"; echo "  expected: [$1]"; echo "  actual:   [$2]"; exit 1
}
assert_contains() { # $1=needle $2=haystack $3=label
  case "$2" in *"$1"*) return 0 ;; esac
  echo "ASSERT FAIL: $3 (missing: $1)"; exit 1
}
assert_not_contains() { # $1=needle $2=haystack $3=label
  case "$2" in *"$1"*) echo "ASSERT FAIL: $3 (should not contain: $1)"; exit 1 ;; esac
  return 0
}
# shellcheck disable=SC1091  # setup.sh는 동적 상대경로라 정적 분석 불가(의도된 소스)
source_setup() { MFS_SOURCED=1 . "$(dirname "$0")/../setup.sh"; }
