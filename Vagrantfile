# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# 택시 배차 서비스 DevOps 프로젝트 - VM 7대 정의 (VirtualBox)
# 물리 서버 2대(호스트 PC, 노트북 서버)에 나눠 띄운다. 같은 Vagrantfile 을 두 머신에서 쓰고,
# 각 머신은 자기 몫의 VM만 정의한다.
#
#   호스트 PC   : ci-01, k8s-master, k8s-worker1, k8s-worker2, db-01, mon-01
#   노트북 서버 : k8s-worker3
#
# 어느 머신인지는 br-lab 주소로 정한다(192.168.56.1 = 호스트, 192.168.56.2 = 노트북).
# 알 수 없으면 기본값을 쓰지 않고 중단한다. 직접 고르려면
#   LAB_MACHINE=laptop vagrant up
#
# 두 머신 모두 리눅스 브리지 br-lab(192.168.56.0/24)이 먼저 있어야 한다. 호스트 .1, 노트북 .2.
# VM 의 두 번째 NIC 는 br-lab 에 브리지로 붙는다. (README §4, §7-1 참고)

BOX = "bento/ubuntu-24.04"
# 두 머신이 같은 박스로 VM 을 만들도록 버전을 고정한다. bootstrap.sh 는 이 박스의 LVM 구성
# (/dev/ubuntu-vg/ubuntu-lv)을 전제로 한다. 호스트에서 `vagrant box list` 로 확인한 버전을 적는다.
# 바꾸면 새로 만드는 VM 에만 적용된다(이미 만든 VM 은 그대로).
BOX_VERSION = "202510.26.0"
ADMIN_USER = "devops"
BRIDGE = "br-lab"
LAB_MACHINES = { "192.168.56.1" => "host", "192.168.56.2" => "laptop" }.freeze

# br-lab 에 붙은 IPv4 주소로 머신을 찾는다. 못 찾으면 nil.
def detect_lab_machine
  addrs = `ip -4 -o addr show dev #{BRIDGE} 2>/dev/null`.scan(%r{inet (\d+\.\d+\.\d+\.\d+)/}).flatten
  addrs.map { |ip| LAB_MACHINES[ip] }.compact.first
end

LAB_MACHINE = ENV["LAB_MACHINE"] || detect_lab_machine

unless LAB_MACHINES.value?(LAB_MACHINE)
  abort "[Vagrantfile] 이 머신이 호스트인지 노트북인지 알 수 없습니다 (LAB_MACHINE=#{LAB_MACHINE.inspect}).\n" \
        "  #{BRIDGE} 에 192.168.56.1(호스트) 또는 192.168.56.2(노트북)가 있는지 확인하거나,\n" \
        "  LAB_MACHINE=host 또는 LAB_MACHINE=laptop 을 붙여 실행하세요."
end

if BOX_VERSION.empty?
  warn "[Vagrantfile] 경고: BOX_VERSION 이 비어 있어 #{BOX} 버전이 고정되지 않았습니다. " \
       "`vagrant box list` 로 확인한 버전을 Vagrantfile 에 적으세요."
end

# disk_gb: 루트 볼륨(LVM) 목표 크기. bento 박스 디스크는 64GB이고 설치 직후 루트 볼륨은 약 31GB라서,
#          bootstrap.sh 가 이 크기까지 늘린다. nil 이면 박스 기본값(약 31GB)을 그대로 쓴다.
# ssh_port: 머신의 127.0.0.1 로 포워딩할 SSH 포트. VM 마다 고정한다.
VMS = [
  { name: "ci-01",       ip: "192.168.56.11", cpus: 2, memory: 8192,  disk_gb: 50,  ssh_port: 2201, machine: "host"   },
  { name: "k8s-master",  ip: "192.168.56.21", cpus: 2, memory: 4096,  disk_gb: nil, ssh_port: 2203, machine: "host"   },
  { name: "k8s-worker1", ip: "192.168.56.22", cpus: 4, memory: 8192,  disk_gb: 50,  ssh_port: 2204, machine: "host"   },
  { name: "k8s-worker2", ip: "192.168.56.23", cpus: 4, memory: 8192,  disk_gb: 50,  ssh_port: 2205, machine: "host"   },
  { name: "db-01",       ip: "192.168.56.31", cpus: 2, memory: 3072,  disk_gb: 50,  ssh_port: 2206, machine: "host"   },
  { name: "mon-01",      ip: "192.168.56.41", cpus: 2, memory: 4096,  disk_gb: 50,  ssh_port: 2207, machine: "host"   },
  { name: "k8s-worker3", ip: "192.168.56.24", cpus: 4, memory: 10240, disk_gb: 50,  ssh_port: 2208, machine: "laptop" },
].freeze

# keys/*.pub (팀원별 공개키)를 모두 devops 계정에 배포한다.
def load_public_keys
  Dir[File.join(__dir__, "keys", "*.pub")].sort.map do |path|
    content = File.read(path).strip
    if content.include?("PRIVATE KEY") || !content.start_with?("ssh-", "ecdsa-", "sk-")
      abort "[Vagrantfile] #{path} 는 공개키 형식이 아닙니다. 비밀키를 keys/ 에 두지 마세요."
    end
    content
  end
end

PUBKEYS = load_public_keys

if PUBKEYS.empty? && (ARGV & %w[up reload provision]).any?
  abort "[Vagrantfile] keys/ 에 공개키(*.pub)가 없습니다. 공개키를 추가한 뒤 다시 실행하세요. (README 참고)"
end

Vagrant.configure("2") do |config|
  config.vm.box = BOX
  config.vm.box_version = BOX_VERSION unless BOX_VERSION.empty?
  config.vm.box_check_update = false

  # 기본 /vagrant 공유 폴더는 쓰지 않는다.
  config.vm.synced_folder ".", "/vagrant", disabled: true

  VMS.select { |vm| vm[:machine] == LAB_MACHINE }.each do |vm|
    config.vm.define vm[:name] do |node|
      node.vm.hostname = vm[:name]

      # 내부망(br-lab, 192.168.56.0/24) 고정 IP. NAT 어댑터는 Vagrant 기본값(인터넷용, 각 머신 Wi-Fi 로 나감).
      node.vm.network "public_network", bridge: BRIDGE, ip: vm[:ip]

      # 기본 SSH 포워딩(2222)은 VM 끼리 겹치므로 VM 별 포트를 명시한다.
      node.vm.network "forwarded_port", guest: 22, host: vm[:ssh_port],
                      host_ip: "127.0.0.1", id: "ssh"

      node.vm.provider "virtualbox" do |vb|
        vb.name = vm[:name]
        vb.cpus = vm[:cpus]
        vb.memory = vm[:memory]
        vb.linked_clone = true
      end

      # Ansible 이 접속할 수 있는 최소 상태만 만든다. 나머지 설정은 Ansible role 에서 한다.
      node.vm.provision "shell",
                        path: "scripts/bootstrap.sh",
                        env: {
                          "ADMIN_USER" => ADMIN_USER,
                          "SSH_PUBKEYS" => PUBKEYS.join("\n"),
                          "ROOT_DISK_GB" => vm[:disk_gb].to_s,
                        }
    end
  end
end
