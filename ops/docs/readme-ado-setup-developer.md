## 🚀 Gradle 피드 연동 가이드 

이 문서는 Azure DevOps 포털의 `Connect to feed -> Gradle`에서 제공되는 설정을 개발자 PC에 적용하는 방법을 정리합니다.

## 1. 사전 준비

1. Azure DevOps에서 PAT(PERSONAL_ACCESS_TOKEN) 발급(운영자에게 요청)
   1. Scope는 `Packaging: Read & write` 포함
   2. 대상 Feed: `iwon-feed`

## 2. build.gradle 설정

아래 `maven` 블록을 `repositories`와 `publishing.repositories` 두 곳에 모두 추가합니다.

```gradle
maven {
  url 'https://pkgs.dev.azure.com/iteyes-ito/iwon-ops/_packaging/iwon-feed/maven/v1'
  name 'iwon-feed'
  credentials(PasswordCredentials)
  authentication {
      basic(BasicAuthentication)
  }
}
```

예시 구조:

```gradle
plugins {
    id 'java'
    id 'maven-publish'
}

repositories {
    mavenCentral()
    maven {
      url 'https://pkgs.dev.azure.com/iteyes-ito/iwon-ops/_packaging/iwon-feed/maven/v1'
      name 'iwon-feed'
      credentials(PasswordCredentials)
      authentication {
          basic(BasicAuthentication)
      }
    }
}

publishing {
    publications {
        mavenJava(MavenPublication) {
            from components.java
        }
    }
    repositories {
        maven {
          url 'https://pkgs.dev.azure.com/iteyes-ito/iwon-ops/_packaging/iwon-feed/maven/v1'
          name 'iwon-feed'
          credentials(PasswordCredentials)
          authentication {
              basic(BasicAuthentication)
          }
        }
    }
}
```

## 3. gradle.properties 설정

Windows PowerShell 기준 사용자 홈 디렉터리 `$env:USERPROFILE\.gradle\gradle.properties` 파일에 아래 값을 추가 또는 수정합니다.

```properties
iwon-feedUsername=iteyes-ito
iwon-feedPassword=PERSONAL_ACCESS_TOKEN
```
* gradle.properties 설정은 프로젝트 루트에도 가능하지만 토큰암호(PAT) 보안을 위해 사용자 홈 권장

## 4. 패키지 생성

프로젝트 디렉터리에서 실행:

```bash
./gradlew build
```

## 5. 패키지 발행

프로젝트 디렉터리에서 실행:

```bash
./gradlew publish
```

## 6. 확인

Azure DevOps `Artifacts > iwon-feed`에서 업로드 결과를 확인합니다.

## 7. 관련 문서

- 운영자용 가이드: [ops/docs/readme-ado-artifacts.md](readme-ado-artifacts.md)
- 개발자용 가이드: [ops/docs/readme-ops-developer-quickstart.md](readme-ops-developer-quickstart.md)
