# Arvore de diagnostico: sintoma -> instrumento -> causa provavel

## A. "FPS baixo / abaixo do cap"
1. Capture. Compare mediana de `MsCPUBusy` e `MsGPUBusy` e o `GPU_Load` da caixa-preta.
   - GPU busy ~ frametime e GPU load > 95% -> **GPU-bound**: resolucao/qualidade, upscaling,
     driver, clock da GPU. (Em jogo competitivo no minimo isso quase nunca e o caso.)
   - CPU busy ~ frametime e GPU ociosa -> **CPU-bound**: va para B/C.
2. Cap de FPS: o cap perto do que a CPU entrega (ex.: 300 com CPU em 3,28 ms = 3,33 ms de
   orcamento) deixa folga de ~1,5% - **mas folga baixa NAO explicou os drops** (49% dos quadros
   acima do orcamento na melhor partida). Nao use "estourou o orcamento" como causa.
3. Baixar o cap pode derrubar o boost (cap 240 pior que 300 nesta maquina): medir, nao supor.

## B. "Microstutter / hitches" (o caso central)
Capture e olhe a **natureza** dos quadros ruins:
- `MsCPUBusy` ~ quadro inteiro e `MsGPUBusy` baixa (GPU esperando) -> **thread de CPU do jogo
  fazendo 4-5x o trabalho** (codigo do jogo, shader/asset novo, troca de round, spawn).
  Em 3 estudos, 100% dos hitches eram CPU; GPU p99,9 de ~1,8 ms.
- Cruze com o **log do jogo** (UTC) por segundo, com controle de deslocamento circular
  aleatorio (1000 sorteios) para evitar acaso. Gatilhos achados: troca de round/fase de compra
  (fora de combate, quadros de 140-190 ms), renascimento em DM, carregamento, fim de partida
  (tela de resultado + vitrine de skin com decodificacao de video). Dano em si **nao**
  correlacionou com hitch, mas correlacionou com *queda sem pico* (ver C).
- Distribuicao no tempo: concentrada nos 60 s iniciais -> cache frio/carregamento;
  plana -> codigo do jogo/mapa; eventos isolados de ~1 s no meio apos patch/driver -> shader.
- Hitches chegam **em rajada** (CV dos intervalos 1,1-2,6): 2-3 colados viram um engasgo.
- Excluir contenda externa **com o instrumento certo**:
  - ETW de kernel durante partida (profile+cswitch): a thread de render espera a GameThread;
    "pronta sem nucleo" ~0,02 ms => ninguem disputa o nucleo. Anti-cheat de kernel: fatias <= 2,5 ms.
  - DPC/ISR: LatencyMon mede latencia **maxima** de um DPC; o que importa e o **tempo total**
    (contadores por nucleo; a mediana por nucleo e inutil por quantizacao de 1,56%).
  - Disco: hitches sem I/O no mesmo instante.
  - Memoria livre, temperatura, clock nos segundos de hitch vs sem hitch (clock igual => nao e throttle).
  - Processos de fundo: FIM-INICIO da CPU acumulada por processo na captura (snapshot).
- Se nada externo: o hitch e **codigo do jogo**. Mas isso NAO encerra: a thread e serial e
  encolhe com **velocidade de um nucleo** - va para o catalogo secoes 3-5.

## C. "Cai o FPS na troca de tiro / muitos personagens" sem hitch grande
Metrica: segundos/min abaixo de X FPS (janela deslizante 0,5 s) e quantos sem quadro > limiar.
Anatomia achada: CPU/quadro 3,26 -> 3,5-3,9 ms (estoura o orcamento a 300 FPS), GPU quase
parada, clock **sobe** (mais trabalho, nao throttle), associado a eventos de habilidade/debuff.
Alavancas: clock efetivo (teto de energia/PPT chapado em ~77 W), latencia de memoria,
trabalho por personagem (sombra, corpos, cenas). **Teto de energia chapado** e checavel na
caixa-preta (`CPU_Watts` maximo identico todo dia).

## D. Freeze total (reinicio manual) / BSOD
- Evento **6008 (provedor `EventLog`) sem BugCheck 1001 vizinho** = freeze; com 1001 = BSOD.
  **Pergunte ao dono se foi ele** (botao de power gera 6008 identico). A hora real e o
  ultimo batimento da caixa-preta, nao a do 6008. Queda de energia tambem gera 6008.
- Filtrar WHEA por `ProviderName='Microsoft-Windows-WHEA-Logger'`, nunca so por Id.
- BSOD `0x1A MEMORY_MANAGEMENT`, `0x13A`, `0x3B/0xC0000005`, `0xA`: suspeite de **RAM** -
  tensao baixa, XMP/DOCP, timings, FCLK/IMC. Cheque a tensao pela *mediana da caixa-preta*
  (SMBIOS "ConfiguredVoltage" mente). Gravar BIOS pode deixar DRAM em 1,20 V no modulo de 1,35 V.
- Freeze **ocioso e frio** com tensoes planas, sem bugcheck: assinatura de C-state profundo
  instavel em Zen 2/3 (remendos: `Power Supply Idle Control = Typical Current Idle`,
  Global C-state Disabled). Fonte sob carga e temperatura ficam descartadas por sensores.
- `testar-memoria` em user-space (padroes, 0 erros) **nao absolve**; so achar erro e conclusivo.
  MemTest86 de boot e o teste completo.
- lsass/PCPKsp.dll/fTPM: TPM firmware com BIOS antiga gera centenas de erros; atualizar BIOS.

## E. Corte de audio de milissegundos
Ordem de suspeita medida: (1) **microfone aberto (sem push-to-talk) num headset sem fio
2,4 GHz duplex** disputando o radio do dongle com a saida; (2) USB selective suspend /
energia do dongle; (3) endpoints duplicados que reaparecem quando o dongle re-enumera;
(4) DPC alto; (5) APO/efeitos (medido: DSP do headset custou ~2% de um nucleo, inocente);
(6) Discord `audioSubsystem` experimental. Audio de passo e informacao competitiva:
**nao** desligue processamento/canais para economizar CPU sem medir que ele nao perde nada.

## F. Input lag / "feel"
Reflex nativo do jogo + cap pelo jogo (nao dois limitadores); fluxo Independent Flip ao
100% (`PresentMode`), `MsFlipDelay` 0, zero quadros sem troca de tela; MPO off pode ser a
maior mudanca (mas PresentMon + MPO off ja deu tela preta - medir em partida descartavel);
tearing/sync desligado e preferencia; tempo de resposta do monitor (modo overshoot).
Cadeia de mouse/teclado/monitor: se o dono ja mediu, **nao remeça** (decisao dele).

## G. Cintilacao / serrilhado em movimento
Hipoteses em ordem de custo zero: escalonamento no monitor em vez de na GPU (verifique no
EDID se a resolucao nao nativa so existe em taxa baixa); "substituir modo de escala do jogo"
no painel do driver; dithering temporal (saida 10 bpc em painel 8 bit / YCbCr -> RGB, 8 bpc,
faixa completa); overshoot do tempo de resposta do monitor; **nitidez/realce de borda amplifica
o artefato do esticamento** (refutado como prejudicial a suavidade). E a cintilacao pode ser
o hitch visto na tela (tearing + ritmo irregular).

## H. Rede
Latencia/jitter/perda do **overlay do proprio jogo** (custo zero) quando engasgar. Servidor
bloqueia ICMP. Em jogos com replay, o arquivo traz ping e tempo de frame do servidor por
jogador. Link negociando 100 Mbps em vez de 1 Gbps: checar cabo/porta, mas medir se importa.
**Nao aplique tweaks de TCP/Nagle/moderacao de interrupcao** (refutados, 5x pior).

## I. "O numero esta igual ao ouro e eu senti ruim"
Suspeite do instrumento: janela do contador de FPS do jogo, recorte que apaga o trecho,
analise rodando durante a partida, overlay/vigia, conta/config diferente (config e da
**conta**, com roaming), patch, mapa, adversarios, rede. Peca **o minuto** em que ocorreu e
olhe aquele segundo. Capture sempre com a vigia ligada (ela morre a cada reboot).
