#!/bin/bash
# tests/ 안의 test-*.sh 전부 실행, 실패 집계. verify-*.sh(네트워크 필요)는 제외.
cd "$(dirname "$0")" || exit 1
fail=0
for t in test-*.sh; do
  echo "== $t"
  if bash "$t"; then echo "   OK"; else echo "   FAIL"; fail=$((fail + 1)); fi
done
if [ "$fail" -eq 0 ]; then echo "ALL PASS"; else echo "FAILURES: $fail"; exit 1; fi
