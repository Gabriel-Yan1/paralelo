# manage.ps1 - Gerenciador CONNECTONGS
# Uso: .\manage.ps1 <comando>
param([string]$cmd = "help")

function Banner {
    Write-Host ""
    Write-Host "  +----------------------------------------------+" -ForegroundColor Green
    Write-Host "  |     CONNECTONGS - Cluster Manager            |" -ForegroundColor Green
    Write-Host "  |     1 VM + 4 nos + Nginx + Manager           |" -ForegroundColor Green
    Write-Host "  +----------------------------------------------+" -ForegroundColor Green
    Write-Host ""
}

Banner

switch ($cmd) {

    "vm-up" {
        Write-Host "Subindo VM (primeira vez ~10 min)..." -ForegroundColor Green
        vagrant up
        Write-Host ""
        Write-Host "VM pronta! Acesse:" -ForegroundColor Green
        Write-Host "   Load Balancer : http://localhost:8080"
        Write-Host "   Manager/Painel: http://localhost:9000"
    }

    "vm-down" {
        vagrant halt
        Write-Host "VM parada." -ForegroundColor Green
    }

    "vm-destroy" {
        vagrant destroy -f
        Write-Host "VM destruida." -ForegroundColor Green
    }

    "vm-ssh" {
        vagrant ssh
    }

    "up" {
        Write-Host "Subindo containers dentro da VM..." -ForegroundColor Green
        vagrant ssh -c "cd /home/vagrant/connectongs; docker compose up -d --build"
        Write-Host ""
        Write-Host "Containers prontos!" -ForegroundColor Green
        Write-Host "   Load Balancer : http://localhost:8080"
        Write-Host "   No 1 HTTP     : http://localhost:8081  RPC: 9101"
        Write-Host "   No 2 HTTP     : http://localhost:8082  RPC: 9102"
        Write-Host "   No 3 HTTP     : http://localhost:8083  RPC: 9103"
        Write-Host "   No 4 HTTP     : http://localhost:8084  RPC: 9104"
        Write-Host "   Manager/Painel: http://localhost:9000"
    }

    "down" {
        Write-Host "Parando containers..." -ForegroundColor Yellow
        vagrant ssh -c "cd /home/vagrant/connectongs; docker compose down"
        Write-Host "Containers parados." -ForegroundColor Green
    }

    "clean" {
        Write-Host "Parando e limpando dados..." -ForegroundColor Yellow
        vagrant ssh -c "cd /home/vagrant/connectongs; docker compose down -v"
        Write-Host "Limpo." -ForegroundColor Green
    }

    "status" {
        Write-Host ""
        Write-Host "Status dos containers:" -ForegroundColor Blue
        vagrant ssh -c "docker ps --format 'table {{.Names}}\t{{.Status}}'"
    }

    "health" {
        Write-Host ""
        Write-Host "Health check dos nos:" -ForegroundColor Blue
        $ports = @(8081, 8082, 8083, 8084)
        $n = 1
        foreach ($p in $ports) {
            try {
                $r = Invoke-RestMethod "http://localhost:$p/health" -TimeoutSec 3
                Write-Host ("  no{0} porta {1} -> OK  node={2}  ip={3}" -f $n, $p, $r.node, $r.ip) -ForegroundColor Green
            } catch {
                Write-Host ("  no{0} porta {1} -> OFFLINE" -f $n, $p) -ForegroundColor Red
            }
            $n++
        }
    }

    "dist" {
        Write-Host ""
        Write-Host "Distribuicao das requisicoes pelo Nginx:" -ForegroundColor Blue
        for ($i = 1; $i -le 8; $i++) {
            try {
                $r = Invoke-RestMethod "http://localhost:8080/health" -TimeoutSec 3
                Write-Host ("  req {0:D2} -> node={1}  ip={2}" -f $i, $r.node, $r.ip)
            } catch {
                Write-Host ("  req {0:D2} -> ERRO" -f $i) -ForegroundColor Red
            }
        }
    }

    "logs" {
        Write-Host "Todos os logs (Ctrl+C para sair)..." -ForegroundColor Cyan
        vagrant ssh -c "cd /home/vagrant/connectongs; docker compose logs -f"
    }

    "logs-node1" { vagrant ssh -c "docker logs -f conn_node1" }
    "logs-node2" { vagrant ssh -c "docker logs -f conn_node2" }
    "logs-node3" { vagrant ssh -c "docker logs -f conn_node3" }
    "logs-node4" { vagrant ssh -c "docker logs -f conn_node4" }

    "rpc-ping" {
        Write-Host ""
        Write-Host "Testando RPC de cada no (socket TCP direto):" -ForegroundColor Magenta
        $ports = @(9101, 9102, 9103, 9104)
        $n = 1
        foreach ($p in $ports) {
            try {
                $tcp    = New-Object System.Net.Sockets.TcpClient
                $tcp.Connect("localhost", $p)
                $stream = $tcp.GetStream()
                $msgStr = '{"action":"ping","args":{}}'
                $msg    = [System.Text.Encoding]::UTF8.GetBytes($msgStr + "`n")
                $stream.Write($msg, 0, $msg.Length)
                Start-Sleep -Milliseconds 500
                $buf  = New-Object byte[] 4096
                $read = $stream.Read($buf, 0, $buf.Length)
                $resp = [System.Text.Encoding]::UTF8.GetString($buf, 0, $read)
                $tcp.Close()
                Write-Host ("  RPC node{0} porta {1} -> OK {2}" -f $n, $p, $resp.Trim()) -ForegroundColor Green
            } catch {
                Write-Host ("  RPC node{0} porta {1} -> OFFLINE" -f $n, $p) -ForegroundColor Red
            }
            $n++
        }
    }

    "dashboard" {
        Write-Host ""
        Write-Host "Abrindo painel no navegador..." -ForegroundColor Cyan
        Start-Process "http://localhost:9000"
        Write-Host "   Manager: http://localhost:9000"
        Write-Host "   Nginx  : http://localhost:8080"
    }

    default {
        Write-Host "  Uso: .\manage.ps1 comando"
        Write-Host ""
        Write-Host "  -- VM --"
        Write-Host "  vm-up        Sobe a VM (primeira vez ~10 min)"
        Write-Host "  vm-down      Para a VM"
        Write-Host "  vm-ssh       Acessa a VM via SSH"
        Write-Host "  vm-destroy   Apaga a VM e todos os dados"
        Write-Host ""
        Write-Host "  -- Containers --"
        Write-Host "  up           Sobe os containers"
        Write-Host "  down         Para os containers"
        Write-Host "  clean        Para e limpa volumes"
        Write-Host ""
        Write-Host "  -- Monitoramento --"
        Write-Host "  status       Estado dos containers"
        Write-Host "  health       Health check dos nos"
        Write-Host "  dist         Distribuicao das requisicoes"
        Write-Host "  dashboard    Abre o painel no navegador"
        Write-Host ""
        Write-Host "  -- Logs --"
        Write-Host "  logs         Todos os logs"
        Write-Host "  logs-node1   Logs do no 1"
        Write-Host "  logs-node2   Logs do no 2"
        Write-Host "  logs-node3   Logs do no 3"
        Write-Host "  logs-node4   Logs do no 4"
        Write-Host ""
        Write-Host "  -- RPC --"
        Write-Host "  rpc-ping     Testa socket RPC de cada no"
    }
}
