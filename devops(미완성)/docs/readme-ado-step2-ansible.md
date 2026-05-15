# 2단계 가이드: Terraform 출력 기반 Ansible 구성

이 단계는 Terraform 출력값을 읽어 Ansible 인벤토리를 동적으로 만들고, Managed Agent에서 bastion 경유로 VM 구성 자동화를 수행하는 단계입니다.

대상 파일:
- [devops/azure-pipelines-vm.yml](../../devops/azure-pipelines-vm.yml)
- [devops/scripts/generate_inventory_from_tf.py](../../devops/scripts/generate_inventory_from_tf.py)
- [vm-ansible/site.yml](../../vm-ansible/site.yml)
- [vm-ansible/ansible.cfg](../../vm-ansible/ansible.cfg)

## 생성 절차

1. SSH 키를 Secure Files에 등록
- 파일 예시: id_rsa
- Pipeline 변수 ANSIBLE_SSH_PRIVATE_KEY_SECURE_FILE에 파일명 지정

2. Ansible 관련 변수 설정
- ANSIBLE_SSH_USER (기본 iwon)
- DB_APP_PASSWORD (secret)
- DB_ROOT_PASSWORD (secret)

3. Terraform 출력 수신
- runTerraform=true면 Stage1 아티팩트 다운로드
- runTerraform=false면 기존 state에서 terraform output -json 실행

4. 동적 인벤토리 생성
- 스크립트 실행: [devops/scripts/generate_inventory_from_tf.py](../../devops/scripts/generate_inventory_from_tf.py)
- 생성 파일: inventory.generated.ini

5. Ansible 실행
- playbook: [vm-ansible/site.yml](../../vm-ansible/site.yml)
- deployTarget 파라미터로 all/web/was/app/integration/db/kafka 선택

## 구성

인벤토리 생성 규칙:
- bastion_public_ip -> bastion01
- vm_private_ips -> web01/was01/app01/smartcontract01/db01/kafka01
- ProxyJump 자동 구성

Ansible 역할 반영:
- web: Nginx
- was/app/integration: Java 서비스 배포
- db: MariaDB 및 초기 SQL
- kafka: Kafka

## 결과물

성공 시:
- ansible-inventory 아티팩트 생성
- 대상 VM에 공통 패키지/서비스 설정 반영
- 선택한 deployTarget 범위에 따라 서비스 재배포

점검 포인트:
- Managed Agent에서 bastion SSH 연결 성공
- internal_vms 대상 작업이 ProxyJump로 수행됨
- 서비스(systemd) 상태가 active로 유지됨
