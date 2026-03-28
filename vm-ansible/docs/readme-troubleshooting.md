# Troubleshooting 정리 (Web/WAS/DB)

이 문서는 2026-03-27 기준으로 본 저장소에서 실제로 발생한 장애와 처리 내역을 정리한 문서입니다.

## 1. 증상 요약

1. 로그인/화면 진입 시 SQL 에러 발생(DB 테이블명 대소문자 불일치)
2. WebSocket 연결 실패
3. 대시보드 API 500 에러
4. SockJS fallback 요청 오류(405/MIME)
5. `/api/error/log` 404
6. WAS 로그에 주기적 `gpcl_bat_schdl` 테이블 없음 에러
7. WAS 로그에 `IWON_MCHT` 테이블 없음(1146) 에러
8. WAS 로그에 Kafka bootstrap broker(`192.168.0.122:9092`) disconnect 경고 반복 발생
9. 브라우저 API 호출 시 `CORS policy` 오류로 요청 차단 / preflight(OPTIONS) 요청 실패
10. `godis-was` 유닛 기준 WAS 로그 조회 시 로그가 비어 있어 장애 분석 지연

---

## 2. 원인 및 처리

## 2.1 DB 테이블명 대소문자 불일치 _(운영 복구용 옵션)_

> **[운영 복구용 옵션]** 아래 "처리" 내역은 초기 긴급 우회 기록임. `lower_case_table_names=1` 정책 + all.sql 소문자 정규화 적용(`readme-db-root-fix-plan.md`) 이후 `db_enable_case_compat: false`로 비활성화됨. 운영 중 root fix 미적용 상황에서만 참조할 것.

- 증상
  - 로그인/화면 진입 시 SQL 에러 발생
  - MariaDB에서 `Table 'appdb.GPCL_*' doesn't exist` 또는 `gpcl_* doesn't exist` 유형 에러
- 원인
  - Linux MariaDB(`lower_case_table_names=0`)는 테이블명 대소문자를 구분
  - 일부 SQL/매퍼/스케줄러는 소문자 `gpcl_*`를 참조, 실제 테이블은 대문자 `GPCL_*`
- 처리
  - `roles/db/files/normalize_gpcl_table_case.py` 추가
  - `roles/db/tasks/main.yml`에 normalize 태스크 추가
  - `gpcl_* -> GPCL_*` 리네임 수행
  - 추가 호환 처리: 소문자 참조용 뷰 생성
    - `gpcl_bat_schdl -> GPCL_BAT_SCHDL`
    - `gpcl_bat_task_grp -> GPCL_BAT_TASK_GRP`
- 반영 파일
  - [vm-ansible/roles/db/files/normalize_gpcl_table_case.py](roles/db/files/normalize_gpcl_table_case.py)
  - [vm-ansible/roles/db/tasks/main.yml](roles/db/tasks/main.yml)
- 케이스별 검증 파일
  - [tools(sh-py)/check-db-case-sensitivity.sh](../tools(sh-py)/check-db-case-sensitivity.sh)
  - [tools(sh-py)/check-db-schema-vs-dump.sh](../tools(sh-py)/check-db-schema-vs-dump.sh)
  - [tools(sh-py)/rename-gpcl-tables-to-uppercase.sh](../tools(sh-py)/rename-gpcl-tables-to-uppercase.sh)

## 2.2 WebSocket/SockJS 경로 실패

- 증상
  - 브라우저에서 `wss://www.iwon-smart.site/ws/...` 실패
  - `/ws/info`가 WAS가 아니라 SPA `index.html`로 응답
  - SockJS fallback에서 405/MIME 오류
- 원인
  - Nginx에 `/ws/` 프록시 location 누락
- 처리
  - Nginx에 `/ws/` 프록시 추가
  - WebSocket Upgrade 헤더/타임아웃 설정 추가
- 반영 파일
  - [dockerfiles/nginx.conf](../dockerfiles/nginx.conf)
  - [backup/dev-web/nginx.conf](../backup/dev-web/nginx.conf)
- 케이스별 검증 파일
  - [tools(sh-py)/check-web-was-db-flow.sh](../tools(sh-py)/check-web-was-db-flow.sh)
- 검증 포인트
  - `/ws/info`가 HTML이 아니라 WAS 응답(403/401 등)인지 확인

## 2.3 WebSocket Origin 제한 + SecurityConfig Origin 상수

- 증상
  - 배포 도메인에서 STOMP/SockJS handshake 차단
- 원인
  - WAS JAR 내 `WebSocketConfig.class`에 localhost origin만 허용
- 처리
  - class 문자열 패치 파이프라인에 `WebSocketConfig.class` 추가
  - 운영 도메인으로 치환
- 반영 파일
  - [vm-ansible/site.yml](site.yml)
  - [vm-ansible/roles/java_service/tasks/main.yml](roles/java_service/tasks/main.yml)
- 케이스별 검증 파일
  - [tools(sh-py)/check-web-was-db-flow.sh](../tools(sh-py)/check-web-was-db-flow.sh)

## 2.4 대시보드 API 500 (`supply`, `onoffchain-diffs`) _(운영 복구용 옵션)_

> **[운영 복구용 옵션]** JAR XML 매퍼 패치(`gpcl_` → `GPCL_`)는 DB 테이블이 대문자였던 환경의 우회책임. all.sql 소문자 정규화 + `lower_case_table_names=1` 완료 후 소스/매퍼 직접 수정(3.5 항목)이 근본 해결. JAR 패치 로직은 운영 긴급 복구 시에만 참조.

- 증상
  - `GET /api/iwon/iwoncoin00m/supply` 500
  - `GET /api/iwon/iwoncoin00m/onoffchain-diffs` 500
- 원인
  - JAR 내부 MyBatis XML(`IWONCOIN00MMapper.xml`)에서 소문자 `gpcl_*` 참조
  - Linux MariaDB 대소문자 구분과 충돌
- 처리
  - JAR XML 매퍼 자동 패치 스크립트 추가
  - 배포 시 `gpcl_` -> `GPCL_` 치환 수행
- 반영 파일
  - [vm-ansible/roles/java_service/files/patch_jar_xml.py](roles/java_service/files/patch_jar_xml.py)
  - [vm-ansible/roles/java_service/tasks/main.yml](roles/java_service/tasks/main.yml)
  - [vm-ansible/site.yml](site.yml)
- 케이스별 검증 파일
  - [tools(sh-py)/check-dashboard-api-errors.sh](../tools(sh-py)/check-dashboard-api-errors.sh)
  - [tools(sh-py)/check-web-was-db-flow.sh](../tools(sh-py)/check-web-was-db-flow.sh)

## 2.5 ScheduledDbPoller 잔여 에러 _(운영 복구용 옵션)_

> **[운영 복구용 옵션]** 소문자 호환 뷰(`gpcl_bat_schdl`, `gpcl_bat_task_grp`) 생성은 `db_enable_case_compat: false` 기준으로 비활성화됨. 소문자 스키마 기준 소스/매퍼 수정(3.5 항목) 완료 후 이 조치는 불필요. 미적용 환경 긴급 복구 시에만 참조.

- 증상
  - WAS 로그에 주기적으로 `gpcl_bat_schdl` 없음 에러
- 원인
  - `ScheduledDbPoller.class` SQL 상수가 소문자 `gpcl_bat_schdl`, `gpcl_bat_task_grp` 사용
  - 기존 class 패치 유틸은 SQL 문자열 일부 치환에 적합하지 않음
- 처리
  - DB에 소문자 호환 뷰 생성으로 런타임 호환
- 반영 파일
  - [vm-ansible/roles/db/tasks/main.yml](roles/db/tasks/main.yml)
- 케이스별 검증 파일
  - [tools(sh-py)/check-db-case-sensitivity.sh](../tools(sh-py)/check-db-case-sensitivity.sh)
  - [tools(sh-py)/check-web-was-db-flow.sh](../tools(sh-py)/check-web-was-db-flow.sh)

## 2.6 `/api/error/log` 404

- 증상
  - 프런트에서 에러 로그 전송 시 404
- 원인
  - WAS 라우트 미구현 또는 프런트/백엔드 계약 불일치
- 상태
  - 기능상 치명도 낮음(에러 로그 수집 경로)
  - 필요 시 Nginx 204 스텁 또는 WAS endpoint 추가 검토
- 케이스별 검증 파일
  - [tools(sh-py)/check-web-was-db-flow.sh](../tools(sh-py)/check-web-was-db-flow.sh)

## 2.7 `IWON_MCHT` 조회 1146 에러 _(운영 복구용 옵션)_

> **[운영 복구용 옵션]** 조건부 호환 뷰(`IWON_MCHT`) 생성은 `db_enable_case_compat: false` 기준으로 비활성화됨. `iwon_mcht` 소문자 덤프 정규화 + 소스 수정(3.5 항목) 완료 후 이 조치는 불필요. 미적용 환경 긴급 복구 시에만 참조.

- 증상
  - WAS 로그에 `Table 'appdb.IWON_MCHT' doesn't exist` 발생
  - 머천트 목록 조회 API 호출 시 `BadSqlGrammarException` 발생
- 원인
  - Linux MariaDB 대소문자 구분으로 인해 실제 테이블(`iwon_mcht`)과 SQL 참조(`IWON_MCHT`) 불일치
- 처리
  - DB role에 조건부 호환 뷰 생성 태스크 추가
  - `IWON_MCHT` 오브젝트가 없고 `iwon_mcht`가 존재할 때만 `IWON_MCHT` 뷰 생성
- 반영 파일
  - [vm-ansible/roles/db/tasks/main.yml](roles/db/tasks/main.yml)
- 케이스별 검증 파일
  - [tools(sh-py)/check-db-case-sensitivity.sh](../tools(sh-py)/check-db-case-sensitivity.sh)
  - [tools(sh-py)/check-db-schema-vs-dump.sh](../tools(sh-py)/check-db-schema-vs-dump.sh)
  - [tools(sh-py)/check-web-was-db-flow.sh](../tools(sh-py)/check-web-was-db-flow.sh)

## 2.8 `Kafaka` 로그 에러

- 증상
  - WAS 로그에 `WARN NetworkClient ... Bootstrap broker 192.168.0.122:9092 ... disconnected`가 반복 발생
  - `consumer-testGroup-*`, `notification-consumer-*` clientId에서 주기적으로 disconnect 발생
- 검토 결과
  - Kafka 관련 로그 라인 다수 확인(경고 위주)
  - Kafka 연관 `ERROR`/`Exception` 스택트레이스는 미확인
- 원인
  - WAS가 참조 중인 Kafka bootstrap broker 주소가 `192.168.0.122:9092`
  - 현재 환경의 기대 브로커 주소는 `10.0.2.60:9092`로 불일치
- 조치 방향
  - WAS Kafka 설정의 bootstrap 서버 값을 `10.0.2.60:9092`로 통일
  - 반영 후 WAS 재기동 및 `NetworkClient disconnected` 경고 재발 여부 재확인
- 케이스별 검증 파일
  - [tools(sh-py)/check-web-was-db-flow.sh](../tools(sh-py)/check-web-was-db-flow.sh)

## 2.9 `CORS` (web 파트) 문제 및 해결

- 증상
  - 브라우저에서 API 호출 시 `CORS policy` 오류로 요청 차단
  - 사전 요청(OPTIONS) 실패 시 실제 API 호출이 진행되지 않음
- 원인
  - web(Nginx)과 WAS의 허용 Origin/헤더 정책 불일치
  - 경로별 프록시 설정에서 CORS 응답 헤더 누락 또는 preflight 미처리
- 해결
  - web(Nginx)에서 API/WebSocket 경로에 대해 CORS 응답 헤더 정책 점검 및 통일
  - OPTIONS(preflight) 요청 처리(204 응답)와 허용 메서드/헤더 정합성 확인
  - WAS 측 Origin 허용 정책과 web 도메인 정책을 동일 기준으로 맞춤
- 반영 파일
  - [dockerfiles/nginx.conf](../dockerfiles/nginx.conf)
  - [backup/dev-web/nginx.conf](../backup/dev-web/nginx.conf)
  - [vm-ansible/roles/java_service/tasks/main.yml](roles/java_service/tasks/main.yml)
- 케이스별 검증 파일
  - [tools(sh-py)/check-web-was-db-flow.sh](../tools(sh-py)/check-web-was-db-flow.sh)

## 2.10 `WAS` 파트 문제 및 해결

- 증상
  - `godis-was` 기준 조회 시 저널 로그가 비어 있어 장애 분석이 지연됨
  - WAS 로그에서 Kafka consumer disconnect 경고가 반복됨
- 원인
  - 실제 활성 서비스 유닛은 `godis-was`가 아니라 `was`
  - Kafka bootstrap 주소 불일치 이력이 있어 로그 상 반복 경고가 발생
- 해결
  - WAS JAR 클래스 상수 패치 수행 (`Security.class` 아님)
    - `BOOT-INF/classes/com/godisweb/config/SecurityConfig.class`
    - `BOOT-INF/classes/com/godisweb/config/websocket/WebSocketConfig.class`
    - 주요 치환: `http://192.168.0.122` 계열/localhost Origin -> 운영 도메인(`https://www.iwon-smart.site`, `https://iwon-smart.site`)
  - 운영 점검/재기동/로그 조회 기준 유닛을 `was`로 통일
  - WAS 유닛 파일(`/etc/systemd/system/was.service`)의 Kafka 환경변수 검증
    - `KAFKA_BOOTSTRAP_SERVERS=10.0.2.60:9092`
    - `SPRING_KAFKA_BOOTSTRAP_SERVERS=10.0.2.60:9092`
  - 반영 후 `systemctl restart was` 및 `/var/log/iwon/was.log`에서 재발 여부 확인
- 반영 파일
  - [vm-ansible/site.yml](site.yml)
  - [vm-ansible/roles/java_service/tasks/main.yml](roles/java_service/tasks/main.yml)
- 케이스별 검증 파일
  - [tools(sh-py)/check-web-was-db-flow.sh](../tools(sh-py)/check-web-was-db-flow.sh)

---

## 3. 배포/검증 절차

## 3.1 배포

```bash
ansible-playbook -i inventory.ini site.yml --limit db
ansible-playbook -i inventory.ini site.yml --limit web,was

# (필요 시) 기존 db_extra_hosts grant 실패 우회를 위한 임시 실행
cat > tmp-db-extra-vars.yml <<'YAML'
db_extra_hosts: []
YAML
ansible-playbook -i inventory.ini site.yml --limit db -e @tmp-db-extra-vars.yml
```

## 3.2 확인

```bash
# WebSocket 라우팅 확인
curl -sk -D - https://www.iwon-smart.site/ws/info -H 'Origin: https://www.iwon-smart.site'

# WAS 로그 확인
ansible was -i inventory.ini -m shell -a 'tail -n 300 /var/log/iwon/was.log' --become
```

- 기대 결과
  1. `/ws/info`가 SPA HTML이 아님
  2. `IWONCOIN00MMapper` 관련 BadSqlGrammarException 미발생
  3. `gpcl_bat_schdl` 관련 스케줄러 에러 미발생
  4. `IWON_MCHT` 관련 BadSqlGrammarException 미발생

## 3.3 검증 스크립트 파일 (tools(sh-py))

- 본 이슈 대응 시 함께 사용한/사용 가능한 검증 스크립트
  - [tools(sh-py)/check-web-was-db-flow.sh](../tools(sh-py)/check-web-was-db-flow.sh)
  - [tools(sh-py)/check-dashboard-api-errors.sh](../tools(sh-py)/check-dashboard-api-errors.sh)
  - [tools(sh-py)/check-db-case-sensitivity.sh](../tools(sh-py)/check-db-case-sensitivity.sh)
  - [tools(sh-py)/check-db-schema-vs-dump.sh](../tools(sh-py)/check-db-schema-vs-dump.sh)
  - [tools(sh-py)/fix-mariadb-collation.sh](../tools(sh-py)/fix-mariadb-collation.sh)
  - [tools(sh-py)/rename-gpcl-tables-to-uppercase.sh](../tools(sh-py)/rename-gpcl-tables-to-uppercase.sh)

- 실행 예시

```bash
# VM 전체 흐름 점검 (web/was/db)
bash ../tools(sh-py)/check-web-was-db-flow.sh

# 대시보드 API 에러 점검
bash ../tools(sh-py)/check-dashboard-api-errors.sh

# DB 대소문자/스키마 정합성 점검
bash ../tools(sh-py)/check-db-case-sensitivity.sh
bash ../tools(sh-py)/check-db-schema-vs-dump.sh
```

---

## 4. 운영 메모

1. Linux MariaDB 환경에서는 테이블명 대소문자 정책을 초기부터 통일해야 함
2. JAR 내부 XML/class SQL 문자열은 소스 없이도 배포 파이프라인에서 패치 가능하지만, 장기적으로는 원본 소스 정합성 확보가 필요
3. 신규 기능 반영 시에는 다음 두 경로를 같이 점검
   - API 매퍼(SQL) 테이블명
   - 스케줄러/배치 SQL 테이블명
