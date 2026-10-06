#!/usr/bin/env bash
# 머신 재부팅 시 이 머신의 VM(호스트 6대, 노트북 k8s-worker3)을 자동으로 켜고, 머신이 꺼질 때 정상 종료하는
# systemd 서비스를 등록한다.
# 호스트 PC와 노트북 서버에서 각각 1회 실행: ./scripts/install-autostart.sh
# 머신(host/laptop)은 Vagrantfile 과 같이 br-lab 주소로 정해 서비스에 고정한다. 부팅 직후 br-lab 주소가
# 늦게 붙어도 엉뚱한 VM 을 켜지 않게 하기 위해서다. 직접 고르려면:
#   LAB_MACHINE=laptop ./scripts/install-autostart.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUN_USER="$(id -un)"
VAGRANT_BIN="$(command -v vagrant)"

if [[ -z "${LAB_MACHINE:-}" ]]; then
  BR_ADDRS="$(ip -4 -o addr show dev br-lab 2>/dev/null || true)"
  if grep -q 'inet 192\.168\.56\.1/' <<<"${BR_ADDRS}"; then
    LAB_MACHINE=host
  elif grep -q 'inet 192\.168\.56\.2/' <<<"${BR_ADDRS}"; then
    LAB_MACHINE=laptop
  fi
fi
if [[ "${LAB_MACHINE:-}" != host && "${LAB_MACHINE:-}" != laptop ]]; then
  echo "머신을 알 수 없습니다. br-lab 주소를 확인하거나 LAB_MACHINE=host|laptop 을 붙여 실행하세요." >&2
  exit 1
fi
ENV_LINE="Environment=LAB_MACHINE=${LAB_MACHINE}"

sudo tee /etc/systemd/system/vagrant-vms.service >/dev/null <<UNIT
[Unit]
Description=Vagrant VMs (DevOps_Infra)
After=network-online.target vboxdrv.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=${RUN_USER}
WorkingDirectory=${REPO_DIR}
${ENV_LINE}
ExecStart=${VAGRANT_BIN} up
ExecStop=${VAGRANT_BIN} halt
TimeoutStartSec=1800
TimeoutStopSec=600

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable vagrant-vms.service
echo "등록 완료(${LAB_MACHINE}): systemctl status vagrant-vms"
