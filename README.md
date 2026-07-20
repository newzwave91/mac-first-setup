# 맥 처음 세팅 도우미

맥을 처음 산 사람을 위해, 터미널에 **한 줄만 붙여넣으면** 이후 모든 과정을
macOS 팝업창 클릭만으로 진행하는 세팅 도구입니다.

- 추천 앱 설치 (프로필: 사무·일반 / 학생 / 크리에이터 / 개발자)
- 편리한 기본 설정 (트랙패드·키보드·Finder·스크린샷 등)
- 모든 설정 변경은 자동 백업 + `복구.sh`로 원상복구 가능
- 재실행 안전 (설치된 항목은 건너뜀)

## 사용법

👉 **안내 페이지**: https://mac-first-setup.vercel.app (지인에게는 이 링크만 보내면 됩니다)

또는 터미널에서:

    bash -c "$(curl -fsSL https://mac-first-setup.vercel.app/setup.sh)"

## 개발

    bash tests/run-tests.sh      # 자동 테스트 (GUI 미실행)
    bash tests/verify-casks.sh   # cask 토큰 전수 검증 (네트워크)
    shellcheck setup.sh
    MFS_DRY_RUN=1 bash setup.sh  # 실제 변경 없이 흐름 확인

앱/설정 목록의 근거: `docs/research/app-curation.md`
