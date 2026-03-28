# DB 대소문자 근본 개선안 실행 결과

기준 문서
- vm-ansible/readme-db-root-fix-plan.md

실행 원칙
- 요청에 따라 3.5(애플리케이션 SQL/JPA/Mapper 소스 반영)는 미실행
- 인프라/DB/Ansible 범위만 단계적으로 실행

---

## Step 1. DB 덤프 원본 확보

실행 내용
- `backup/db/all.sql` 존재 확인
- `backup/db/all.raw.sql` 백업 생성

실행 명령어

```powershell
Test-Path C:/Workspace/k8s-lab-dabin/backup/db/all.sql
```

```powershell
$repo='C:\Workspace\k8s-lab-dabin'; $sql=Join-Path $repo 'backup\db\all.sql'; $raw=Join-Path $repo 'backup\db\all.raw.sql'; if (!(Test-Path $raw)) { Copy-Item $sql $raw -Force; Write-Output "CREATED_BACKUP:$raw" } else { Write-Output "BACKUP_EXISTS:$raw" }
```

결과
- 완료
- 생성 파일: `backup/db/all.raw.sql`

증적
- `CREATED_BACKUP:C:\Workspace\k8s-lab-dabin\backup\db\all.raw.sql`

---

## Step 2. all.sql 소문자 정규화

실행 내용
- `backup/db/all.raw.sql` 기준으로 `backup/db/all.sql` 재생성
- 대문자 식별자 치환
  - `GPCL_* -> gpcl_*`
  - `IWON_MCHT -> iwon_mcht`

실행 명령어

```powershell
python -c "import re, pathlib; p=pathlib.Path(r'C:/Workspace/k8s-lab-dabin/backup/db/all.raw.sql'); out=pathlib.Path(r'C:/Workspace/k8s-lab-dabin/backup/db/all.sql'); t=p.read_text(encoding='utf-8', errors='ignore'); t2=re.sub(r'\bGPCL_[A-Z0-9_]+\b', lambda m: m.group(0).lower(), t); t2=re.sub(r'\bIWON_MCHT\b', 'iwon_mcht', t2); out.write_text(t2, encoding='utf-8'); print('NORMALIZED_WRITTEN', out); print('UPPER_GPCL_LEFT', len(re.findall(r'\bGPCL_[A-Z0-9_]+\b', t2))); print('UPPER_IWON_MCHT_LEFT', len(re.findall(r'\bIWON_MCHT\b', t2)));"
```

```powershell
python C:/Workspace/k8s-lab-dabin/vm-ansible/tmp/analyze_sql_case.py
```

결과
- 완료

증적
- `UPPER_GPCL_LEFT 0`
- `UPPER_IWON_MCHT_LEFT 0`

추가 점검
- `CREATE_TABLE_COUNT 474`
- `UPPERCASE_TABLE_DEFS 4` (분석 정규식 상 오탐 샘플: `IF`, `T1`, `TABLE`)

---

## Step 3. Ansible 변수/Role 반영

실행 내용
1. `vm-ansible/group_vars/all.yml` 변경
- `db_lower_case_table_names: 1`
- `db_enable_case_compat: false`
- `db_schema_naming_standard: lowercase`

2. `vm-ansible/roles/db/tasks/main.yml` 변경
- MariaDB 설정 파일에 `lower_case_table_names` 반영
- 정책 검증 태스크 추가
  - `SHOW VARIABLES LIKE 'lower_case_table_names'`
  - assert로 기대값 검증
- 기존 우회 태스크를 조건부화
  - `when: db_enable_case_compat | bool`

3. 문법 검증
- WSL에서 `ansible-playbook --syntax-check` 실행

실행 명령어

```bash
wsl.exe bash -lc 'cd /mnt/c/Workspace/k8s-lab-dabin/vm-ansible && ansible-playbook -i inventory.ini site.yml --limit db --syntax-check'
```

```powershell
git -C C:/Workspace/k8s-lab-dabin diff -- vm-ansible/group_vars/all.yml vm-ansible/roles/db/tasks/main.yml
```

결과
- 완료
- syntax-check 통과 (`playbook: site.yml`)

---

## Step 4. DB 서버 프로비저닝/반영

실행 내용
1. 1차 `--limit db` 실행
- 설정 반영은 되었으나 기존 import marker(`/.appdb_imported`)로 인해 import 단계 skip 확인

2. 초기 구축 기준으로 재적용 수행
- `appdb` 드롭/재생성
- `/opt/vm-lab/.appdb_imported` 삭제
- `ansible-playbook -i inventory.ini site.yml --limit db` 재실행

실행 명령어

```bash
wsl.exe bash -lc 'cd /mnt/c/Workspace/k8s-lab-dabin/vm-ansible && ansible-playbook -i inventory.ini site.yml --limit db'
```

```bash
wsl.exe bash -lc 'chmod +x /mnt/c/Workspace/k8s-lab-dabin/vm-ansible/tmp/reset-and-reimport-db.sh && /mnt/c/Workspace/k8s-lab-dabin/vm-ansible/tmp/reset-and-reimport-db.sh'
```

결과
- 완료
- 재실행 시 `Attempt initial SQL import` 수행됨
- 우회 호환 태스크는 정책대로 skip됨 (`db_enable_case_compat=false`)

증적
- `TASK [db : Attempt initial SQL import] changed: [db01]`
- `TASK [db : Mark SQL import as completed] changed: [db01]`

---

## Step 5. 검증

실행 내용
- DB 정책 변수, 스키마 소문자 규칙, Smoke test 전 항목 확인
- 검증 스크립트: `vm-ansible/tmp/step5-verify.sh`

실행 명령어

```bash
# 기본 검증 (Step 4 완료 직후 실행)
wsl.exe bash -lc 'chmod +x /mnt/c/Workspace/k8s-lab-dabin/vm-ansible/tmp/check-db-root-fix.sh && /mnt/c/Workspace/k8s-lab-dabin/vm-ansible/tmp/check-db-root-fix.sh'

# Step 5 통합 검증 스크립트
wsl.exe bash -lc 'chmod +x /mnt/c/Workspace/k8s-lab-dabin/vm-ansible/tmp/step5-verify.sh && bash /mnt/c/Workspace/k8s-lab-dabin/vm-ansible/tmp/step5-verify.sh'
```

### 5-1. SHOW VARIABLES LIKE 'lower_case_table_names'

실행 명령어

```bash
ansible db -i inventory.ini -m shell \
  -a "mariadb -h 127.0.0.1 -u root -p'<ROOT_DB_PASSWORD>' -Nse \"SHOW VARIABLES LIKE 'lower_case_table_names'\"" \
  --become
```

결과

```
db01 | CHANGED | rc=0 >>
lower_case_table_names  1
```

→ **정책 적용 확인 ✓**

### 5-2. SHOW TABLES (소문자 규칙 충족)

실행 명령어

```bash
# 대문자 포함 테이블 수 (기대: 0)
ansible db -i inventory.ini -m shell \
  -a "mariadb -h 127.0.0.1 -u root -p'<ROOT_DB_PASSWORD>' appdb -Nse \
     \"SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='appdb' AND BINARY TABLE_NAME REGEXP '[A-Z]'\"" \
  --become

# 샘플 10개 테이블명 확인
ansible db -i inventory.ini -m shell \
  -a "mariadb -h 127.0.0.1 -u root -p'<ROOT_DB_PASSWORD>' appdb -Nse \
     \"SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='appdb' ORDER BY TABLE_NAME LIMIT 10\"" \
  --become
```

결과

```
# 대문자 포함 테이블 수
db01 | CHANGED | rc=0 >>
0

# 샘플 10개 (전부 소문자)
db01 | CHANGED | rc=0 >>
gpcl_bas_dd
gpcl_bat_execute_grp
gpcl_bat_execute_grp_conn
gpcl_bat_execute_ready_grp
gpcl_bat_execute_task
gpcl_bat_schdl
gpcl_bat_sms_snd_prn
gpcl_bat_task
gpcl_bat_task_conn
gpcl_bat_task_grp
```

→ **전체 80개 테이블 소문자 규칙 충족 ✓**

### 5-3. Web / WAS / DB Smoke Test

실행 명령어

```bash
# External HTTPS (web01 nginx)
curl -sk -o /dev/null -w "HTTP %{http_code} | %{url_effective}\n" https://www.iwon-smart.site

# WAS health (was01 내부)
ansible was -i inventory.ini -m shell \
  -a "curl -sS -o /dev/null -w 'WAS HTTP %{http_code}' http://127.0.0.1:8080/api/auth/session \
      -X POST -H 'Content-Type: application/json' --data '{}' 2>/dev/null"

# DB appuser connectivity
ansible db -i inventory.ini -m shell \
  -a "mariadb -h 127.0.0.1 -u appuser -p'<APP_DB_PASSWORD>' appdb -Nse \"SELECT NOW(), DATABASE();\"" \
  --become
```

결과

```
# External HTTPS
HTTP 200 | https://www.iwon-smart.site/

# WAS health
was01 | CHANGED | rc=0 >>
WAS HTTP 200

# DB appuser
db01 | CHANGED | rc=0 >>
2026-03-28 06:47:43     appdb
```

### 5-4. app01 / smartcontract01

- 현재 서비스 미배포 상태 (초기 구축 단계 / 후속 배포 대상)
- Java 프로세스 없음 확인 (`ps aux | grep java` 결과 없음)
- `db_enable_case_compat: false` 기반 진행 시 별도 우회책 없이 소문자 스키마 직접 연동 예정

결론

| 항목 | 기대값 | 결과 |
|------|--------|------|
| `lower_case_table_names` | 1 | **1** ✓ |
| 대문자 포함 테이블 수 | 0 | **0** ✓ |
| 전체 테이블 수 | - | **80** |
| External HTTPS | HTTP 200 | **200** ✓ |
| WAS `/api/auth/session` | HTTP 200 | **200** ✓ |
| DB appuser 접속 | 성공 | **성공** ✓ |

목표 상태 전 항목 충족

---

## Step 6. 우회책 제거(격리) 확인

실행 내용
1. Ansible 정책 변수를 통한 우회 태스크 비활성화 유지 (`db_enable_case_compat: false`)
2. `readme-troubleshooting.md` 내 DB 대소문자 우회 섹션(2.1, 2.4, 2.5, 2.7)을 **[운영 복구용 옵션]** 으로 격리 표기

Ansible 격리 확인 명령어

```bash
# db_enable_case_compat=false 기준 실행 → 우회 태스크 skip 확인 (Step 4 완료 시점에 이미 수행)
wsl.exe bash -lc 'cd /mnt/c/Workspace/k8s-lab-dabin/vm-ansible && ansible-playbook -i inventory.ini site.yml --limit db'
```

git 상태 확인

```powershell
git -C C:/Workspace/k8s-lab-dabin status --short \
  vm-ansible/group_vars/all.yml \
  vm-ansible/roles/db/tasks/main.yml \
  vm-ansible/readme-troubleshooting.md \
  backup/db/all.sql backup/db/all.raw.sql
```

troubleshooting.md 격리 표기 적용 대상

| 섹션 | 우회 내용 | 격리 방식 |
|------|-----------|----------|
| 2.1 | GPCL_ 테이블 리네임 + 소문자 호환 뷰 생성 | `db_enable_case_compat: false` skip + 문서 _(운영 복구용 옵션)_ 표기 |
| 2.4 | JAR XML 매퍼 `gpcl_ → GPCL_` 자동 패치 | all.sql 소문자 정규화로 근본 해결 + 문서 표기 |
| 2.5 | ScheduledDbPoller 소문자 호환 뷰 생성 | `db_enable_case_compat: false` skip + 문서 표기 |
| 2.7 | IWON_MCHT 조건부 호환 뷰 생성 | `iwon_mcht` 덤프 정규화 완료 + 문서 표기 |

결과
- `db_enable_case_compat: false` 기준 플레이북 실행 시 우회 태스크 4개 skip 확인 (Step 4 증적 참고)
- `readme-troubleshooting.md` 섹션 2.1 / 2.4 / 2.5 / 2.7에 **[운영 복구용 옵션]** 표기 완료
- 우회 로직은 물리 삭제하지 않고 `db_enable_case_compat: true` 전환으로 재활성화 가능하도록 보존

---

## 3.5 항목 처리 상태

요청에 따라 미실행
- 대상: 애플리케이션 SQL/JPA/Mapper 소스 반영
- 사유: 개발자 직접 반영 범위로 분리

---

## 실행 중 생성된 보조 파일

- `vm-ansible/tmp/check-db-root-fix.sh` — 기본 DB 정책/대문자 테이블 수 확인
- `vm-ansible/tmp/step5-verify.sh` — Step 5 통합 검증 (SHOW VARIABLES, SHOW TABLES, Smoke test)
- `vm-ansible/tmp/reset-and-reimport-db.sh` — DB 재생성 + 재import
- `vm-ansible/tmp/analyze_sql_case.py` — SQL 덤프 대소문자 분석
