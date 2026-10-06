#!/usr/bin/env bash
# Vagrant 부트스트랩: Ansible 이 접속할 수 있는 최소 상태만 만든다.
#   - 시간대 KST
#   - swap 해제 (kubeadm 요구사항, 재부팅 후에도 유지)
#   - 관리자 계정(devops) + sudo NOPASSWD
#   - 공개키 배포 (SSH_PUBKEYS, 줄바꿈으로 구분)
#   - SSH 호스트 키 재생성 (최초 1회)
#   - 루트 볼륨 확장 (ROOT_DISK_GB 가 있을 때만, 이미 크면 그대로)
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

# 박스 이미지에 들어 있던 SSH 호스트 키를 VM 마다 새로 만든다(복제된 VM 끼리 같은 키를 쓰지 않도록). 최초 1회만.
HOSTKEY_MARKER="/etc/ssh/.hostkeys-regenerated"
if [[ ! -f "${HOSTKEY_MARKER}" ]]; then
  echo "[bootstrap] SSH 호스트 키 재생성"
  rm -f /etc/ssh/ssh_host_*
  ssh-keygen -A
  systemctl restart ssh
  touch "${HOSTKEY_MARKER}"
fi

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

if [[ -n "${ROOT_DISK_GB:-}" ]]; then
  # bento/ubuntu-24.04 박스의 LVM 구성을 전제로 한다(Vagrantfile 의 BOX_VERSION 참고).
  ROOT_LV="/dev/ubuntu-vg/ubuntu-lv"
  if ! lvs "${ROOT_LV}" &>/dev/null; then
    echo "[bootstrap] 오류: 루트 볼륨 ${ROOT_LV} 이 없습니다. 박스 디스크 구성이 바뀌었는지 확인하세요." >&2
    exit 1
  fi
  CUR_GB="$(lvs --noheadings --units g --nosuffix -o lv_size "${ROOT_LV}" | awk '{printf "%d", $1}')"
  if (( CUR_GB < ROOT_DISK_GB )); then
    echo "[bootstrap] 루트 볼륨 ${CUR_GB}GB -> ${ROOT_DISK_GB}GB"
    lvextend -r -L "${ROOT_DISK_GB}G" "${ROOT_LV}"
  fi
fi

echo "[bootstrap] 완료: $(hostname) / $(date '+%Z') / swap=$(swapon --show --noheadings | wc -l) / root=$(df -h --output=size / | tail -1 | tr -d ' ')"
