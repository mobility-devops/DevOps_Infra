# DevOps_Infra

택시 배차 서비스 DevOps 프로젝트의 인프라 저장소.
개인 PC 한 대 위의 VirtualBox VM을 **Vagrant**로 만들고, 서버 설정은 **Ansible**로 적용한다.

| 저장소 | 역할 |
|---|---|
| DevOps_Backend | Spring Boot 코드, Dockerfile, Jenkinsfile |
| DevOps_GitOps | 배포 상태(Kustomize, Argo CD 설정) |
| **DevOps_Infra** (이 저장소) | Vagrantfile, Ansible(VM 설정, K8s·MySQL 설치) |
| DevOps_Docs | 확정된 문서, ADR, Runbook |

설계 기준은 노션 「아키텍처 개요」 문서를 따른다.

## 브랜치 규칙

`feature/*` 브랜치 → PR → `main` (Squash and merge). `main`에 직접 push하지 않는다.
브랜치명에 `#`을 넣지 않는다.

## 보안

- `keys/`에는 **공개키(`*.pub`)만** 올린다. 비밀키는 각자 PC에만 둔다.
- 비밀번호, 토큰, `ansible-vault` 비밀번호를 커밋하지 않는다.
