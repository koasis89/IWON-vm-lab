# Azure VM Docker 적용 절차서

이 문서는 현재 저장소의 [`dockerfiles`](/c:/Workspace/k8s-lab-dabin/dockerfiles), [`backup`](/c:/Workspace/k8s-lab-dabin/backup), [`vm-azure`](/c:/Workspace/k8s-lab-dabin/vm-azure) 구성을 기준으로 Docker 이미지를 빌드하고 Azure VM에 반영하는 전체 절차를 단계별로 정리한 문서입니다.

대상 범위:
- Terraform으로 Azure VM 생성
- Bastion을 통한 VM 접속
- 각 VM에 Docker 설치
- 저장소의 Dockerfile로 이미지 빌드
- 컨테이너 실행 및 재기동 정책 적용
- MariaDB 초기 데이터 적재 확인

현재 저장소 기준 주요 VM 매핑:
- `web01`: Nginx 계층
- `was01`: WAS 컨테이너
- `app01`: App 컨테이너
- `db01`: MariaDB 컨테이너
- `bastion01`: 점프 호스트

현재 저장소에 이미 준비된 Dockerfile:
- [`dockerfiles/nginx-dockerfile`](/c:/Workspace/k8s-lab-dabin/dockerfiles/nginx-dockerfile)
- [`dockerfiles/was-dockerfile`](/c:/Workspace/k8s-lab-dabin/dockerfiles/was-dockerfile)
- [`dockerfiles/app-dockerfile`](/c:/Workspace/k8s-lab-dabin/dockerfiles/app-dockerfile)
- [`dockerfiles/db-dockerfile`](/c:/Workspace/k8s-lab-dabin/dockerfiles/db-dockerfile)

주의:
- `smartcontract01`, `kafka01`용 Dockerfile은 현재 `dockerfiles/`에 없습니다.
- [`vm-azure/compute.tf`](/c:/Workspace/k8s-lab-dabin/vm-azure/compute.tf) 기준으로 VM OS는 Ubuntu 22.04 LTS Gen2이며, Bastion만 Public IP가 할당됩니다.

## 1. 작업 전 준비

로컬 PC에 아래 도구가 있어야 합니다.

- Azure CLI
- Terraform
- Git
- Docker Desktop 또는 Docker Engine
- SSH 클라이언트

PowerShell에서 작업 시작:

```powershell
cd C:\Workspace\k8s-lab-dabin
```

도구 확인:

```powershell
az version
terraform -version
docker version
git --version
ssh -V
```

## 2. Azure 로그인 및 구독 선택

Azure에 로그인하고 대상 구독을 선택합니다.

```powershell
az login
az account set --subscription "아이티아이즈-sub-gtm-msp-ktpartners-17"
az account show --output table
```

구독 이름 대신 GUID를 사용할 경우:

```powershell
az account set --subscription "<SUBSCRIPTION_ID>"
```

## 3. Terraform 구성 확인

현재 VM 정의와 출력값을 먼저 확인합니다.

확인 대상:
- [`vm-azure/variables_vms.tf`](/c:/Workspace/k8s-lab-dabin/vm-azure/variables_vms.tf)
- [`vm-azure/compute.tf`](/c:/Workspace/k8s-lab-dabin/vm-azure/compute.tf)
- [`vm-azure/outputs.tf`](/c:/Workspace/k8s-lab-dabin/vm-azure/outputs.tf)

특히 아래 항목을 확인합니다.

- `bastion01` Public IP 생성 여부
- `web01`, `was01`, `app01`, `db01`의 사설 IP
- 관리자 계정명
- SSH 공개키 경로

## 4. Terraform 초기화 및 배포

Terraform 작업 디렉터리로 이동합니다.

```powershell
cd C:\Workspace\k8s-lab-dabin\vm-azure
```

초기화:

```powershell
terraform init
```

유효성 점검:

```powershell
terraform validate
```

실행 계획 확인:

```powershell
terraform plan
```

배포:

```powershell
terraform apply
```

자동 승인으로 진행할 경우:

```powershell
terraform apply -auto-approve
```

## 5. 배포 결과 확인

배포 완료 후 출력값을 확인합니다.

```powershell
terraform output
terraform output bastion_public_ip
terraform output vm_private_ips
```

확인할 값:
- `bastion_public_ip`
- `vm_private_ips.web01`
- `vm_private_ips.was01`
- `vm_private_ips.app01`
- `vm_private_ips.db01`

## 6. SSH 접속 준비

로컬 PC에 SSH 개인키가 있어야 합니다.

확인:

```powershell
Test-Path "$HOME\.ssh\id_rsa"
Test-Path "$HOME\.ssh\id_rsa.pub"
```

필요하면 Bastion을 경유하는 SSH 설정을 작성합니다. 예시는 아래와 같습니다.

```sshconfig
Host bastion01
  HostName <BASTION_PUBLIC_IP>
  User iwon
  IdentityFile ~/.ssh/id_rsa

Host web01
  HostName 10.0.2.10
  User iwon
  IdentityFile ~/.ssh/id_rsa
  ProxyJump bastion01

Host was01
  HostName 10.0.2.20
  User iwon
  IdentityFile ~/.ssh/id_rsa
  ProxyJump bastion01

Host app01
  HostName 10.0.2.30
  User iwon
  IdentityFile ~/.ssh/id_rsa
  ProxyJump bastion01

Host db01
  HostName 10.0.2.50
  User iwon
  IdentityFile ~/.ssh/id_rsa
  ProxyJump bastion01
```

접속 테스트:

```powershell
ssh bastion01
ssh web01
ssh was01
ssh app01
ssh db01
```

## 7. 소스 전달 방식 결정

적용 방식은 2가지가 있습니다.

1. VM에서 직접 Git clone 후 빌드
2. 로컬에서 소스를 Bastion 경유로 복사 후 빌드

현재 저장소 구조상 가장 단순한 방법은 `web01`, `was01`, `app01`, `db01`에 전체 저장소를 복사한 뒤 각 VM에서 필요한 Dockerfile만 빌드하는 방식입니다.

권장 원격 작업 경로:

```bash
/opt/k8s-lab-dabin
```

## 8. VM에 Docker 설치

각 대상 VM에서 아래 절차를 수행합니다.

대상 VM:
- `web01`
- `was01`
- `app01`
- `db01`

Ubuntu 기준 설치 명령:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
```

설치 확인:

```bash
docker --version
sudo docker version
sudo systemctl status docker --no-pager
```

`usermod` 적용 후에는 다시 로그인하는 것이 안전합니다.

## 9. 저장소 파일을 Azure VM으로 복사

로컬 PowerShell에서 각 VM으로 저장소를 전송합니다.

먼저 압축:

```powershell
cd C:\Workspace\k8s-lab-dabin
Compress-Archive -Path dockerfiles,backup -DestinationPath k8s-docker-assets.zip -Force
```

Bastion으로 업로드:

```powershell
scp .\k8s-docker-assets.zip bastion01:/tmp/k8s-docker-assets.zip
```

Bastion에서 각 VM으로 전달:

```bash
scp /tmp/k8s-docker-assets.zip iwon@10.0.2.10:/tmp/
scp /tmp/k8s-docker-assets.zip iwon@10.0.2.20:/tmp/
scp /tmp/k8s-docker-assets.zip iwon@10.0.2.30:/tmp/
scp /tmp/k8s-docker-assets.zip iwon@10.0.2.50:/tmp/
```

각 VM에서 압축 해제:

```bash
sudo mkdir -p /opt/k8s-lab-dabin
sudo apt-get install -y unzip
sudo unzip -o /tmp/k8s-docker-assets.zip -d /opt/k8s-lab-dabin
sudo chown -R $USER:$USER /opt/k8s-lab-dabin
```

구조 확인:

```bash
cd /opt/k8s-lab-dabin
find dockerfiles -maxdepth 1 -type f
find backup -maxdepth 2 -type f
```

## 10. VM별 Docker 이미지 빌드

각 VM에서 자기 역할에 맞는 이미지만 빌드합니다.

### 10.1 web01

```bash
cd /opt/k8s-lab-dabin
docker build -t k8s-lab-nginx -f dockerfiles/nginx-dockerfile dockerfiles
```

### 10.2 was01

```bash
cd /opt/k8s-lab-dabin
docker build -t k8s-lab-was -f dockerfiles/was-dockerfile .
```

### 10.3 app01

```bash
cd /opt/k8s-lab-dabin
docker build -t k8s-lab-app -f dockerfiles/app-dockerfile .
```

### 10.4 db01

[`dockerfiles/db-dockerfile`](/c:/Workspace/k8s-lab-dabin/dockerfiles/db-dockerfile)는 현재 `mariadb:latest` 기반이며, `backup/db/all.sql`을 초기 스키마/데이터로 포함합니다.

```bash
cd /opt/k8s-lab-dabin
docker build -t k8s-lab-mariadb -f dockerfiles/db-dockerfile .
```

빌드 결과 확인:

```bash
docker images | grep k8s-lab
```

## 11. 기존 프로세스 정리 여부 확인

컨테이너로 전환하기 전에 기존 방식으로 애플리케이션이 떠 있는지 확인합니다.

예시:

```bash
ps -ef | grep java
ps -ef | grep nginx
sudo ss -lntp
docker ps -a
```

기존 systemd 서비스나 프로세스가 이미 사용 중이면 포트 충돌이 발생할 수 있습니다.

점검 대상:
- `80`, `443` on `web01`
- `8080` on `was01`
- `8080` on `app01`
- `3306` on `db01`

## 12. 컨테이너 실행

### 12.1 db01에서 MariaDB 실행

MariaDB는 데이터 영속성을 위해 호스트 디렉터리를 마운트합니다.

```bash
sudo mkdir -p /data/mariadb
sudo chown -R 999:999 /data/mariadb || true
docker run -d \
  --name mariadb \
  --restart unless-stopped \
  -e MARIADB_ROOT_PASSWORD=<ROOT_DB_PASSWORD> \
  -e MARIADB_DATABASE=appdb \
  -e MARIADB_USER=appuser \
  -e MARIADB_PASSWORD=<APP_DB_PASSWORD> \
  -p 3306:3306 \
  -v /data/mariadb:/var/lib/mysql \
  k8s-lab-mariadb
```

중요:
- `/var/lib/mysql`이 비어 있는 첫 실행 시에만 `/docker-entrypoint-initdb.d/01-all.sql`이 적용됩니다.
- 이미 데이터가 존재하면 SQL 초기화는 다시 실행되지 않습니다.

### 12.2 was01에서 WAS 실행

```bash
docker run -d \
  --name was \
  --restart unless-stopped \
  -p 8080:8080 \
  k8s-lab-was
```

### 12.3 app01에서 App 실행

```bash
docker run -d \
  --name app \
  --restart unless-stopped \
  -p 8080:8080 \
  k8s-lab-app
```

### 12.4 web01에서 Nginx 실행

포트 사용 중인 기존 Nginx가 없다면:

```bash
docker run -d \
  --name web \
  --restart unless-stopped \
  -p 80:80 \
  k8s-lab-nginx
```

HTTPS까지 직접 처리할 경우에는 인증서 마운트와 `443` 포트 구성이 추가로 필요합니다.

## 13. 컨테이너 상태 검증

각 VM에서 아래를 확인합니다.

```bash
docker ps
docker logs --tail 100 mariadb
docker logs --tail 100 was
docker logs --tail 100 app
docker logs --tail 100 web
```

포트 상태 확인:

```bash
sudo ss -lntp
```

헬스체크 예시:

```bash
curl -I http://127.0.0.1
curl http://127.0.0.1:8080
```

## 14. MariaDB 초기 데이터 적재 검증

`db01`에서 MariaDB가 정상 기동되면 SQL 초기화 여부를 확인합니다.

```bash
docker exec -it mariadb mariadb -u root -p
```

접속 후 확인 예시:

```sql
SHOW DATABASES;
USE appdb;
SHOW TABLES;
```

빠른 1회성 확인:

```bash
docker exec mariadb mariadb -u root -p<ROOT_DB_PASSWORD> -e "SHOW DATABASES;"
docker exec mariadb mariadb -u root -p<ROOT_DB_PASSWORD> -e "USE appdb; SHOW TABLES;"
```

## 15. 재배포 절차

Dockerfile 또는 `backup/` 내용이 바뀌면 아래 순서로 재배포합니다.

1. 로컬에서 `dockerfiles`, `backup` 최신화
2. ZIP 재생성
3. VM에 재전송
4. 대상 VM에서 이미지 재빌드
5. 기존 컨테이너 중지 및 삭제
6. 새 컨테이너 실행
7. 로그 및 포트 검증

예시:

```bash
docker stop mariadb
docker rm mariadb
docker build -t k8s-lab-mariadb -f dockerfiles/db-dockerfile .
docker run -d \
  --name mariadb \
  --restart unless-stopped \
  -e MARIADB_ROOT_PASSWORD=<ROOT_DB_PASSWORD> \
  -e MARIADB_DATABASE=appdb \
  -e MARIADB_USER=appuser \
  -e MARIADB_PASSWORD=<APP_DB_PASSWORD> \
  -p 3306:3306 \
  -v /data/mariadb:/var/lib/mysql \
  k8s-lab-mariadb
```

MariaDB는 기존 데이터 디렉터리를 유지하면 초기 SQL이 다시 실행되지 않는 점을 반드시 감안합니다.

## 16. 운영 권장 사항

- 컨테이너 이름은 VM 역할과 동일하게 단순하게 유지합니다.
- `--restart unless-stopped`를 기본 적용합니다.
- 데이터성 컨테이너는 반드시 호스트 볼륨을 사용합니다.
- 애플리케이션 환경변수는 실행 명령에 직접 쓰기보다 `.env` 또는 비밀관리 체계로 분리하는 것이 좋습니다.
- 장기적으로는 VM별 수동 실행 대신 `docker compose` 또는 systemd unit으로 고정하는 것이 운영에 유리합니다.

## 17. 장애 점검 순서

1. Terraform 출력값에서 Bastion Public IP와 대상 VM 사설 IP를 다시 확인합니다.
2. Bastion SSH 접속이 되는지 확인합니다.
3. 대상 VM에서 Docker 서비스가 실행 중인지 확인합니다.
4. 이미지 빌드 경로가 `/opt/k8s-lab-dabin` 기준으로 맞는지 확인합니다.
5. `docker logs`로 컨테이너 오류를 확인합니다.
6. 포트 충돌 여부를 `ss -lntp`로 확인합니다.
7. MariaDB는 `/data/mariadb`에 기존 데이터가 있어 초기화 SQL이 생략된 것은 아닌지 확인합니다.

## 18. 참고 파일

- [`dockerfiles/db-dockerfile`](/c:/Workspace/k8s-lab-dabin/dockerfiles/db-dockerfile)
- [`dockerfiles/app-dockerfile`](/c:/Workspace/k8s-lab-dabin/dockerfiles/app-dockerfile)
- [`dockerfiles/was-dockerfile`](/c:/Workspace/k8s-lab-dabin/dockerfiles/was-dockerfile)
- [`dockerfiles/nginx-dockerfile`](/c:/Workspace/k8s-lab-dabin/dockerfiles/nginx-dockerfile)
- [`dockerfiles/README.md`](/c:/Workspace/k8s-lab-dabin/dockerfiles/README.md)
- [`vm-azure/compute.tf`](/c:/Workspace/k8s-lab-dabin/vm-azure/compute.tf)
- [`vm-azure/variables_vms.tf`](/c:/Workspace/k8s-lab-dabin/vm-azure/variables_vms.tf)
- [`vm-azure/outputs.tf`](/c:/Workspace/k8s-lab-dabin/vm-azure/outputs.tf)
- [`vm-azure/readme-sh.md`](/c:/Workspace/k8s-lab-dabin/vm-azure/readme-sh.md)
