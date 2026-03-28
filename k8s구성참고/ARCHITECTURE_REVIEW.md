# 📄 K8S-LAB 프로젝트 아키텍처 개선 및 자동화 보고서

## 1. 핵심 자동화 전략: `run.sh` (One-Click Provisioning)
본 프로젝트의 모든 구축 과정은 `run.sh` 하나로 통합되어 있으며, 이는 **'반복 가능하고 예측 가능한 인프라'**를 지향합니다. 
* **End-to-End 자동화**: Azure 로그인부터 Terraform 인프라 생성, Ansible 구성 관리, Helm/ArgoCD 배포까지 전 과정을 단일 스크립트로 제어합니다.
* **자가 치유 환경(Self-Provisioning)**: 실행 호스트에 SSH Key나 Ansible Vault 비번 파일이 없어도 스크립트가 스스로 진단하여 생성하는 독립성을 확보했습니다.
* **멱등성(Idempotency) 확보**: 여러 번 실행해도 동일한 환경이 유지되도록 설계되어, 환경 오염이나 휴먼 에러를 원천 차단합니다.

## 2. AS-IS vs TO-BE 상세 비교 및 개선 사항

| 항목 | AS-IS (과거 구조) | TO-BE (현재 구조) | 개선 효과 및 기술적 의사결정 |
| :--- | :--- | :--- | :--- |
| **파일 구조** | 루트에 설정 파일 혼재 | **기능별 디렉토리화** | 가독성 및 프로젝트 확장성 확보 |
| **보안/접속** | **모든 노드 개별 수동 SSH 설정** | **Bastion 기반 SSH 터널링** | 보안 관문 일원화 및 SSH 자동 주입 |
| **Terraform** | 단일 파일 나열 방식 | **Module & Live 분리** | 인프라 부품화 및 재사용성 극대화 |
| **Ansible** | 역할 미비, 단일 실행 | **Role 기반 체계화** | 복잡한 구성 요소의 유지보수 용이성 |
| **환경** | Windows Native | **WSL2 (Ubuntu)** | 실제 운영 서버와 동일한 커널 환경 확보 |
| **보안** | 인증서(`.conf`) 깃 포함 | **민감 정보 동적 생성** | 보안 취약점 제거 및 권한 관리 강화 |
| **스토리지** | 개별 YAML 수동 배포 | **Helm 통합 관리** | NFS Provisioner 파라미터화 및 자동화 |

## 3. 기술적 표준 근거 (Technical Standards)
글로벌 표준 가이드와 오픈소스 베스트 프랙티스를 준수하여 아키텍처를 설계했습니다.

* **Terraform Standard Module Structure**: [HashiCorp 공식 가이드] 준수.
* **K8s Networking**: `kubeadm-config.yaml`의 **Control Plane Endpoint**를 클라우드 사설 IP(10 대역)로 표준화하여 정합성 확보.
* **GitOps 선언적 배포**: [ArgoCD 공식 문서]의 개념을 도입하여 'Single Source of Truth' 체계 구축.

## 4. 환경 독립적 실행 능력 (Environment Independence)
* **Zero-Touch Provisioning**: Terraform을 통해 VM 생성 시점에 SSH 공개키를 자동 주입하여, 과거 방식의 **노드별 `ssh-copy-id` 반복 작업**을 완전히 제거했습니다.
* **Bastion Proxy Tunneling**: 외부 노출을 최소화하기 위해 전용 Bastion 호스트를 구성하고, Ansible의 **ProxyCommand**를 통해 사설망 내 노드들을 안전하게 자동 제어합니다.
* **Dynamic Variable Injection**: 설정 파일의 정적 IP 한계를 극복하기 위해 실행 시점에 환경에 맞는 사설 IP(10.0.2.x)를 적용하도록 최적화.

## 5. 제거된 기술적 부채 (Cleanup List)
* **중복 코드 제거**: `azure/` 구형 폴더 및 루트의 파편화된 `.tf`, `roles/` 폴더를 표준 경로로 통합 및 삭제.
* **불필요한 파일 정리**: `*.png`, `*-설치결과.txt` 등 히스토리성 자산 정리를 통한 프로젝트 경량화.
* **디렉토리 표준화**: `argo-yaml` 등 혼용되던 폴더명을 `argoCd`로 단일화하여 자동화 경로 정합성 완성.