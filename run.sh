#!/bin/bash

# 0. 경로 정의
export CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="${CURRENT_DIR}"

SSH_KEY_PATH="$HOME/.ssh/id_rsa"
SSH_CONFIG_PATH="${PROJECT_ROOT}/terraform/ssh_config"
INVENTORY_PATH="${PROJECT_ROOT}/terraform/inventory.ini"
TF_DIR="${PROJECT_ROOT}/terraform/live/azure"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"

1. SSH 키 보안 자격 증명 및 에이전트 설정
echo "==> [1/5] SSH 보안 환경 준비..."
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "    - SSH 키가 없습니다. 생성 중..."
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -q
    chmod 600 "$SSH_KEY_PATH"
fi

# SSH Agent 실행 및 키 등록 (중복 실행 방지)
if ! ssh-add -l > /dev/null 2>&1; then
    eval $(ssh-agent -s)
    ssh-add "$SSH_KEY_PATH"
fi

# 2. 테라폼 배포
echo "==> [2/5] 인프라 프로비저닝 시작..."
cd "$TF_DIR" && terraform init && terraform apply -auto-approve

# 3. SSH Config 최적화 (Bastion 터널링용)
echo "==> [3/5] SSH 접근 경로 구성..."
LOCAL_SSH_CONF="$HOME/.ssh/config"
touch "$LOCAL_SSH_CONF"

if [ -f "$SSH_CONFIG_PATH" ]; then
    # 중복 Include 방지 및 경로 등록
    grep -q "Include $SSH_CONFIG_PATH" "$LOCAL_SSH_CONF" || echo "Include $SSH_CONFIG_PATH" >> "$LOCAL_SSH_CONF"
    chmod 600 "$LOCAL_SSH_CONF" "$SSH_CONFIG_PATH"
fi

# # 4. 앤서블 연결 검증
# echo "==> [4/5] 가상 네트워크 연결 확인 (최대 2분 대기)..."
# export ANSIBLE_HOST_KEY_CHECKING=False

# for i in {1..5}; do
#     if ansible all -i "$INVENTORY_PATH" -m ping --ssh-common-args='-o StrictHostKeyChecking=no'; then
#         echo "    - [성공] 모든 노드 연결 완료!"
#         break
#     else
#         echo "    - 접속 대기 중... ($i/5)"
#         [ $i -eq 5 ] && echo "    - [오류] 연결 실패. 네트워크를 확인하세요." && exit 1
#         sleep 20
#     fi
# done

# # 5. 앤서블 플레이북 실행
# echo "==> [5/5] 쿠버네티스 런타임 및 클러스터 배포..."
# cd "$ANSIBLE_DIR"
# ansible-playbook -i "$INVENTORY_PATH" site.yaml \
#     --ssh-common-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

# echo "===================================================="
# echo "배포가 완료되었습니다."
# echo "===================================================="
