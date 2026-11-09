# Catalogo de alavancas - tudo que foi tentado, por camada e fabricante

Legenda de status (sempre diga qual e ao propor):
- `CONFIRMADO-AQUI` medido na maquina de referencia (Ryzen 7 5700X, RTX 2060, B550M, DDR4, Win11 22631, Valorant) e adotado.
- `REFUTADO-AQUI` medido, piorou ou ganho zero. **Nao reofereca sem dado novo.**
- `NEUTRO-AQUI` medido, sem efeito demonstravel (custo zero pode ficar por higiene).
- `DECISAO-DONO` o dono decidiu; nao se reabre.
- `HIPOTESE` literatura/mecanismo geral, **nunca testado aqui**; trate como teste a montar.
- `[ESPECIFICO]` o resultado depende do hardware; em outro PC refaca o teste.

Para cada mudanca: **anote valor original -> aplique -> comando de desfazer -> A/B (2 corridas)**.
Mudancas de registro/servico/BIOS: registre no diario antes. BIOS: uma variavel por viagem.

---------------------------------------------------------------------------------------------
## 1. Display / scanout (camada mais barata: nao entra no frametime)

| alavanca | como | status |
|---|---|---|
| Escalonamento **na GPU**, nao no monitor | NVIDIA: Painel > "Ajustar tamanho e posicao da area de trabalho" > Executar dimensionamento em **GPU** e marcar **"Substituir o modo de dimensionamento definido por jogos e programas"**. AMD: Adrenalin > Display > GPU Scaling On + Scaling Mode (Full panel). Intel: Graphics Command Center > Display > Scaling | CONFIRMADO-AQUI (eliminou cintilacao) |
| Nunca escalar no monitor | Leia o **EDID** (registro `HKLM\SYSTEM\CurrentControlSet\Enum\DISPLAY\*\*\Device Parameters\EDID`): resolucoes nao nativas costumam existir so a taxa baixa (1280x1024 so a 75 Hz no LG UltraGear). Escala no monitor = cabo em modo/refresh baixo. Detector: proporcao do OSD do monitor em "Original" (tarja lateral = escala voltou ao monitor) | CONFIRMADO-AQUI |
| **Digital Vibrance / saturacao no painel por display** (saida de video, custo zero) em vez de filtro por quadro (Dynamic Vibrance, Freestyle, filtros do jogo) | NVIDIA: Ajustar configuracoes de cor > Vibrancia digital. AMD: Adrenalin > Display > Color > Saturation | CONFIRMADO-AQUI (60% e preferencia do dono; Dynamic Vibrance **REFUTADO**: custa GPU) |
| Tempo de resposta do monitor (overdrive) | OSD do monitor. "Mais rapido"/Extreme costuma ter overshoot (halo invertido em movimento). Teste: modo do meio, um DM, veredito do dono | HIPOTESE (julgavel) - proposto, sem veredito |
| Adaptive-Sync/G-Sync | com FPS muito acima da faixa do monitor nao agrega; seria segunda variavel | NEUTRO/DECISAO |
| Saida de cor | RGB, **8 bpc**, faixa **Completa**, 32 bits (evita dithering temporal e YCbCr) | HIPOTESE (pendente de teste) |
| Refresh | Usar o refresh nativo maximo no Windows e no jogo; confira `MaxRefreshRate` vs `PresentMon` (apresentacao a 179 em 179 Hz) | CONFIRMADO-AQUI |
| **Independent Flip** (PresentMode) em ~100% dos quadros, `MsFlipDelay` 0 | verifique no CSV; se o DWM compoe (Composed: Flip / Copy) ha latencia e custo. Fullscreen exclusivo/Flip direto | CONFIRMADO-AQUI (medido) |
| **MPO (Multiplane Overlay) desligado** | `HKLM\SOFTWARE\Microsoft\Windows\Dwm` DWORD `OverlayTestMode = 5`. Desfazer: apagar o valor. **Cuidado:** PresentMon + MPO off ja produziu tela preta no jogo -> medir so em partida descartavel | CONFIRMADO-AQUI (a mudanca que mais rendeu) [ESPECIFICO ao driver NVIDIA/Win11] |
| Filtros de nitidez/realce de borda (NVIDIA Image Sharpening, AMD RIS/CAS, Freestyle) | amplificam o artefato do esticamento; cintilam em movimento | REFUTADO-AQUI (preferencia: suavidade > nitidez parada) |
| Resolucao/aspecto/modo esticado/DPI/sens | preferencia pessoal | DECISAO-DONO: nao argumente |

---------------------------------------------------------------------------------------------
## 2. Driver de video

### 2a. NVIDIA
| alavanca | detalhe | status |
|---|---|---|
| Modo de gerenciamento de energia = "Preferir desempenho maximo" | por app ou global. GPU em P0 com 30% de carga ficando em 1365 MHz na 2060 e **normal**, nao defeito | CONFIRMADO-AQUI |
| Reflex (On, ou On+Boost) **no jogo** | Reflex nativo como limitador de FPS (nao usar limitador do driver ao mesmo tempo: dois limitadores brigam) | CONFIRMADO-AQUI |
| Limitador de FPS do driver (Max Frame Rate) junto com Reflex/jogo | evitar | REFUTADO por principio |
| Cap de FPS abaixo do que a CPU entrega (ex.: 240 vs 300) | derrubou o boost (GPU -202 MHz, CPU -170 MHz) | REFUTADO-AQUI |
| HAGS desligado | ganho zero e variancia 3-5x maior | REFUTADO-AQUI |
| Threaded Optimization | e controle de OpenGL; jogo DX11 nao usa | NEUTRO (nao vale) |
| Tamanho do cache de shader | **pela GUI global** (Gerenciar configuracoes 3D > Tamanho do cache de sombreador, 5-10 GB). **Nunca por perfil de app** via NVAPI: sobrepoe em silencio a escolha global. Em D3D11 so existe o cache do driver | NEUTRO-AQUI (uso real era 16 MB de 5 GB; hipotese de saturacao morreu 3 vezes) |
| Compilacao automatica de shaders (Beta) | e para DX12 e roda em ocioso: deixar desligada | NEUTRO |
| Perfil por script (NVAPI / Profile Inspector) | possivel, mas "aplicado" nao e "funcionando": confirme lendo de volta e medindo | ver armadilhas |
| Atualizar driver | zera cache de shader e reseta perfil/escala/vibrance; so com motivo; apos atualizar, ~dias de travoes isolados nao sao regressao | DECISAO: congelar versao |
| Resizable BAR | depende de BIOS + GPU; HIPOTESE para jogos CPU-bound: pouco | HIPOTESE |
| Sondar o "blob" do DisplayDatabase | hash de `nvlddmkm\State\DisplayDatabase` guarda escala+vibrance+faixa RGB; alterna sozinho entre estados validos; congele **com jogo fechado** e guarde o conjunto aceito | ver estado-ouro |

### 2b. AMD (Radeon)
Tudo `HIPOTESE` - nenhum testado aqui; monte A/B:
- **Anti-Lag / Anti-Lag+** (Anti-Lag+ ja causou banimento em alguns anti-cheats em 2023; use Anti-Lag classico ou Reflex-equivalente do jogo), **Radeon Chill OFF**, **Radeon Boost OFF**, **Enhanced Sync OFF** (adiciona latencia), **Image Sharpening OFF** (ver sec. 1), Texture Filtering Quality = Standard/Performance, Tessellation = Override/App, **Shader Cache = AMD Optimized/On**, **Frame Rate Target Control OFF** se o jogo ja limita, Surface Format Optimization On.
- Perfil de energia de GPU: "Default/Performance"; evite undervolt agressivo sem teste de estabilidade (artefatos).
- Atualizacao de driver Adrenalin: tambem recria cache; mesma regra de congelar versao.
- Overlays: Adrenalin Metrics Overlay e Radeon Software hotkeys injetam hook; desligue o que nao usa.

### 2c. Intel Arc / iGPU
`HIPOTESE`: Resizable BAR **obrigatoria** para Arc render bem; driver recente (DX11 melhorou muito); Intel Graphics Software > Performance tuning; iGPU compartilha banda de memoria -> memoria dual-channel e XMP importam muito mais.

---------------------------------------------------------------------------------------------
## 3. CPU e firmware (BIOS) - a unica via de acelerar a thread serial do jogo

A thread do jogo (GameThread Unreal etc.) e **serial**: encolher hitch/queda = **velocidade de um nucleo** (clock efetivo, latencia de memoria, menos disputa de cache L3). Mas lembre: o clock medio nao mudou hitch (ver 3.1).

### 3.1 Qualquer CPU / Windows
| alavanca | detalhe | status |
|---|---|---|
| Plano de energia: alto desempenho/ultimate; EPP do processador | `powercfg /setacvalueindex <GUID_do_plano> SUB_PROCESSOR PERFEPP 0` e `powercfg /setactive`; **aplicar em todos os planos** que algum software (ex.: Process Lasso) alterne. Desfazer: setar o valor original (era 10). Em CPU com `PERFAUTONOMOUS=1` o hardware decide o ramp pelo EPP | CONFIRMADO-AQUI: EPP 10 -> 0 = clock mediano no jogo +8% (4075 -> 4393 MHz), mesmos watts |
| `PROCTHROTTLEMIN` 100 / `LATENCYHINTPERF` alto / core parking off | em desktop sempre AC; confirme que planos diferem em algo alcancavel (comparar `powercfg /q` dos dois) | NEUTRO-AQUI (ja estava) |
| Efeito do **clock +8% nos hitches** | hitch de 13 ms vira ~12 ms e continua acima do limiar: **a contagem de hitches nao caiu**; clock mediano nos segundos COM hitch = SEM hitch (nao e throttle) | NEUTRO p/ contagem; ajuda a "queda sem pico" |
| Modo de Jogo do Windows | off desde antes do ouro; nao e diferenca | NEUTRO (vigiar) |
| Game Bar/DVR/captura | `GameDVR_Enabled=0`, `AppCaptureEnabled=0`, `UseNexusForGameBarEnabled=0` | CONFIRMADO-AQUI (higiene) |
| VBS / Integridade de memoria (HVCI) | desligar se ligado (custo CPU); conferir `Win32_DeviceGuard`; nesta maquina ja estava off e sem hypervisor | NEUTRO-AQUI (ja off); HIPOTESE em PCs com VBS ligado |
| Mitigacoes Spectre/Meltdown desligadas | CPU/quadro 3,28 -> 3,29 ms (zero em Zen 3, sem Meltdown/MDS). **Em Intel antigo (Skylake-Coffee Lake) o custo pode existir** - HIPOTESE para esses | REFUTADO-AQUI [ESPECIFICO] |
| Timer: fonte QPC | confirme 10 MHz = TSC (HPET forcado daria 14,318 MHz); `bcdedit /enum` para `useplatformclock`/`disabledynamictick` | NEUTRO-AQUI (ja certo) |
| `Win32PrioritySeparation` | 0x26 (quantum curto, boost de primeiro plano) ja estava | NEUTRO |
| Afinidade/prioridade do processo do jogo | anti-cheat (Vanguard) bloqueia: `ProcessorAffinity` lê 0x0 | REFUTADO-AQUI (bloqueado) [ESPECIFICO ao anti-cheat] |
| Process Lasso / ProcessGovernor | usado so para alternar plano de energia por jogo | NEUTRO |

### 3.2 AMD Ryzen (Zen 2/3/4/5) - BIOS (Gigabyte nomes; outras placas equivalem)
| alavanca | detalhe | status |
|---|---|---|
| **SMT Disabled** | `Tweaker > SMT Mode`. 8C/16T -> 8C/8T. Desfazer: Auto | CONFIRMADO-AQUI (dono: "TO MUITO SATISFEITO, NAO QUERO QUE REGRIDA"); hipotese: tamanho do pior pico cai ([ESPECIFICO]; em X3D/8 nucleos ou CPUs com poucos nucleos pode piorar; teste) |
| **Global C-state Control Disabled** | decisao dele apos testes; sem C-state profundo o nucleo nao paga latencia de acordar; protege contra freeze ocioso em Zen | DECISAO-DONO (nao reabrir). Medicao de 07/09: hitches 12,5 -> 7,4/min mas p99 piorou (uma corrida, com PBO junto) |
| `Power Supply Idle Control = Typical Current Idle` | remendo para freeze em idle Zen 2/3 | HIPOTESE de remendo (nao mais necessario com C-state off) |
| **PBO Enabled/Advanced** | nesta B550M **baixou o teto para 71,7 W** (de 77,8) e piorou; no modo Advanced PPT 90/TDC 70/EDC 100 idem, e lsass caiu com 0xc0000005 em PCPKsp.dll | REFUTADO-AQUI [ESPECIFICO a placa/AGESA]; retestar em outra placa so com limites verificados por foto e sensores |
| Teto PPT do 5700X (~76 W) chapado no jogo | `CPU_Watts` max cravado 77,8 W todo dia; Vcore cai 1,300 -> 1,281 V nessa faixa e o clock recua; tempo >= 74 W 5-18% | HIPOTESE forte (teste: so limite maior, sem override/CO) |
| Curve Optimizer (negativo), Boost Override | mais boost com menos tensao; nunca testado aqui; exige teste de estabilidade (OCCT/Cinebench loop/jogo longo) | HIPOTESE |
| **DOCP/XMP/EXPO** + tensao de DRAM | ver sec. 4 | |
| **FCLK 1:1** | FCLK = UCLK = MCLK (1700/1700/3400); medir latencia; dessincronizado = +10-20 ns. Conferir pelo HWiNFO | CONFIRMADO-AQUI (1:1 mantido) |
| CPPC / CPPC Preferred Cores | defaults da BIOS funcionam; boost 4641 MHz preservado | NEUTRO |
| Cool'n'Quiet | desligado junto com PBO/C-state no pacote de 07/09 (sem teste isolado) | sem veredito |
| Ryzen X3D (5800X3D/7800X3D/9800X3D) | `HIPOTESE`: instalar driver de chipset AMD (3D V-Cache optimizer) e manter Xbox Game Bar/`Game Mode` conforme exigido pelo driver de preferencia de nucleo; nao desligar SMT sem teste (X3D 8C: teste); nao use Curve Optimizer sem estabilidade; temperatura limita boost |
| Ryzen 7000/9000: EXPO, PBO com Curve Shaper, "Game Mode" BIOS | `HIPOTESE` | |
| Atualizar BIOS/AGESA | corrigiu centenas de erros de fTPM, mas **zerou** SMT/DOCP/C-state/Secure Boot em silencio | CONFIRMADO-AQUI (com roteiro pos-gravacao, sec. 10) |

### 3.3 Intel Core (12a/13a/14a/Core Ultra)
Tudo `HIPOTESE` (nenhum testado aqui). Monte os testes na ordem:
- **Microcodigo/BIOS**: 13a/14a gen (Raptor Lake) com degradacao de tensao (Vmin shift): instalar BIOS com microcodigo 0x12B+ e perfil "Intel Default Settings"/limites de fabrica **antes** de qualquer outra coisa; instabilidade em shader compilation/crash de jogos Unreal e sintoma classico.
- **Limites de energia PL1/PL2/Tau/ICCMAX**: placas desbloqueiam ("MCE") e sobem o consumo; compare "Intel Default" vs "Performance"; meça clock efetivo e temperatura.
- **Hyper-Threading Off** (equivalente ao SMT): testar; **E-cores**: desabilitar em BIOS (ou afinidade/Thread Director) para jogos que escalam mal; Win11 + Thread Director + "Alto desempenho" para P-core preferencial.
- **Ring/cache ratio** (Raptor Lake: ring 4,0-5,0 GHz) afeta latencia de L3 e jogo; **undervolt (Adaptive/AC-DC loadline)** reduz temperatura e melhora boost sustentado; exigir estabilidade.
- **Thermal Velocity Boost**, **Intel Turbo Boost Max 3.0**, **Intel APO** (Application Optimization, 14a gen/Core Ultra; so alguns jogos) - ligar e testar.
- **C-states** (C1E, C6/C7, Package C): desligar reduz latencia de wake e, em desktops, nao custa muito em ocioso. Medir consumo ocioso (W) e hitch.
- **Resizable BAR / Above 4G decoding**.
- **Memoria**: XMP e Gear 1 vs Gear 2 (DDR5: Gear 2 padrao; DDR4 Gear 1 ate ~3600-3800); Intel MLC para latencia.
- **AVX offset**, **Speed Shift (EPP via HWP)**: EPP 0 no plano de energia tambem se aplica.
- **Windows 11 24H2**: o escalonamento de threads em hibrido mudou; compare 23H2 vs 24H2 se houver regressao.

### 3.4 CPU em notebook
`HIPOTESE`: limites PL1/PL2 do fabricante, modo "Turbo/Performance" do OEM, aplicativo de ventoinha, dGPU em modo "Discrete only"/MUX, undervolt bloqueado em muitas geracoes; bateria desligada (AC).

---------------------------------------------------------------------------------------------
## 4. Memoria (latencia e estabilidade)

| alavanca | detalhe | status |
|---|---|---|
| Latencia medida (pointer-chase) | referencia aqui: 72 ns @3400 CL22 (F5), 73 ns @3200, 81 ns @3400 com timings AUTO da F8c (tRFC 596!), 75 ns @3200/1,35 V. **Jogo fechado**, L3 estavel (12 ns) indica maquina quieta | CONFIRMADO-AQUI (instrumento) |
| **DRAM Voltage manual 1,35 V** em modulo que o SPD nao traz XMP/rodava 1,35-1,36 V meses | depois de gravar BIOS, a placa pode cair em **1,20 V**; verifique pela mediana da caixa-preta (V7_DRAM), nunca SMBIOS | CONFIRMADO-AQUI (era a unica anomalia objetiva; 0 BSOD/WHEA desde) [ESPECIFICO ao modulo] |
| **DOCP/XMP/EXPO ligado** | a 3400 em BIOS nova com **tensao automatica errada** deu `0x1A`; com 1,35 V manual voltou a ser candidato, mas a F8c em Auto escolheu timings frouxos (24-24-24-55, tRFC 596) -> 81 ns | REFUTADO-AQUI para auto; HIPOTESE para manual com timings conhecidos |
| Timings da foto da BIOS antiga (22-22-22-52, tRC 74, tRFC 312, tFAW 34...) | rodaram meses estaveis e davam 72 ns; ter **fotos da BIOS** de um estado bom e um ativo | candidato a teste futuro (DECISAO-DONO) |
| Timings secundarios apertados a mao | duas telas azuis em 4 min (0xA, 0x3B) junto com outras mudancas | REFUTADO-AQUI sem plano de estabilidade de horas |
| Dual channel/ranks | verifique 2 modulos nos slots corretos (A2/B2); 2x8 GB dual-rank vs single-rank | HIPOTESE |
| Pressao de RAM | 7,1 GB livres na mediana: a teoria de "stutter = falta de RAM" morre; so veja se livre < 1-2 GB | REFUTADO-AQUI |
| Pagefile/Standby list | deixar gerenciado; "limpadores de RAM" nao ajudam | NEUTRO |
| Teste de estabilidade | MemTest86 de boot (completo); `testar-memoria` em user-space so pega defeito grosseiro | ver diagnostico D |

---------------------------------------------------------------------------------------------
## 5. Armazenamento
- Jogo em NVMe, nao HDD; SSD com >15% livre. Disco foi **descartado** como causa de hitch (55 de 55 hitches sem I/O no mesmo instante, pre-patch; remeça apos patch grande se suspeitar: assets de mapa).
- DRAM-less NVMe (ex.: SN350) funciona; o que zera no reboot e so o cache de arquivos do Windows.
- Nao apague `C:\Windows\Installer` (quebra todo MSI). Nao apague `SoftwareDistribution\Download` com download em andamento.
- Armazenamento: Sensor de Armazenamento limpando `D3D Shader Cache` foi checado e nao era o caso.

---------------------------------------------------------------------------------------------
## 6. Rede
- Medido: 8 ms, jitter 0, 0% perda; rede **descartada** como causa de hitch de frametime. Mas nunca foi medida durante a partida pelo proprio jogo: ligar o overlay de Latencia/Perda (so texto, custo zero).
- **REFUTADO-AQUI (pioraram 5x: 6,6 -> 35,7 hitches/min):** `TcpAckFrequency`, `TCPNoDelay`, `*InterruptModeration=0`. O guardiao os remove de proposito. Nao reofereca "tweaks de latencia de rede" classicos.
- Link a 100 Mbps com 0 erros: nao explicou diferenca; checar cabo/porta/autonegociacao.
- Politicas de interrupcao (MSI, DevicePolicy, afinidade de IRQ): lidas, **nao** mexidas; tweak dessa familia e o que mais deu arrependimento.
- Nucleo 0 concentra o DPC (3344/s, 4,3%) - custo de fundo constante (mouse 1000 Hz + timer), nao gatilho (0,15 desvio entre segundos com/sem hitch).

---------------------------------------------------------------------------------------------
## 7. Audio
- Fone sem fio com dongle 2,4 GHz duplex: **push-to-talk** em jogo e Discord. Mic aberto disputa o radio com a saida -> corte de ms (CONFIRMADO-AQUI, 18/09). Config de voz e da **conta** do jogo: trocar de conta reabre o mic sem avisar.
- Dongle USB composto expõe Game (saida) e Chat (mic); selective suspend de USB desligado.
- Re-enumeracao do dongle ("2-" -> "3-") recria endpoint de saida; desabilite endpoint extra por nome (`Disable-PnpDevice`), uma linha elevada. Vigie com sonda `audio/endpoints-ligados`.
- APO/SpatialAPO do headset: medido 1,95% vs 2,03% de um nucleo -> inocente. QuantumService (JBL) e quem mantém o efeito de EQ; nao remova.
- Nao desligue processamento/canais para economizar CPU sem provar que nao perde informacao (passo = informacao).
- Corte de audio de ms e problema de **performance/radio**, nao estetico.

---------------------------------------------------------------------------------------------
## 8. Software de fundo e higiene do Windows
| item | acao | status |
|---|---|---|
| Fechar na abertura/durante o jogo: navegador, launchers de outras lojas, OneDrive/cloud sync, Adobe, Wondershare, WhatsApp Desktop, widgets, RGB, capturadores, o proprio agente | vigia a cada 3 min com **a mesma lista** do modo-jogo (nunca copia) | CONFIRMADO-AQUI (efeito isolado nao demonstrado; ambiente limpo e pre-requisito de A/B) |
| Manter abertos (decisao do dono): comunicacao por voz (Discord), musica, sync de nuvem | nao reabrir | DECISAO-DONO |
| Impedir de nascer > matar | `StartupApproved\Run` byte 3 = desabilitado (a presenca no Run NAO decide); app da Store: `HKCU\...\BackgroundAccessApplications\<pacote>` `Disabled=1`,`DisabledByUser=1`; Edge/Chrome: politicas `BackgroundModeEnabled=0`, `StartupBoostEnabled=0` | CONFIRMADO-AQUI |
| Widgets desligados por politica | `HKLM\SOFTWARE\Policies\Microsoft\Dsh` `AllowNewsAndInterests=0` | CONFIRMADO-AQUI (WebView2 nao correlacionou com hitch; custo CPU de fundo removido) |
| **Windows Update contido** | `wuauserv`,`UsoSvc`,`DoSvc`,`WaaSMedicSvc` `Start=4` **no registro** (Set-Service da "Acesso negado" nesses mesmo elevado); BITS em Manual (deliberado: Riot Client usa); tarefas do Orchestrator sao do TrustedInstaller (nao tomar posse). `wuauserv` **religa sozinho** a cada ~65 min -> **vigia a cada 3 min cura sempre**, com jogo aberto ou fechado | CONFIRMADO-AQUI (suspeito n.1 de cauda; correlacao exata do religamento com partidas ruins) |
| Atualizar app da Store com update contido | roteiro `store-janela.ps1`: pausar tarefas, `Start=3`, **reiniciar**, atualizar, restaurar, reiniciar; `DoSvc` sem ele = 0x80004002 | CONFIRMADO-AQUI |
| Boot enxuto | desabilitar Run/tarefas/servicos de updaters; lista `$PROTEGIDO` recusa tocar em anti-cheat, launcher do jogo, audio, driver NVIDIA, periferico, ativacao. **Instalador recria tarefa/servico**: reaplicar via guardiao a cada 30 min | CONFIRMADO-AQUI |
| ClickToRunSvc (Office) | desabilitar quebra o Office (0x426-0x0); matar o despertar de update por politica `officeupdate EnableAutomaticUpdates=0` | REFUTADO-AQUI (como servico); politica OK |
| Defender | pode estar off por politica; sem AV em tempo real e risco que o dono deve saber, nao e assunto de performance | DECISAO-DONO |
| Overlays injetando no Present: RTSS/Afterburner OSD, Discord overlay, Steam, Overwolf, Medal, GeForce Experience/NVIDIA App/FrameView | listar, desligar os que nao usa. RTSS: `EnableHooking=0`; Afterburner relanca o RTSS por **`ShowInOSD=1`** e por fontes de FPS na linha `Sources=` (`+Framerate`...) -> trocar para `-`; e **a tarefa `RTSS` e recriada** pelo proprio RTSS ("Iniciar com o Windows"): apagar com `schtasks /delete /tn RTSS /f`. Gancho ja injetado so sai no proximo boot | NEUTRO-AQUI (tirar o RTSS nao moveu o numero de forma demonstravel); mas elimina variavel |
| NVIDIA App/FvContainer/PresentMon do FrameView abertos durante captura | ~3% de um nucleo; variavel da captura | fechar antes de medir |
| Codex/Claude/terminal/powershell do agente | ~1-6% de um nucleo; **o agente nao usa a maquina enquanto o dono joga** | disciplina |
| Antivirus de terceiros, anti-cheat de terceiros, RGB suite, Armoury Crate, Corsair iCUE, Razer Synapse, Logitech G Hub, Gigabyte Control Center/Update, MSI Center | HIPOTESE: fontes comuns de poll/servico; meça snapshot FIM-INICIO e decida | HIPOTESE |
| Tarefas agendadas interativas | nascer com console tira o jogo do foco (11,7 s medidos). Troque `powershell -WindowStyle Hidden` por `wscript.exe x.vbs` com `Run(cmd,0,True)` (4o arg True mantem ExecutionTimeLimit e IgnoreNew) | CONFIRMADO-AQUI |
| Foco fugindo do jogo no menu | fullscreen exclusivo + qualquer janela que roube foreground minimiza o jogo. Monitor de `GetForegroundWindow` a **50 ms** (200 ms perde flash de console) e fotografar processos nascidos nos ultimos 15 s | CONFIRMADO-AQUI |
| Modo de tela | exclusivo (pior para alt-tab) vs sem bordas: preferencia/medicao do dono | DECISAO-DONO |

---------------------------------------------------------------------------------------------
## 9. Configuracao do jogo (so o que reduz CPU por personagem) - exemplos do Valorant; para outro jogo ver `jogos.md`
- **Sombras OFF** e a unica opcao do Valorant que custa CPU por personagem. Dono decidiu desligar sempre ciente de perder sombra de inimigo como informacao. Mecanica: a chave so existe no `RiotUserSettings.ini` depois de mexer uma vez no menu; **nunca invente nome de chave** (corrompe o config em silencio); trave qualquer chave que case `Shadow`.
- **Corpos (`ShowCorpses=False`)**: o ganho nunca foi medido (confundido com patch/conta); corpo no chao e informacao. DECISAO-DONO.
- **MSAA**: nao desligue (dos 44 quadros ruins medidos, 0 eram de GPU; MSAA 4x ajuda a ver inimigo distante).
- Tudo no minimo (qualidade de textura/detalhe/efeitos), AF 16x, contadores de overlay desnecessarios off. Overlay nativo de FPS/Rede/Perda (custo zero).
- Multithreaded rendering ligado (padrao em Valorant).
- **Config e da CONTA** (nuvem/roaming), nao da maquina: editar o ini com o jogo fechado e apagado no proximo login. Mude pelo menu, na conta em que ele joga. Trocar de conta traz outra config.
- Outros jogos (`HIPOTESE`): CS2 (`-novid -high`? nao necessario; `fps_max` + Reflex; Nvidia/AMD Anti-Lag; autoexec `cl_` valores sao preferencia), Apex/Fortnite (D3D11 vs DX12 em Fortnite; modo Desempenho/Meshes), Overwatch 2, etc.: o metodo e o mesmo - **meca no cenario de reclamacao, o catalogo de config e secundario**.

---------------------------------------------------------------------------------------------
## 10. BIOS: gravar, o que quebra, e o roteiro de volta
- **Q-Flash (Gigabyte) sem pendrive**: le FAT32 interno so da **primeira particao** do disco (a ESP de 100 MB funcionou; uma particao no fim do GPT nao). Monte a ESP, copie o arquivo, confira espaco >= 25 MB, grave e **apague depois** (encher a ESP quebra o Windows Update). Nunca use @BIOS dentro do Windows em maquina que trava.
- Depois de gravar: Secure Boot cai (**chaves de plataforma apagadas, Setup Mode**): `Secure Boot Mode -> Custom` > `Key Management -> Restore Factory Keys -> Yes` > `Standard` > `Secure Boot Enable -> Enabled` > F10. Confirme `reg query HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot\State /v UEFISecureBootEnabled` = `0x1`. Sem isso, Vanguard `VAN9003`.
- DOCP cai (memoria volta ao SPD), `Power Supply Idle Control` volta a Auto, SMT/C-state/PBO/DRAM voltage voltam ao padrao, **fTPM e limpo** (BitLocker pediria chave: confirme antes).
- Tire **fotos de todas as abas Tweaker/Advanced** antes de gravar (foram a unica fonte dos timings que rodaram 3400/72 ns).
- Sobrevivem ao reset: boost, 8C/16T, MPO, perfil NVIDIA, tarefas.
- Nao dimensione `Resize-Partition` pelo espaco livre; leia `Get-PartitionSupportedSize`.
- Uma variavel por viagem a BIOS; BIOS e decisao do dono (irreversivel/arriscada).

---------------------------------------------------------------------------------------------
## 11. Anti-cheat: o que ele impede (impacta toda alavanca)
- **Vanguard (Valorant)**: carrega sempre (driver de kernel): bloqueia `Stop-Process` no jogo, afinidade/prioridade, escrita HID por software de periferico, `Win32_ProcessStopTrace` nunca dispara para o jogo (Start funciona). Roda em fatias <= 2,5 ms nas threads do jogo (inocentado como mecanismo de hitch). Exige Secure Boot + TPM 2.0 (Win11).
- Outros (EAC, BattlEye, FACEIT, Ricochet): `HIPOTESE` - pesquise o que cada um bloqueia (injecao de overlay, drivers de baixo nivel, ferramentas ETW). Nao use cheat-engine-like/driver de terceiro nao assinado; ferramentas de tuning que carregam driver (alguns monitores de HW) podem ser bloqueadas.
- Se "algo nao funciona so com o jogo aberto", suspeite do anti-cheat primeiro.

---------------------------------------------------------------------------------------------
## 12. Hardware fisico
- Fonte: 12 V em carga estavel (11,7-11,9, desvio 0,04) descarta fonte; teste sob carga se freeze.
- Temperatura: CPU 55-60 C, GPU 44 C, VRM 73-86 C. VRM acima de ~95-100 C -> cuidado ao subir limites de energia.
- Cooler/pasta/fluxo de ar; ventoinha do gabinete; poeira.
- Monitor com refresh nativo > FPS alvo ajuda a latencia; cabo DP certificado; porta correta (iGPU vs dGPU!).
- Mouse: 1000 Hz (mais DPC, mas nao mexa: DECISAO-DONO); 8000 Hz exige nucleo dedicado e mais DPC (`HIPOTESE`).

---------------------------------------------------------------------------------------------
## 13. O que ainda NAO foi testado aqui (fila de hipoteses para PCs novos)
Curve Optimizer/undervolt; PPT maior sem PBO override; 3400 manual com os timings da foto; Resizable BAR on/off; "Rapido" vs "Mais rapido" no monitor; `ShowCorpses` isolado; saida RGB 8 bpc/faixa completa; Intel HT/E-core off, ring, APO, Gear 1; AMD GPU Anti-Lag/Chill; troca de modo de tela; ultimate performance power plan; HVCI on vs off em PC onde esta ligado; kernel trace numa partida ruim com muitos hitches (confirmar com forca estatistica).
