# VM Ansible 배포

이 디렉터리는 [`vm-azure/readme-shell.md`](/c:/Workspace/k8s-lab-dabin/vm-azure/readme-shell.md)의 수동 절차를 Ansible 플레이북으로 옮긴 것입니다.

대상:
- `web01`
- `was01`
- `app01`
- `smartcontract01`
- `db01`
- `kafka01`

접속 방식:
- 로컬 PC에서 Ansible 실행
- 내부 VM 접속은 `bastion01`을 `ProxyJump`로 사용
- SSH 개인키는 로컬 `~/.ssh/id_rsa` 기준

## 1. 준비

Ansible 설치 확인:

```powershell
ansible --version
```

필수 파일:
- [`backup/dev-web/html.zip`](/c:/Workspace/k8s-lab-dabin/backup/dev-web/html.zip)
- [`backup/dev-was/GodisWebServer-0.0.1-SNAPSHOT.jar`](/c:/Workspace/k8s-lab-dabin/backup/dev-was/GodisWebServer-0.0.1-SNAPSHOT.jar)
- [`backup/dev-app/godisappserver-0.0.1-SNAPSHOT.jar`](/c:/Workspace/k8s-lab-dabin/backup/dev-app/godisappserver-0.0.1-SNAPSHOT.jar)
- [`backup/dev-integration/IWonPaymentIntegration-0.0.1-SNAPSHOT.jar`](/c:/Workspace/k8s-lab-dabin/backup/dev-integration/IWonPaymentIntegration-0.0.1-SNAPSHOT.jar)
- [`backup/db/*.*`](/c:/Workspace/k8s-lab-dabin/backup/db/*.*)
- [`vm-azure/fix-mariadb-collation.sh`](/c:/Workspace/k8s-lab-dabin/vm-azure/fix-mariadb-collation.sh)

## 2. 인벤토리 확인

기본 인벤토리:
- [`inventory.ini`](/c:/Workspace/k8s-lab-dabin/vm-ansible/inventory.ini)

현재 값:
- `bastion01`: `20.214.224.224`
- `web01`: `10.0.2.10`
- `was01`: `10.0.2.20`
- `app01`: `10.0.2.30`
- `smartcontract01`: `10.0.2.40`
- `db01`: `10.0.2.50`
- `kafka01`: `10.0.2.60`

## 3. 실행

WSL에서 Ansible 실행 위치로 이동 후 환경변수를 설정합니다.

```bash
wsl
cd /mnt/c/Workspace/k8s-lab-dabin/vm-ansible
export ANSIBLE_CONFIG=/mnt/c/Workspace/k8s-lab-dabin/vm-ansible/ansible.cfg
export ANSIBLE_HOST_KEY_CHECKING=False
export PATH="$HOME/.local/bin:$PATH"
```

현재 환경은 WSL 사용자 홈에 Ansible이 설치되어 있으므로 `~/.local/bin/ansible-playbook` 또는 위 `PATH` 설정 후 `ansible-playbook` 명령을 사용합니다.

Ping 테스트:

```bash
ansible internal_vms -m ping
```

bastion에서 내부 VM으로 직접 `scp` 하려면(1회 설정):

```bash
ansible-playbook -i inventory.ini bastion-internal-ssh-setup.yml
```

설정 후 bastion에서 아래처럼 바로 복사할 수 있습니다.

```bash
scp /tmp/deploy-shell-assets/dev-web/html.zip iwon@10.0.2.10:/tmp/
scp /tmp/deploy-shell-assets/dev-was/GodisWebServer-0.0.1-SNAPSHOT.jar iwon@10.0.2.20:/tmp/
```

전체 배포:

```bash
ansible-playbook site.yml
```

서버별 배포 예시:

```bash
ansible-playbook site.yml --limit web
ansible-playbook site.yml --limit was
ansible-playbook site.yml --limit app
ansible-playbook site.yml --limit integration
ansible-playbook site.yml --limit db
ansible-playbook site.yml --limit kafka
```

직접 전체 경로로 실행하려면 아래처럼 사용합니다.

```bash
~/.local/bin/ansible-playbook site.yml --limit web
~/.local/bin/ansible-playbook site.yml --limit db
```

## 4. 선택 설정

NFS 마운트가 필요하면 [`group_vars/all.yml`](/c:/Workspace/k8s-lab-dabin/vm-ansible/group_vars/all.yml)에서 아래 값을 수정합니다.

```yaml
nfs_mount_enabled: true
nfs_storage_account: <storage_account>
nfs_share_name: <share_name>
```

DB 계정, 비밀번호, collation도 같은 파일에서 조정합니다.

## 5. 결과

플레이북은 아래 작업을 수행합니다.
- `web01`: nginx 설치, `html.zip` 배포(`/var/www/html/dist/` 기준), `nginx.conf` 적용 (root: `/var/www/html/dist`)
- `was01`, `app01`, `smartcontract01`: JDK 설치, JAR 배포, `systemd` 등록
- `db01`: MariaDB 12.1 설치, DB/계정 생성, `all.sql` import, 필요 시 collation fix 스크립트 실행
- `kafka01`: Kafka 4.1.1 설치, KRaft 단일 브로커 설정, `systemd` 등록

### 5.0 Kafka 클라이언트 반영 내역 (was01, smartcontract01)

`helm_bak_20260318` 기준 수집한 클라이언트 정책을 VM 배포 기준으로 아래처럼 반영했습니다.

- 대상 서버: `was01`, `smartcontract01` (integration)
- 접속 엔드포인트: `10.0.2.60:9092`
- 프로토콜: `PLAINTEXT`
- TLS: 비활성 (`false`)
- SASL: 비활성 (`false`)

Ansible 적용 방식:

- `java_service` systemd 유닛에 환경변수 주입 기능 추가
- `site.yml`에서 `was`, `integration`에 Kafka 관련 환경변수 전달
- Spring 호환 변수(`SPRING_KAFKA_*`)도 함께 주입

### 5.1 외부 라우팅 기준

- `https://www.iwon-smart.site/` -> `web01:80` (정적 프론트엔드)
- `https://iwon-smart.site/` -> `web01:80` (정적 프론트엔드)
- `https://www.iwon-smart.site/app` -> `app01:8080`
- `https://iwon-smart.site/app` -> `app01:8080`
- `https://www.iwon-smart.site/api/*` -> `web01:80` -> **(프록시)** -> `was01:8080`
- `https://iwon-smart.site/api/*` -> `web01:80` -> **(프록시)** -> `was01:8080`

`www.iwon-smart.site` 는 더 이상 `was01` 기본 경로로 보내지지 않습니다.

#### API 프록시 설정 (nginx / web01)

web01의 nginx에는 `/api/*` 요청을 was01:8080으로 프록시하는 설정이 적용되어 있습니다.

**설정 파일**:
- [`dockerfiles/nginx.conf`](/c:/Workspace/k8s-lab-dabin/dockerfiles/nginx.conf)
- [`backup/dev-web/nginx.conf`](/c:/Workspace/k8s-lab-dabin/backup/dev-web/nginx.conf)

**nginx.conf 구성**:

```nginx
upstream was_backend {
    server 10.0.2.20:8080;
}

server {
  # 정적 프론트엔드 (/index.html 기준)
  location / {
    root /var/www/html/dist;
    try_files $uri $uri/ /index.html;
  }

  # API 프록시 (/api 또는 /api/* 요청 → WAS)
  location /api/ {
    # CORS preflight (OPTIONS) + 모든 응답에 CORS 헤더 추가
    add_header 'Access-Control-Allow-Origin' '*' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
    add_header 'Access-Control-Max-Age' '1728000' always;

    if ($request_method = 'OPTIONS') {
      add_header 'Content-Type' 'text/plain; charset=utf-8';
      add_header 'Content-Length' '0';
      return 204;
    }

    proxy_pass http://was_backend;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Connection "";
    
    # 응답 헤더 투과 (CORS 헤더 동기화)
    proxy_pass_header Set-Cookie;
    proxy_pass_header Vary;
  }

  # WebSocket / SockJS (/ws/* 요청 → WAS)
  location /ws/ {
    proxy_pass http://was_backend;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 86400;
    proxy_send_timeout 86400;
    proxy_buffering off;
  }
}
```

**주요 특징**:
- `/api/auth/login` 요청 → WAS의 `/api/auth/login` (전체 경로 유지)
- `/ws/*` 요청 → WAS의 SockJS/STOMP 엔드포인트로 전달
- CORS preflight (OPTIONS) 자동 처리: 204 No Content 반환
- 모든 응답에 CORS 헤더 포함 (`Access-Control-Allow-*`)
- 요청/응답 헤더 투과 (Set-Cookie, Vary 등)

**CORS 테스트 결과** (2026-03-27):
- ✅ OPTIONS preflight: 204 No Content + CORS 헤더
- ✅ POST/GET 프록시: WAS로 정상 전달 (nginx CORS 헤더 포함)
- ⚠️ WAS 응답: HTTP 401 또는 403 시 WAS의 CORS Origin 화이트리스트 확인 필요

**확인 결과 및 반영 사항**:
- nginx preflight 자체는 정상이며, 실제 403은 WAS의 Spring Security CORS 화이트리스트에서 발생
- 배포된 WAS JAR의 `SecurityConfig` 에 개발용 Origin만 포함되어 있었음
- 배포된 WAS JAR의 `WebSocketConfig` 에도 localhost origin 만 포함되어 있었음
- `site.yml` 의 `was` 배포 단계에서 `SecurityConfig.class`, `WebSocketConfig.class` 상수값을 패치해 아래 production Origin 을 허용하도록 자동화함
  - `https://www.iwon-smart.site`
  - `https://iwon-smart.site`
- `web` nginx 설정에 `/ws/` 프록시를 추가해 SockJS/WebSocket 요청이 SPA index.html 로 빠지지 않도록 수정함
- DB는 Linux MariaDB(`lower_case_table_names=0`) 환경이라 테이블명 대소문자를 구분함
- SQL dump 는 소문자 `gpcl_*` 로 import 되었지만, WAS 쿼리는 대문자 `GPCL_*` 를 사용하므로 `table doesn't exist` 가 발생할 수 있음
- `roles/db` 에 `normalize_gpcl_table_case.py` 단계를 추가해 `gpcl_*` 테이블을 `GPCL_*` 로 정규화하도록 자동화함

**다음 단계**:
1. `ansible-playbook -i inventory.ini site.yml --limit db` 로 DB 테이블명 정규화 반영
2. `ansible-playbook -i inventory.ini site.yml --limit was` 또는 기존 서비스 유지 상태에서 로그인 재검증
3. 이후 로그인 요청이 실제 계정/비밀번호 검증 단계로 진입하는지 확인

App Gateway 기본 라우팅을 web01 로 전환하려면 아래 플레이북을 실행합니다.

```bash
ansible-playbook -i inventory.ini appgw-web-routing.yml
```

---

## 6. Let's Encrypt 인증서 갱신 (`cert-renewal.yml`)

### 개요

```
was01(certbot webroot)
  → App Gateway HTTP passthrough
  → Let's Encrypt 발급
  → PFX 변환 → 로컬 저장
  → Key Vault import
  → App Gateway SSL cert 갱신
  → HTTP→HTTPS redirect 복구
```

### 사전 조건
#### DNS 설정
| 항목 | 내용 |
|------|------|
| DNS A레코드 | `iwon-smart.site` / `www.iwon-smart.site` → App Gateway 공인 IP (`20.194.3.246`) |
| Azure CLI | 실행 환경에 설치·로그인 완료 (`az login`) |
| App Gateway | 기본 경로(`/`)는 `web-backend-pool` -> web01(`10.0.2.10`), `/app`은 app01(`10.0.2.30`) |
| HTTP settings | `was-http-settings`: port 8080, protocol HTTP |

https://www.namecheap.com/ 접속
>id: itejhko
>password: 클라우드센터 공용 비번(7979포함된거)
>도메인: iwon-smart.site
>www 레코드도 동일하게 연결
DNS 관리: Namecheap 대시보드에서 직접 관리

![도메인 구매 및 DNS 설정 화면](..\vm-azure\도메인구매및설정화면.png)

### 변수 (group_vars/azure.yml)

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `az_resource_group` | `iwon-svc-rg` | 리소스 그룹 |
| `az_appgw_name` | `iwon-svc-appgw` | App Gateway 이름 |
| `az_keyvault_name` | `iwonsvckvkrc001` | Key Vault 이름 |
| `az_kv_cert_name` | `iwon-web-tls-cert` | Key Vault 인증서 이름 |
| `certbot_domains` | `[iwon-smart.site, www.iwon-smart.site]` | 발급 도메인 목록 |
| `certbot_http_port` | `8080` | ACME challenge 포트 |
| `certbot_pfx_password` | `TempPfx2026!` | PFX export 패스워드 |
| `certbot_webroot` | `/var/www/certbot` | was01 webroot 경로 |
| `certbot_pfx_local` | `tmp/iwon-smart.pfx` | 로컬 임시 PFX 경로 |
| `certbot_cleanup_local_pfx` | `true` | 완료 후 로컬 PFX 삭제 여부 |

> **보안**: `certbot_pfx_password` 는 ansible-vault 로 암호화 권장
> ```powershell
> ansible-vault encrypt group_vars/azure.yml
> ```

### 실행

```powershell
cd C:\Workspace\k8s-lab-dabin\vm-ansible

# 전체 플로우 (발급 → KV import → AppGW 갱신 → 복구)
ansible-playbook -i inventory.ini cert-renewal.yml

# 단계별 실행 (태그 사용)
ansible-playbook -i inventory.ini cert-renewal.yml --tags certbot      # 발급·PFX변환만
ansible-playbook -i inventory.ini cert-renewal.yml --tags keyvault     # KV import + AppGW SSL
ansible-playbook -i inventory.ini cert-renewal.yml --tags appgw        # AppGW 규칙 복구만
ansible-playbook -i inventory.ini cert-renewal.yml --tags appgw_prep   # 임시 passthrough 규칙 생성만
ansible-playbook -i inventory.ini cert-renewal.yml --tags appgw_restore # redirect 복구만

# vault 암호화된 경우
ansible-playbook -i inventory.ini cert-renewal.yml --ask-vault-pass
```

### 플레이북 단계 요약

| 단계 | 대상 | 태그 | 내용 |
|------|------|------|------|
| 1 | localhost | `appgw_prep` | http-redirect-rule 삭제 → 임시 passthrough 생성 |
| 2 | was01 | `certbot` | certbot 설치, 임시 웹서버 기동, 인증서 발급, PFX 변환, 로컬 저장 |
| 3 | localhost | `keyvault` | Key Vault 인증서 import, SID 조회 |
| 4 | localhost | `keyvault`, `appgw` | App Gateway SSL cert 갱신, provisioningState 폴링 |
| 5 | localhost | `appgw_restore` | 임시 규칙 삭제, http-redirect-rule 복구 |
| 6 | localhost | `cleanup` | 로컬 임시 PFX 파일 삭제 |
| 7 | localhost | `verify` | HTTPS 접속·인증서 체인·만료일·리다이렉트 검증 |
| 8 | was01 | `autoupdate` | 자동갱신 deploy hook 설치, cron/timer 활성화 |

---

## 7. HTTPS 접속 검증 (`--tags verify`)

```powershell
ansible-playbook -i inventory.ini cert-renewal.yml --tags verify
```

수행 내용:
- `https://iwon-smart.site` 로 HTTP GET → 200/301/302 응답 확인
- `openssl s_client` 로 인증서 subject, issuer, 만료일, SHA-256 fingerprint 출력
- 만료까지 30일 이하면 `[WARNING]` 메시지 출력
- `http://iwon-smart.site` 로 GET → 301/302 리다이렉트 확인

---

## 8. certbot 자동갱신 → Key Vault/App Gateway 자동 반영 (`--tags autoupdate`)

### 구조

```
매주 월요일 03:30 (cron) / certbot.timer
  └─ certbot renew --quiet
       └─ (갱신 성공 시 자동 실행)
            /etc/letsencrypt/renewal-hooks/deploy/10-azure-update.sh
              ├─ openssl pkcs12 (PFX 변환)
              ├─ az keyvault certificate import
              └─ az network application-gateway ssl-cert update
```

로그 위치:
- certbot 표준 로그: `/var/log/letsencrypt/letsencrypt.log`
- Azure 갱신 로그:   `/var/log/certbot-azure-update.log`

### 사전 준비: Azure Service Principal 생성

```powershell
# SP 생성 (Key Vault Certificates Officer + Contributor 권한)
az ad sp create-for-rbac `
  --name "certbot-kv-appgw" `
  --role "Key Vault Certificates Officer" `
  --scopes /subscriptions/<SUB_ID>/resourceGroups/iwon-svc-rg

az role assignment create `
  --assignee <CLIENT_ID> `
  --role Contributor `
  --scope /subscriptions/<SUB_ID>/resourceGroups/iwon-svc-rg/providers/Microsoft.Network/applicationGateways/iwon-svc-appgw
```

출력된 `tenantId`, `appId`, `password` 를 `group_vars/azure.yml` 에 입력한 뒤 암호화:

```powershell
# group_vars/azure.yml 내 az_sp_* 변수 채운 후
ansible-vault encrypt group_vars/azure.yml
```

### 설치

```powershell
ansible-playbook -i inventory.ini cert-renewal.yml --tags autoupdate --ask-vault-pass
```

수행 내용:
- was01에 `azure-cli` 설치 (미설치 시)
- `/etc/iwon/az-sp-env.sh` 배포 (SP 자격증명, 권한 600)
- `/etc/letsencrypt/renewal-hooks/deploy/10-azure-update.sh` 배포
- `certbot renew --dry-run` 으로 갱신 경로 검증
- `certbot.timer` 활성화 (없으면 cron 등록: 매주 월 03:30)

### 갱신 로그 확인

```bash
# was01 에서
sudo tail -f /var/log/certbot-azure-update.log
sudo systemctl status certbot.timer
sudo journalctl -u certbot -n 50
```

### 인증서 만료일 확인

```powershell
az keyvault certificate show --vault-name iwonsvckvkrc001 --name iwon-web-tls-cert --query "attributes.expires" -o tsv
```

> Let's Encrypt 인증서는 **90일 유효**, 만료 **30일 전**에 자동갱신 시도합니다.  
> deploy hook이 설치되어 있으면 갱신과 동시에 Key Vault/App Gateway가 자동으로 업데이트됩니다.
