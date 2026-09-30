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

## VM 구성

Host-Only 네트워크(`vboxnet0`, 192.168.56.0/24)로 서로 통신한다. 호스트는 `.1`.
VM은 신규 7대이고, `controlnode`(192.168.56.101, Ansible 제어 노드)는 기존 VM이라 Vagrant로 만들지 않는다.

| VM | 역할 | vCPU | RAM | Host-Only IP | SSH 포워딩 | 기본 기동 |
|---|---|---|---|---|---|---|
| ci-01 | Jenkins, Docker | 2 | 6GB | 192.168.56.11 | 2201 | 아니오 (3단계) |
| sonar-01 | SonarQube | 2 | 4GB | 192.168.56.12 | 2202 | 아니오 (3단계) |
| k8s-master | Kubernetes Control Plane | 2 | 4GB | 192.168.56.21 | 2203 | 예 |
| k8s-worker1 | 앱, Ingress, Argo CD | 4 | 6GB | 192.168.56.22 | 2204 | 예 |
| k8s-worker2 | 앱, 모니터링 | 4 | 8GB | 192.168.56.23 | 2205 | 예 |
| db-01 | MySQL 8 | 2 | 3GB | 192.168.56.31 | 2206 | 예 |
| sec-01 | Wazuh | 4 | 8GB | 192.168.56.41 | 2207 | 아니오 (7단계) |

- 신규 7대 RAM 합계 39GB, controlnode(2GB로 축소)까지 41GB. 호스트 RAM(62GiB)에 여유를 두기 위해
  **필요한 VM만 켠다.** 기본 `vagrant up`은 4대(21GB)만 올린다.
- 스펙은 노션 「아키텍처 개요」 3장 「자원 운영 방안」 조정안 기준이다. 부족하면 `Vagrantfile`의 `VMS`에서 값을 고친 뒤
  `vagrant reload <이름>` 한다.
- 디스크 크기는 `Vagrantfile`에서 강제하지 않는다(박스 기본 디스크, 동적 할당).

## 사전 준비 (호스트 PC)

1. **Vagrant**와 **VirtualBox**를 설치한다. VirtualBox 7.2를 쓰므로 Vagrant는 최신 버전을 쓴다. (`vagrant --version`)
2. 본인 SSH 키를 만든다. 비밀키는 절대 공유하지 않는다.
   ```bash
   ssh-keygen -t ed25519 -C "이름@devops" -f ~/.ssh/id_devops
   ```
3. **공개키(`.pub`)만** `keys/이름.pub`으로 저장소에 추가한다(PR).
4. Ansible용 키는 controlnode에서 만들고, 공개키만 `keys/controlnode_ansible_key.pub`으로 추가한다.
   ```bash
   # controlnode 안에서 (passphrase 없음: 무인 실행용)
   ssh-keygen -t ed25519 -C "controlnode-ansible" -f ~/.ssh/ansible_key -N ""
   ```
5. 기존 VM(managednode1·2)과 `ubuntu-server-02` 폴더는 삭제하기로 했다. 삭제 전에 필요한 데이터가 없는지 확인한다.
6. controlnode RAM을 2GB로 줄인다(VM을 끈 상태에서). VirtualBox 등록 이름은 `ubuntu-server-01`이다.
   ```bash
   VBoxManage modifyvm ubuntu-server-01 --memory 2048
   ```

`keys/`에 공개키가 하나도 없으면 `vagrant up`이 중단된다. `keys/`에 비밀키가 들어 있어도 중단된다.

## 사용법

```bash
# 1~2단계: k8s 3대 + db-01 (autostart: true)
vagrant up

# 3단계에서
vagrant up ci-01 sonar-01

# 7단계(Wazuh 도입 시)
vagrant up sec-01

vagrant status              # 상태 확인
vagrant halt <이름>         # 안 쓰는 VM 끄기 (RAM 확보)
vagrant reload <이름>       # 스펙 변경 반영
vagrant provision <이름>    # 공개키 변경 반영 (bootstrap.sh 재실행, 여러 번 실행해도 안전)
vagrant destroy -f <이름>   # 삭제 후 다시 만들 때
```

### 접속

```bash
# 호스트에서 (Host-Only IP)
ssh -i ~/.ssh/id_devops devops@192.168.56.21
# 또는 localhost 포워딩
ssh -i ~/.ssh/id_devops -p 2203 devops@127.0.0.1
# Vagrant 기본 계정(vagrant)으로 접속
vagrant ssh k8s-master
```

### 기동 후 확인

```bash
ssh -i ~/.ssh/id_devops devops@192.168.56.21 'hostname; date; swapon --show | wc -l; sudo -n true && echo sudo-ok'
# 기대 결과: 호스트명, KST 시각, swap 0, sudo-ok
```

## 파일 구성

| 경로 | 설명 |
|---|---|
| `Vagrantfile` | VM 7대 정의(스펙, IP, SSH 포트, autostart) |
| `scripts/bootstrap.sh` | 최소 부트스트랩: KST, swap 해제, `devops` 계정, sudo NOPASSWD, 공개키 배포 |
| `keys/` | 공개키(`*.pub`)만. 팀원별 키 + controlnode Ansible 키 |

Vagrant는 Ansible이 접속할 수 있는 상태까지만 만든다. chrony, SSH 하드닝, fail2ban, `/etc/hosts`,
Kubernetes·MySQL 설치는 Ansible role로 적용한다(다음 작업).

## 알아둘 점

- **SSH 포트:** Vagrant 기본 포워딩(2222)은 기존 NAT Network 포트포워딩(1111/2222/3333)과 겹쳐서
  VM마다 2201~2207을 명시했다.
- **Kubernetes 노드 IP:** 모든 VM의 NAT 어댑터가 10.0.2.15라서, kubeadm/kubelet에는 Host-Only IP를 반드시 명시한다(2단계).
- **스냅샷:** `vagrant snapshot save <이름> base-clean`으로 초기 상태를 저장해 두면 실험 후 복구가 쉽다.
  스냅샷은 같은 디스크에 저장되므로 백업이 아니다.
