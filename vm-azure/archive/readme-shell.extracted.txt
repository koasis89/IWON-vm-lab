Azure VM Shell 실행 절차서
이 문서는  readme-docker.md 와 동일한 Azure VM 배포 흐름을 기준으로, Docker 없이 VM에 직접 패키지와 산출물을 배치하고 shell 스크
립트로 실행하는 절차를 단계별로 정리한 문서입니다.
대상 범위:
Terraform으로 Azure VM 생성
Bastion을 통한 VM 접속
백업 산출물 전송
VM별 런타임 직접 설치
shell 스크립트로 서비스 실행
 systemd  자동기동 등록
MariaDB 데이터 import 확인
현재 저장소 기준 주요 대상:
 web01 : Nginx 정적 웹
 was01 : Java WAS
 app01 : Java App
 smartcontract01 : SmartContract Java App
 kafka01 : Apache Kafka 단일 브로커
 db01 : MariaDB
 bastion01 : 점프 호스트
사용하는 주요 백업 파일:
 backup/dev-web/usr/share/nginx/html.tar 
 backup/dev-was/workspace/GodisWebServer-0.0.1-SNAPSHOT.jar 
 backup/dev-app/workspace/workspace/godisappserver-0.0.1-SNAPSHOT.jar 
 backup/db/all.sql 
 dockerfiles/nginx.conf 
 C:\Workspace\k8s-backup\backup_all\helm_bak_20260318\dev-kafka-cluster.yaml 
 C:\Workspace\k8s-backup\backup_all\helm_bak_20260318\dev-kafka-kafka-bootstrap-svc.yaml 
 C:\Workspace\k8s-backup\backup_all\helm_bak_20260318\dev-kafka-kafka-brokers-svc.yaml 
 C:\Workspace\k8s-backup\backup_all\helm_bak_20260318\dev-kafka-entity-operator-deployment.yaml 
주의:
아래 kafka01 절차는 Strimzi Operator 환경을 VM 단일 브로커 실행 방식으로 단순화한 것입니다.
 vm-azure/compute.tf  기준 OS는 Ubuntu 22.04 LTS Gen2입니다.
1. 작업 전 준비
로컬 PC에 아래 도구가 있어야 합니다.
Azure CLI
Terraform
SSH 클라이언트

PowerShell
작업 시작:
cd C:\Workspace\vm-lab
도구 확인:
az version
terraform -version
ssh -V
2. Azure 로그인 및 구독 선택
az login
az account set --subscription "아이티아이즈-sub-gtm-msp-ktpartners-17"
az account show --output table
GUID로 지정할 경우:
az account set --subscription "<SUBSCRIPTION_ID>"
3. Terraform 배포
Terraform 디렉터리로 이동:
cd C:\Workspace\vm-lab\vm-azure
초기화:
terraform init
검증:
terraform validate
terraform plan
적용:
terraform apply
자동 승인:
terraform apply -auto-approve

4. 배포 결과 확인
구성 시스템 IP(현재 출력값 기준):
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
terraform output
terraform output bastion_public_ip
terraform output vm_private_ips
필수 확인값:
 bastion_public_ip 
 vm_private_ips.web01 
 vm_private_ips.was01 
 vm_private_ips.app01 
 vm_private_ips.db01 
VM 구성 테이블 (Korea Central 기준 권장 VM 타입)
VM 이름
사설
IP(예시)
주요 역할
권장 Azure VM
타입
기본
vCPU
기본
vMem
(GiB)
오픈
포트
(내부
기준)
비고
web01
10.0.2.10
정적 파일/
리버스 프록시
Standard_B2s
2
4
80,
443,
22
공인 직접 노출 금지
권장
was01
10.0.2.20
WAS/JDK
기반 비즈니스
서비스
Standard_D2s_v5
2
8
8080,
22
LB 또는 web
계층에서만 접근
app01
10.0.2.30
메인
애플리케이션
서비스
Standard_D2s_v5
2
8
8080,
22
내부 API 제공

VM 이름
사설
IP(예시)
주요 역할
권장 Azure VM
타입
기본
vCPU
기본
vMem
(GiB)
오픈
포트
(내부
기준)
비고
smartcontract01
10.0.2.40
스마트컨트랙트
연동 서비스
Standard_D2s_v5
2
8
8080,
22
내부 API 제공
db01
10.0.2.50
MariaDB DB
서버
Standard_D4s_v5
4
16
3306,
22
Private 전용, 백업
필수
kafka01
10.0.2.60
Kafka 브로커
(단일 노드
기본)
Standard_D4s_v5
4
16
9092,
22
운영은 3노드(01~03)
권장
bastion01
10.0.2.101
점프 호스트
(운영자 접속)
Standard_B1ms
1
2
22
SSH 소스
 162.120.184.41/32 만
허용
5. SSH 접속 준비
SSH 키 확인:
Test-Path "$HOME\.ssh\id_rsa"
Test-Path "$HOME\.ssh\id_rsa.pub"
현재 구성은 로컬 PC에서 내부 VM으로 직접 접속할 수 없는 구조입니다.
따라서 로컬 PC에서는  bastion01 에만 접속하고, 이후 내부 VM 접속은 Bastion 안에서 수행합니다.
로컬 PC용 최소 SSH 설정 예시:
~/.ssh/config 또는 C:\Users<사용자명>.ssh\config에 직접 저장해야 한다
bastion 공인 IP : 20.214.224.224
Host bastion01
  HostName 20.214.224.224
  User iwon
  IdentityFile ~/.ssh/id_rsa
접속 테스트:
ssh bastion01
Bastion 접속 후 내부 VM 접속 예시:

ssh iwon@10.0.2.10 # web01
ssh iwon@10.0.2.20 # was01
ssh iwon@10.0.2.30 # app01
ssh iwon@10.0.2.40 # smartcontract01
ssh iwon@10.0.2.50 # db01
ssh iwon@10.0.2.60 # kafka01
6. VM에 전달할 파일 준비
Dockerfile은 필요 없고 실행 산출물과 설정만 있으면 됩니다. 로컬에서 ZIP을 만듭니다.
cd C:\Workspace\vm-lab
Compress-Archive -Path backup,dockerfiles\nginx.conf -DestinationPath deploy-shell-assets.zip -Force
Bastion으로 업로드:
scp .\deploy-shell-assets.zip bastion01:/tmp/deploy-shell-assets.zip
Bastion에 접속한 뒤 각 VM으로 복사:
scp /tmp/deploy-shell-assets.zip iwon@10.0.2.10:/tmp/
scp /tmp/deploy-shell-assets.zip iwon@10.0.2.20:/tmp/
scp /tmp/deploy-shell-assets.zip iwon@10.0.2.30:/tmp/
scp /tmp/deploy-shell-assets.zip iwon@10.0.2.40:/tmp/
scp /tmp/deploy-shell-assets.zip iwon@10.0.2.50:/tmp/
scp /tmp/deploy-shell-assets.zip iwon@10.0.2.60:/tmp/
7. 공통 디렉터리 생성 및 파일 배치
아래 절차는 Bastion에서 각 내부 VM으로 접속한 후 실행합니다.
예:
ssh iwon@10.0.2.10
각 대상 VM에서 아래 명령을 실행합니다.
sudo apt-get update
sudo apt-get install -y unzip tar curl
sudo mkdir -p /opt/vm-lab
sudo unzip -o /tmp/deploy-shell-assets.zip -d /opt/vm-lab
sudo chown -R $USER:$USER /opt/vm-lab
구조 확인:

cd /opt/vm-lab
find backup -maxdepth 3 -type f
find dockerfiles -maxdepth 2 -type f
8. web01 직접 설치 및 실행
8.1 Nginx 설치
sudo apt-get update
sudo apt-get install -y nginx
8.2 웹 파일 배치
sudo mkdir -p /var/www/html
sudo tar -xf /opt/vm-lab/backup/dev-web/usr/share/nginx/html.tar -C /var/www/html
sudo cp /opt/vm-lab/dockerfiles/nginx.conf /etc/nginx/sites-available/default
sudo nginx -t
8.3 shell 스크립트 작성
 web01 에서 실행 스크립트:
sudo mkdir -p /opt/scripts
cat <<'EOF' | sudo tee /opt/scripts/start-web.sh
#!/usr/bin/env bash
set -euo pipefail
sudo nginx -t
exec sudo systemctl restart nginx
EOF
sudo chmod +x /opt/scripts/start-web.sh
실행:
/opt/scripts/start-web.sh
sudo systemctl enable nginx
sudo systemctl status nginx --no-pager
9. was01 직접 설치 및 실행
9.1 Java 설치
sudo apt-get update
sudo apt-get install -y openjdk-17-jre-headless
java -version

9.2 애플리케이션 배치
sudo mkdir -p /opt/apps/was
sudo mkdir -p /var/log/iwon
sudo cp /opt/vm-lab/backup/dev-was/workspace/GodisWebServer-0.0.1-SNAPSHOT.jar /opt/apps/was/app.jar
sudo chown -R $USER:$USER /opt/apps/was
sudo chown -R $USER:$USER /var/log/iwon
9.3 shell 스크립트 작성
sudo mkdir -p /opt/scripts /var/log/iwon
cat <<'EOF' | sudo tee /opt/scripts/start-was.sh
#!/usr/bin/env bash
set -euo pipefail
cd /opt/apps/was
exec java -jar /opt/apps/was/app.jar >> /var/log/iwon/was.log 2>&1
EOF
sudo chmod +x /opt/scripts/start-was.sh
9.4 systemd 서비스 등록
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
10. app01 직접 설치 및 실행
10.1 Java 설치
sudo apt-get update
sudo apt-get install -y openjdk-17-jre-headless
java -version

10.2 애플리케이션 배치
sudo mkdir -p /opt/apps/app
sudo mkdir -p /var/log/iwon
sudo cp /opt/vm-lab/backup/dev-app/workspace/workspace/godisappserver-0.0.1-SNAPSHOT.jar /opt/apps/app/app.jar
sudo chown -R $USER:$USER /opt/apps/app
sudo chown -R $USER:$USER /var/log/iwon
10.3 shell 스크립트 작성
sudo mkdir -p /opt/scripts /var/log/iwon
cat <<'EOF' | sudo tee /opt/scripts/start-app.sh
#!/usr/bin/env bash
set -euo pipefail
cd /opt/apps/app
exec java -jar /opt/apps/app/app.jar >> /var/log/iwon/app.log 2>&1
EOF
sudo chmod +x /opt/scripts/start-app.sh
10.4 systemd 서비스 등록
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
11. smartcontract01 직접 설치 및 실행
smartcontract01은 app01과 동일하게 Java 런타임 기반으로 실행합니다.

11.1 Java 설치
sudo apt-get update
sudo apt-get install -y openjdk-17-jre-headless
java -version
11.2 애플리케이션 배치
아래 JAR 경로는 예시이므로 실제 smartcontract 빌드 산출물 파일명에 맞게 변경합니다.
sudo mkdir -p /opt/apps/smartcontract
sudo mkdir -p /var/log/iwon
sudo cp /opt/vm-lab/backup/dev-smartcontract/workspace/smartcontractserver-0.0.1-SNAPSHOT.jar /opt/apps/smartcontract/app
sudo chown -R $USER:$USER /opt/apps/smartcontract
sudo chown -R $USER:$USER /var/log/iwon
11.3 shell 스크립트 작성
sudo mkdir -p /opt/scripts /var/log/iwon
cat <<'EOF' | sudo tee /opt/scripts/start-smartcontract.sh
#!/usr/bin/env bash
set -euo pipefail
cd /opt/apps/smartcontract
exec java -jar /opt/apps/smartcontract/app.jar >> /var/log/iwon/smartcontract.log 2>&1
EOF
sudo chmod +x /opt/scripts/start-smartcontract.sh
11.4 systemd 서비스 등록
cat <<'EOF' | sudo tee /etc/systemd/system/smartcontract.service
[Unit]
Description=IWON SmartContract Service
After=network.target
[Service]
Type=simple
User=iwon
WorkingDirectory=/opt/apps/smartcontract
ExecStart=/opt/scripts/start-smartcontract.sh
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now smartcontract
sudo systemctl status smartcontract --no-pager

12. kafka01 직접 설치 및 실행
helm 백업( helm_bak_20260318 ) 기준 Kafka 설정 핵심값은 다음과 같습니다.
Kafka 버전:  4.1.1  (Strimzi  0.50.0  기준)
리스너:  plain ,  9092 ,  tls: false 
단일 브로커/단일 복제 계수
 default.replication.factor=1 
 min.insync.replicas=1 
 offsets.topic.replication.factor=1 
12.1 Java 설치
sudo apt-get update
sudo apt-get install -y openjdk-17-jre-headless wget tar
java -version
12.2 Kafka 4.1.1 설치
KAFKA_VERSION=4.1.1
SCALA_VERSION=2.13
cd /tmp
wget -O kafka.tgz "https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"
sudo tar -xzf kafka.tgz -C /opt
sudo ln -sfn "/opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION}" /opt/kafka
sudo mkdir -p /var/lib/kafka /etc/kafka /opt/scripts
sudo chown -R $USER:$USER /var/lib/kafka /etc/kafka

12.3 KRaft 단일 브로커 설정
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
스토리지 포맷:
KAFKA_CLUSTER_ID=$(/opt/kafka/bin/kafka-storage.sh random-uuid)
/opt/kafka/bin/kafka-storage.sh format -t "$KAFKA_CLUSTER_ID" -c /etc/kafka/server.properties
echo "$KAFKA_CLUSTER_ID" | tee /etc/kafka/cluster.id
12.4 shell 스크립트 작성
cat <<'EOF' | sudo tee /opt/scripts/start-kafka.sh
#!/usr/bin/env bash
set -euo pipefail
exec /opt/kafka/bin/kafka-server-start.sh /etc/kafka/server.properties
EOF
sudo chmod +x /opt/scripts/start-kafka.sh

12.5 systemd 서비스 등록
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
12.6 동작 확인
sudo ss -lntp | grep 9092
/opt/kafka/bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --list
/opt/kafka/bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --create --topic health-check --partitions 1 --replicati
/opt/kafka/bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --describe --topic health-check
13. db01 직접 설치 및 실행
13.1 MariaDB 서버 설치
백업 원본 DB 버전이 아래와 같다면 원본은  MariaDB 12.1.2  계열입니다.
mariadb from 12.1.2-MariaDB, client 15.2 for Linux (x86_64) using readline 5.1
기존 MariaDB 제거(설치한 경우):
sudo systemctl stop mariadb || true
sudo apt-get purge -y mariadb-server mariadb-client mariadb-common
sudo apt-get autoremove -y
sudo rm -rf /var/lib/mysql
sudo rm -rf /etc/mysql
MariaDB 공식 저장소 설정 스크립트 설치:

sudo apt-get update
sudo apt-get install -y curl ca-certificates gnupg
curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version=12.1
MariaDB  12.1  설치:
sudo apt-get update
sudo apt-get install -y mariadb-server
sudo systemctl enable mariadb
sudo systemctl start mariadb
sudo systemctl status mariadb --no-pager
설치 확인:
mariadb --version
sudo mariadb -e "SELECT VERSION();"
목표:
 12.1.x  계열이 나오면 정상
패치 버전은 시점에 따라  12.1.2  이상으로 달라질 수 있음
같은  12.1  시리즈면 원본 호환성이  10.6 보다 훨씬 높음
13.2 DB 및 계정 준비
 !  문자가 bash history expansion에 걸릴 수 있으므로 먼저 아래를 실행합니다.
set +H
sudo mariadb -e "CREATE DATABASE IF NOT EXISTS appdb;"
sudo mariadb -e "CREATE USER IF NOT EXISTS 'appuser'@'%' IDENTIFIED BY '<APP_DB_PASSWORD>';"
sudo mariadb -e "GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'%';"
sudo mariadb -e "FLUSH PRIVILEGES;"
13.3 SQL 백업 import
sudo mariadb appdb < /opt/vm-lab/backup/db/all.sql
 ERROR 1273 (HY000): Unknown collation  오류가 나면 현재 MariaDB 버전이 덤프에 포함된 collation을 지원하지 않는 경우입니다.
중요:
백업 원본이  12.1.2 라면 가능하면 대상도  12.1.x  시리즈로 맞추는 편이 가장 안전합니다.
 MariaDB 10.6.x 는 원본보다 낮아서  utf8mb3_uca1400_ai_ci  같은 더 최신 collation 문제를 낼 수 있습니다.
이 경우에는 덤프의 collation을 치환하거나, 원본과 더 가까운 상위 MariaDB 버전을 사용해야 합니다.
확인:

mariadb --version
sudo mariadb -e "SELECT VERSION();"
grep -n "utf8mb3_uca1400_ai_ci" /opt/vm-lab/backup/db/all.sql | head
grep -n "utf8mb3_uca1400_ai_ci" /opt/vm-lab/backup/db/all.sql | head
grep -oE "utf8(mb3|mb4)?_[A-Za-z0-9_]+_ci|utf8(mb3|mb4)?_[A-Za-z0-9_]+_bin|utf8(mb3|mb4)?" /opt/vm-lab/backup/db/all.sql 
utf8mb4_general_ci
빠른 조치:
cp /opt/vm-lab/backup/db/all.sql /opt/vm-lab/backup/db/all.sql.bak
sed -i 's/utf8mb3_uca1400_ai_ci/utf8mb3_general_ci/g' /opt/vm-lab/backup/db/all.sql
sed -i 's/utf8mb4_uca1400_ai_ci/utf8mb4_general_ci/g' /opt/vm-lab/backup/db/all.sql
sudo mariadb -e "DROP DATABASE IF EXISTS appdb;"
sudo mariadb -e "CREATE DATABASE appdb CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
sudo mariadb appdb < /opt/vm-lab/backup/db/all.sql
자동 처리 스크립트:
스크립트 파일:  fix-mariadb-collation.sh 
기본 동작:
 all.sql 에서  utf8mb3_uca1400_* ,  utf8mb4_uca1400_*  계열 collation 자동 탐지
너무 넓은  grep -o "utf8[^' ,;)]*"  대신 collation/charset 패턴만 추출
 .bak  백업 생성
 utf8mb3 와  utf8mb4 를 구분해서 각각 다른 target collation으로 치환
DB drop/create 후 재import
사용 예시:
chmod +x /opt/vm-lab/vm-azure/fix-mariadb-collation.sh
/opt/vm-lab/vm-azure/fix-mariadb-collation.sh /opt/vm-lab/backup/db/all.sql appdb utf8mb3_general_ci utf8mb4_general_ci
파라미터:
1. SQL 파일 경로
2. DB 이름
3.  utf8mb3  target collation
4.  utf8mb4  target collation
현재처럼  utf8mb3  컬럼과  utf8mb4  테이블이 섞인 덤프에서는 하나의 collation으로 통일하면
 COLLATION ... is not valid for CHARACTER SET ...  오류가 날 수 있습니다. 가능하면 charset별로 나눠 치환합니다.
주의:
이 방식은 빠른 복구용입니다.
원본 DB와 정렬/비교 규칙이 완전히 같지 않을 수 있습니다.
운영 이관이면 가능한 한 원본과 같은 계열의 MariaDB 버전으로 맞추는 편이 더 안전합니다.
13.4 shell 스크립트 작성
MariaDB는 systemd 자체 서비스가 있으므로, 실행 스크립트는 재기동/복구용으로만 둡니다.

sudo mkdir -p /opt/scripts
cat <<'EOF' | sudo tee /opt/scripts/start-db.sh
#!/usr/bin/env bash
set -euo pipefail
exec sudo systemctl restart mariadb
EOF
sudo chmod +x /opt/scripts/start-db.sh
검증:
/opt/scripts/start-db.sh
sudo mariadb -e "SHOW DATABASES;"
sudo mariadb appdb -e "SHOW TABLES;"
14. 포트 및 프로세스 확인
각 VM에 Bastion에서 접속한 뒤 확인합니다.
sudo ss -lntp
ps -ef | grep java
sudo systemctl status nginx --no-pager
sudo systemctl status was --no-pager
sudo systemctl status app --no-pager
sudo systemctl status smartcontract --no-pager
sudo systemctl status kafka --no-pager
sudo systemctl status mariadb --no-pager
예상 포트:
 web01 :  80 
 was01 :  8080 
 app01 :  8080 
 smartcontract01 :  8080 
 kafka01 :  9092 
 db01 :  3306 
15. 로그 확인
tail -n 100 /var/log/iwon/was.log
tail -n 100 /var/log/iwon/app.log
tail -n 100 /var/log/iwon/smartcontract.log
sudo journalctl -u nginx -n 100 --no-pager
sudo journalctl -u smartcontract -n 100 --no-pager
sudo journalctl -u kafka -n 100 --no-pager
sudo journalctl -u mariadb -n 100 --no-pager

16. 재배포 절차
JAR나 웹 정적 파일, SQL 백업이 바뀌면 아래 순서로 진행합니다.
1. 로컬에서  deploy-shell-assets.zip  재생성
2. Bastion으로 업로드
3. 대상 VM에 재전송
4.  /opt/vm-lab 에 재압축 해제
5. 대상 산출물 덮어쓰기
6. 해당 서비스 재시작
7. 로그 및 포트 확인
예시:
sudo cp /opt/vm-lab/backup/dev-was/workspace/GodisWebServer-0.0.1-SNAPSHOT.jar /opt/apps/was/app.jar
sudo systemctl restart was
sudo systemctl status was --no-pager
tail -n 100 /var/log/iwon/was.log
MariaDB는  all.sql 을 다시 import하면 중복 데이터나 충돌이 생길 수 있으므로 운영 데이터에 바로 재적용하면 안 됩니다.
17. 장애 점검 순서
1. Terraform 출력값에서 Bastion Public IP와 각 VM 사설 IP를 다시 확인합니다.
2. 로컬 PC에서 Bastion SSH 접속이 되는지 먼저 확인합니다.
3. Bastion 내부에서 대상 VM 사설 IP로 SSH 접속이 되는지 확인합니다.
4.  /opt/vm-lab  아래 파일이 정상 배치되었는지 확인합니다.
5.  java -version ,  nginx -v ,  mariadb --version 으로 런타임 설치 상태를 확인합니다.
6.  systemctl status 와  journalctl 로 서비스 오류를 확인합니다.
7.  ss -lntp 로 포트 충돌 여부를 확인합니다.
8. MariaDB는  appdb  생성 여부와  all.sql  import 성공 여부를 다시 확인합니다.
9. MariaDB import 중  Unknown collation  오류가 나면 SQL 덤프와 현재 MariaDB 버전 호환성을 먼저 점검합니다.
18. 운영 권장 사항
Java 애플리케이션은 shell 스크립트 단독 실행보다  systemd 로 관리하는 편이 안정적입니다.
환경변수와 비밀번호는 스크립트에 직접 하드코딩하지 말고 별도 env 파일이나 비밀관리 체계로 분리하는 것이 좋습니다.
배포 전 기존 프로세스를 먼저 확인해 포트 충돌을 막아야 합니다.
 web01 ,  was01 ,  app01 ,  smartcontract01 ,  kafka01 ,  db01 은 VM 역할별로 분리 유지하는 편이 운영이 단순합니다.
19. 참고 파일
 readme-docker.md 
 backup/dev-web/usr/share/nginx/html.tar 
 backup/dev-was/workspace/GodisWebServer-0.0.1-SNAPSHOT.jar 
 backup/dev-app/workspace/workspace/godisappserver-0.0.1-SNAPSHOT.jar 
 backup/db/all.sql 

 dockerfiles/nginx.conf 
 vm-azure/compute.tf 
 vm-azure/variables_vms.tf 
 vm-azure/outputs.tf 
