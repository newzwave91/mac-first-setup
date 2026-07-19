#!/bin/bash
# APP_CATALOG의 cask 토큰 전수 실재 검증 (formulae.brew.sh API)
# shellcheck disable=SC1091  # setup.sh는 동적 상대경로라 정적 분석 불가(의도된 소스)
MFS_SOURCED=1 . "$(dirname "$0")/../setup.sh"
fail=0
while IFS='|' read -r id _cat method token _rest; do
  [ "$method" = "cask" ] || continue
  code=$(curl -s -o /dev/null -w '%{http_code}' "https://formulae.brew.sh/api/cask/${token}.json")
  if [ "$code" != "200" ]; then echo "MISSING CASK: $id ($token) http=$code"; fail=1; fi
done <<EOF
$(catalog_lines "$APP_CATALOG")
EOF
if [ "$fail" -eq 0 ]; then echo "ALL CASKS OK"; else exit 1; fi
