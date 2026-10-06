#!/usr/bin/env bash
# 머신 재부팅 시 이 머신의 VM(호스트 6대, 노트북 k8s-worker3)을 자동으로 켜고, 머신이 꺼질 때 정상 종료하는
# systemd 서비스를 등록한다.
# 호스트 PC와 노트북 서버에서 각각 1회 실행: ./scripts/install-autostart.sh
# 호스트 이름으로 머신 구분이 안 되면 LAB_MACHINE 을 붙여 실행한다(서비스에도 그대로 들어간다):
#   LAB_MACHINE=laptop ./scripts/install-autostart.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUN_USER="$(id -un)"
VAGRANT_BIN="$(command -v vagrant)"
ENV_LINE=""
if [[ -n "${LAB_MACHINE:-}" ]]; then
  ENV_LINE="Environment=LAB_MACHINE=${LAB_MACHINE}"
fi

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
echo "등록 완료: systemctl status vagrant-vms"
