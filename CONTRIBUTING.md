# Contribution & Branch Strategy

본 저장소는 Kubernetes Lab 프로젝트를 위한 협업 및 배포 전략 가이드를 제공합니다.

---

## Branch Strategy

- `main` : 안정 브랜치 (통합 / 운영 기준)
- `setup` : 기본 작업 브랜치 (개발 기준)

---

## 기본 작업 흐름

1️⃣ Repository Clone

 git clone https://github.com/iteyes9797/k8s-lab.git

 cd k8s-lab

2️⃣ setup 브랜치로 이동

 git checkout setup

3️⃣ 작업 후 Commit & Push

 git add .

 git commit -m "feat: 작업 내용"

 git push origin setup

🔀 main 반영 절차 (PR 필수)

 main 브랜치에는 직접 push 하지 않습니다.

 main 반영 절차:
 1. GitHub에서 Pull Request 생성
 2. base: main
 3. compare: setup
 4. 리뷰 후 Merge 진행

# 정책

## main 직접 push 금지
- ✔ 모든 작업은 setup 브랜치에서 진행
- ✔ main 반영은 Pull Request 필수

## Workflow 요약

 작업 → setup push → Pull Request → main merge
