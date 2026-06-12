#!/usr/bin/env bash
# cluster.sh — Gerencia o cluster CONNECTONGS
#
# COMO USAR (Git Bash no Windows):
#   bash cluster.sh up          → sobe master + 4 nós
#   bash cluster.sh down        → para tudo
#   bash cluster.sh status      → estado de cada VM e container
#   bash cluster.sh logs node1  → logs de um nó
#   bash cluster.sh dashboard   → mostra o link do painel
#   bash cluster.sh destroy     → apaga tudo

set -e

case "$1" in

  up)
    echo "========================================"
    echo "  Subindo cluster CONNECTONGS..."
    echo "  Primeira vez: ~10-15 min"
    echo "  Proximas vezes: ~2-3 min"
    echo "========================================"
    echo ""
    echo "[1/2] Subindo master (banco + painel web)..."
    vagrant up master
    echo ""
    echo "[2/2] Subindo os 4 nos..."
    vagrant up node1 node2 node3 node4
    echo ""
    echo "========================================"
    echo "  CONNECTONGS Cluster esta pronto!"
    echo ""
    echo "  Master  192.168.56.10  banco + painel"
    echo "  Node1   192.168.56.11  1 container app"
    echo "  Node2   192.168.56.12  1 container app"
    echo "  Node3   192.168.56.13  1 container app"
    echo "  Node4   192.168.56.14  1 container app"
    echo ""
    echo "  Painel web: http://localhost:8080"
    echo "========================================"
    ;;

  down)
    echo "Parando cluster..."
    vagrant halt
    echo "Cluster parado."
    ;;

  status)
    echo "========================================"
    echo "  Status do cluster"
    echo "========================================"
    for vm in master node1 node2 node3 node4; do
      echo ""
      echo "--- $vm ---"
      vagrant ssh $vm -c \
        "docker ps --format 'table {{.Names}}\t{{.Status}}'" \
        2>/dev/null || echo "  (VM offline)"
    done
    ;;

  logs)
    TARGET=${2:-node1}
    echo "Logs de $TARGET (Ctrl+C para sair)..."
    vagrant ssh $TARGET -c \
      "docker logs -f connectongs_${TARGET} 2>&1" 2>/dev/null
    ;;

  dashboard)
    echo ""
    echo "========================================"
    echo "  Painel CONNECTONGS"
    echo ""
    echo "  Abra no navegador:"
    echo "  http://localhost:8080"
    echo ""
    echo "  Ou acesse direto pelo IP do master:"
    echo "  http://192.168.56.10:8080"
    echo "========================================"
    # Tenta abrir automaticamente no Windows
    cmd.exe /c start http://localhost:8080 2>/dev/null || \
    powershell.exe -Command "Start-Process 'http://localhost:8080'" 2>/dev/null || \
    echo "  (abra manualmente no navegador)"
    ;;

  destroy)
    echo "ATENCAO: Isso vai apagar todas as VMs e dados."
    read -p "Confirma? [s/N] " c
    [[ "$c" == "s" || "$c" == "S" ]] || exit 0
    vagrant destroy -f
    echo "Cluster destruido."
    ;;

  *)
    echo ""
    echo "CONNECTONGS Cluster Manager"
    echo ""
    echo "  bash cluster.sh up            Sobe master + 4 nos"
    echo "  bash cluster.sh down          Para o cluster"
    echo "  bash cluster.sh status        Estado de cada VM"
    echo "  bash cluster.sh logs [no]     Logs de um no (padrao: node1)"
    echo "  bash cluster.sh dashboard     Abre o painel web"
    echo "  bash cluster.sh destroy       Apaga tudo"
    echo ""
    ;;
esac
