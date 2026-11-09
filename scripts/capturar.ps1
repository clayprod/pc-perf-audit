# capturar.ps1 - captura de frametime com PresentMon, SEM analisar (analise e offline, jogo fechado).
# PowerShell 5.1. ASCII only.
# Uso (elevado ou em "Performance Log Users"):
#   powershell -NoProfile -ExecutionPolicy Bypass -File capturar.ps1 -Processo VALORANT-Win64-Shipping.exe -Segundos 420 -Rotulo "DM Sunset estado-base" -PresentMon C:\ferramentas\PresentMon.exe
# Saida em -Saida: frametime-AAAAMMDD-HHMMSS.csv, .processos-inicio.json, .processos-fim.json, .meta.json
param(
    [Parameter(Mandatory = $true)][string]$Processo,
    [int]$Segundos = 420,
    [string]$Rotulo = '',
    [string]$PresentMon = '',
    [string]$Saida = (Join-Path $env:USERPROFILE 'capturas')
)
$ErrorActionPreference = 'Stop'

# --- localizar PresentMon
if (-not $PresentMon) {
    $cand = @(Get-Command PresentMon*.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source)
    if ($cand.Count) { $PresentMon = $cand[0] }
}
if (-not $PresentMon -or -not (Test-Path $PresentMon)) {
    Write-Host 'PresentMon nao encontrado. Baixe de https://github.com/GameTechDev/PresentMon/releases e passe -PresentMon <caminho>.'
    exit 2
}
New-Item -ItemType Directory -Force -Path $Saida | Out-Null

# --- pre-condicoes
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { Write-Host 'AVISO: nao elevado. ETW pode falhar se voce nao estiver em "Performance Log Users".' }
$nomeProc = [IO.Path]::GetFileNameWithoutExtension($Processo)
if (-not (Get-Process -Name $nomeProc -ErrorAction SilentlyContinue)) {
    Write-Host ('O processo ' + $Processo + ' nao esta rodando. Abra o jogo e entre na partida primeiro.')
    exit 3
}

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$base = Join-Path $Saida ('frametime-' + $ts)
$csv = $base + '.csv'

# --- snapshot barato de processos (so Get-Process: o CSV do PresentMon so ve quem APRESENTA)
function Snap($arquivo) {
    Get-Process | ForEach-Object {
        $cpuS = $null; try { $cpuS = [math]::Round($_.TotalProcessorTime.TotalSeconds, 2) } catch {}
        [ordered]@{ nome = $_.ProcessName; pid = $_.Id; cpuSegAcumulado = $cpuS; MB = [math]::Round($_.WorkingSet64 / 1MB) }
    } | ConvertTo-Json -Depth 3 | Set-Content -Path $arquivo -Encoding UTF8
}
Snap ($base + '.processos-inicio.json')

# --- argumentos conforme a versao (1.x usa -process_name; 2.x usa --process_name)
$major = (Get-Item $PresentMon).VersionInfo.FileMajorPart
if ($major -ge 2) {
    $args = @('--process_name', $Processo, '--output_file', $csv, '--timed', $Segundos, '--terminate_after_timed', '--no_console_stats')
} else {
    $args = @('-process_name', $Processo, '-output_file', $csv, '-timed', $Segundos, '-terminate_after_timed', '-no_top')
}

Write-Host ('Capturando ' + $Segundos + ' s de ' + $Processo + '  -> ' + $csv)
Write-Host 'NAO USE A MAQUINA ate terminar (nem o agente). Jogue normalmente.'
$ini = Get-Date
# -NoNewWindow: herda o console atual; um console novo roubaria o foco do jogo em tela cheia exclusiva.
$p = Start-Process -FilePath $PresentMon -ArgumentList $args -NoNewWindow -Wait -PassThru
$fim = Get-Date
Snap ($base + '.processos-fim.json')

$meta = [ordered]@{ rotulo = $Rotulo; processo = $Processo; inicio = $ini.ToString('s'); fim = $fim.ToString('s'); segundosPedidos = $Segundos
    presentMon = $PresentMon; presentMonMajor = $major; exitCode = $p.ExitCode; csv = $csv
    observacao = 'anotar: mapa/modo, estado da maquina (o que mudou desde a ultima captura), veredito do dono' }
$meta | ConvertTo-Json | Set-Content -Path ($base + '.meta.json') -Encoding UTF8

if (-not (Test-Path $csv)) { Write-Host 'ERRO: CSV nao foi criado (permissao ETW? processo nao apresentou?).'; exit 4 }
$tam = [math]::Round((Get-Item $csv).Length / 1MB, 1)
Write-Host ('Pronto: ' + $tam + ' MB.')
Write-Host 'Quando o jogo estiver FECHADO, analise:'
Write-Host ('  python "' + (Join-Path $PSScriptRoot 'analisar-frametime.py') + '" "' + $csv + '"')
