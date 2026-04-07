# Do Not Sleep

Do Not Sleep은 Mac 메뉴바에서 바로 켜고 끌 수 있는 초소형 유틸리티입니다. AI 에이전트, 장시간 빌드, 원격 작업, 다운로드 같은 흐름이 돌아가는 동안 Mac이 유휴 상태로 잠들거나 화면보호기로 넘어가서 작업이 끊기는 일을 막는 것이 목적입니다.

## Features

- `Keep Mac Awake`: 사용자 유휴 시스템 슬립을 방지합니다.
- `Prevent Screen Saver`: 화면보호기와 디스플레이 유휴 절전을 방지합니다.
- `Launch at Login`: 로그인 시 자동 실행할 수 있습니다.
- `Menu Bar First`: Dock 없이 메뉴바에서 바로 상태를 보고 토글할 수 있습니다.
- `Multilingual`: 한국어, 영어, 일본어, 중국어 간체/번체를 지원합니다.

## How It Works

- 시스템 슬립 방지는 `IOPMAssertionTypePreventUserIdleSystemSleep`을 사용합니다.
- 화면보호기 방지는 `IOPMAssertionTypePreventUserIdleDisplaySleep`을 사용합니다.
- 로그인 시 자동 실행은 `SMAppService.mainApp` 기반으로 처리합니다.
- 앱 번들 ID는 `im.umo.dns`입니다.

## Local Build

```bash
./scripts/build-app.sh
```

빌드가 끝나면 `dist/Do Not Sleep.app`이 생성됩니다.

Xcode로 열려면:

```bash
open DoNotSleep.xcodeproj
```

프로젝트 파일은 `project.yml`에서 생성되므로, 배포용 팀/서명 설정을 바꾸려면 Xcode와 `project.yml`을 함께 맞춰야 합니다.

## Project Layout

- `project.yml`: XcodeGen 스펙
- `Sources/DoNotSleep`: 앱 소스
- `Sources/DoNotSleep/Resources`: 다국어 리소스
- `scripts/build-app.sh`: 빌드 및 앱 번들 생성 스크립트
- `Support`: 아이콘 및 번들 지원 파일

## Homebrew Distribution Plan

이 프로젝트의 기본 배포 방향은 Mac App Store보다 Homebrew cask를 우선하는 것입니다.

배포에 필요한 핵심 항목:

1. `Developer ID Application`으로 Release 빌드
2. Apple notarization 통과
3. `.app`을 `.zip` 또는 `.dmg`로 패키징
4. GitHub Releases 같은 공개 URL에 업로드
5. Homebrew tap의 cask 파일에서 `version`, `sha256`, `url` 갱신
6. `brew install --cask`, `brew uninstall --cask`, `brew reinstall --cask`로 검증

현재 README는 Homebrew 배포 준비를 위한 프로젝트 문서 역할을 하며, 실제 cask와 release artifact는 별도로 추가할 예정입니다.

## Release Checklist

- 버전과 빌드 번호 증가
- 배포용 서명 확인
- notarization 확인
- 릴리즈 아카이브 생성
- SHA-256 계산
- 릴리즈 노트 작성
- Homebrew cask 업데이트

## Notes

- Mac App Store 제출에 필요한 구조도 어느 정도 정리되어 있지만, 현재 우선순위는 Homebrew 배포입니다.
- Homebrew 사용자 기준으로는 앱 내부 자동 업데이트보다 `brew upgrade --cask` 흐름이 더 자연스럽습니다.
