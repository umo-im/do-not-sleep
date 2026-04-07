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

현재 로컬 기본 빌드는 `Apple Development` 서명으로 만들어질 수 있으므로, 공개 배포용 빌드는 아래의 `Developer ID Release` 절차를 사용하는 것이 안전합니다.

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

현재 저장소에는 same-repo tap용 cask와 배포 스크립트가 같이 들어 있습니다.

## Homebrew Install

이 저장소 자체를 tap으로 사용할 수 있습니다. 저장소 이름이 `homebrew-*` 형식이 아니므로, tap 추가 시 URL을 같이 넘겨야 합니다.

설치:

```bash
brew tap umo-im/do-not-sleep https://github.com/umo-im/do-not-sleep.git
brew install --cask umo-im/do-not-sleep/umo-do-not-sleep
```

업데이트:

```bash
brew update
brew upgrade --cask umo-im/do-not-sleep/umo-do-not-sleep
```

삭제:

```bash
brew uninstall --cask umo-im/do-not-sleep/umo-do-not-sleep
```

같은 저장소 tap용 cask는 [Casks/umo-do-not-sleep.rb](/Users/k1005/workspace/do-not-sleep-for-mac/Casks/umo-do-not-sleep.rb)에 있습니다.

중요:

- GitHub Release가 `draft`이면 Homebrew에서 다운로드할 수 없습니다.
- release asset을 교체하거나 새 버전을 만들면 cask의 `sha256`도 함께 갱신해야 합니다.
- 공개 배포용으로는 `Developer ID Application` 서명과 notarization이 끝난 zip을 올리는 것이 맞습니다.

## Developer ID Release

배포용 macOS 앱은 `Developer ID Application` 서명과 notarization이 필요합니다.

사전 준비:

1. Xcode에 Apple Developer 계정 로그인
2. `Developer ID Application` 인증서 설치
3. 필요하면 `project.yml`의 `DEVELOPMENT_TEAM`을 본인 팀으로 변경
4. notarization까지 할 경우 `notarytool` keychain profile 생성

설치된 코드 서명 인증서 확인:

```bash
./scripts/check-signing.sh
```

배포용 아카이브와 zip 생성:

```bash
./scripts/release-developer-id.sh
```

팀 ID를 스크립트에서 임시 override하려면:

```bash
TEAM_ID=YOURTEAMID ./scripts/release-developer-id.sh
```

특정 인증서를 명시하고 싶다면:

```bash
DEVELOPER_ID_SIGNING_CERTIFICATE="Developer ID Application" ./scripts/release-developer-id.sh
```

notarization까지 같이 수행하려면:

```bash
NOTARY_PROFILE=DoNotSleep ./scripts/release-developer-id.sh
```

이 스크립트는 다음을 자동으로 수행합니다.

- Xcode 프로젝트 재생성
- `Developer ID` 방식 archive/export
- 서명 결과 검증
- 선택적 notarization + stapling
- 배포용 zip 생성
- SHA-256 파일 생성

release zip을 만든 뒤 cask를 현재 zip 기준으로 갱신하려면:

```bash
./scripts/update-homebrew-cask.sh
```

`notarytool` profile 예시는 다음과 같습니다.

```bash
xcrun notarytool store-credentials "DoNotSleep"
```

명령을 실행하면 Apple ID, 팀 ID, 앱 전용 비밀번호를 keychain profile로 저장할 수 있습니다.

## Release Checklist

- 버전과 빌드 번호 증가
- 배포용 서명 확인
- notarization 확인
- 릴리즈 아카이브 생성
- SHA-256 계산
- Homebrew cask 갱신
- 릴리즈 노트 작성
- GitHub Release publish

## Notes

- Mac App Store 제출에 필요한 구조도 어느 정도 정리되어 있지만, 현재 우선순위는 Homebrew 배포입니다.
- Homebrew 사용자 기준으로는 앱 내부 자동 업데이트보다 `brew upgrade --cask` 흐름이 더 자연스럽습니다.
