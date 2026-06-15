# manage.ps1 — Gerenciador CONNECTONGS
# Uso: .\manage.ps1 <comando>
param([string]$cmd = "help")

function Banner {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║     CONNECTONGS — Cluster Manager            ║" -ForegroundColor Green
    Write-Host "  ║     1 VM + 4 nos + Nginx + Manager           ║" -ForegroundColor Green
    Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
}

Banner

switch ($cmd) {

    # ── VM ────────────────────────────────────────────────────────────────────
    "vm-up" {
        Write-Host "▶ Subindo VM (primeira vez ~10 min)..." -ForegroundColor Green
        vagrant up
        Write-Host ""
        Write-Host "✅ VM pronta! Acesse:" -ForegroundColor Green
        Write-Host "   Load Balancer : http://localhost:8080"
        Write-Host "   Manager/Painel: http://localhost:9000"
    }

    "vm-down"    { vagrant halt;       Write-Host "✅ VM parada." -ForegroundColor Green }
    "vm-destroy" { vagrant destroy -f; Write-Host "✅ VM destruida." -ForegroundColor Green }
    "vm-ssh"     { vagrant ssh }

    # ── Docker (roda dentro da VM via vagrant ssh) ────────────────────────────
    "up" {
        Write-Host "▶ Subindo containers dentro da VM..." -ForegroundColor Green
        vagrant ssh -c "cd /home/vagrant/connectongs && docker compose up -d --build"
        Write-Host ""
        Write-Host "✅ Containers prontos!" -ForegroundColor Green
        Write-Host "   Load Balancer : http://localhost:8080"
        Write-Host "   No 1 HTTP     : http://localhost:8081  RPC: localhost:9101"
        Write-Host "   No 2 HTTP     : http://localhost:8082  RPC: localhost:9102"
        Write-Host "   No 3 HTTP     : http://localhost:8083  RPC: localhost:9103"
        Write-Host "   No 4 HTTP     : http://localhost:8084  RPC: localhost:9104"
        Write-Host "   Manager/Painel: http://localhost:9000"
    }

    "down" {
        Write-Host "⏹ Parando containers..." -ForegroundColor Yellow
        vagrant ssh -c "cd /home/vagrant/connectongs && docker compose down"
        Write-Host "✅ Containers parados." -ForegroundColor Green
    }

    "clean" {
        Write-Host "🧹 Parando e limpando dados..." -ForegroundColor Yellow
        vagrant ssh -c "cd /home/vagrant/connectongs && docker compose down -v"
        Write-Host "✅ Limpo." -ForegroundColor Green
    }

    # ── Monitoramento ─────────────────────────────────────────────────────────
    "status" {
        Write-Host "`n📊 Status dos containers:" -ForegroundColor Blue
        vagrant ssh -c "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
    }

    "health" {
        Write-Host "`n💓 Health check dos nos:" -ForegroundColor Blue
        8081..8084 | ForEach-Object {
            try {
                $r = Invoke-RestMethod "http://localhost:$_/health" -TimeoutSec 3
                Write-Host ("  porta {0} → ✅ no={1}  ip={2}" -f $_, $r.node, $r.ip) -ForegroundColor Green
            } catch {
                Write-Host ("  porta {0} → ❌ offline" -f $_) -ForegroundColor Red
            }
        }
    }

    "ips" {
        Write-Host "`n🌐 IPs dos containers:" -ForegroundColor Blue
        $cs = @("conn_node1","conn_node2","conn_node3","conn_node4","conn_lb","conn_manager")
        foreach ($c in $cs) {
            $ip = vagrant ssh -c "docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $c 2>/dev/null" 2>$null
            Write-Host ("  {0,-20} → {1}" -f $c, $ip.Trim())
        }
    }

    "dist" {
        Write-Host "`n📊 Distribuicao das requisicoes pelo Nginx:" -ForegroundColor Blue
        1..8 | ForEach-Object {
            try {
                $r = Invoke-RestMethod "http://localhost:8080/health" -TimeoutSec 3
                Write-Host ("  req {0:D2} → no={1}  ip={2}" -f $_, $r.node, $r.ip)
            } catch {
                Write-Host ("  req {0:D2} → ❌ erro" -f $_) -ForegroundColor Red
            }
        }
    }

    # ── Logs ──────────────────────────────────────────────────────────────────
    "logs" {
        Write-Host "📋 Todos os logs (Ctrl+C para sair)..." -ForegroundColor Cyan
        vagrant ssh -c "cd /home/vagrant/connectongs && docker compose logs -f"
    }

    "logs-node1" { vagrant ssh -c "docker logs -f conn_node1" }
    "logs-node2" { vagrant ssh -c "docker logs -f conn_node2" }
    "logs-node3" { vagrant ssh -c "docker logs -f conn_node3" }
    "logs-node4" { vagrant ssh -c "docker logs -f conn_node4" }
    "logs-lb"    { vagrant ssh -c "docker logs -f conn_lb" }

    # ── RPC ───────────────────────────────────────────────────────────────────
    "rpc-ping" {
        Write-Host "`n🔌 Testando RPC de cada no (socket TCP direto):" -ForegroundColor Magenta
        $ports = @(9101, 9102, 9103, 9104)
        $n = 1
        foreach ($p in $ports) {
            try {
                $tcp    = New-Object System.Net.Sockets.TcpClient
                $tcp.Connect("localhost", $p)
                $stream = $tcp.GetStream()
                $msg    = [System.Text.Encoding]::UTF8.GetBytes('{"action":"ping","args":{}}' + "`n")
                $stream.Write($msg, 0, $msg.Length)
                Start-Sleep -Milliseconds 500
                $buf  = New-Object byte[] 4096
                $read = $stream.Read($buf, 0, $buf.Length)
                $resp = [System.Text.Encoding]::UTF8.GetString($buf, 0, $read)
                $tcp.Close()
                Write-Host ("  RPC node{0} porta {1} → ✅ {2}" -f $n, $p, $resp.Trim()) -ForegroundColor Green
            } catch {
                Write-Host ("  RPC node{0} porta {1} → ❌ offline" -f $n, $p) -ForegroundColor Red
            }
            $n++
        }
    }

    # ── Painel ────────────────────────────────────────────────────────────────
    "dashboard" {
        Write-Host "`n🌐 Abrindo painel no navegador..." -ForegroundColor Cyan
        Start-Process "http://localhost:9000"
        Write-Host "   Manager: http://localhost:9000"
        Write-Host "   Nginx  : http://localhost:8080"
    }

    # ── Help ──────────────────────────────────────────────────────────────────
    default {
        Write-Host "  Uso: .\manage.ps1 <comando>`n"
        Write-Host "  -- VM --"
        Write-Host "  vm-up          Sobe a VM (primeira vez ~10 min)"
        Write-Host "  vm-down        Para a VM"
        Write-Host "  vm-ssh         Acessa a VM via SSH"
        Write-Host "  vm-destroy     Apaga a VM e todos os dados"
        Write-Host ""
        Write-Host "  -- Containers (dentro da VM) --"
        Write-Host "  up             Sobe os containers"
        Write-Host "  down           Para os containers"
        Write-Host "  clean          Para e limpa volumes"
        Write-Host ""
        Write-Host "  -- Monitoramento --"
        Write-Host "  status         Estado dos containers"
        Write-Host "  health         Health check dos nos"
        Write-Host "  ips            IPs de cada container"
        Write-Host "  dist           Distribuicao das requisicoes"
        Write-Host "  dashboard      Abre o painel no navegador"
        Write-Host ""
        Write-Host "  -- Logs --"
        Write-Host "  logs           Todos os logs"
        Write-Host "  logs-node1     Logs do no 1"
        Write-Host "  logs-node2     Logs do no 2"
        Write-Host ""
        Write-Host "  -- RPC --"
        Write-Host "  rpc-ping       Testa socket RPC de cada no"
        Write-Host ""
    }
}
