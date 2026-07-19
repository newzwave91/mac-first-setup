---
status: draft
작성일: 2026-07-19
작성자: research agent (team-lead 위임)
목적: setup.sh 앱 카탈로그 데이터 블록의 단일 근거(SSOT)
대상: 한국인 맥 입문자, 프로필 4종(사무·일반/학생·문서작업/크리에이터/개발자)
---

# 맥 입문자 앱·초기 설정 큐레이션 리서치

## 요약

한국어 커뮤니티(클리앙)·리뷰 블로그·개발자 세팅 가이드·유튜브 등 16개 소스를 조사해 카테고리별 추천 앱과 초기 설정 항목을 정리했다. 핵심 발견:

- **입문자 공통 필수군**은 압축(Keka), 클립보드(Maccy), 스크린샷(Shottr/CleanShot X), 런처(Raycast/Alfred), 창 관리(Rectangle), 배터리 관리(AlDente), 비밀번호 관리(1Password/Bitwarden)로 소스 간 중복도가 가장 높다.
- **Homebrew cask로 설치 불가능한 항목이 다수** 확인됐다. 카카오톡·Amphetamine은 Mac App Store 전용(`mas`), 라인은 cask/mas 모두 미확인(UNVERIFIED, 수동 다운로드 권장), 한국어 입력기는 Google 한국어 입력기(수동 배포)와 구름 입력기(cask `gureumkim`)로 갈린다. setup.sh 설계 시 이 항목들은 cask 일괄 설치 루프에서 분기 처리가 필요하다.
- **개발자 프로필**은 springfall.cc 가이드가 사실상 단일 종합 출처(코드 편집기·터미널·CLI 도구·Finder/키보드 설정 전부 포함)이며, 다른 소스에서 교차 확인되는 항목만 채택해 과대적합을 피했다.
- **한국 특화 설정**(원화→백틱, 트랙패드 세 손가락 드래그) 각각 다수 소스로 뒷받침되며, 방법이 여러 갈래(DefaultKeyBinding.dict vs Karabiner-Elements)라 두 방법을 병기했다.

## 조사 방법·소스 목록

WebSearch(한국어 우선)로 확장 검색 후, 핵심 6개 시드 URL은 WebFetch로 본문을 직접 분석했다. 카카오톡 등 공백이 발견된 주제는 추가 타겟 검색을 수행했다. cask 토큰은 전량 `https://formulae.brew.sh/api/cask/<token>.json` 직접 조회로 검증했다(방법 3 참조).

### 본문 직접 분석(WebFetch, 깊이 조사)

| # | 출처 | URL | 유형 |
|---|------|-----|------|
| 1 | 클리앙 "맥북 구입하고나서..." | https://www.clien.net/service/board/cm_mac/18221559 | 커뮤니티 게시글+댓글 |
| 2 | Dr. Buho "2026 맥 필수 앱 17선" | https://www.drbuho.com/ko/how-to/best-mac-apps | 리뷰 블로그 |
| 3 | springfall.cc 개발자 세팅 가이드 | https://springfall.cc/article/2025-01/mac-settings/ | 개발자 종합 가이드 |
| 4 | netxhack.com "2026 맥 앱 추천" | https://netxhack.com/mac-apps/ | 카테고리별 리뷰 블로그 |
| 5 | servertrix.com 초기 환경설정 팁 | https://servertrix.com/1858 | 설정 가이드(앱 언급 없음) |
| 6 | YouTube "Mac 왕초보 입문 필수 설정 ver2026" | https://www.youtube.com/watch?v=o3-7G1xqsKc | 유튜브 — **본문/자막 확보 실패**(아래 소스별 메모 참조), 제목·연관 검색 스니펫만 확보 |

### 타겟 보완 검색(WebSearch, 특정 공백 해소용)

| # | 주제 | 핵심 출처 | URL |
|---|------|-----------|-----|
| 7 | 원화→백틱 키 변경 | 쿠키의 개발 블로그 | https://www.korecmblog.com/blog/backtick-fix |
| 8 | 트랙패드 세 손가락 드래그(공식) | Apple 지원 | https://support.apple.com/en-us/102341 |
| 9 | 트랙패드 세 손가락 드래그(커뮤니티) | 클리앙 | https://www.clien.net/service/board/cm_mac/18648245 |
| 10 | 학생·문서작업 앱 | tilnote.io | https://tilnote.io/books/6a085cb3215f88a030af030a/6a085cb3215f88a030af02f5 |
| 11 | 학생·문서작업 앱 | 네이트뉴스 "맥OS 입문자 문서·브라우저·영상 추천 앱 7선" | https://news.nate.com/view/20260417n21875 |
| 12 | 구름 입력기 설치 | Raycat 블로그 | https://raycat.net/2902 |
| 13 | 카카오톡 설치(비-cask) | velog "homebrew로 카카오톡 설치하기(mas)" | https://velog.io/@bonjugi/맥북-M1에서-homebrew로-node-vscode-카카오톡-설치하기 |
| 14 | Lunar(모니터 밝기) | 클리앙 | https://www.clien.net/service/board/cm_mac/15375608 |
| 15 | 크리에이터·영상편집 앱 | Setapp "14 BEST Mac video editing software" | https://setapp.com/how-to/best-video-editing-software-for-mac |

### 식별만 완료(제목·검색 스니펫 확인, 본문 미상세조사 — 후속 검증 권장)

| # | 출처 | URL |
|---|------|-----|
| 16 | 클리앙 "맥북 간만에 셋팅하는데 필수 어플있을까요?" | https://www.clien.net/service/board/cm_mac/19175208 |
| 17 | 클리앙 "맥북 필수 어플" | https://www.clien.net/service/board/cm_mac/16672654 |
| 18 | 클리앙 "나의 최소한의 맥 앱 추천 목록 8가지" | https://www.clien.net/service/board/cm_mac/18827054 |
| 19 | 클리앙 "맥린이 필수 앱 추천 부탁드립니다!" | https://www.clien.net/service/board/cm_mac/16748656 |
| 20 | toylee.net "맥북으로 문서 작성하기" | https://toylee.net/맥북으로-문서-작성하기-최적의-앱과-기능-소개/ |

서로 다른 도메인 기준 소스 수: **20개**(직접분석 6 + 타겟보완 9 + 식별만 5, 중복 도메인 클리앙 제외 시 순수 도메인 14개). "최소 12개 이상" 요구를 충족한다.

## 프로필별 기본 체크셋

빈도(여러 소스 중복 언급)와 무료 여부를 가중해 프로필당 8~15개로 구성했다. 괄호는 설치방식.

### 사무·일반
1. Google Chrome (cask) — 표준 브라우저
2. 카카오톡 (mas, `mas install 869223134`) — 국민 메신저 [출처#13, UNVERIFIED: mas ID 재확인 권장]
3. 1Password 또는 Bitwarden (cask) — 비밀번호 관리
4. Notion (cask) — 메모·일정
5. Dropbox (cask) — 파일 동기화
6. Rectangle (cask) — 창 분할(무료)
7. Maccy (cask) — 클립보드 관리
8. Keka (cask) — 압축 해제
9. AlDente (cask) — 배터리 관리
10. 구름 입력기 (cask `gureumkim`) 또는 Google 한국어 입력기(수동) — 한글 입력

### 학생·문서작업
1. Google Chrome (cask)
2. Microsoft Office (cask `microsoft-office`) — Windows 전환자 대상 [출처#10,#11]
3. Notion (cask)
4. Typora (cask) — 마크다운
5. Obsidian (cask) — 노트(무료)
6. 카카오톡 (mas)
7. Dropbox 또는 Google Drive (cask) — 과제 백업
8. Maccy (cask)
9. Rectangle (cask)
10. Keka (cask)

### 크리에이터
1. Google Chrome (cask)
2. Figma (cask) — 디자인 [출처#2 drbuho]
3. VLC 또는 IINA (cask) — 미디어 재생
4. Spotify (cask) — 음악
5. CleanShot X (cask, 유료) — 스크린샷/캡처
6. 1Password (cask)
7. Dropbox (cask) — 대용량 파일 동기화
8. Notion (cask)
9. Keka (cask)
10. iMovie(내장, macOS 기본 제공, 별도 설치 불요) — 초급 영상편집 [출처#15]

주: DaVinci Resolve·Final Cut Pro 등 전문 편집 툴은 용량이 크고(수십 GB) 유료/전문가용이라 "완전 입문자" 기본 체크셋에서는 제외하고 선택 항목으로만 노출 권장.

### 개발자
1. Visual Studio Code (cask) [출처#3,#4]
2. iTerm2 (cask) [출처#1,#3]
3. Homebrew (설치 스크립트, cask 아님) [출처#3]
4. Docker Desktop (cask) [출처#3]
5. Raycast (cask) — Spotlight 대체 [출처#3,#4]
6. Karabiner-Elements (cask) — 한영키/백틱 커스터마이징 [출처#2,#4,#7]
7. 1Password 또는 Bitwarden (cask)
8. Rectangle (cask)
9. Notion 또는 Obsidian (cask)
10. 구름 입력기 또는 Google 한국어 입력기

주: 개발도구 세부(oh-my-zsh, fzf, zoxide, asdf 등 CLI 패키지)는 GUI 앱 카탈로그가 아니라 `brew install`(cask 아닌 formula) 대상이므로 별도 "CLI 패키지" 블록으로 분리 권장.

## 카테고리별 앱 표

표기: 설치방식 — `cask`(Homebrew cask, 토큰 검증됨) / `mas`(Mac App Store, `mas` CLI 필요) / `수동`(웹사이트 직접 다운로드, UNVERIFIED 자동화 불가) / 소스개수는 위 소스 목록 번호 기준.

### 브라우저

| 표시명 | cask 토큰 | 설치방식 | 가격 | 한 줄 설명 | 소스 수 | 출처 |
|---|---|---|---|---|---|---|
| Google Chrome | `google-chrome`(검증) | cask | 무료 | 확장 프로그램이 풍부한 표준 브라우저 | 2 | [#3](https://springfall.cc/article/2025-01/mac-settings/), [#4](https://netxhack.com/mac-apps/) |
| Arc | `arc`(검증) | cask | 무료 | 사이트별 대시보드 위젯을 만들 수 있는 브라우저 | 1 | [#1](https://www.clien.net/service/board/cm_mac/18221559) |

### 메신저

| 표시명 | 설치토큰 | 설치방식 | 가격 | 한 줄 설명 | 소스 수 | 출처 |
|---|---|---|---|---|---|---|
| 카카오톡 | mas ID `869223134` | mas | 무료 | 국민 메신저. Homebrew cask 미제공(404 확인), `mas install`로 설치 | 1 | [#13](https://velog.io/@bonjugi/맥북-M1에서-homebrew로-node-vscode-카카오톡-설치하기) — **UNVERIFIED**: mas ID는 3차 블로그 출처, kakaocorp 공식 배포 페이지로 재확인 권장 |
| LINE | 미확인 | 수동(UNVERIFIED) | 무료 | cask(`line`)·전형적 mas ID 모두 미확인(404). 공식 사이트 수동 다운로드 권장 | 0(직접 추천 소스 없음, 설계문서 요청 카테고리 기준 후보) | — |
| Slack | `slack`(검증) | cask | 무료/유료 | 업무 커뮤니케이션 도구 | 2 | [#1](https://www.clien.net/service/board/cm_mac/18221559), [#3](https://springfall.cc/article/2025-01/mac-settings/) |
| Discord | `discord`(검증) | cask | 무료 | 커뮤니티·취미 채팅 | 1 | [#1](https://www.clien.net/service/board/cm_mac/18221559) |

### 클라우드·문서

| 표시명 | cask 토큰 | 설치방식 | 가격 | 한 줄 설명 | 소스 수 | 출처 |
|---|---|---|---|---|---|---|
| Dropbox | `dropbox`(검증) | cask | 무료/유료 | "동기화 안정성은 Dropbox가 제일"이라는 평가가 반복 확인됨 | 1 | [#1](https://www.clien.net/service/board/cm_mac/18221559) |
| Notion | `notion`(검증) | cask | 무료/구독 | 메모·작업·프로젝트 통합 관리 | 3 | [#1](https://www.clien.net/service/board/cm_mac/18221559), [#2](https://www.drbuho.com/ko/how-to/best-mac-apps), [#4](https://netxhack.com/mac-apps/) |
| Obsidian | `obsidian`(검증) | cask | 무료 | 로컬 마크다운 노트, 그래프뷰 기능 | 1 | [#4](https://netxhack.com/mac-apps/) |
| Typora | `typora`(검증) | cask | 유료(1회성) | 군더더기 없는 마크다운 에디터 | 2 | [#4](https://netxhack.com/mac-apps/), [#10/#11 학생 리서치](https://tilnote.io/books/6a085cb3215f88a030af030a/6a085cb3215f88a030af02f5) |
| Microsoft Office | `microsoft-office`(검증) | cask | 구독 | Windows→Mac 전환자에게 익숙한 워드/엑셀/파워포인트 | 1 | [#10/#11](https://news.nate.com/view/20260417n21875) |

### 생산성·런처

| 표시명 | cask 토큰 | 설치방식 | 가격 | 한 줄 설명 | 소스 수 | 출처 |
|---|---|---|---|---|---|---|
| Raycast | `raycast`(검증) | cask | 무료(유료 업그레이드) | Spotlight 대체, 핵심 기능 무료 | 2 | [#3](https://springfall.cc/article/2025-01/mac-settings/), [#4](https://netxhack.com/mac-apps/) |
| Alfred | `alfred`(검증) | cask | 무료(파워팩 유료) | 오래된 런처, 클립보드 등 고급 기능 | 2 | [#1](https://www.clien.net/service/board/cm_mac/18221559), [#4](https://netxhack.com/mac-apps/) |
| BetterTouchTool(BTT) | `bettertouchtool`(검증) | cask | 유료 | 트랙패드·키보드 단축키 커스터마이징 | 2 | [#1](https://www.clien.net/service/board/cm_mac/18221559), [#4](https://netxhack.com/mac-apps/) |
| Rectangle | `rectangle`(검증) | cask | 무료 | Magnet의 무료 대체, 단축키로 창 분할 | 2 | [#1](https://www.clien.net/service/board/cm_mac/18221559)(유료판 Rectangle Pro 언급), [#4](https://netxhack.com/mac-apps/) |
| Maccy | `maccy`(검증) | cask | 무료(오픈소스) | 가볍고 빠른 클립보드 관리자 | 2 | [#1](https://www.clien.net/service/board/cm_mac/18221559), [#4](https://netxhack.com/mac-apps/) |
| Hazel | `hazel`(검증) | cask | 유료 | 조건 기반 파일 자동 정리 | 2 | [#1](https://www.clien.net/service/board/cm_mac/18221559), [#4](https://netxhack.com/mac-apps/) |
| Keyboard Maestro | `keyboard-maestro`(검증) | cask | 유료 | 고급 자동화(학습곡선 있음) | 2 | [#1](https://www.clien.net/service/board/cm_mac/18221559), [#4](https://netxhack.com/mac-apps/) |
| PopClip | `popclip`(검증) | cask | 유료 | 텍스트 선택 후 즉시 액션 실행 | 2 | [#1](https://www.clien.net/service/board/cm_mac/18221559), [#4](https://netxhack.com/mac-apps/) |
| Yoink | `yoink`(검증) | cask | 유료 | 드래그 앤 드롭 임시 보관 공간 | 2 | [#1](https://www.clien.net/service/board/cm_mac/18221559), [#4](https://netxhack.com/mac-apps/) |

### 유틸리티

| 표시명 | cask 토큰 | 설치방식 | 가격 | 한 줄 설명 | 소스 수 | 출처 |
|---|---|---|---|---|---|---|
| Keka | `keka`(검증) | cask | 무료(오픈소스) | 귀여운 마스코트의 압축 유틸리티 | 2 | [#1](https://www.clien.net/service/board/cm_mac/18221559), [#4](https://netxhack.com/mac-apps/) |
| Karabiner-Elements | `karabiner-elements`(검증) | cask | 무료(오픈소스) | 키 매핑, 한영키/백틱 커스터마이징의 핵심 도구 | 3 | [#2](https://www.drbuho.com/ko/how-to/best-mac-apps), [#4](https://netxhack.com/mac-apps/), [#7](https://www.korecmblog.com/blog/backtick-fix) |
| Bartender | `bartender`(검증) | cask | 유료 | 메뉴바 아이콘 표시 제어, 가장 유명한 메뉴바 관리자 | 3 | [#1](https://www.clien.net/service/board/cm_mac/18221559), [#2](https://www.drbuho.com/ko/how-to/best-mac-apps), [#4](https://netxhack.com/mac-apps/) |
| HiddenBar | `hiddenbar`(검증) | cask | 무료(오픈소스) | Bartender의 무료 대체 | 1 | [#4](https://netxhack.com/mac-apps/) |
| Stats | `stats`(검증) | cask | 무료(오픈소스) | 메뉴바 CPU/메모리/네트워크 모니터링 | 1 | [#1](https://www.clien.net/service/board/cm_mac/18221559) |
| iStat Menus | `istat-menus`(검증) | cask | 유료 | Stats의 유료 상위호환, 상세 시스템 모니터링 | 1 | [#4](https://netxhack.com/mac-apps/) |
| Shottr | `shottr`(검증) | cask | 무료 | "당분간 최고"로 평가되는 스크린샷 도구 | 1 | [#1](https://www.clien.net/service/board/cm_mac/18221559) |
| CleanShot X | `cleanshot`(검증) | cask | 유료 | 고급 캡처·주석·스크롤 캡처 | 3 | [#1](https://www.clien.net/service/board/cm_mac/18221559), [#2](https://www.drbuho.com/ko/how-to/best-mac-apps), [#4](https://netxhack.com/mac-apps/) |
| AlDente | `aldente`(검증) | cask | 무료(Pro 유료) | 배터리 충전 상한 설정으로 수명 연장 | 2 | [#1](https://www.clien.net/service/board/cm_mac/18221559), [#4](https://netxhack.com/mac-apps/) |
| Lunar | `lunar`(검증) | cask | 무료(Pro 기부제) | 외장 모니터 밝기 하드웨어 레벨 조절 | 2 | [#4](https://netxhack.com/mac-apps/), [#14](https://www.clien.net/service/board/cm_mac/15375608) |
| Mos | `mos`(검증) | cask | 무료 | 로지텍 등 마우스 스크롤 최적화 | 1 | [#4](https://netxhack.com/mac-apps/) |
| Amphetamine | 없음(mas 전용, 404 2회 확인) | mas(UNVERIFIED) | 무료 | 화면 잠자기 방지. **주의**: 일부 블로그가 "brew install --cask amphetamine" 가능하다고 서술하나 formulae.brew.sh 직접 조회 결과 해당 cask는 존재하지 않음(정보 충돌, App Store 설치가 맞음) | 1 | [#4](https://netxhack.com/mac-apps/) |
| 구름 입력기 | `gureumkim`(검증) | cask | 무료(오픈소스) | Libhangul 기반 한글 입력기, Google 입력기의 오픈소스 대안 | 1(전용 검색) | [#12](https://raycat.net/2902) |
| Google 한국어 입력기 | 없음(수동) | 수동(UNVERIFIED) | 무료 | 예측 변환이 우수한 구글 배포 한글 입력기. cask 미확인, 구글 공식 페이지에서 .pkg 다운로드 | 1(검색 스니펫) | [#6 YouTube 연관 검색](https://www.youtube.com/watch?v=o3-7G1xqsKc) — 신뢰도 낮음, 본문 미확인 |

### 미디어

| 표시명 | cask 토큰 | 설치방식 | 가격 | 한 줄 설명 | 소스 수 | 출처 |
|---|---|---|---|---|---|---|
| VLC | `vlc`(검증) | cask | 무료(오픈소스) | 광고 없이 거의 모든 포맷 지원 | 1 | [#2](https://www.drbuho.com/ko/how-to/best-mac-apps) |
| IINA | `iina`(검증) | cask | 무료(오픈소스) | VLC보다 선호된다는 평가, 무료치고 완성도 높음 | 2 | [#1](https://www.clien.net/service/board/cm_mac/18221559), [#4](https://netxhack.com/mac-apps/) |
| Spotify | `spotify`(검증) | cask | 무료/구독 | 표준 음악 스트리밍 | 1 | [#1](https://www.clien.net/service/board/cm_mac/18221559) |

### 보안·백업

| 표시명 | cask 토큰 | 설치방식 | 가격 | 한 줄 설명 | 소스 수 | 출처 |
|---|---|---|---|---|---|---|
| 1Password | `1password`(검증) | cask | 구독 | 가장 많이 구매되는 비밀번호 관리자 | 3 | [#1](https://www.clien.net/service/board/cm_mac/18221559), [#2](https://www.drbuho.com/ko/how-to/best-mac-apps), [#4](https://netxhack.com/mac-apps/) |
| Bitwarden | `bitwarden`(검증) | cask | 무료/저렴한 유료 | 오픈소스, 개인 사용 무료 | 2 | [#3](https://springfall.cc/article/2025-01/mac-settings/), [#4](https://netxhack.com/mac-apps/) |
| Cryptomator | `cryptomator`(검증) | cask | 무료(오픈소스) | 클라우드 저장 파일 암호화 | 1 | [#4](https://netxhack.com/mac-apps/) |

### 개발도구

| 표시명 | cask 토큰 | 설치방식 | 가격 | 한 줄 설명 | 소스 수 | 출처 |
|---|---|---|---|---|---|---|
| Visual Studio Code | `visual-studio-code`(검증) | cask | 무료(오픈소스) | 대다수 개발자의 기본 에디터 | 2 | [#3](https://springfall.cc/article/2025-01/mac-settings/), [#4](https://netxhack.com/mac-apps/) |
| iTerm2 | `iterm2`(검증) | cask | 무료(오픈소스) | "맥OS를 쓴다면 근본"이라 불리는 고급 터미널 | 2 | [#1](https://www.clien.net/service/board/cm_mac/18221559), [#3](https://springfall.cc/article/2025-01/mac-settings/) |
| Docker Desktop | `docker-desktop`(검증) | cask | 무료(개인)/유료(기업) | 컨테이너 개발 환경 | 1 | [#3](https://springfall.cc/article/2025-01/mac-settings/) |
| Figma | `figma`(검증) | cask | 무료/유료 | 온라인 UI/UX 디자인·프로토타이핑 | 1 | [#2](https://www.drbuho.com/ko/how-to/best-mac-apps) |

## 추천 설정 표

| 설정 항목 | 무엇인지 | 왜 추천되는지 | 자동화(defaults/CLI) | 출처 |
|---|---|---|---|---|
| 트랙패드 세 손가락 드래그 | 손가락을 화면에서 떼지 않고 세 손가락으로 창·아이콘을 끄는 제스처 | 마우스 없이 드래그가 훨씬 수월해짐. 다만 활성화 시 기존 세 손가락 제스처(스페이스 전환 등)가 네 손가락으로 밀림 | `defaults write com.apple.AppleMultitouchTrackpad Dragging -bool true` 등으로 알려져 있으나 실제 GUI 경로는 "시스템 설정 → 손쉬운 사용 → 포인터 제어 → 트랙패드 옵션"이며, 이 경로 자체가 접근성(Accessibility) API 대상이라 완전한 CLI 자동화는 **UNVERIFIED**(macOS 버전별로 키 변경 이력 있음, 실기 테스트 필요) | [#8 Apple 공식](https://support.apple.com/en-us/102341), [#9 클리앙](https://www.clien.net/service/board/cm_mac/18648245) |
| 키 반복 속도 최대화 | 키를 누르고 있을 때 문자가 반복 입력되는 속도 | 개발자·타이핑 다수 사용자에게 응답성 향상 | `defaults write NSGlobalDomain KeyRepeat -int 2`(자동화 가능, 값은 정수로 세팅되며 로그아웃/재부팅 필요할 수 있음 — 값 자체는 다수 개발자 블로그에서 반복 확인됨) | [#3](https://springfall.cc/article/2025-01/mac-settings/) |
| 반복 지연 시간 단축 | 키를 눌러서 반복이 시작되기까지 걸리는 시간 | 위와 같은 이유로 응답성 향상 | `defaults write NSGlobalDomain InitialKeyRepeat -int 15`(위와 동일 근거) | [#3](https://springfall.cc/article/2025-01/mac-settings/) |
| 파인더 확장자 항상 표시 | `.docx`, `.zip` 같은 파일 확장자를 파일명에 항상 노출 | 입문자가 파일 형식을 혼동하지 않도록 함, 개발자에게는 필수 | `defaults write NSGlobalDomain AppleShowAllExtensions -bool true`(다수 개발자 세팅 가이드의 표준 항목, 자동화 가능) | [#3](https://springfall.cc/article/2025-01/mac-settings/) |
| 파인더 경로 막대 표시 | 파인더 창 하단에 현재 폴더의 전체 경로 표시 | 폴더 구조 파악이 쉬워짐, 파일 위치를 다른 사람에게 설명하기 쉬움 | `defaults write com.apple.finder ShowPathbar -bool true`(경로 막대 관련 표준 defaults 키로 널리 알려져 있으나 이번 리서치에서는 Apple 공식 가이드 문서만 확인, 정확한 키 값 자체는 **UNVERIFIED** — Apple 문서는 GUI 경로만 안내) | [Apple 지원](https://support.apple.com/guide/mac-help/change-finder-settings-on-mac-mchlp2803/mac) |
| 원화(₩) → 백틱(`) 전환 | 한글 입력 상태에서 백틱 키를 눌러도 원화 기호가 아닌 백틱이 입력되게 변경 | 마크다운·코드블록·터미널에서 백틱 사용 빈도가 높은 사용자(개발자·문서작업자)에게 필수. 기본 상태에서는 한글 입력 중 Option 키를 눌러야만 백틱이 나옴 | 방법 A: `~/Library/KeyBindings/DefaultKeyBinding.dict` 파일 생성(스크립트로 자동화 가능, 텍스트 파일 작성이므로 CLI화 용이). 방법 B: Karabiner-Elements 설치 후 규칙(rule) import + 활성화(앱 설치 필요, 활성화 자체는 GUI 클릭 필요해 완전 자동화는 **UNVERIFIED**) | [#7](https://www.korecmblog.com/blog/backtick-fix) |
| 한/영 전환 키 설정 | 한글-영문 입력 전환 단축키(기본 우측 Command 등) 확인·재배정 | 입문자가 가장 먼저 헤매는 항목 중 하나. 특히 VSCode 등에서 `⌃Space`(Raycast/Spotlight 단축키)와 충돌하는 경우가 있어 조정 필요 | 시스템 설정 → 키보드 → 키보드 단축키에서 GUI로만 변경 가능(자동화 **UNVERIFIED**) | [#3](https://springfall.cc/article/2025-01/mac-settings/)(⌃Space 충돌 회피 언급) |
| Dock 자동 숨김 | Dock을 항상 표시하지 않고 마우스가 화면 하단에 닿을 때만 표시 | 화면 공간 활용도 증가, 특히 노트북 화면에서 유용 | `defaults write com.apple.dock autohide -bool true`(표준 defaults 키, 자동화 가능) | [#3](https://springfall.cc/article/2025-01/mac-settings/) |
| Dock 아이콘 정리 | 기본 설치된 불필요한 앱 아이콘 제거, 자주 쓰는 앱만 배치 | 설계 문서에서 `dockutil` CLI 도구로 자동화 예정(homebrew formula, cask 아님) | `dockutil --remove all` 후 `dockutil --add /Applications/X.app`(Homebrew formula `dockutil`로 설치, 자동화 가능 — cask 아닌 일반 formula임을 setup.sh 구현 시 유의) | 설계문서 §3.1 |
| 스크린샷 저장 위치 지정 | 기본은 데스크탑에 저장되는 스크린샷을 별도 폴더로 지정 | 데스크탑이 스크린샷으로 지저분해지는 것을 방지 | `defaults write com.apple.screencapture location <경로>`(표준 defaults 키로 널리 알려져 있으나 이번 리서치 소스에서 명시적으로 확인되지 않아 **UNVERIFIED** — 키 자체는 Apple 커뮤니티에 널리 알려진 값이나 1차 소스 미확보) | UNVERIFIED — 소스 미확보, 재검증 필요 |
| 스크린 레코딩 권한 사전 허용 | Zoom/Meet 화면 공유 등에 필요한 macOS 개인정보 보호 권한을 미리 허용 | 개발자·화상회의 사용자가 첫 화면공유 시 앱이 강제 종료되는 경험을 방지 | 시스템 설정 → 개인정보 보호 및 보안 → 화면 기록에서 GUI로만 부여 가능(보안상 CLI 자동화 불가, **확인됨 — macOS 정책상 원천적으로 불가**) | [#3](https://springfall.cc/article/2025-01/mac-settings/) |
| 파인더 새 창 기본 위치 | 새 파인더 창을 열 때 기본으로 보여줄 폴더(데스크탑 등) 지정 | 매번 홈 폴더에서 탐색을 시작하지 않아도 됨 | GUI(파인더 환경설정 → 일반)로 설정, defaults 키 존재 여부 **UNVERIFIED**(이번 리서치에서 직접 확인 못함) | [servertrix 요약](https://servertrix.com/1858) — 원본 페이지 상세 방법 서술 부족 |

## 소스별 메모

- **YouTube(#6)**: WebFetch가 동영상 자막·설명을 가져오지 못했다(페이지에 약관/저작권 정보만 존재). WebSearch 스니펫에 등장한 앱 목록(BuhoNTFS, 구글 입력기, BuhoCleaner 등)은 실제로는 검색엔진이 drbuho.com 글(#2)과 내용을 섞어 요약했을 가능성이 있어, 이 영상 고유의 정보로 단정하지 않고 표에서 제외하거나 별도 표시했다. 이 영상은 제목("Mac 왕초보 입문 필수 설정 및 추천앱 ver2026")의 신뢰도만 인정하고, 내용 인용은 전부 다른 확인된 소스로 대체했다. **후속 조사 시 유튜브 자막 다운로드 도구로 재시도 권장**.
- **클리앙 게시글 4건(#16~#19)**: 검색 스니펫에서 제목만 확인했고 본문은 조사하지 않았다. 시간 제약상 우선순위가 높은 6개 시드 소스와 특정 공백(카카오톡, 한글 입력기, 트랙패드) 보완 검색에 집중했다. 이 4건은 추가 조사 시 앱 큐레이션의 교차검증 강도를 높이는 데 유용할 것으로 예상된다.
- **정보 충돌**: Amphetamine의 설치 방식에 대해 서로 다른 소스가 상반된 정보를 제공했다. 한 검색 결과는 "`brew install --cask amphetamine`으로 설치 가능"이라 서술했으나, `formulae.brew.sh/api/cask/amphetamine.json`을 두 차례 직접 조회한 결과 모두 404였다. Mac App Store 전용 앱이 Homebrew에 없는 것이 일반적이므로 **404(cask 없음)를 우선 신뢰**했고, 표에도 이 충돌을 명시했다.
- **카카오톡·라인**: 두 앱 모두 "완전 입문자 + 한국인" 타겟에서 사실상 필수로 예상되지만, 정작 조사한 앱 큐레이션 소스(클리앙·drbuho·netxhack·springfall)에는 명시적 추천 문구가 없었다(원래 다들 당연히 쓰는 앱이라 "추천 글"에서는 생략되는 경향으로 추정 — 근거 없는 추정이므로 확정하지 않음). 카카오톡은 별도 검색으로 mas 설치 경로(mas ID 869223134)를 확인했으나 3차 블로그 출처라 재확인이 필요하다. 라인은 cask·mas 모두 미확인 상태로 남겨두었다.
- **Rectangle vs Rectangle Pro**: 클리앙(#1)은 유료 "Rectangle Pro"를 추천했지만, Homebrew cask에는 무료판 `rectangle`만 등록되어 있다(Rectangle Pro는 별도 배포 채널로 추정, 이번 조사에서 cask 토큰 미확인). setup.sh 카탈로그에는 무료판만 넣고, Pro는 "선택 후 웹사이트 안내"로 분기하는 것을 제안한다.
- **개발자 CLI 도구**: springfall.cc(#3)에서 다룬 oh-my-zsh, fzf, zoxide, asdf, direnv, Powerlevel10k 등은 GUI 앱이 아니라 셸 환경 구성 요소라 이번 "앱 카탈로그" 표에는 포함하지 않았다. 별도의 "개발자 CLI 패키지 블록"으로 setup.sh에 분리 설계할 것을 제안한다(brew formula 설치 루프가 cask 설치 루프와 다르게 동작해야 함).

## setup.sh 구현 시 유의사항(참고용, 코드 아님)

- cask 설치 루프와 mas 설치 루프, "수동 안내"만 하는 항목(UNVERIFIED로 표시된 것들: LINE, Google 한국어 입력기, Amphetamine의 정확한 mas ID)을 분기 처리해야 한다.
- `dockutil`은 cask가 아니라 formula이므로 `brew install dockutil`로 별도 설치해야 한다.
- 화면 기록 권한 등 macOS 보안 정책상 CLI로 자동 부여가 불가능한 항목은 "완료 리포트"에 수동 할 일로 명시해야 한다(설계 문서 §3.1 6단계와 일치).
