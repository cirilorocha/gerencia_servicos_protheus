# Configurações de Log - Caminho e Nome
$LogPath = Join-Path $PSScriptRoot "Log_Servicos_Totvs_Fluig.txt"
$script:historicoParados = @()

# Função de Log com Carimbo de Tempo (Append para não sobrepor)
function Write-Log {
    param([string]$Message, [string]$Level="INFO")
    $TimeStamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    $LogEntry = "$TimeStamp [$Level] - $Message"
    Add-Content -Path $LogPath -Value $LogEntry
}

# Hierarquia Granular (1 = Base, 5 = Aplicação)
function Get-Priority {
    param($service)
    $txt = ([string]$service.Name + [string]$service.DisplayName + [string]$service.Description).ToLower()
    
    if ($txt -like "*license*" ) { return 1 }
    if ($txt -like "*dbaccess*"  -or $txt -like "*dbaces*") { return 2 }
    if ($txt -like "*indexer*" -or $txt -like "*solr*") { return 3 } 
    if ($txt -like "*realtime*") { return 4 } 
    return 5 
}

function Obter-ServicosAlvo {
    $termos = @("*TSS*", "*TOTVS*", "*DBACCESS*", "*DBACES*", "*license*", "*fluig*", "*solr*")
    return Get-CimInstance Win32_Service | Where-Object {
        $curr = $_
        ($termos | Where-Object { $curr.Name -like $_ -or $curr.DisplayName -like $_ -or $curr.Description -like $_ }) -and 
        ($curr.Name -notlike "*LicenseManager*") -and
        ($curr.Name -notlike "*sppsvc*") -and
        ($curr.Name -notlike "*ClipSVC*") -and
        ($curr.Name -notlike "*MsDtsServer*") -and
        ($curr.Name -notlike "*UALSVC*") -and
        ($curr.Name -notlike "*PSI_SVC_2*") -and
        ($curr.Name -notlike "*LITSSVC*")
    }
}

# --- FUNÇÕES DE EXECUÇÃO COM LOG E CONTADOR DE PROGRESSO ---

function Executar-Parada {
    param($ListaServicos)
    # Ordena por Prioridade (Desc) e Descrição
    $paraParar = $ListaServicos | Sort-Object `
    @{ Expression = { Get-Priority $_ }; Descending = $true },
    @{ Expression = { $_.DisplayName }; Descending = $true }
    
    $total = $paraParar.Count
    $atual = 1
    
    foreach ($s in $paraParar) {
        $prio = Get-Priority $s
        $svcPID = $s.ProcessId
        $desc = $s.Description
        
        # Log incluindo a descrição
        Write-Log "Comando PARAR: $($s.Name) | Desc: $desc | (PID: $svcPID) [Prio $prio]"
        
        # Interface: Inclui o contador [X/Total] e garante o alinhamento
        $statusPrefix = "[$atual/$total] [Prio $prio] Parando: $($s.DisplayName.PadRight(40)) "
        Write-Host $statusPrefix -NoNewline
        
        Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue
        
        $wait = 30 
        while ((Get-Service -Name $s.Name).Status -ne 'Stopped' -and $wait -gt 0) {
            Write-Host "." -NoNewline
            Start-Sleep -Seconds 1
            $wait--
        }
        
        if ((Get-Service -Name $s.Name).Status -ne 'Stopped' -and $svcPID -gt 0) {
            Write-Host " [KILL] " -ForegroundColor Red -NoNewline
            Write-Log "FORÇANDO PARADA (KILL) no PID $svcPID - Serviço: $($s.Name)" "WARN"
            Stop-Process -Id $svcPID -Force -ErrorAction SilentlyContinue
        }
        
        Write-Host " [OK]" -ForegroundColor Green
        $atual++
    }
}

function Executar-Inicio {
    param($ListaServicos)
    # Ordena por Prioridade (Asc) e Descrição
    $paraSubir = $ListaServicos | Sort-Object @{Expression={(Get-Priority $_)}; Descending=$false}, DisplayName
    
    $total = $paraSubir.Count
    $atual = 1

    foreach ($s in $paraSubir) {
        $prio = Get-Priority $s
        $desc = $s.Description
        
        # Log incluindo a descrição
        Write-Log "Comando INICIAR: $($s.Name) | Desc: $desc | [Prio $prio]"
        
        # Interface: Inclui o contador [X/Total]
        $statusPrefix = "[$atual/$total] [Prio $prio] Iniciando: $($s.DisplayName.PadRight(40)) "
        Write-Host $statusPrefix -NoNewline
        
        Start-Service -Name $s.Name -ErrorAction SilentlyContinue
        
        # Simula progresso visual para serviços críticos
        if ($prio -lt 5) { 
            for ($i=0; $i -lt 5; $i++) { 
                Write-Host "." -NoNewline
                Start-Sleep -Seconds 1 
            }
        } else {
            Write-Host ".." -NoNewline
        }
        
        Write-Host " [OK]" -ForegroundColor Green
        $atual++
    }
}

# -----------------------------------------------------------

function Gerenciar-Servicos-TI {
    $continuar = $true
    Write-Log "=== Nova Sessão Iniciada ==="

    while ($continuar) {
        Clear-Host
        Write-Host "=== GERENCIADOR TOTVS/FLUIG (V4.3) ===" -ForegroundColor Cyan
        Write-Host "1. PARAR serviços (Apps -> License)"
        Write-Host "2. INICIAR serviços (License -> Apps)"
        Write-Host "3. REINICIAR serviços (Ciclo Completo: Para e Sobe)"
        Write-Host "4. SUBIR últimos serviços que foram parados"
        Write-Host "5. Abrir arquivo de Log"
        Write-Host "6. Sair"
        
        $escolha = Read-Host "`nEscolha uma opção"

        switch ($escolha) {
            "1" {
                $servicos = Obter-ServicosAlvo | Where-Object { $_.State -eq 'Running' }
                if ($servicos) {
                    $selecionados = $servicos | Select-Object Name, DisplayName, ProcessId, Description | 
                                    Sort-Object DisplayName | Out-GridView -Title "Selecione para PARAR" -PassThru
                    if ($selecionados) {
                        $script:historicoParados = $selecionados.Name
                        Executar-Parada $selecionados
                        Pause
                    }
                }
            }
            
            "2" {
                $servicos = Obter-ServicosAlvo | Where-Object { $_.State -eq 'Stopped' }
                if ($servicos) {
                    $selecionados = $servicos | Select-Object Name, DisplayName, Description | 
                                    Sort-Object DisplayName | Out-GridView -Title "Selecione para INICIAR" -PassThru
                    if ($selecionados) {
                        Executar-Inicio $selecionados
                        Pause
                    }
                }
            }

            "3" {
                $servicos = Obter-ServicosAlvo | Where-Object { $_.State -eq 'Running' }
                if ($servicos) {
                    $selecionados = $servicos | Select-Object Name, DisplayName, ProcessId, Description | 
                                    Sort-Object DisplayName | Out-GridView -Title "Selecione para REINICIAR" -PassThru
                    if ($selecionados) {
                        Write-Log "Iniciando ciclo de REINICIALIZAÇÃO para $($selecionados.Count) serviços."
                        Write-Host "`n--- ETAPA 1: PARADA ---" -ForegroundColor Yellow
                        Executar-Parada $selecionados
						
						Start-Sleep -Seconds 2
                        Write-Host "`n--- ETAPA 2: INICIALIZAÇÃO ---" -ForegroundColor Cyan
                        Executar-Inicio $selecionados
                        
                        Write-Log "Ciclo de reinicialização concluído."
                        Pause
                    }
                }
            }

            "4" {
                if ($script:historicoParados.Count -gt 0) {
                    $todos = Obter-ServicosAlvo
                    $selecionados = $todos | Where-Object { $script:historicoParados -contains $_.Name }
                    Write-Log "Reiniciando histórico de $($script:historicoParados.Count) serviços."
                    Executar-Inicio $selecionados
                    Pause
                } else {
                    Write-Host "Nenhum histórico de parada encontrado nesta sessão." -ForegroundColor Yellow; Pause
                }
            }

            "5" { if (Test-Path $LogPath) { notepad.exe $LogPath } }
            
            "6" { Write-Log "Script encerrado pelo usuário."; $continuar = $false }
            default { Write-Host "Opção inválida." }
        }
    }
}

# Verificação de Permissão de Administrador
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "ERRO: Execute o PowerShell como ADMINISTRADOR."
    Pause
} else {
    Gerenciar-Servicos-TI
}