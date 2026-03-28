helm values파일 경로
- /workspace/helm/

## helm 설치 명령어 시행 history

### nfs 프로비저너 helm repo
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
helm repo update

#### helm 설치 명령어(values.yaml 파일 있는 위치에서 실행) values파일명으로 -f 변경
helm install nfs-provisioner \
  nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  -n nfs-provisioner \
  --create-namespace \
  -f nfs-values.yaml

### ingress-nginx helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

#### helm 설치 명령어
helm install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx \
  --create-namespace \
  -f ingress-nginx-values.yaml

### cert-manager helm repo
helm repo add jetstack https://charts.jetstack.io
helm repo update

#### helm 설치 명령어
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  -f cert-manager-values.yaml

### mariadb helm repo
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

#### helm 설치 명령어
helm install mariadb bitnami/mariadb \
  -n mariadb \
  --create-namespace \
  -f mariadb-values.yaml

### Argo workflow, Argo CD helm repo 
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update 

#### Argo Workflows helm 설치 명령어
helm install argocd argo/argo-cd \
  -n argo \
  --create-namespace \
  -f argocd-values.yaml
#### Argo CD helm 설치 명령어
helm install argo-workflows argo/argo-workflows \
  -n argo \
  --create-namespace \
  -f argo-workflows-values.yaml

* docker hub 등록
kubectl -n ci create secret docker-registry dockerhub-creds \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username='itecloudcenter' \
  --docker-password='<YOUR_DOCKER_PAT>' \
  --docker-email='soloh@iteyes.co.kr'
* 서비스 어카운트(sa)에 시크릿 연결
kubectl -n ci patch sa ci-runner \
  -p '{"secrets":[{"name":"dockerhub-creds"}], "imagePullSecrets":[{"name":"dockerhub-creds"}]}'
