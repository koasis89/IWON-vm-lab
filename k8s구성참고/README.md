# K8S-LAB: All-in-One Infrastructure & GitOps Platform

인프라 생성부터 애플리케이션 배포까지 **단 한 줄의 명령어로 완성하는
통합 자동화 프로젝트**

이 프로젝트는 **Terraform, Ansible, Helm, ArgoCD, Argo Workflows**를
유기적으로 결합하여\
Azure 클라우드 환경에서 **IaC(Infrastructure as Code)** 기반의
Kubernetes 및 CI/CD 플랫폼을 구축하는 표준 모델을 제공합니다.

------------------------------------------------------------------------

# 1. Project Overview

## 1.1 목적

본 프로젝트는 다음 목표를 위해 설계되었습니다.

-   **Kubernetes 클러스터 자동 구축**
-   **IaC 기반 인프라 관리**
-   **GitOps 기반 배포**
-   **CI/CD 자동화**
-   **클라우드 네이티브 아키텍처 표준화**

## 1.2 주요 구성 기술

  영역                사용 기술
  ------------------- -------------------------
  Infrastructure      Terraform
  Configuration       Ansible
  Container Runtime   CRI-O
  Kubernetes          K8s v1.32
  CI                  Argo Workflows + Kaniko
  CD                  ArgoCD
  Registry            Harbor
  Storage             NFS Provisioner

------------------------------------------------------------------------

# 2. Key Highlights

## 2.1 Full‑Stack Automation

`run.sh` 실행 한 번으로 다음 작업이 자동 수행됩니다.

-   VM 생성 (Terraform)
-   Kubernetes 클러스터 구축 (Ansible)
-   Harbor Registry 설치
-   Argo Workflows CI 환경 구성
-   ArgoCD GitOps 배포

------------------------------------------------------------------------

## 2.2 Security First

보안 강화를 위해 **Bastion Host 기반 SSH 터널링 구조**를 적용했습니다.

구성 특징

-   외부에서 직접 Worker 접근 불가
-   Bastion을 통한 내부 접근
-   SSH Key 자동 생성
-   인증 자동화

------------------------------------------------------------------------

## 2.3 Zero‑Configuration Connection

Terraform → Ansible 자동 연동

-   inventory 자동 생성
-   IP 수동 입력 제거
-   Bastion 터널 자동 설정

------------------------------------------------------------------------

## 2.4 Path Independence

프로젝트 실행 위치와 관계없이 동작하도록 설계

    PROJECT_ROOT=$(pwd)

WSL 내부 경로를 자동 인식합니다.

------------------------------------------------------------------------

## 2.5 Environment Self-Healing Script

실행 환경을 자동으로 진단합니다.

자동 수행 항목

-   SSH Key 생성
-   Vault Password 생성
-   Azure CLI 체크
-   필수 패키지 검사

------------------------------------------------------------------------

# 3. Quick Start

## Step 0: [선택 사항] 환경 초기화 및 최적화
만약 기존 WSL 환경이 꼬여서 재설치했거나, **방법 B(심볼릭 링크)**를 사용할 계획이라면 아래 설정을 먼저 수행하세요.

# 1. WSL 권한 설정 (방법 B 필수): 윈도우 드라이브에서도 리눅스 권한이 작동하도록 설정합니다.
```bash
# WSL 터미널에서 실행
sudo tee /etc/wsl.conf << 'EOF'
[automount]
options = "metadata"
EOF

# 2. WSL 재시작: 
# Windows PowerShell에서 실행
wsl --shutdown

# 3. 환경 초기화 (최후의 수단):
wsl --unregister Ubuntu
wsl --install -d Ubuntu
```
------------------------------------------------------------------------

## Step 1: 프로젝트 환경 구축 및 연결

VS Code 하단 터미널 우측 상단의 **화살표(∨)**를 클릭하여 **[Ubuntu (WSL)]**을 선택하세요. (목록에 없다면 터미널에 wsl 입력)

방법 A: 프로젝트 복사 (가장 추천: 안전한 격리 환경)
윈도우 드라이브와 완전히 분리된 WSL 내부 저장소에 파일을 복사합니다. 속도가 가장 빠르고 권한 문제가 없습니다.

``` bash
# 1. 현재 위치 정보를 변수에 담기
TARGET_PATH=$(pwd)

# 2. 기존 폴더 삭제 및 WSL 홈에 재생성
rm -rf ~/k8s-lab && mkdir -p ~/k8s-lab

# 3. 파일 복사 및 이동
cp -rv "$TARGET_PATH/." ~/k8s-lab/
cd ~/k8s-lab
chmod -R 755 .

# 4. VS Code로 해당 위치 열기
code .
```

방법 B: 심볼릭 링크 연결 (윈도우-WSL 실시간 공유)
윈도우 폴더를 리눅스에 연결합니다. 윈도우 탐색기 사용이 편하지만 권한 설정 시 주의가 필요합니다.
수정 사항이 실시간 반영되지만, 반드시 Step 0의 metadata 설정이 완료되어야 합니다.

``` bash
# 1. 기존 폴더/링크 삭제 후 심볼릭 링크 생성
rm -rf ~/k8s-lab
ln -s "$(pwd)" ~/k8s-lab

# 2. 이동 및 확인
cd ~/k8s-lab
```

[!IMPORTANT]
VS Code 하단 바가 **초록색 [WSL: Ubuntu]**로 표시되는지 확인하세요. 
이제 VS Code에서 파일을 수정하고 Ctrl+S를 누르면, 아래 터미널에서 즉시 업데이트된 파일로 run.sh를 실행할 수 있습니다.

------------------------------------------------------------------------

## Step 2: 필수 패키지 설치
run.sh 실행에 필요한 도구들을 한 번에 설치합니다.
프로젝트 구동 전, 전체 파일의 권한을 정리하고 Ansible Vault 비밀번호를 설정합니다.

``` bash
# 1. 로컬 패키지 저장소 정보를 최신 상태로 업데이트 및 핵심 유틸리티 한꺼번에 설치
# git: 소스 코드 버전 관리 및 레포지토리 관리
# python3-pip: Ansible 등 파이썬 기반 자동화 도구 설치 및 관리
# unzip: Terraform 바이너리 등 압축 파일 해제
# curl: 외부 서버(Azure, HashiCorp 등)에서 설치 스크립트 및 키 다운로드
# jq: 리눅스 커맨드라인에서 JSON 데이터(Terraform Output 등) 필터링 및 가공
# gnupg: 외부 레포지토리의 보안 서명(GPG Key)을 검증하고 관리
# software-properties-common: 추가 소프트웨어 저장소(PPA)를 안전하게 관리
# dos2unix: 윈도우에서 작성된 파일의 줄 바꿈(^M)을 리눅스 형식(LF)으로 강제 변환
# nfs-common: 쿠버네티스 노드들이 NFS 서버에 접속하기 위해 반드시 필요한 라이브러리
# nfs-kernel-server는 원격 서버용
sudo apt update && sudo apt install -y git python3-pip unzip curl jq dos2unix nfs-common nfs-kernel-server
```

### Azure CLI

``` bash
# Microsoft에서 제공하는 자동 설치 스크립트를 다운로드하여 즉시 실행
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### Terraform

``` bash
# GPG 키 관리 및 소프트웨어 소스 관리를 위한 필수 패키지 설치
sudo apt install -y gnupg software-properties-common

# HashiCorp 공식 GPG 키를 다운로드하여 시스템 키링에 등록 (보안 검증용)
curl -fsSL https://apt.releases.hashicorp.com/gpg \
| sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# HashiCorp 공식 레포지토리를 시스템 소프트웨어 소스 리스트에 추가
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
| sudo tee /etc/apt/sources.list.d/hashicorp.list

# 새로 추가된 레포지토리 정보를 반영하여 업데이트 후 테라폼 설치
sudo apt update && sudo apt install -y terraform
```

### Ansible 

``` bash
# 최신 패키지 정보를 반영하여 앤서블 핵심 패키지 설치
sudo apt update && sudo apt install -y ansible
```
### kubectl 설치 

``` bash
sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update && sudo apt-get install -y kubectl
```

### Helm

``` bash
# Helm 공식 설치 스크립트를 실행하여 최신 스테이블 버전 설치
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### ArgoCD CLI

``` bash
# GitHub에서 최신 버전의 ArgoCD 리눅스 실행 파일을 다운로드
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

# 다운로드한 파일을 실행 가능한 권한(555)으로 설정하여 시스템 경로(/usr/local/bin)에 설치
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# 설치 완료 후 사용한 임시 설치 파일 삭제
rm argocd-linux-amd64
```

### 기존 환경설정 파일 삭제 및 초기화

``` bash
# 윈도우에서 복사해온 뒤, 꼬인 권한과 OS가 다른 바이너리 정리
rm -rf .terraform .terraform.lock.hcl
```
------------------------------------------------------------------------

## Step 3: 권한 초기화

``` bash
# 1. 줄바꿈 LF로 통일 (윈도우 환경에서 필수)
find . -type f -not -path '*/.*' -exec dos2unix {} +

# 2. 파일 권한 기본 설정
find . -type f -not -path '*/.*' -exec chmod 644 {} +

# 3. 비밀번호 파일 생성 (우리가 아까 run.sh에 넣은 로직과 중복되지만, 미리 해두면 더 안전합니다)
# 만약 이미 .vault_pass를 만드셨다면 이 단계는 넘어가도 됩니다.
cp .vault_pass.template .vault_pass
read -p "Enter Ansible Vault Password: " pw && echo "$pw" > .vault_pass && unset pw

# 4. 보안 및 실행 권한 부여
chmod 600 .vault_pass
chmod +x run.sh
```

------------------------------------------------------------------------

# 4. Cloud Authentication

Azure 로그인

    az login

브라우저 인증 후 CLI 세션이 활성화됩니다.

------------------------------------------------------------------------

# 5. One‑Click Deployment

전체 환경을 자동 구축합니다.

    ./run.sh

실행 시 다음 단계가 자동 수행됩니다.

1️⃣ SSH Key 생성\
2️⃣ Terraform Infrastructure Provisioning\
3️⃣ Ansible Kubernetes Cluster Setup\
4️⃣ Helm 기반 서비스 설치\
5️⃣ ArgoCD GitOps 동기화

------------------------------------------------------------------------

# 6. System Architecture

## 6.1 Infrastructure Layer

Azure VM 기반 구성

-   Master Node
-   Worker Node
-   Bastion Host
-   NFS Server
-   Load Balancer

Terraform으로 자동 생성됩니다.

------------------------------------------------------------------------

## 6.2 Kubernetes Layer

Ansible을 이용해 다음 구성 요소가 설치됩니다.

-   Kubernetes
-   CRI-O Container Runtime
-   Calico CNI
-   NFS Storage Provisioner

------------------------------------------------------------------------

## 6.3 Storage Architecture

NFS Subdir External Provisioner 사용

지원 기능

-   Dynamic PVC
-   자동 PV 생성
-   Namespace 분리 스토리지

------------------------------------------------------------------------

## 6.4 CI/CD Pipeline

### CI

Argo Workflows + Kaniko

-   Docker daemon 없이 이미지 빌드
-   Harbor Registry Push

### CD

ArgoCD

-   GitOps 기반 배포
-   Git Repository 상태 자동 동기화

------------------------------------------------------------------------

# 7. Project Structure

    k8s-lab
    │
    ├ terraform/       # Azure Infrastructure IaC
    ├ ansible/         # Kubernetes Cluster Setup
    ├ helm/            # Helm Chart Values
    ├ argoCd/          # GitOps Application Manifest
    ├ docker/          # Container Build Environment
    │
    ├ run.sh           # One‑Click Automation Script
    │
    └ docs/
        ├ ARCHITECTURE_REVIEW.md
        ├ TROUBLE_SHOOTING.md
        └ CONTRIBUTING.md

------------------------------------------------------------------------

# 8. Documentation

프로젝트의 상세 기술 설명과 구축 과정에서 발생한 문제 해결 기록은 아래 문서에서 확인할 수 있습니다.

👉 [ARCHITECTURE_REVIEW.md](ARCHITECTURE_REVIEW.md)

AS-IS → TO-BE 아키텍처 개선 분석

포함 내용

- Bastion 기반 보안 아키텍처
- Terraform 모듈화 설계
- Ansible Role 구조 설계
- Legacy 구성 제거 및 리팩토링

---

👉 [TROUBLE_SHOOTING.md](TROUBLE_SHOOTING.md)

실제 구축 과정에서 해결한 주요 기술 문제 기록

예시

- Ansible SSH 터널링 문제
- kubeadm 인증서 오류
- NFS IP 동적 주입 문제
- Calico MTU 이슈

---

👉 [CONTRIBUTING.md](CONTRIBUTING.md)

협업 및 Git 전략

- `main` : 안정 버전
- `setup` : 환경 구축 브랜치
- Pull Request 기반 협업

------------------------------------------------------------------------

# Future Roadmap

향후 확장 예정

-   Istio Service Mesh
-   Keycloak Identity Provider
-   Observability Stack
    -   Prometheus
    -   Grafana
    -   Loki
    -   OpenTelemetry
-   GitOps Multi Cluster

------------------------------------------------------------------------

# Author

Cloud Native / DevOps Infrastructure Template

Terraform + Ansible + Kubernetes + GitOps 기반 표준 플랫폼 구축 프로젝트
