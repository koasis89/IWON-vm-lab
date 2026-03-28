[쿠버네티스 개발 VM 사용 안내 – NodePort 방식]

────────────────────────────────────────
1. 서버 정보
────────────────────────────────────────
192.168.0.106   k8s-master01 (kubectl 사용 가능)
192.168.0.107   k8s-master02
192.168.0.108   k8s-master03
192.168.0.109   nfs
192.168.0.110   lb-proxy
192.168.0.111   k8s-worker01
192.168.0.112   k8s-worker02

각 서버 계정
ID: root 또는 rocky
PW: <CHANGE_ME_ADMIN_PASSWORD>

모든 작업은 기본적으로
- Putty로 k8s-master01 (192.168.0.106)에 접속한 뒤
- 그 안에서 kubectl 명령어를 사용합니다.
────────────────────────────────────────
2. DB접속정보 
────────────────────────────────────────


DB 접속정보(MariaDB)

호스트: 192.168.0.111
포트: 30306 
rootPassword: "<ROOT_DB_PASSWORD>"
database: "appdb"
username: "appuser"
password: "<APP_DB_PASSWORD>"

────────────────────────────────────────
2. 현재 실행 중인 “개발 VM(컨테이너)” 확인
────────────────────────────────────────
k8s-master01에 접속 후:

kubectl get pods -n dev-vm

출력 예:
dev-app-xxxx
dev-was-xxxx
dev-smartcontract-xxxx
dev-web-nginx-xxxx

여기서 xxxx 부분이 실제 Pod 이름입니다.
이 이름을 이후 명령어에 그대로 사용합니다.

────────────────────────────────────────
3. 컨테이너 안으로 들어가기 (VM 접속 느낌)
────────────────────────────────────────
각 컨테이너는 “개발용 VM”처럼 사용합니다.
SSH 대신 kubectl exec로 접속합니다.

dev-app 접속:
kubectl exec -it -n dev-vm dev-app-xxxx -- sh

dev-was 접속:
kubectl exec -it -n dev-vm dev-was-xxxx -- sh

dev-smartcontract 접속:
kubectl exec -it -n dev-vm dev-smartcontract-xxxx -- sh

dev-web-nginx 접속:
kubectl exec -it -n dev-vm dev-web-nginx-xxxx -- sh

※ xxxx는 `kubectl get pods -n dev-vm` 결과에서 복사해서 사용

접속되면 일반 리눅스 서버에 SSH로 들어온 것처럼
ls, cd, vi, java, curl 등의 명령을 그대로 사용할 수 있습니다.

────────────────────────────────────────
4. 파일 복사 방법 (scp 대신 kubectl cp 사용)
────────────────────────────────────────
직접 SSH가 안 되므로, 파일 전송은 kubectl cp를 사용합니다.

(1) 로컬 PC → k8s-master01
- WinSCP 등으로 192.168.0.106에 파일 업로드
  예: /tmp/app.jar 에 업로드

(2) k8s-master01 → 컨테이너(dev-app 예시)

kubectl cp /tmp/app.jar dev-vm/dev-app-xxxx:/workspace/app.jar

(3) 컨테이너 → k8s-master01 (로그 등 회수)

kubectl cp dev-vm/dev-app-xxxx:/workspace/app.log /tmp/app.log

이 방식으로
- 소스
- jar/war 파일
- 설정 파일
- 로그 파일
등을 자유롭게 주고받을 수 있습니다.

────────────────────────────────────────
5. 컨테이너 안에서 애플리케이션 실행
────────────────────────────────────────
예: dev-app에서 jar 실행

kubectl exec -it -n dev-vm dev-app-xxxx -- sh

컨테이너 안에서:
cd /workspace
java -jar app.jar

현재 구조는 컨테이너가 항상 떠 있도록 되어 있으므로,
직접 들어가서 실행하는 방식입니다.

────────────────────────────────────────
6. 서비스 접근 방법 (NodePort 방식)
────────────────────────────────────────
외부에서 접근할 때는 “워커 노드 IP + NodePort”를 사용합니다.
어느 워커 노드 IP로 접근해도 됩니다.

현재 설정된 포트:

dev-app-svc
- 내부 8080 → 외부 32280

dev-was-svc
- 내부 8080 → 외부 32180

dev-smartcontract-svc
- 내부 8080 → 외부 32380

dev-web-nginx-svc
- 내부 80 → 외부 32080

접속 예시 (회사 내부망에서):

dev-app:
http://192.168.0.111:32280
http://192.168.0.112:32280

dev-was:
http://192.168.0.111:32180

dev-smartcontract:
http://192.168.0.111:32380

dev-web-nginx:
http://192.168.0.111:32080


1) 접속(쉘):
kubectl exec -it -n dev-vm <pod이름> -- sh

2) 파일 전송:
kubectl cp 로컬파일 dev-vm/<pod이름>:/경로

3) 서비스 접근:
http://<워커노드IP>:<NodePort>


```
argo              argo-workflows-server-7c457f58d5-76wqt                          10.244.69.202   k8s-worker02
argo              argo-workflows-workflow-controller-86c8cd4764-926h8             10.244.69.225   k8s-worker02
argo              argocd-application-controller-0                                  10.244.79.72    k8s-worker01
argo              argocd-applicationset-controller-848c97db68-tkbwz               10.244.69.222   k8s-worker02
argo              argocd-dex-server-85666f775f-ckbbt                              10.244.69.236   k8s-worker02
argo              argocd-notifications-controller-8598cdc66c-9ttbw                10.244.69.193   k8s-worker02
argo              argocd-redis-bf6d4b7f7-pctvv                                    10.244.69.220   k8s-worker02
argo              argocd-repo-server-785fdc48d-27tg6                              10.244.79.78    k8s-worker01
argo              argocd-server-67bdfc6f89-kfh4k                                  10.244.69.221   k8s-worker02
cert-manager      cert-manager-65c68b4c4f-wjb9s                                   10.244.69.218   k8s-worker02
cert-manager      cert-manager-cainjector-6b6bc948df-kfdc4                        10.244.69.223   k8s-worker02
cert-manager      cert-manager-webhook-5dbbc66b86-hm9dj                           10.244.79.83    k8s-worker01
dev-vm            demo-frontend-5bfcb9f7db-m5q7n                                  10.244.69.204   k8s-worker02
dev-vm            demo-frontend-5bfcb9f7db-pvp8s                                  10.244.79.82    k8s-worker01
dev-vm            dev-app-8577f47fcc-s68zq                                        10.244.69.197   k8s-worker02
dev-vm            dev-integration-668d49ddbf-zg4gh                                10.244.69.196   k8s-worker02
dev-vm            dev-kafka-entity-operator-59684b5cfc-jsrfw                      10.244.79.84    k8s-worker01
dev-vm            dev-kafka-pool1-0                                               10.244.79.81    k8s-worker01
dev-vm            dev-smartcontract-69ffc54f9b-wphv2                              10.244.69.217   k8s-worker02
dev-vm            dev-was-d77d995d5-xq6nj                                         10.244.79.86    k8s-worker01
dev-vm            dev-web-nginx-dbcd46584-9cq5z                                   10.244.69.232   k8s-worker02
dev-vm            strimzi-cluster-operator-6c84667cb8-ks7p6                       10.244.79.77    k8s-worker01
ingress-nginx     ingress-nginx-controller-77f94b5ffb-4mjql                       10.244.69.211   k8s-worker02
ingress-nginx     ingress-nginx-defaultbackend-547d77fb7c-gk7xl                   10.244.79.79    k8s-worker01
kube-system       calico-kube-controllers-6fdf6dcb69-7dvpz                        10.244.69.201   k8s-worker02
kube-system       calico-node-47gn8                                               192.168.0.111   k8s-worker01
kube-system       calico-node-gj5lr                                               192.168.0.112   k8s-worker02
kube-system       calico-node-lppqx                                               192.168.0.106   k8s-master01
kube-system       calico-node-t2fc2                                               192.168.0.107   k8s-master02
kube-system       calico-node-xdhl7                                               192.168.0.108   k8s-master03
kube-system       coredns-668d6bf9bc-bz7v9                                        10.244.69.199   k8s-worker02
kube-system       coredns-668d6bf9bc-r5wqm                                        10.244.79.85    k8s-worker01
kube-system       etcd-k8s-master01                                               192.168.0.106   k8s-master01
kube-system       etcd-k8s-master02                                               192.168.0.107   k8s-master02
kube-system       etcd-k8s-master03                                               192.168.0.108   k8s-master03
kube-system       kube-apiserver-k8s-master01                                     192.168.0.106   k8s-master01
kube-system       kube-apiserver-k8s-master02                                     192.168.0.107   k8s-master02
kube-system       kube-apiserver-k8s-master03                                     192.168.0.108   k8s-master03
kube-system       kube-controller-manager-k8s-master01                            192.168.0.106   k8s-master01
kube-system       kube-controller-manager-k8s-master02                            192.168.0.107   k8s-master02
kube-system       kube-controller-manager-k8s-master03                            192.168.0.108   k8s-master03
kube-system       kube-proxy-2vrr9                                                192.168.0.111   k8s-worker01
kube-system       kube-proxy-5449p                                                192.168.0.108   k8s-master03
kube-system       kube-proxy-7dsp6                                                192.168.0.107   k8s-master02
kube-system       kube-proxy-bksh8                                                192.168.0.106   k8s-master01
kube-system       kube-proxy-zqd68                                                192.168.0.112   k8s-worker02
kube-system       kube-scheduler-k8s-master01                                     192.168.0.106   k8s-master01
kube-system       kube-scheduler-k8s-master02                                     192.168.0.107   k8s-master02
kube-system       kube-scheduler-k8s-master03                                     192.168.0.108   k8s-master03
kube-system       metrics-server-9d969b89-x5ndr                                   10.244.69.214   k8s-worker02
mariadb           mariadb-0                                                       10.244.79.76    k8s-worker01
nfs-provisioner   nfs-provisioner-nfs-subdir-external-provisioner-7cd7f495dcxxhjb 10.244.79.80   k8s-worker01
```
