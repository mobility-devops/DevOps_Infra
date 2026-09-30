# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# 택시 배차 서비스 DevOps 프로젝트 - 신규 VM 7대 정의 (VirtualBox)
# controlnode(192.168.56.101)는 기존 VM이라 이 파일에 없다.
#
# 기동 순서는 로드맵 단계에 맞춘다(호스트 RAM 절약).
#   vagrant up                    # autostart: true 인 VM만 (k8s 3대, db-01)
#   vagrant up ci-01 sonar-01     # 3단계(CI)에서
#   vagrant up sec-01             # 7단계(Wazuh)에서

BOX = "bento/ubuntu-24.04"
ADMIN_USER = "devops"

# ssh_port: 호스트 localhost 로 포워딩할 SSH 포트. 기존 NAT Network 가 1111/2222/3333 을
# 쓰고 있으므로 겹치지 않게 VM 마다 고정한다.
VMS = [
  { name: "ci-01",       ip: "192.168.56.11", cpus: 2, memory: 6144, ssh_port: 2201, autostart: false },
  { name: "sonar-01",    ip: "192.168.56.12", cpus: 2, memory: 4096, ssh_port: 2202, autostart: false },
  { name: "k8s-master",  ip: "192.168.56.21", cpus: 2, memory: 4096, ssh_port: 2203, autostart: true  },
  { name: "k8s-worker1", ip: "192.168.56.22", cpus: 4, memory: 6144, ssh_port: 2204, autostart: true  },
  { name: "k8s-worker2", ip: "192.168.56.23", cpus: 4, memory: 8192, ssh_port: 2205, autostart: true  },
  { name: "db-01",       ip: "192.168.56.31", cpus: 2, memory: 3072, ssh_port: 2206, autostart: true  },
  { name: "sec-01",      ip: "192.168.56.41", cpus: 4, memory: 8192, ssh_port: 2207, autostart: false },
].freeze

# keys/*.pub (팀원별 공개키 + controlnode Ansible 공개키)를 모두 devops 계정에 배포한다.
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

  # 기본 /vagrant 공유 폴더는 쓰지 않는다.
  config.vm.synced_folder ".", "/vagrant", disabled: true

  VMS.each do |vm|
    config.vm.define vm[:name], autostart: vm[:autostart] do |node|
      node.vm.hostname = vm[:name]

      # Host-Only(vboxnet0, 192.168.56.0/24) 고정 IP. NAT 어댑터는 Vagrant 기본값(인터넷용).
      node.vm.network "private_network", ip: vm[:ip]

      # 기본 SSH 포워딩(2222)은 기존 NAT Network 와 충돌하므로 VM 별 포트를 명시한다.
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
                        env: { "ADMIN_USER" => ADMIN_USER, "SSH_PUBKEYS" => PUBKEYS.join("\n") }
    end
  end
end
