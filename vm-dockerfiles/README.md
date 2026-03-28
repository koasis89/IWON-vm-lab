# VM Server Dockerfiles

이 폴더는 `vm-azure/readme-vm.md`의 3.2 VM 매핑 테이블 기준으로 서버별 Dockerfile을 분리한 결과입니다.

우선순위 원칙:
1. `helm_bak_20260318` 기준
2. 보완이 필요한 경우 `dockerfiles` 사용
3. DB 관련은 `backup/db/values.yaml` 참고

## 서버별 파일

- `web01.Dockerfile`
- `was01.Dockerfile`
- `app01.Dockerfile`
- `smartcontract01.Dockerfile`
- `db01.Dockerfile`
- `kafka01.Dockerfile`
- `bastion01.Dockerfile`
- `web01-nginx.conf`

## 빠른 빌드 예시

```powershell
cd C:\Workspace\k8s-lab-dabin

docker build -f vm-dockerfiles/web01.Dockerfile -t vm-web01:latest vm-dockerfiles
docker build -f vm-dockerfiles/was01.Dockerfile -t vm-was01:latest vm-dockerfiles
docker build -f vm-dockerfiles/app01.Dockerfile -t vm-app01:latest vm-dockerfiles
docker build -f vm-dockerfiles/smartcontract01.Dockerfile -t vm-smartcontract01:latest vm-dockerfiles
docker build -f vm-dockerfiles/db01.Dockerfile -t vm-db01:latest vm-dockerfiles
docker build -f vm-dockerfiles/kafka01.Dockerfile -t vm-kafka01:latest vm-dockerfiles
docker build -f vm-dockerfiles/bastion01.Dockerfile -t vm-bastion01:latest vm-dockerfiles
```
