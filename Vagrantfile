# -*- mode: ruby -*-
# Vagrantfile — CONNECTONGS com Docker + Nginx + Manager
#
# Igual ao academic_v3:
#   - 1 VM Ubuntu 22.04
#   - Docker roda DENTRO da VM
#   - 4 containers nó + 1 Nginx + 1 Manager
#   - Rede isolada 172.30.0.0/24
#
# Uso:
#   vagrant up          → sobe a VM e todos os containers
#   vagrant ssh         → acessa a VM
#   vagrant halt        → para
#   vagrant destroy -f  → apaga tudo

Vagrant.configure("2") do |config|
  config.vm.box      = "ubuntu/jammy64"
  config.vm.hostname = "connectongs-vm"

  config.vm.network "private_network", ip: "192.168.56.20"

  # Porta do Nginx (load balancer) → acessa em http://localhost:8080
  config.vm.network "forwarded_port", guest: 8080, host: 8080
  # Portas individuais de cada nó
  (8081..8084).each do |p|
    config.vm.network "forwarded_port", guest: p, host: p
  end
  # Portas RPC de cada nó
  (9101..9104).each do |p|
    config.vm.network "forwarded_port", guest: p, host: p
  end
  # Manager / painel
  config.vm.network "forwarded_port", guest: 9000, host: 9000

  config.vm.provider "virtualbox" do |vb|
    vb.name   = "CONNECTONGS-VM"
    vb.memory = "3072"
    vb.cpus   = 2
    vb.gui    = false
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    vb.customize ["modifyvm", :id, "--nictype1", "virtio"]
    vb.customize ["modifyvm", :id, "--nictype2", "virtio"]
  end

  # Pasta do projeto sincronizada dentro da VM
  config.vm.synced_folder ".", "/home/vagrant/connectongs",
    owner: "vagrant", group: "vagrant"

  config.vm.provision "shell", inline: <<-SHELL
    set -e
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl gnupg python3 net-tools

    # Instala Docker
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
      gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
      docker-buildx-plugin docker-compose-plugin

    usermod -aG docker vagrant
    systemctl enable docker && systemctl start docker

    # Sobe todos os containers
    cd /home/vagrant/connectongs
    sudo -u vagrant docker compose up -d --build

    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "  ✅  CONNECTONGS VM pronta!"
    echo ""
    echo "  Load Balancer : http://192.168.56.20:8080"
    echo "                  http://localhost:8080"
    echo ""
    echo "  Nó 1 HTTP     : http://localhost:8081   RPC: 9101"
    echo "  Nó 2 HTTP     : http://localhost:8082   RPC: 9102"
    echo "  Nó 3 HTTP     : http://localhost:8083   RPC: 9103"
    echo "  Nó 4 HTTP     : http://localhost:8084   RPC: 9104"
    echo ""
    echo "  Manager/Painel: http://localhost:9000"
    echo "╚══════════════════════════════════════════════════════╝"
  SHELL
end
