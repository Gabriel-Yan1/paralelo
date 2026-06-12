# =============================================================================
# CONNECTONGS — Vagrantfile
# Windows 11 + VirtualBox + Vagrant
#
# Topologia:
#   master  192.168.56.10  banco SQLite (NFS) + painel web (porta 8080)
#   node1   192.168.56.11  1 container app
#   node2   192.168.56.12  1 container app
#   node3   192.168.56.13  1 container app
#   node4   192.168.56.14  1 container app
#
# Comandos:
#   vagrant up master          → sobe só o master
#   vagrant up node1           → sobe só o node1
#   vagrant up                 → sobe tudo
#   vagrant ssh master         → acessa o master
#   vagrant halt               → para tudo
#   vagrant destroy -f         → apaga tudo
# =============================================================================

MASTER_IP = "192.168.56.10"
NODES = {
  "node1" => "192.168.56.11",
  "node2" => "192.168.56.12",
  "node3" => "192.168.56.13",
  "node4" => "192.168.56.14",
}

Vagrant.configure("2") do |config|

  config.vm.box = "ubuntu/jammy64"
  config.vm.box_check_update = false
  config.vm.boot_timeout = 600

  # Desabilita pasta compartilhada padrão (evita erro de symlink no Windows)
  config.vm.synced_folder ".", "/vagrant", disabled: false,
    owner: "vagrant", group: "vagrant",
    mount_options: ["dmode=755", "fmode=644"]

  # ── Script base instalado em todas as VMs ──────────────────────────────────
  $install_base = <<-SHELL
    set -e
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq curl git nfs-common

    # Docker
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -qq
    apt-get install -y -qq \
      docker-ce docker-ce-cli containerd.io \
      docker-buildx-plugin docker-compose-plugin
    usermod -aG docker vagrant
    systemctl enable docker
    systemctl start docker
    echo "Docker instalado: $(docker --version)"
  SHELL

  $clone_repo = <<-SHELL
    set -e
    if [ ! -d /opt/connectongs ]; then
      git clone https://github.com/oliverhenrique04/Projeto-de-Computacao-Paralela.git \
        /opt/connectongs
    else
      cd /opt/connectongs && git pull --quiet
    fi

    # Copia os arquivos gerados (docker/ e dashboard/)
    cp -rf /vagrant/docker/.    /opt/connectongs/docker/    2>/dev/null || true
    cp -rf /vagrant/dashboard/. /opt/connectongs/dashboard/ 2>/dev/null || true
    echo "Repositorio pronto em /opt/connectongs"
  SHELL

  # ── MASTER ─────────────────────────────────────────────────────────────────
  config.vm.define "master", primary: true do |m|
    m.vm.hostname = "connectongs-master"
    m.vm.network "private_network", ip: MASTER_IP

    # Painel web acessível em http://localhost:8080 na sua máquina
    m.vm.network "forwarded_port", guest: 8080, host: 8080, auto_correct: true

    m.vm.provider "virtualbox" do |vb|
      vb.name   = "CONNECTONGS-Master"
      vb.memory = 1536
      vb.cpus   = 2
      vb.customize ["modifyvm", :id, "--groups", "/CONNECTONGS"]
      # Melhora desempenho de rede no Windows
      vb.customize ["modifyvm", :id, "--nictype1", "virtio"]
      vb.customize ["modifyvm", :id, "--nictype2", "virtio"]
    end

    m.vm.provision "shell", name: "base",  inline: $install_base
    m.vm.provision "shell", name: "clone", inline: $clone_repo

    m.vm.provision "shell", name: "master-setup", inline: <<-SHELL
      set -e
      echo "==> Configurando Master..."

      # Diretório do banco compartilhado
      mkdir -p /data
      chown -R vagrant:vagrant /data

      # NFS server
      apt-get install -y -qq nfs-kernel-server
      grep -q "^/data" /etc/exports 2>/dev/null || \
        echo "/data 192.168.56.0/24(rw,sync,no_subtree_check,no_root_squash)" \
        >> /etc/exports
      exportfs -ra
      systemctl enable nfs-kernel-server
      systemctl restart nfs-kernel-server
      echo "NFS exportando /data para 192.168.56.0/24"

      # Copia e sobe o painel web
      mkdir -p /opt/dashboard
      cp -r /opt/connectongs/dashboard/. /opt/dashboard/
      cd /opt/dashboard
      docker compose up -d --build
      echo "Painel web disponivel em http://#{MASTER_IP}:8080"
      echo "Na sua maquina Windows: http://localhost:8080"
    SHELL
  end

  # ── NODES ──────────────────────────────────────────────────────────────────
  NODES.each do |name, ip|
    config.vm.define name do |n|
      n.vm.hostname = "connectongs-#{name}"
      n.vm.network "private_network", ip: ip

      n.vm.provider "virtualbox" do |vb|
        vb.name   = "CONNECTONGS-#{name.capitalize}"
        vb.memory = 768
        vb.cpus   = 1
        vb.customize ["modifyvm", :id, "--groups", "/CONNECTONGS"]
        vb.customize ["modifyvm", :id, "--nictype1", "virtio"]
        vb.customize ["modifyvm", :id, "--nictype2", "virtio"]
      end

      n.vm.provision "shell", name: "base",  inline: $install_base
      n.vm.provision "shell", name: "clone", inline: $clone_repo

      n.vm.provision "shell", name: "node-setup", inline: <<-SHELL
        set -e
        NODE_NAME="#{name}"
        NODE_IP="#{ip}"
        MASTER_IP="#{MASTER_IP}"
        echo "==> Configurando $NODE_NAME ($NODE_IP)..."

        # Monta o banco do master via NFS
        mkdir -p /data
        echo "Aguardando NFS do master..."
        for i in $(seq 1 20); do
          if showmount -e $MASTER_IP &>/dev/null; then
            echo "NFS master encontrado!"
            break
          fi
          echo "  Tentativa $i/20 — aguardando 6s..."
          sleep 6
        done

        grep -q "$MASTER_IP:/data" /etc/fstab 2>/dev/null || \
          echo "$MASTER_IP:/data /data nfs rw,sync,hard,intr 0 0" >> /etc/fstab
        mount -a 2>/dev/null || mount -t nfs $MASTER_IP:/data /data
        echo "/data montado do master com sucesso"

        # Constrói a imagem Docker
        echo "Construindo imagem Docker..."
        cd /opt/connectongs
        docker build -f docker/Dockerfile -t connectongs:latest . -q
        echo "Imagem construida!"

        # Sobe o container do nó
        NODE_NAME=$NODE_NAME \
        NODE_IP=$NODE_IP \
        MASTER_IP=$MASTER_IP \
        CONNECTONGS_DB=/data/connectongs.db \
          docker compose -f docker/docker-compose.node.yml up -d

        echo "Container connectongs_$NODE_NAME rodando!"

        # Registra no painel
        curl -s -X POST http://$MASTER_IP:8080/api/register \
          -H "Content-Type: application/json" \
          -d "{\"node\":\"$NODE_NAME\",\"ip\":\"$NODE_IP\",\"status\":\"online\"}" \
          2>/dev/null && echo "No registrado no painel" || \
          echo "(painel ainda iniciando, tudo bem)"
      SHELL
    end
  end

end
