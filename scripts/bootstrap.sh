#!/usr/bin/env bash
# Vagrant 부트스트랩: Ansible 이 접속할 수 있는 최소 상태만 만든다.
#   - 시간대 KST
#   - swap 해제 (kubeadm 요구사항, 재부팅 후에도 유지)
#   - 관리자 계정(devops) + sudo NOPASSWD
#   - 공개키 배포 (SSH_PUBKEYS, 줄바꿈으로 구분)
# chrony, SSH 하드닝, fail2ban, /etc/hosts 등은 Ansible common role 에서 처리한다.
set -euo pipefail

ADMIN_USER="${ADMIN_USER:-devops}"
: "${SSH_PUBKEYS:?SSH_PUBKEYS 가 비어 있습니다 (keys/*.pub 확인)}"

echo "[bootstrap] 시간대 Asia/Seoul"
timedatectl set-timezone Asia/Seoul

echo "[bootstrap] swap 해제"
swapoff -a
# 주석이 아닌 swap 항목을 주석 처리해서 재부팅 후에도 켜지지 않게 한다.
sed -ri '/^[^#].*[[:space:]]swap[[:space:]]/ s/^/#/' /etc/fstab

echo "[bootstrap] 계정 ${ADMIN_USER}"
if ! id "${ADMIN_USER}" &>/dev/null; then
  useradd --create-home --shell /bin/bash "${ADMIN_USER}"
fi
# 비밀번호 로그인은 막고(키만 사용), sshd 가 계정을 잠긴 것으로 취급하지 않도록 '*' 로 둔다.
usermod --password '*' "${ADMIN_USER}"

SUDOERS_FILE="/etc/sudoers.d/90-${ADMIN_USER}"
echo "${ADMIN_USER} ALL=(ALL) NOPASSWD:ALL" > "${SUDOERS_FILE}"
chmod 440 "${SUDOERS_FILE}"
visudo -cf "${SUDOERS_FILE}"

echo "[bootstrap] 공개키 배포"
SSH_DIR="/home/${ADMIN_USER}/.ssh"
install -d -m 700 -o "${ADMIN_USER}" -g "${ADMIN_USER}" "${SSH_DIR}"
printf '%s\n' "${SSH_PUBKEYS}" > "${SSH_DIR}/authorized_keys"
chown "${ADMIN_USER}:${ADMIN_USER}" "${SSH_DIR}/authorized_keys"
chmod 600 "${SSH_DIR}/authorized_keys"

echo "[bootstrap] 완료: $(hostname) / $(date '+%Z') / swap=$(swapon --show --noheadings | wc -l)"
