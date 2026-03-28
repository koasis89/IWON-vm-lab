# Azure VM Shell 실행 절차서

이 문서는 [`vm-azure/readme-docker.md`](/c:/Workspace/k8s-lab-dabin/vm-azure/readme-docker.md)와 동일한 Azure VM 배포 흐름을 기준으로, Docker 없이 VM에 직접 패키지와 산출물을 배치하고 shell 스크립트로 실행하는 절차를 단계별로 정리한 문서입니다.

대상 범위:
- Terraform으로 Azure VM 생성
- Bastion을 통한 VM 접속
- 백업 산출물 전송
- VM별 런타임 직접 설치
- shell 스크립트로 서비스 실행
- `systemd` 자동기동 등록
- MariaDB 데이터 import 확인

현재 저장소 기준 주요 대상:
- `web01`: Nginx 정적 웹
- `was01`: Java WAS
- `app01`: Java App
- `smartcontract01`: SmartContract Java App
- `kafka01`: Apache Kafka 단일 브로커
- `db01`: MariaDB
- `bastion01`: 점프 호스트

사용하는 주요 백업 파일:
- [`backup/dev-web/html.zip`](/c:/Workspace/k8s-lab-dabin/backup/dev-web/html.zip)
- [`backup/dev-was/GodisWebServer-0.0.1-SNAPSHOT.jar`](/c:/Workspace/k8s-lab-dabin/backup/dev-was/GodisWebServer-0.0.1-SNAPSHOT.jar)
- [`backup/dev-app/godisappserver-0.0.1-SNAPSHOT.jar`](/c:/Workspace/k8s-lab-dabin/backup/dev-app/godisappserver-0.0.1-SNAPSHOT.jar)
- [`backup/dev-integration/IWonPaymentIntegration-0.0.1-SNAPSHOT.jar`](/c:/Workspace/k8s-lab-dabin/backup/dev-integration/IWonPaymentIntegration-0.0.1-SNAPSHOT.jar)
- [`backup/db/*.*`](/c:/Workspace/k8s-lab-dabin/backup/db/*.*)
- [`dockerfiles/nginx.conf`](/c:/Workspace/k8s-lab-dabin/dockerfiles/nginx.conf)
- [`helm_bak_20260318/dev-kafka-cluster.yaml`](/c:/Workspace/k8s-lab-dabin/helm_bak_20260318/dev-kafka-cluster.yaml)
- [`helm_bak_20260318/dev-kafka-kafka-bootstrap-svc.yaml`](/c:/Workspace/k8s-lab-dabin/helm_bak_20260318/dev-kafka-kafka-bootstrap-svc.yaml)
- [`helm_bak_20260318/dev-kafka-kafka-brokers-svc.yaml`](/c:/Workspace/k8s-lab-dabin/helm_bak_20260318/dev-kafka-kafka-brokers-svc.yaml)
- [`helm_bak_20260318/dev-kafka-entity-operator-deployment.yaml`](/c:/Workspace/k8s-lab-dabin/helm_bak_20260318/dev-kafka-entity-operator-deployment.yaml)

주의:
- 아래 `kafka01` 절차는 Strimzi Operator 환경을 VM 단일 브로커 실행 방식으로 단순화한 것입니다.
- [`vm-azure/compute.tf`](/c:/Workspace/k8s-lab-dabin/vm-azure/compute.tf) 기준 OS는 Ubuntu 22.04 LTS Gen2입니다.

## 1. 작업 전 준비

로컬 PC에 아래 도구가 있어야 합니다.

- Azure CLI
- Terraform
- SSH 클라이언트
- PowerShell

작업 시작:

```powershell
cd C:\Workspace\k8s-lab-dabin
```

도구 확인:

```powershell
az version
terraform -version
ssh -V
```

## 2. Azure 로그인 및 구독 선택

```powershell
az login
az account set --subscription "아이티아이즈-sub-gtm-msp-ktpartners-17"
az account show --output table
```

GUID로 지정할 경우:

```powershell
az account set --subscription "<SUBSCRIPTION_ID>"
```

## 3. Terraform 배포

Terraform 디렉터리로 이동:

```powershell
cd C:\Workspace\k8s-lab-dabin\vm-azure
```

초기화:

```powershell
terraform init
```

검증:

```powershell
terraform validate
terraform plan
```

적용:

```powershell
terraform apply
```

자동 승인:

```powershell
terraform apply -auto-approve
```

## 4. 배포 결과 확인

구성 시스템 IP:

```powershell
terraform output bastion_public_ip
terraform output vm_private_ips
```

현재 출력값 기준:

```powershell
terraform output bastion_public_ip
"20.214.224.224"

terraform output vm_private_ips
{
  "app01" = "10.0.2.30"
  "bastion01" = "10.0.3.10"
  "db01" = "10.0.2.50"
  "kafka01" = "10.0.2.60"
  "smartcontract01" = "10.0.2.40"
  "was01" = "10.0.2.20"
  "web01" = "10.0.2.10"
}
```

필수 확인값:
- `bastion_public_ip`
- `vm_private_ips.web01`
- `vm_private_ips.was01`
- `vm_private_ips.app01`
- `vm_private_ips.smartcontract01`
- `vm_private_ips.db01`
- `vm_private_ips.kafka01`

VM 구성 테이블:

| VM 이름 | 사설 IP | 주요 역할 | 권장 Azure VM 타입 | 오픈 포트 |
|---|---|---|---|---|
| `web01` | `10.0.2.10` | 정적 파일 / 리버스 프록시 | `Standard_B2s` | `80, 443, 22` |
| `was01` | `10.0.2.20` | WAS/JDK 기반 비즈니스 서비스 | `Standard_D2s_v5` | `8080, 22` |
| `app01` | `10.0.2.30` | 메인 애플리케이션 서비스 | `Standard_D2s_v5` | `8080, 22` |
| `smartcontract01` | `10.0.2.40` | 스마트컨트랙트 연동 서비스 | `Standard_D2s_v5` | `8080, 22` |
| `db01` | `10.0.2.50` | MariaDB DB 서버 | `Standard_D4s_v5` | `3306, 22` |
| `kafka01` | `10.0.2.60` | Kafka 브로커 | `Standard_D4s_v5` | `9092, 22` |
| `bastion01` | `10.0.3.10` | 점프 호스트 | `Standard_B1ms` | `22` |

## 5. SSH 접속 준비

SSH 키 확인:

```powershell
Test-Path "$HOME\.ssh\id_rsa"
Test-Path "$HOME\.ssh\id_rsa.pub"
```

현재 구성은 로컬 PC에서 내부 VM으로 직접 접속할 수 없는 구조입니다. 로컬 PC에서는 `bastion01`에만 접속하고, 이후 내부 VM 접속은 Bastion 안에서 수행합니다.

로컬 PC용 최소 SSH 설정 예시:
- `~/.ssh/config` 또는 `C:\Users\<사용자명>\.ssh\config`에 직접 저장

```sshconfig
Host bastion01
  HostName 20.214.224.224
  User iwon
  IdentityFile ~/.ssh/id_rsa
```

접속 테스트:

```powershell
ssh bastion01
```

Bastion 접속 후 내부 VM 접속 예시:

```bash
ssh iwon@10.0.2.10  # web01
ssh iwon@10.0.2.20  # was01
ssh iwon@10.0.2.30  # app01
ssh iwon@10.0.2.40  # smartcontract01
ssh iwon@10.0.2.50  # db01
ssh iwon@10.0.2.60  # kafka01
```

## 6. Bastion에 배포 파일 준비

로컬에서 ZIP 생성:

```powershell
cd C:\Workspace\k8s-lab-dabin
Compress-Archive -Path backup,dockerfiles\nginx.conf -DestinationPath deploy-shell-assets.zip -Force
```

Bastion으로 업로드:

```powershell
scp .\deploy-shell-assets.zip bastion01:/tmp/deploy-shell-assets.zip
```

Bastion에서 압축 해제:

```bash
ssh bastion01
sudo apt-get update
sudo apt-get install -y unzip
rm -rf /tmp/deploy-shell-assets
mkdir -p /tmp/deploy-shell-assets
unzip -o /tmp/deploy-shell-assets.zip -d /tmp/deploy-shell-assets
find /tmp/deploy-shell-assets/backup -maxdepth 3 -type f
```

압축 해제 후 Bastion 기준 주요 파일:

```bash
/tmp/deploy-shell-assets/backup/dev-web/html.zip
/tmp/deploy-shell-assets/backup/dev-was/GodisWebServer-0.0.1-SNAPSHOT.jar
/tmp/deploy-shell-assets/backup/dev-app/godisappserver-0.0.1-SNAPSHOT.jar
/tmp/deploy-shell-assets/backup/dev-integration/IWonPaymentIntegration-0.0.1-SNAPSHOT.jar
/tmp/deploy-shell-assets/backup/db/all.sql
/tmp/deploy-shell-assets/dockerfiles/nginx.conf
```

## 7. 각 VM 공통 준비

각 대상 VM에서:

```bash
sudo apt-get update
sudo apt-get install -y unzip tar curl
sudo mkdir -p /opt/vm-lab
sudo chown -R $USER:$USER /opt/vm-lab
```

구조 확인:

```bash
cd /opt/vm-lab
pwd
ls -al /opt/vm-lab
```

### 7.1 Azure Files NFS 마운트

마운트 대상:
- `was01`
- `app01`
- `smartcontract01`

마운트 경로:
- `/mnt/shared`

NFS 버전:
- `v4.1`
- `minorversion=1`

절차:

**Step 1: NFS 클라이언트 설치**

각 앱 VM에서 실행:

```bash
sudo apt-get update
sudo apt-get install -y nfs-common
```

**Step 2: 마운트 포인트 생성**

```bash
sudo mkdir -p /mnt/shared
sudo chown -R $USER:$USER /mnt/shared
```

**Step 3: 수동 마운트 테스트**

Terraform output 또는 Azure Files 구성값에서 제공되는 `storage account`와 `share name`을 사용합니다.

```bash
sudo mount -t nfs -o vers=4,minorversion=1,sec=sys <storage_account>.privatelink.file.core.windows.net:/<share_name> /mnt/shared
```

마운트 확인:

```bash
mount | grep /mnt/shared
df -h | grep /mnt/shared
ls -al /mnt/shared
```

**Step 4: /etc/fstab 영구 등록**

```bash
echo "<storage_account>.privatelink.file.core.windows.net:/<share_name>  /mnt/shared  nfs4  vers=4,minorversion=1,sec=sys,noatime,_netdev  0  0" | sudo tee -a /etc/fstab
```

등록 후 검증:

```bash
sudo umount /mnt/shared
sudo mount -a
mount | grep /mnt/shared
```

**Step 5: 권한 및 테스트**

```bash
sudo chown -R $USER:$USER /mnt/shared || true
touch /mnt/shared/.write-test
ls -al /mnt/shared/.write-test
rm -f /mnt/shared/.write-test
```

참고:
- NFS 마운트는 `was01`, `app01`, `smartcontract01`에서만 수행합니다.
- 현재 [`vm-azure/network.tf`](/c:/Workspace/k8s-lab-dabin/vm-azure/network.tf)에는 앱 서브넷 기준 NFS 관련 포트(`2049`, `111`) 허용 규칙이 포함되어 있습니다.
- 실제 마운트 값은 Terraform output, Azure Portal, 또는 별도 스토리지 문서에서 최종 확인해야 합니다.

## 8. web01 직접 설치 및 실행

Nginx 설치:

```bash
sudo apt-get update
sudo apt-get install -y nginx
```

웹 파일 배치:

```bash
scp /tmp/deploy-shell-assets/backup/dev-web/html.zip iwon@10.0.2.10:/tmp/
scp /tmp/deploy-shell-assets/dockerfiles/nginx.conf iwon@10.0.2.10:/tmp/
ssh iwon@10.0.2.10
sudo mkdir -p /var/www/html
sudo apt-get install -y unzip
cp /tmp/html.zip /opt/vm-lab/html.zip
cp /tmp/nginx.conf /opt/vm-lab/nginx.conf
sudo unzip -o /opt/vm-lab/html.zip -d /var/www/html
sudo cp /opt/vm-lab/nginx.conf /etc/nginx/sites-available/default
sudo nginx -t
```

실행 스크립트:

```bash
sudo mkdir -p /opt/scripts
cat <<'EOF' | sudo tee /opt/scripts/start-web.sh
#!/usr/bin/env bash
set -euo pipefail
sudo nginx -t
exec sudo systemctl restart nginx
EOF
sudo chmod +x /opt/scripts/start-web.sh
```

실행:

```bash
/opt/scripts/start-web.sh
sudo systemctl enable nginx
sudo systemctl status nginx --no-pager
```

## 9. was01 직접 설치 및 실행

Java 설치:

```bash
sudo apt-get update
sudo apt-get install -y openjdk-17-jre-headless
java -version
```

애플리케이션 배치:

```bash
scp /tmp/deploy-shell-assets/backup/dev-was/GodisWebServer-0.0.1-SNAPSHOT.jar iwon@10.0.2.20:/tmp/
ssh iwon@10.0.2.20
sudo mkdir -p /opt/apps/was
sudo mkdir -p /var/log/iwon
cp /tmp/GodisWebServer-0.0.1-SNAPSHOT.jar /opt/vm-lab/GodisWebServer-0.0.1-SNAPSHOT.jar
sudo cp /opt/vm-lab/GodisWebServer-0.0.1-SNAPSHOT.jar /opt/apps/was/app.jar
sudo chown -R $USER:$USER /opt/apps/was
sudo chown -R $USER:$USER /var/log/iwon
```

실행 스크립트:

```bash
sudo mkdir -p /opt/scripts
cat <<'EOF' | sudo tee /opt/scripts/start-was.sh
#!/usr/bin/env bash
set -euo pipefail
cd /opt/apps/was
exec java -jar /opt/apps/was/app.jar >> /var/log/iwon/was.log 2>&1
EOF
sudo chmod +x /opt/scripts/start-was.sh
```

systemd 등록:

```bash
cat <<'EOF' | sudo tee /etc/systemd/system/was.service
[Unit]
Description=IWON WAS Service
After=network.target

[Service]
Type=simple
User=iwon
WorkingDirectory=/opt/apps/was
ExecStart=/opt/scripts/start-was.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now was
sudo systemctl status was --no-pager
```

## 10. app01 직접 설치 및 실행

Java 설치:

```bash
sudo apt-get update
sudo apt-get install -y openjdk-17-jre-headless
java -version
```

애플리케이션 배치:

```bash
scp /tmp/deploy-shell-assets/backup/dev-app/godisappserver-0.0.1-SNAPSHOT.jar iwon@10.0.2.30:/tmp/
ssh iwon@10.0.2.30
sudo mkdir -p /opt/apps/app
sudo mkdir -p /var/log/iwon
cp /tmp/godisappserver-0.0.1-SNAPSHOT.jar /opt/vm-lab/godisappserver-0.0.1-SNAPSHOT.jar
sudo cp /opt/vm-lab/godisappserver-0.0.1-SNAPSHOT.jar /opt/apps/app/app.jar
sudo chown -R $USER:$USER /opt/apps/app
sudo chown -R $USER:$USER /var/log/iwon
```

실행 스크립트:

```bash
sudo mkdir -p /opt/scripts
cat <<'EOF' | sudo tee /opt/scripts/start-app.sh
#!/usr/bin/env bash
set -euo pipefail
cd /opt/apps/app
exec java -jar /opt/apps/app/app.jar >> /var/log/iwon/app.log 2>&1
EOF
sudo chmod +x /opt/scripts/start-app.sh
```

systemd 등록:

```bash
cat <<'EOF' | sudo tee /etc/systemd/system/app.service
[Unit]
Description=IWON App Service
After=network.target

[Service]
Type=simple
User=iwon
WorkingDirectory=/opt/apps/app
ExecStart=/opt/scripts/start-app.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now app
sudo systemctl status app --no-pager
```

## 11. smartcontract01 직접 설치 및 실행

Java 설치:

```bash
sudo apt-get update
sudo apt-get install -y openjdk-17-jre-headless
java -version
```

애플리케이션 배치:

```bash
scp /tmp/deploy-shell-assets/backup/dev-integration/IWonPaymentIntegration-0.0.1-SNAPSHOT.jar iwon@10.0.2.40:/tmp/
ssh iwon@10.0.2.40
sudo mkdir -p /opt/apps/integration
sudo mkdir -p /var/log/iwon
cp /tmp/IWonPaymentIntegration-0.0.1-SNAPSHOT.jar /opt/vm-lab/IWonPaymentIntegration-0.0.1-SNAPSHOT.jar
sudo cp /opt/vm-lab/IWonPaymentIntegration-0.0.1-SNAPSHOT.jar /opt/apps/integration/IWonPaymentIntegration-0.0.1-SNAPSHOT.jar
sudo chown -R $USER:$USER /opt/apps/integration
sudo chown -R $USER:$USER /var/log/iwon
```

실행 스크립트:

```bash
sudo mkdir -p /opt/scripts
cat <<'EOF' | sudo tee /opt/scripts/start-integration.sh
#!/usr/bin/env bash
set -euo pipefail
cd /opt/apps/integration
exec java -jar /opt/apps/integration/IWonPaymentIntegration-0.0.1-SNAPSHOT.jar >> /var/log/iwon/integration.log 2>&1
EOF
sudo chmod +x /opt/scripts/start-integration.sh
```

systemd 등록:

```bash
cat <<'EOF' | sudo tee /etc/systemd/system/integration.service
[Unit]
Description=IWON Integration Service
After=network.target

[Service]
Type=simple
User=iwon
WorkingDirectory=/opt/apps/integration
ExecStart=/opt/scripts/start-integration.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now integration
sudo systemctl status integration --no-pager
```

## 12. kafka01 직접 설치 및 실행

Java 및 도구 설치:

```bash
sudo apt-get update
sudo apt-get install -y openjdk-17-jre-headless wget tar
java -version
```

Kafka 4.1.1 설치:

```bash
KAFKA_VERSION=4.1.1
SCALA_VERSION=2.13
cd /tmp
wget -O kafka.tgz "https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"
sudo tar -xzf kafka.tgz -C /opt
sudo ln -sfn "/opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION}" /opt/kafka
sudo mkdir -p /var/lib/kafka /etc/kafka /opt/scripts
sudo chown -R $USER:$USER /var/lib/kafka /etc/kafka
```

KRaft 단일 브로커 설정:

```bash
cat <<'EOF' > /etc/kafka/server.properties
process.roles=broker,controller
node.id=1
controller.quorum.voters=1@10.0.2.60:9093

listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
advertised.listeners=PLAINTEXT://10.0.2.60:9092
listener.security.protocol.map=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT
inter.broker.listener.name=PLAINTEXT
controller.listener.names=CONTROLLER

log.dirs=/var/lib/kafka
num.partitions=1
default.replication.factor=1
min.insync.replicas=1
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1

log.retention.hours=168
log.segment.bytes=1073741824
EOF
```

스토리지 포맷:

```bash
KAFKA_CLUSTER_ID=$(/opt/kafka/bin/kafka-storage.sh random-uuid)
/opt/kafka/bin/kafka-storage.sh format -t "$KAFKA_CLUSTER_ID" -c /etc/kafka/server.properties
echo "$KAFKA_CLUSTER_ID" | tee /etc/kafka/cluster.id
```

실행 스크립트:

```bash
cat <<'EOF' | sudo tee /opt/scripts/start-kafka.sh
#!/usr/bin/env bash
set -euo pipefail
exec /opt/kafka/bin/kafka-server-start.sh /etc/kafka/server.properties
EOF
sudo chmod +x /opt/scripts/start-kafka.sh
```

systemd 등록:

```bash
cat <<'EOF' | sudo tee /etc/systemd/system/kafka.service
[Unit]
Description=Apache Kafka (KRaft Single Broker)
After=network.target

[Service]
Type=simple
User=iwon
ExecStart=/opt/scripts/start-kafka.sh
Restart=always
RestartSec=5
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now kafka
sudo systemctl status kafka --no-pager
```

동작 확인:

```bash
sudo ss -lntp | grep 9092
/opt/kafka/bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --list
/opt/kafka/bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --create --topic health-check --partitions 1 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --describe --topic health-check
```

## 13. db01 직접 설치 및 실행

MariaDB 12.1 저장소 설정:

```bash
sudo systemctl stop mariadb || true
sudo apt-get purge -y mariadb-server mariadb-client mariadb-common
sudo apt-get autoremove -y
sudo rm -rf /var/lib/mysql
sudo rm -rf /etc/mysql
sudo apt-get update
sudo apt-get install -y curl ca-certificates gnupg
curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version=12.1
```

MariaDB 설치:

```bash
sudo apt-get update
sudo apt-get install -y mariadb-server
sudo systemctl enable mariadb
sudo systemctl start mariadb
sudo systemctl status mariadb --no-pager
```

설치 확인:

```bash
mariadb --version
sudo mariadb -e "SELECT VERSION();"
```

DB 및 계정 준비:

```bash
set +H
sudo mariadb -e "CREATE DATABASE IF NOT EXISTS appdb;"
sudo mariadb -e "CREATE USER IF NOT EXISTS 'appuser'@'%' IDENTIFIED BY '<APP_DB_PASSWORD>';"
sudo mariadb -e "GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'%';"
sudo mariadb -e "FLUSH PRIVILEGES;"
```

SQL import:

```bash
scp /tmp/deploy-shell-assets/backup/db/all.sql iwon@10.0.2.50:/tmp/
ssh iwon@10.0.2.50
cp /tmp/all.sql /opt/vm-lab/all.sql
sudo mariadb appdb < /opt/vm-lab/all.sql
```

Collation 문제 확인:

```bash
mariadb --version
sudo mariadb -e "SELECT VERSION();"
grep -n "utf8mb3_uca1400_ai_ci" /opt/vm-lab/backup/db/all.sql | head
grep -n "utf8mb3_uca1400_ai_ci" /opt/vm-lab/all.sql | head
grep -oE "utf8(mb3|mb4)?_[A-Za-z0-9_]+_ci|utf8(mb3|mb4)?_[A-Za-z0-9_]+_bin|utf8(mb3|mb4)?" /opt/vm-lab/all.sql | sort -u
```

빠른 수동 조치:

```bash
cp /opt/vm-lab/all.sql /opt/vm-lab/all.sql.bak
sed -i 's/utf8mb3_uca1400_ai_ci/utf8mb3_general_ci/g' /opt/vm-lab/all.sql
sed -i 's/utf8mb4_uca1400_ai_ci/utf8mb4_general_ci/g' /opt/vm-lab/all.sql
sudo mariadb -e "DROP DATABASE IF EXISTS appdb;"
sudo mariadb -e "CREATE DATABASE appdb CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
sudo mariadb appdb < /opt/vm-lab/all.sql
```

자동 처리 스크립트:

```bash
chmod +x /opt/vm-lab/vm-azure/fix-mariadb-collation.sh
/opt/vm-lab/vm-azure/fix-mariadb-collation.sh /opt/vm-lab/all.sql appdb utf8mb3_general_ci utf8mb4_general_ci
```

재기동용 스크립트:

```bash
sudo mkdir -p /opt/scripts
cat <<'EOF' | sudo tee /opt/scripts/start-db.sh
#!/usr/bin/env bash
set -euo pipefail
exec sudo systemctl restart mariadb
EOF
sudo chmod +x /opt/scripts/start-db.sh
```

검증:

```bash
/opt/scripts/start-db.sh
sudo mariadb -e "SHOW DATABASES;"
sudo mariadb appdb -e "SHOW TABLES;"
```

## 14. 포트 및 프로세스 확인

```bash
sudo ss -lntp
ps -ef | grep java
sudo systemctl status nginx --no-pager
sudo systemctl status was --no-pager
sudo systemctl status app --no-pager
sudo systemctl status integration --no-pager
sudo systemctl status kafka --no-pager
sudo systemctl status mariadb --no-pager
```

예상 포트:
- `web01`: `80`
- `was01`: `8080`
- `app01`: `8080`
- `smartcontract01`: `8080`
- `kafka01`: `9092`
- `db01`: `3306`

## 15. 로그 확인

```bash
tail -n 100 /var/log/iwon/was.log
tail -n 100 /var/log/iwon/app.log
tail -n 100 /var/log/iwon/integration.log
sudo journalctl -u nginx -n 100 --no-pager
sudo journalctl -u integration -n 100 --no-pager
sudo journalctl -u kafka -n 100 --no-pager
sudo journalctl -u mariadb -n 100 --no-pager
```

## 16. 재배포 절차

1. 로컬에서 `deploy-shell-assets.zip` 재생성
2. Bastion으로 업로드
3. 대상 VM에 재전송
4. `/opt/vm-lab`에 재압축 해제
5. 대상 산출물 덮어쓰기
6. 해당 서비스 재시작
7. 로그 및 포트 확인

예시:

```bash
sudo cp /opt/vm-lab/backup/dev-was/GodisWebServer-0.0.1-SNAPSHOT.jar /opt/apps/was/app.jar
sudo systemctl restart was
sudo systemctl status was --no-pager
tail -n 100 /var/log/iwon/was.log
```

주의:
- MariaDB는 `all.sql`을 운영 데이터에 바로 재적용하면 안 됩니다
- 기존 프로세스와 포트 충돌 여부를 먼저 확인합니다

## 17. 장애 점검 순서

1. Terraform 출력값에서 Bastion Public IP와 각 VM 사설 IP를 다시 확인
2. 로컬 PC에서 Bastion SSH 접속 확인
3. Bastion 내부에서 각 VM SSH 접속 확인
4. `/opt/vm-lab` 아래 파일 배치 확인
5. `java -version`, `nginx -v`, `mariadb --version` 확인
6. `systemctl status`와 `journalctl`로 서비스 오류 확인
7. `ss -lntp`로 포트 충돌 확인
8. MariaDB `appdb` 생성 및 `all.sql` import 성공 여부 확인
9. MariaDB import 중 collation 오류가 나면 덤프와 현재 MariaDB 버전 호환성 점검

## 18. 운영 권장 사항

- Java 애플리케이션은 shell 스크립트 단독 실행보다 `systemd`로 관리
- 환경변수와 비밀번호는 스크립트에 직접 하드코딩하지 말고 별도 파일이나 비밀관리 체계로 분리
- 배포 전 기존 프로세스를 먼저 확인해 포트 충돌 방지
- `web01`, `was01`, `app01`, `smartcontract01`, `kafka01`, `db01`은 VM 역할별로 분리 유지

## 19. 참고 파일

- [`vm-azure/readme-docker.md`](/c:/Workspace/k8s-lab-dabin/vm-azure/readme-docker.md)
- [`backup/dev-web/html.zip`](/c:/Workspace/k8s-lab-dabin/backup/dev-web/html.zip)
- [`backup/dev-was/GodisWebServer-0.0.1-SNAPSHOT.jar`](/c:/Workspace/k8s-lab-dabin/backup/dev-was/GodisWebServer-0.0.1-SNAPSHOT.jar)
- [`backup/dev-app/godisappserver-0.0.1-SNAPSHOT.jar`](/c:/Workspace/k8s-lab-dabin/backup/dev-app/godisappserver-0.0.1-SNAPSHOT.jar)
- [`backup/dev-integration/IWonPaymentIntegration-0.0.1-SNAPSHOT.jar`](/c:/Workspace/k8s-lab-dabin/backup/dev-integration/IWonPaymentIntegration-0.0.1-SNAPSHOT.jar)
- [`backup/db/all.sql`](/c:/Workspace/k8s-lab-dabin/backup/db/all.sql)
- [`dockerfiles/nginx.conf`](/c:/Workspace/k8s-lab-dabin/dockerfiles/nginx.conf)
- [`vm-azure/compute.tf`](/c:/Workspace/k8s-lab-dabin/vm-azure/compute.tf)
- [`vm-azure/variables_vms.tf`](/c:/Workspace/k8s-lab-dabin/vm-azure/variables_vms.tf)
- [`vm-azure/outputs.tf`](/c:/Workspace/k8s-lab-dabin/vm-azure/outputs.tf)
- [`vm-azure/fix-mariadb-collation.sh`](/c:/Workspace/k8s-lab-dabin/vm-azure/fix-mariadb-collation.sh)
