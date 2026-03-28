# Helm Charts & Values

이 폴더는 Kubernetes 클러스터에 설치된 주요 Helm 차트들의 설정 파일(`values.yaml`)과 설치 로그(`설치결과.txt`)를 관리합니다.

## 구성 요소 목록

| 컴포넌트 | Helm 차트 | Values 파일 | 설치 결과 로그 |
|---|---|---|---|
| NFS Provisioner | `nfs-subdir-external-provisioner` | `nfs-values.yaml` | - |
| Ingress NGINX | `ingress-nginx` | `ingress-nginx-values.yaml` | `ingress-nginx설치결과.txt` |
| Cert Manager | `cert-manager` | `cert-manager-values.yaml` | `cert-manager설치결과.txt` |
| MariaDB | `mariadb` | `mariadb-values.yaml` | `mariadb설치결과.txt` |
| Argo CD | `argo-cd` | `argocd-values.yaml` | `argo-cd설치결과.txt` |
| Argo Workflows | `argo-workflows` | `argo-workflows-values.yaml` | `argo-workflow설치결과.txt` |

## 설치 방법

각 컴포넌트의 설치 명령어는 아래와 같습니다. 모든 명령어는 `helm/` 디렉토리 내부에서 실행해야 합니다.

### 1. NFS Subdir External Provisioner
```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
helm repo update

helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  -n nfs-provisioner \
  --create-namespace \
  -f nfs-values.yaml
```

### 2. Ingress NGINX
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx \
  --create-namespace \
  -f ingress-nginx-values.yaml
```

### 3. Cert Manager
```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  -f cert-manager-values.yaml
```

### 4. MariaDB
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm install mariadb bitnami/mariadb \
  -n mariadb \
  --create-namespace \
  -f mariadb-values.yaml
```

### 5. Argo CD & Argo Workflows
Argo 프로젝트 관련 차트 리포지토리:
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

**Argo CD 설치:**
```bash
helm install argocd argo/argo-cd \
  -n argo \
  --create-namespace \
  -f argocd-values.yaml
```

**Argo Workflows 설치:**
```bash
helm install argo-workflows argo/argo-workflows \
  -n argo \
  --create-namespace \
  -f argo-workflows-values.yaml
```

## 기타 설정

### Docker Hub Secret 생성 (CI 네임스페이스)
```bash
kubectl -n ci create secret docker-registry dockerhub-creds \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username='itecloudcenter' \
  --docker-password='<YOUR_DOCKER_PASSWORD>' \
  --docker-email='soloh@iteyes.co.kr'
```

### Service Account에 Secret 연결
```bash
kubectl -n ci patch sa ci-runner \
  -p '{"secrets":[{"name":"dockerhub-creds"}], "imagePullSecrets":[{"name":"dockerhub-creds"}]}'
```
