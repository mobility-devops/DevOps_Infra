# DevOps_Infra

택시 배차 서비스 DevOps 프로젝트의 **인프라 저장소**.
물리 서버 2대(호스트 PC, 노트북 서버) 위에 VirtualBox VM 7대를 **Vagrant**로 만든다.

> 전체 설계(CI·CD·앱·모니터링·보안)는 DevOps_Docs의 [프로젝트 아키텍처](https://github.com/mobility-devops/DevOps_Docs/blob/main/architecture/project-architecture.md)에 있다.
> 서로 다르면 노션 「프로젝트 아키텍처」가 기준이다.

## 파일 구성

| 경로 | 설명 |
|---|---|
| `Vagrantfile` | VM 7대 정의. 머신(host/laptop) 자동 구분, 스펙, IP, SSH 포트(2201~2208) |
| `scripts/bootstrap.sh` | VM 최초 설정: KST, swap 해제, SSH 호스트 키 재생성, `devops` 계정(sudo NOPASSWD), 공개키 배포, 루트 볼륨 확장 |
| `scripts/install-autostart.sh` | 머신 재부팅 시 VM 자동 기동·정상 종료(systemd `vagrant-vms`) 등록 |
| `keys/` | 팀원 공개키(`*.pub`)만 |
| `docs/` | README 그림 |

## VM 구성

![VM 배치](docs/vm-layout-simple.png)

| VM | IP | vCPU | RAM | 디스크 | 머신 | 역할 |
|---|---|---|---|---|---|---|
| ci-01 | 192.168.56.11 | 2 | 8GB | 50GB | 호스트 | Jenkins, Docker |
| k8s-master | 192.168.56.21 | 2 | 4GB | 31GB | 호스트 | Control Plane |
| k8s-worker1 | 192.168.56.22 | 4 | 8GB | 50GB | 호스트 | 앱, Gateway, 플랫폼 도구 |
| k8s-worker2 | 192.168.56.23 | 4 | 8GB | 50GB | 호스트 | 〃 |
| k8s-worker3 | 192.168.56.24 | 4 | 10GB | 50GB | 노트북 | 〃 |
| db-01 | 192.168.56.31 | 2 | 3GB | 50GB | 호스트 | MySQL |
| mon-01 | 192.168.56.41 | 2 | 4GB | 50GB | 호스트 | Prometheus, Grafana, Loki |

- 모든 VM: Ubuntu 24.04(`bento/ubuntu-24.04`), KST, swap 끔, 관리 계정 `devops`(키 인증만).
- 내부망 **br-lab**(192.168.56.0/24): 호스트 `.1`, 노트북 `.2`. 두 머신을 랜선으로 직접 연결한다.
- VM의 `eth0`은 Vagrant NAT(인터넷), `eth1`이 br-lab이다.

## 사용법

### 1. 사전 준비 (각 머신)
1. VirtualBox 7.2와 최신 Vagrant를 설치한다.
2. br-lab을 만든다. 없으면 `vagrant up`이 실패한다.
   - 호스트(NetworkManager): `nmcli`로 bridge `br-lab`(192.168.56.1/24) + 랜포트·`dummy0`
   - 노트북(netplan): `/etc/netplan/60-br-lab.yaml`에 랜포트(dhcp 끔) + `dummy-devices: dummy0` + `bridges: br-lab`(192.168.56.2/24)

### 2. 공개키 추가 (팀원)
```bash
ssh-keygen -t ed25519 -C "이름@devops"      # 비밀키는 절대 공유하지 않음
```
공개키(`.pub`)만 `keys/이름.pub`으로 PR을 올린다. `keys/`에 공개키가 없거나 비밀키가 있으면 `vagrant up`이 중단된다.

키를 추가·삭제한 뒤에는 **두 머신 모두**에서 반영한다(`bootstrap.sh`는 VM을 처음 만들 때만 자동 실행).
```bash
vagrant provision <이름>             # 켜져 있는 VM
vagrant up --provision <이름>        # 꺼져 있는 VM
```

### 3. VM 실행
```bash
vagrant up                      # 호스트: 6대 / 노트북: k8s-worker3 (호스트 이름으로 자동 구분)
LAB_MACHINE=laptop vagrant up   # 머신을 직접 고를 때 (host | laptop)
vagrant status
vagrant halt <이름>
vagrant reload <이름>           # 스펙 변경 반영
```

### 4. 재부팅 시 자동 기동 (각 머신 1회)
```bash
./scripts/install-autostart.sh
sudo systemctl start vagrant-vms    # 이 머신의 VM 기동
sudo systemctl stop vagrant-vms     # 이 머신의 VM 정상 종료
```
터미널에서 직접 켠 VM은 머신 종료 시 `aborted`로 꺼질 수 있으므로, 전체 기동·종료는 서비스로 한다.

### 5. 접속 (팀원 PC)
1. Tailscale 초대 수락 → 로그인 → `ping 192.168.56.21`
2. `~/.ssh/config`:
   ```
   Host ci-01
     HostName 192.168.56.11
   Host k8s-master
     HostName 192.168.56.21
   Host k8s-worker1
     HostName 192.168.56.22
   Host k8s-worker2
     HostName 192.168.56.23
   Host k8s-worker3
     HostName 192.168.56.24
   Host db-01
     HostName 192.168.56.31
   Host mon-01
     HostName 192.168.56.41

   Host ci-01 k8s-master k8s-worker1 k8s-worker2 k8s-worker3 db-01 mon-01 192.168.56.*
     User devops
     IdentityFile ~/.ssh/id_ed25519
     IdentitiesOnly yes
   ```
3. 확인: `ssh k8s-master 'hostname; date; swapon --show | wc -l'` → 호스트명, KST 시각, swap 0

## 규칙

- `keys/`에는 **공개키만** 올린다. 비밀번호·토큰·비밀키를 커밋하지 않는다(저장소 public).
- `main` 하나. `feature/<번호>-<내용>` 브랜치 → PR(승인 1명) → **Squash** 머지. `main`에 직접 push하지 않는다.

## 알아둘 점

- **linked clone:** VirtualBox에 `ubuntu-24.04-amd64_...` 원본 VM이 생긴다. 모든 VM이 이 디스크를 공유하므로 삭제하거나 켜지 않는다.
- **스냅샷:** `vagrant snapshot save <이름> base-clean`으로 초기 상태를 저장해 두면 복구가 쉽다. 같은 디스크라 백업은 아니다.
- **노트북도 같은 `Vagrantfile`을 쓴다.** 예전 `Vagrantfile.laptop`은 쓰지 않는다.
- **장애:** 노트북이 꺼지거나 랜선이 빠지면 worker3만 빠진다. 호스트 PC가 꺼지면 전체가 멈춘다.
