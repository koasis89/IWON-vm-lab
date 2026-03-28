# DB 테이블명 대소문자 근본 개선안 (초기 구축 단계용)

작성 목적
- 현재는 서비스 운영 중 긴급복구를 위해 우회(뷰, JAR 패치, 대문자 정규화)가 포함되어 있음
- 하지만 지금은 인프라 설치 + 개발소스 반영 단계이므로, DB 표준을 먼저 고정하는 근본 개선안을 적용하는 것이 맞음
- 본 문서는 vm-ansible, DB 설정, all.sql(백업본)까지 한 번에 정렬하기 위한 실행안임

적용 범위
- Ansible: vm-ansible/roles/db/tasks/main.yml, vm-ansible/group_vars/all.yml
- DB 설정: MariaDB my.cnf 계열(현재 60-appdb.cnf)
- SQL 덤프: backup/db/all.sql (group_vars/all.yml의 db_sql_src 기준)

---

## 1. 목표 상태 (Target State)

1. 테이블/뷰/인덱스 명명 규칙을 소문자로 통일
- 예: GPCL_USER -> gpcl_user

2. MariaDB 설정을 lower_case_table_names=1로 고정
- 초기 구축 시점에만 적용
- 동일 데이터 디렉터리에서 정책을 바꾸는 재초기화 리스크를 제거

3. all.sql 자체를 소문자 표준에 맞춰 정규화
- import 이후 별도 보정 스크립트에 의존하지 않음

4. 애플리케이션 SQL/JPA/Mapper도 소문자 기준으로 유지
- DB 엔진 정책 의존도를 낮춤

---

## 3. 실행 전략 (권장 순서)

### 3.1 사전 원칙

- 표준 테이블명은 소문자로 확정
- 신규 SQL/Mapper 리뷰 규칙에 소문자 강제 추가
- 초기 설치 단계에서는 DB 데이터 디렉터리 재생성 허용

### 3.2 all.sql 정규화

작업 내용
1. backup/db/all.sql에서 스키마 오브젝트 명칭을 소문자로 정렬
2. 테이블 생성문, FK 참조, 인덱스/뷰 명칭까지 동일 기준으로 맞춤
3. 정규화 후 스테이징 import 검증

검증 기준
- SHOW TABLES 결과에 대문자 오브젝트가 없어야 함
- 애플리케이션 주요 API 조회 SQL이 에러 없이 동작

### 3.3 MariaDB 설정 고정

적용 설정
- [mysqld]
- lower_case_table_names=1
- bind-address는 기존 변수(db_bind_address) 유지

주의
- lower_case_table_names는 초기화 상태에서 고정해야 안전함
- 이미 데이터가 있는 서버라면 덤프/재초기화/복원 절차 필요

### 3.4 Ansible 역할 정리

초기 구축 모드에서 다음을 목표로 함
1. import 전 DB 정책(lower_case_table_names=1)을 먼저 반영
2. 우회성 태스크 제거 또는 기본 비활성화

정리 대상(현재 우회 태스크)
- normalize_gpcl_table_case.py 실행
- gpcl_bat_schdl, gpcl_bat_task_grp 호환 뷰 생성
- IWON_MCHT 호환 뷰 생성

권장 방식
- 변수 기반 스위치 도입
  - db_enable_case_compat: false (기본)
  - 필요 시에만 true로 운영 복구 모드 활성화

### 3.5 애플리케이션 SQL/JPA/Mapper 정렬(개발자가 직접 반영)
- SQL 파일과 JPA 엔티티/매퍼에서 테이블명 식별자를 소문자로 통일
- 예: `SELECT * FROM GPCL_USER` -> `SELECT * FROM gpcl_user

핵심 결론
- MariaDB에서 lower_case_table_names=1이면 DB명/테이블명 식별자는 대소문자 비구분으로 동작함
- 따라서 SQL/JPA/Mapper에서 `GPCL_USER`와 `gpcl_user`를 혼용해도 대부분 동일하게 조회됨

단, "아무렇게나 써도 100% 안전"은 아님
1. 적용 범위 한계
- 주로 DB명/테이블명 식별자 동작에 대한 정책이며, 문자열 값 비교나 비즈니스 로직 문제를 해결하지는 않음

2. 이식성 리스크
- 향후 PostgreSQL 등 다른 DB로 마이그레이션할 경우 식별자 대소문자 규칙이 달라 재이슈 가능

3. 프레임워크/도구 변수
- JPA naming strategy, quoted identifier, Flyway/Liquibase, native query 설정에 따라 예외 케이스 발생 가능

4. 환경 드리프트 리스크
- 환경별 lower_case_table_names 값이 다르면 개발/운영 동작이 달라질 수 있음

권장 정책
- 인프라 초기 구축에서는 lower_case_table_names=1로 고정
- 동시에 SQL/JPA/Mapper와 all.sql을 소문자 표준으로 통일해 장기 리스크를 최소화

---

## 4. vm-ansible 변경 설계안

### 4.1 group_vars/all.yml

추가/변경 제안
- db_lower_case_table_names: 1
- db_enable_case_compat: false
- db_schema_naming_standard: lowercase

효과
- 정책 의도를 변수로 명시하여 역할 태스크가 일관되게 동작

### 4.2 roles/db/tasks/main.yml

변경 제안
1. MariaDB 설정 파일에 lower_case_table_names 항목 추가
2. DB 초기 import 전에 MariaDB 재시작 + 상태 확인
3. 아래 우회 태스크를 조건부로 감싸기
- when: db_enable_case_compat | bool

조건부 전환 대상
- Upload gpcl table case normalization helper
- Normalize gpcl table names to uppercase for Linux MariaDB
- Create lowercase compatibility views for legacy scheduler SQL
- Create uppercase compatibility view for IWON merchant table

### 4.3 site.yml

현재 구조 유지 가능
- hosts: db에서 db role 호출은 그대로 사용
- 정책은 group_vars와 db role 내부 분기에서 처리

---

## 5. all.sql 운영 가이드

권장 파일 운영
1. 원본 보관
- backup/db/all.raw.sql

2. 적용본
- backup/db/all.sql (실제 Ansible import 대상)

3. 릴리즈 기준
- all.sql은 소문자 규칙 검증 통과본만 반영

검증 체크리스트
- 대문자 테이블명 잔존 여부 검사
- FK 참조 무결성
- 초기 데이터 로드 성공
- 주요 API smoke test 성공

---

## 6. 단계별 적용 절차 (초기 구축 기준)

1단계. DB 덤프 원본 확보
- 기존 all.sql을 all.raw.sql로 백업

2단계. all.sql 소문자 정규화
- 스키마 오브젝트/참조 일관화

3단계. Ansible 변수/role 반영
- db_lower_case_table_names=1
- db_enable_case_compat=false

4단계. 신규 DB 서버 프로비저닝
- 데이터 디렉터리 초기화 상태에서 MariaDB 설치/기동
- 설정 반영 후 import 실행

5단계. 검증
- SHOW VARIABLES LIKE lower_case_table_names 결과가 1
- SHOW TABLES 결과 소문자 규칙 충족
- web/was/app/integration smoke test 통과

6단계. 우회책 제거 확인
- readme-troubleshooting의 우회 항목을 "운영 복구용 옵션"으로 격리 표기

---

## 7. 리스크와 대응

리스크
- 일부 소스(SQL/Mapper/JPA)가 대문자 하드코딩일 수 있음
- 외부 인터페이스 SQL이 숨겨져 있을 수 있음

대응
- 초기 구축 단계에서 통합 스모크 테스트를 필수화
- 누락 쿼리 발견 시 소스 수정 후 all.sql/테스트 케이스에 즉시 반영
- 우회모드(db_enable_case_compat=true)를 비상 롤백 옵션으로만 유지

---

## 8. 최종 권고

- 현재 단계에서는 lower_case_table_names=1 + 소문자 스키마 표준화가 맞는 방향임
- 다만 운영 복구용으로 만든 기존 우회 로직은 즉시 삭제하지 말고, 변수로 비활성화한 상태로 1~2 릴리즈 보관 후 제거 권장
- 이 방식이면 "초기 구축의 깔끔함"과 "비상시 복구 안전장치"를 동시에 확보할 수 있음
