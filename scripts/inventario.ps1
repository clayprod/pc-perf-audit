# inventario.ps1 - inventario SOMENTE LEITURA de um PC Windows para auditoria de performance.
# PowerShell 5.1. ASCII only (PS 5.1 le .ps1 sem BOM como ANSI).
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File inventario.ps1 -Saida C:\auditoria\pc1
# Rode ELEVADO para campos completos (bcdedit, tarefas SYSTEM, eventos). Nao altera nada.
param(
    [string]$Saida = (Join-Path $env:TEMP 'inventario-pc'),
    [int]$AmostraCpuSegundos = 5
)
$ErrorActionPreference = 'SilentlyContinue'
New-Item -ItemType Directory -Force -Path $Saida | Out-Null

$inv = [ordered]@{}
$txt = New-Object System.Text.StringBuilder
function Add-Linha([string]$s) { [void]$txt.AppendLine($s) }
function Add-Sec([string]$s) { Add-Linha ''; Add-Linha ('=== ' + $s + ' ===') }
function Reg($path, $name) { try { (Get-ItemProperty -Path $path -Name $name -ErrorAction Stop).$name } catch { $null } }

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$inv.elevado = $admin
Add-Linha ('Inventario ' + (Get-Date -Format 's') + '  elevado=' + $admin)
if (-not $admin) { Add-Linha 'AVISO: nao elevado - bcdedit, tarefas SYSTEM e alguns eventos virao vazios.' }

# ---- CPU
Add-Sec 'CPU'
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$inv.cpu = [ordered]@{ nome = $cpu.Name.Trim(); fabricante = $cpu.Manufacturer; nucleos = $cpu.NumberOfCores
    threads = $cpu.NumberOfLogicalProcessors; clockMaxMHz = $cpu.MaxClockSpeed; l3KB = $cpu.L3CacheSize; soquetes = @(Get-CimInstance Win32_Processor).Count }
$inv.cpu.GetEnumerator() | ForEach-Object { Add-Linha ('{0,-12} {1}' -f $_.Key, $_.Value) }
$nome = $cpu.Name
$plat = 'desconhecida'
if ($nome -match 'Ryzen') { $plat = 'AMD Ryzen'; if ($nome -match 'X3D') { $plat += ' X3D' } }
elseif ($nome -match 'Core\(TM\) Ultra') { $plat = 'Intel Core Ultra (hibrido)' }
elseif ($nome -match 'i[3579]-1[2-4]\d{3}') { $plat = 'Intel Core hibrido (12a-14a gen: P+E cores)' }
elseif ($nome -match 'Intel') { $plat = 'Intel Core nao-hibrido (<=11a gen) ou outro' }
$inv.plataformaCpu = $plat
Add-Linha ('plataforma  ' + $plat)
Add-Linha ('SMT/HT ativo: ' + ($cpu.NumberOfLogicalProcessors -gt $cpu.NumberOfCores))

# ---- Placa e BIOS
Add-Sec 'PLACA / BIOS'
$bb = Get-CimInstance Win32_BaseBoard; $bios = Get-CimInstance Win32_BIOS
$inv.placa = [ordered]@{ fabricante = $bb.Manufacturer; modelo = $bb.Product; biosVersao = $bios.SMBIOSBIOSVersion
    biosData = if ($bios.ReleaseDate) { $bios.ReleaseDate.ToString('yyyy-MM-dd') } else { $null } }
$inv.placa.GetEnumerator() | ForEach-Object { Add-Linha ('{0,-12} {1}' -f $_.Key, $_.Value) }

# ---- RAM
Add-Sec 'MEMORIA'
$mods = @(Get-CimInstance Win32_PhysicalMemory)
$inv.ram = @($mods | ForEach-Object { [ordered]@{ slot = $_.DeviceLocator; GB = [math]::Round($_.Capacity / 1GB, 1)
    fabricante = $_.Manufacturer; pn = ([string]$_.PartNumber).Trim(); nominalMTs = $_.Speed; configuradoMTs = $_.ConfiguredClockSpeed
    tensaoConfiguradaMV = $_.ConfiguredVoltage; tensaoMinMV = $_.MinVoltage; tensaoMaxMV = $_.MaxVoltage } })
$inv.ram | ForEach-Object { Add-Linha (($_.GetEnumerator() | ForEach-Object { $_.Key + '=' + $_.Value }) -join '  ') }
Add-Linha 'NOTA: ConfiguredVoltage do SMBIOS pode mentir (mostrou 1200 mV com 1,36 V real). Use sensor (HWiNFO) para tensao.'
if ($mods.Count -ge 1 -and ($mods | Select-Object -First 1).ConfiguredClockSpeed -lt ($mods | Select-Object -First 1).Speed) { Add-Linha 'ATENCAO: configurado < nominal (XMP/DOCP/EXPO desligado?)' }
if ($mods.Count -eq 1) { Add-Linha 'ATENCAO: 1 modulo = single channel.' }

# ---- GPU / Display
Add-Sec 'GPU / DISPLAY'
$gpus = @(Get-CimInstance Win32_VideoController)
$inv.gpu = @($gpus | ForEach-Object { [ordered]@{ nome = $_.Name; driver = $_.DriverVersion
    data = if ($_.DriverDate) { $_.DriverDate.ToString('yyyy-MM-dd') } else { $null }; resAtual = ('{0}x{1}' -f $_.CurrentHorizontalResolution, $_.CurrentVerticalResolution)
    refreshAtual = $_.CurrentRefreshRate } })
$inv.gpu | ForEach-Object { Add-Linha (($_.GetEnumerator() | ForEach-Object { $_.Key + '=' + $_.Value }) -join '  ') }
$vendor = 'desconhecido'
$gn = ($gpus | ForEach-Object { $_.Name }) -join ' '
if ($gn -match 'NVIDIA|GeForce|RTX|GTX') { $vendor = 'NVIDIA' } elseif ($gn -match 'AMD|Radeon') { $vendor = 'AMD' } elseif ($gn -match 'Intel.*Arc') { $vendor = 'Intel Arc' } elseif ($gn -match 'Intel') { $vendor = 'Intel iGPU' }
$inv.gpuVendor = $vendor
Add-Linha ('vendor GPU: ' + $vendor + '   (mais de uma GPU? confira qual esta ligada ao monitor)')
try {
    $mons = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID | ForEach-Object {
        $n = -join ($_.UserFriendlyName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })
        $m = -join ($_.ManufacturerName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })
        $m + ' ' + $n }
    $inv.monitores = @($mons); Add-Linha ('monitores: ' + ($mons -join ' | '))
} catch {}
Add-Linha 'Leia o EDID (HKLM\SYSTEM\CurrentControlSet\Enum\DISPLAY\*\*\Device Parameters\EDID) para saber que resolucoes nao nativas existem e a que taxa.'

# ---- SO e flags de performance
Add-Sec 'WINDOWS'
$os = Get-CimInstance Win32_OperatingSystem
$inv.so = [ordered]@{ nome = $os.Caption; build = $os.BuildNumber; versao = $os.Version; ultimoBoot = $os.LastBootUpTime.ToString('s') }
$inv.so.GetEnumerator() | ForEach-Object { Add-Linha ('{0,-12} {1}' -f $_.Key, $_.Value) }

$flags = [ordered]@{}
$flags.MPO_OverlayTestMode = Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode'
$flags.HAGS_HwSchMode_2on_1off = Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
$flags.ModoDeJogo_AutoGameModeEnabled = Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled'
$flags.GameDVR_Enabled = Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled'
$flags.AppCaptureEnabled = Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled'
$flags.Win32PrioritySeparation = Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation'
$flags.SecureBoot_UEFI = Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State' 'UEFISecureBootEnabled'
$flags.HVCI_Enabled = Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled'
$flags.Widgets_Policy = Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests'
$flags.Defender_DisableAntiSpyware_Policy = Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' 'DisableAntiSpyware'
$flags.HypervisorPresent = (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
try { $dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard
      $flags.VBS_Status_0off_2running = $dg.VirtualizationBasedSecurityStatus; $flags.DeviceGuard_ServicesRunning = ($dg.SecurityServicesRunning -join ',') } catch {}
$inv.flags = $flags
$flags.GetEnumerator() | ForEach-Object { Add-Linha ('{0,-40} {1}' -f $_.Key, $_.Value) }
Add-Linha 'Legenda: MPO OverlayTestMode=5 -> MPO off. HAGS 2=ligado 1=desligado. AutoGameModeEnabled 0=off.'

$tpm = $null; try { $tpm = Get-CimInstance -Namespace root\cimv2\Security\MicrosoftTpm -ClassName Win32_Tpm } catch {}
if ($tpm) { $inv.tpm = [ordered]@{ presente = $true; versao = $tpm.SpecVersion; habilitado = $tpm.IsEnabled_InitialValue }; Add-Linha ('TPM: ' + $tpm.SpecVersion) } else { Add-Linha 'TPM: nao lido (sem elevacao ou ausente)' }

if ($admin) {
    $bcd = (& bcdedit /enum '{current}') 2>$null | Out-String
    $inv.bcdedit = $bcd
    Add-Linha 'bcdedit (procure useplatformclock, disabledynamictick, hypervisorlaunchtype):'
    ($bcd -split "`r?`n") | Where-Object { $_ -match 'useplatform|dynamictick|hypervisor|tscsync|nx\s' } | ForEach-Object { Add-Linha ('  ' + $_) }
}

# ---- Energia
Add-Sec 'ENERGIA'
$plano = (& powercfg /getactivescheme) 2>$null | Out-String
$inv.planoAtivo = $plano.Trim(); Add-Linha $plano.Trim()
$pq = (& powercfg /q SCHEME_CURRENT SUB_PROCESSOR) 2>$null | Out-String
Set-Content -Path (Join-Path $Saida 'powercfg-processador.txt') -Value $pq -Encoding UTF8
Add-Linha 'Config completa do subgrupo do processador (EPP=PERFEPP, PERFAUTONOMOUS, PROCTHROTTLEMIN/MAX, LATENCYHINTPERF, CPMINCORES) em powercfg-processador.txt'
$pl = (& powercfg /list) 2>$null | Out-String
Add-Linha $pl
Add-Linha 'NOTA: o plano pode alternar por software (Process Lasso). Aplique EPP em TODOS os planos relevantes.'

# ---- Rede
Add-Sec 'REDE'
$nics = @(Get-NetAdapter | Where-Object { $_.Status -eq 'Up' })
$inv.nics = @($nics | ForEach-Object { [ordered]@{ nome = $_.Name; desc = $_.InterfaceDescription; link = $_.LinkSpeed } })
$inv.nics | ForEach-Object { Add-Linha (($_.GetEnumerator() | ForEach-Object { $_.Key + '=' + $_.Value }) -join '  ') }
Add-Linha 'ATENCAO: link < 1 Gbps em LAN gigabit = cabo/porta/negociacao (medir se importa).'

# ---- Discos
Add-Sec 'ARMAZENAMENTO'
$inv.discos = @(Get-PhysicalDisk | ForEach-Object { [ordered]@{ nome = $_.FriendlyName; tipo = $_.MediaType; barramento = $_.BusType; GB = [math]::Round($_.Size / 1GB) } })
$inv.discos | ForEach-Object { Add-Linha (($_.GetEnumerator() | ForEach-Object { $_.Key + '=' + $_.Value }) -join '  ') }
$inv.volumes = @(Get-Volume | Where-Object { $_.DriveLetter } | ForEach-Object { [ordered]@{ letra = $_.DriveLetter; livreGB = [math]::Round($_.SizeRemaining / 1GB, 1); totalGB = [math]::Round($_.Size / 1GB, 1) } })
$inv.volumes | ForEach-Object { Add-Linha (($_.GetEnumerator() | ForEach-Object { $_.Key + '=' + $_.Value }) -join '  ') }

# ---- Servicos de update
Add-Sec 'WINDOWS UPDATE (contencao)'
$upd = foreach ($n in 'wuauserv', 'UsoSvc', 'DoSvc', 'WaaSMedicSvc', 'BITS') {
    [ordered]@{ servico = $n; startRegistro = (Reg ('HKLM:\SYSTEM\CurrentControlSet\Services\' + $n) 'Start'); estado = (Get-Service $n).Status } }
$inv.update = @($upd)
$upd | ForEach-Object { Add-Linha (($_.GetEnumerator() | ForEach-Object { $_.Key + '=' + $_.Value }) -join '  ') }
Add-Linha 'Start: 2=auto 3=manual 4=desabilitado.'

# ---- Startup
Add-Sec 'STARTUP (Run + StartupApproved)'
function Get-Run($hive, $label) {
    $k = $hive + '\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
    $ap = $hive + '\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
    $p = Get-ItemProperty -Path $k
    if (-not $p) { return }
    $p.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
        $b = $null; try { $b = (Get-ItemProperty -Path $ap -Name $_.Name -ErrorAction Stop).($_.Name)[0] } catch {}
        $st = 'habilitado(sem byte)'; if ($b -eq 2) { $st = 'habilitado' } elseif ($b -eq 3) { $st = 'DESABILITADO' }
        [ordered]@{ chave = $label; nome = $_.Name; estado = $st; comando = $_.Value } }
}
$run = @(Get-Run 'HKCU:' 'HKCU') + @(Get-Run 'HKLM:' 'HKLM')
$inv.startup = $run
$run | ForEach-Object { Add-Linha ('{0} | {1} | {2} | {3}' -f $_.chave, $_.nome, $_.estado, $_.comando) }
Add-Linha 'O que decide se sobe e o byte do StartupApproved (2=on, 3=off), nao a presenca no Run.'

# ---- Servicos de terceiros rodando
Add-Sec 'SERVICOS DE TERCEIROS RODANDO'
$svc = Get-CimInstance Win32_Service | Where-Object { $_.State -eq 'Running' -and $_.PathName -notmatch '\\Windows\\' -and $_.PathName -notmatch 'svchost' }
$inv.servicosTerceiros = @($svc | ForEach-Object { [ordered]@{ nome = $_.Name; exibicao = $_.DisplayName; inicio = $_.StartMode; caminho = $_.PathName } })
$svc | ForEach-Object { Add-Linha ('{0} | {1} | {2}' -f $_.Name, $_.StartMode, $_.PathName) }

# ---- Tarefas nao-Microsoft
Add-Sec 'TAREFAS AGENDADAS NAO-MICROSOFT (ativas)'
$tsk = Get-ScheduledTask | Where-Object { $_.State -ne 'Disabled' -and $_.TaskPath -notmatch '^\\Microsoft\\' }
$inv.tarefas = @($tsk | ForEach-Object { [ordered]@{ nome = $_.TaskName; caminho = $_.TaskPath; estado = [string]$_.State } })
$tsk | ForEach-Object { Add-Linha ($_.TaskPath + $_.TaskName + '  ' + $_.State) }
if (-not $admin) { Add-Linha '(sem elevacao, tarefas SYSTEM ficam invisiveis)' }

# ---- Processos: amostra de CPU
Add-Sec ('PROCESSOS - CPU em ' + $AmostraCpuSegundos + ' s (agora, jogo aberto ou nao)')
$ncpu = [Environment]::ProcessorCount
$a = @{}; Get-Process | ForEach-Object { $a[$_.Id] = @($_.ProcessName, $_.TotalProcessorTime.TotalSeconds) }
Start-Sleep -Seconds $AmostraCpuSegundos
$linhas = foreach ($p in Get-Process) {
    if ($a.ContainsKey($p.Id)) { $d = $p.TotalProcessorTime.TotalSeconds - $a[$p.Id][1]
        [pscustomobject]@{ nome = $p.ProcessName; pctNucleo = [math]::Round(100 * $d / $AmostraCpuSegundos, 1); MB = [math]::Round($p.WorkingSet64 / 1MB) } }
}
$top = $linhas | Sort-Object pctNucleo -Descending | Select-Object -First 20
$inv.topCpu = @($top)
$top | ForEach-Object { Add-Linha ('{0,-32} {1,6}% de UM nucleo  {2,6} MB' -f $_.nome, $_.pctNucleo, $_.MB) }
$inv.totalProcessos = @(Get-Process).Count

# ---- Overlays / ruido conhecido
Add-Sec 'OVERLAYS / SOFTWARE CONHECIDO POR TER CUSTO'
$conhecidos = 'RTSS', 'RTSSHooksLoader64', 'EncoderServer', 'MSIAfterburner', 'Discord', 'Spotify', 'Steam', 'steamwebhelper', 'GalaxyClient', 'EpicGamesLauncher',
    'EpicWebHelper', 'Battle.net', 'OneDrive', 'GoogleDriveFS', 'chrome', 'msedge', 'firefox', 'WhatsApp.Root', 'Widgets', 'msedgewebview2', 'NVIDIA App', 'nvcontainer',
    'FvContainer', 'PresentMon_x64', 'obs64', 'Overwolf', 'Medal', 'iCUE', 'LGHUB', 'lghub_agent', 'RazerCentralService', 'Razer Synapse 3', 'ArmouryCrate.Service', 'GCC', 'MSI Center',
    'AnyDesk', 'TeamViewer', 'Tailscale', 'Adobe Desktop Service', 'AdobeUpdateService', 'AdobeIPCBroker', 'NZXT CAM', 'SignalRgb', 'OpenRGB', 'Lasso', 'ProcessLasso', 'HWiNFO64', 'LatencyMon', 'claude', 'codex', 'Code'
$vivos = Get-Process | Where-Object { $conhecidos -contains $_.ProcessName } | Group-Object ProcessName | ForEach-Object { '{0} x{1}' -f $_.Name, $_.Count }
$inv.conhecidosVivos = @($vivos); Add-Linha (($vivos) -join ' | ')
$hook = @(Get-Process | Where-Object { try { $_.Modules.ModuleName -contains 'RTSSHooks64.dll' } catch { $false } } | ForEach-Object { $_.ProcessName })
if ($hook.Count) { Add-Linha ('RTSSHooks64.dll carregada em: ' + ($hook -join ', ')) }

# ---- Estabilidade (30 dias)
Add-Sec 'ESTABILIDADE (30 dias)'
$ini = (Get-Date).AddDays(-30)
$e6008 = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'EventLog'; Id = 6008; StartTime = $ini })
$e1001 = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'; StartTime = $ini })
$e41 = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'; Id = 41; StartTime = $ini })
$whea = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WHEA-Logger'; StartTime = $ini })
$tpmErr = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-TPM-WMI'; Level = 2; StartTime = $ini })
$inv.estabilidade = [ordered]@{ e6008 = $e6008.Count; bugcheck1001 = $e1001.Count; kernelPower41 = $e41.Count; whea = $whea.Count; tpmErros = $tpmErr.Count }
$inv.estabilidade.GetEnumerator() | ForEach-Object { Add-Linha ('{0,-14} {1}' -f $_.Key, $_.Value) }
Add-Linha '6008 sem 1001 vizinho = freeze/desligamento sujo. PERGUNTE ao dono se foi ele (botao de power) ou queda de energia.'
$e6008 | Select-Object -First 10 | ForEach-Object { Add-Linha ('6008 logado ' + $_.TimeCreated.ToString('s') + '  ' + ($_.Message -split "`n")[0]) }
$e1001 | Select-Object -First 10 | ForEach-Object { Add-Linha ('1001 ' + $_.TimeCreated.ToString('s') + '  ' + ($_.Message -split "`n")[0]) }
$dumps = @(Get-ChildItem 'C:\Windows\Minidump' -ErrorAction SilentlyContinue)
Add-Linha ('minidumps: ' + $dumps.Count)

# ---- Saida
$inv | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $Saida 'inventario.json') -Encoding UTF8
Set-Content -Path (Join-Path $Saida 'inventario.txt') -Value $txt.ToString() -Encoding UTF8
Write-Host ('Inventario gravado em ' + $Saida)
Write-Host ('  inventario.txt  (leia este)  |  inventario.json  |  powercfg-processador.txt')
