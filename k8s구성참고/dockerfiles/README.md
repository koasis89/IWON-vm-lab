# Dockerfiles 안내

## 목차
- 개요
- 목적
- Prerequisites
- Usage

## 개요

`dockerfiles/` 디렉토리는 Kubernetes Lab 실습에서 사용하는 컨테이너 이미지 정의 파일을 모아둔 폴더입니다.
각 Dockerfile은 용도별(개발도구, Java 빌드/런타임, Nginx, Node.js)로 분리되어 있으며, 필요에 따라 개별적으로 빌드해 사용할 수 있습니다.

포함 파일:
- `devcontainer.dockerfile`: Ansible, kubectl, Helm 기반 개발/운영 유틸 환경
- `db-dockerfile`: MariaDB 이미지 + `backup/db` 초기 데이터(`all.sql`) 및 참조 설정 파일 포함
- `jdk-dockerfile`: Java 빌드 환경(JDK + Gradle + Maven)
- `jre-dockerfile`: Java 런타임 베이스 이미지
- `nginx-dockerfile`: Nginx 기반 정적 웹/SPA 서빙 이미지
- `nginx.conf`: Nginx 기본 서버 설정(SPA 라우팅 포함)
- `node-dockerfile`: Node.js 개발/빌드 베이스 이미지

## 목적

- 실습/운영에 필요한 도구 환경을 빠르게 컨테이너로 재현
- 빌드 환경과 런타임 환경을 분리해 이미지 역할 명확화
- 팀 단위에서 동일한 베이스 이미지를 사용해 실행 환경 표준화
- Kubernetes 배포 전 로컬 이미지 기반 테스트를 용이하게 수행

## Prerequisites

아래 항목이 준비되어 있어야 이미지 빌드 및 실행이 가능합니다.

1. Docker Desktop 또는 Docker Engine 설치
2. Docker 데몬 실행 상태 확인
3. 현재 셸에서 `docker` 명령 사용 가능

확인 명령:

```bash
docker version
docker info
```

## Usage

`k8s-lab`(vscode 현재프로젝트, 예시:`/mnt/c/Workspace/I-Won/k8s-lab`) 루트 경로에서 아래 명령으로 개별 이미지를 빌드합니다.

```bash
# Devcontainer
docker build -t k8s-lab-devcontainer -f dockerfiles/devcontainer.dockerfile .

# MariaDB
docker build -t k8s-lab-mariadb -f dockerfiles/db-dockerfile .

# Java JDK
docker build -t k8s-lab-jdk -f dockerfiles/jdk-dockerfile .

# Java JRE
docker build -t k8s-lab-jre -f dockerfiles/jre-dockerfile .

# Nginx (nginx.conf가 dockerfiles에 있으므로 context는 dockerfiles)
docker build -t k8s-lab-nginx -f dockerfiles/nginx-dockerfile dockerfiles

# Node.js
docker build -t k8s-lab-node -f dockerfiles/node-dockerfile .
```

빌드 확인:

```bash
docker images | findstr k8s-lab
```

MariaDB 실행 예시:

```bash
docker run -d --name k8s-lab-mariadb ^
  -e MARIADB_ROOT_PASSWORD=<ROOT_DB_PASSWORD> ^
  -e MARIADB_DATABASE=appdb ^
  -e MARIADB_USER=appuser ^
  -e MARIADB_PASSWORD=<APP_DB_PASSWORD> ^
  -p 3306:3306 ^
  k8s-lab-mariadb
```
