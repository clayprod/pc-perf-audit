# Metodo de medicao

## Ferramentas
- **PresentMon** (Intel, open source; 1.x ou 2.x). Mede quando cada quadro e *apresentado*.
  Precisa de ETW: admin ou grupo "Performance Log Users". **So enxerga quem apresenta** -
  quem consome CPU sem desenhar (Spotify, audiodg, o agente) e invisivel: grave um snapshot
  de processos no inicio e no fim de cada captura (o `capturar.ps1` faz).
- **Caixa-preta de sensores**: HWiNFO (log CSV) ou LibreHardwareMonitor gravando clock, watts,
  temperatura, tensoes (Vcore, VSoC, DRAM, 12 V), RAM livre, MB do processo do jogo, a cada 1 s.
  Sobrevive a freeze (a ultima linha e o instante real da queda; o evento 6008 mente na hora).
- **Log do proprio jogo**: marca round, dano, abate, fim de partida, troca de mapa, com hora
  exata (UTC no Unreal). Melhor que inferir fim de partida por degrau de watts.
- **ETW de kernel** (`logman` com `process,thread,img,profile`, sem pilha = ~24 MB/60 s;
  com pilha dava 1,9 GB) para ver *quem* roda na thread do jogo; ISR/DPC por contador.
- **Latencia de memoria**: pointer-chase em varios tamanhos (64 KB..256 MB) com L1/L2/L3 de
  controle; jogo fechado. L3 estavel e o denunciante de carga concorrente.

## Protocolo de captura
1. Uma variavel por vez. Estado da maquina anotado (inventario + snapshot de processos).
2. Captura de **420 s** em partida real do cenario-alvo. **Descartar o primeiro minuto**
   (carregamento concentra hitches) - 60 s, nao 30.
3. **Nao analisar durante a partida.** A analise em PowerShell de 100 mil quadros custou
   23,7 s de CPU e 745 MB com o jogo aberto. Analise offline, jogo fechado.
4. **Duas corridas no minimo**; primeira apos boot/patch/driver e fria e nao e comparavel.
5. Olhe **desvio por minuto**, nao so a media; variancia e o que o usuario sente.
6. Compare **no mesmo mapa/modo**. Mapa explicou grande parte da variacao (6 -> 34
   hitches/min entre mapas, mesma maquina). DM e 5v5 tem linhas de base diferentes.
7. Quem dispara a captura nao pode roubar foco: tarefa agendada "interativa" que nasce
   com console tira o jogo de fullscreen exclusivo. Use `wscript.exe` + `.vbs`
   (`Run(cmd, 0, True)`) ou `-NoNewWindow` herdando o console ja existente.
8. Espere o **processo do PresentMon sair** antes de abrir o CSV (ele fica ~30 s sem flush).

## Metricas (e o que cada uma vale)
| metrica | uso |
|---|---|
| **hitches por minuto** (> mediana + 8 ms; ~11 ms a 300 FPS) | metrica principal; correlacionou rho -0,94 com os vereditos do dono apos consertar o medidor |
| **pior quadro** e **graves > 20 ms** | pode ser o que o dono sente quando a contagem esta baixa (hipotese n=3: com SMT off, o tamanho do pior pico importava mais que a contagem) |
| 1% / 0,1% low **por percentil** (p99 / p99,9 do frametime) | nao confundir com "media do pior 1%" - sao numeros diferentes |
| desvio dos hitches/min minuto a minuto | variancia percebida |
| seg/min abaixo de X FPS (janela 0,5 s) | captura "queda sem pico" (CPU 3,3 -> 3,6 ms estoura orcamento sem hitch) |
| FPS medio, p50, CPU/quadro | so para pegar regressao grosseira; foram iguais no melhor e no pior dia |
| latencia input->foton (PresentMon 2.x) | pior caso util; nao separou vereditos sozinha |
| MsAnimationError, "atualizacao perdida" (> 1 refresh) | testadas e **nao** separaram vereditos |

**Antes de adotar qualquer metrica nova, valide contra TODOS os vereditos guardados**
(correlacao de posto, Spearman). Escolher 4 capturas que confirmam a tese e quase
levar isso ao usuario ja aconteceu.

## Recortes e filtros (cada um ja apagou o evento que se queria medir)
- **Recorte de ponta por mediana do frametime por balde de 10 s**, nunca por contagem de
  quadros (um travao de 1,5 s derruba a contagem do balde e o apaga). Corta so as bordas.
- **Teto de sanidade de 60 s**, nao 1 s: um quadro de 1 s e justamente o travao alvo.
- Todo filtro que descarta dado **diz quantos descartou** no resumo.
- Filtre **todos** os arrays paralelos pelos mesmos indices (tempo, cpu, gpu, latencia).
- `MsCPUBusy` alto **nao prova execucao**: o intervalo inclui espera e preempcao fora do
  `Present`. Para provar que a thread executa, use ETW de kernel (cswitch/profile).
- Contagem de quadros por minuto de um *trecho de menu* contamina: para saber se um trecho e
  partida ou menu use `MB do processo`/watts/log do jogo, **nunca** PresentMode, FPS ou
  contagem de processos apresentando (iguais nos dois estados).

## Veredito
`ADOTAR` se bate (ou empata) a linha de base **e** o dono aprova no julgavel.
`REVERTER` se piora cauda, variancia ou estabilidade, mesmo que a media suba.
`SEM VEREDITO` se a dispersao entre corridas do *mesmo* estado e maior que a diferenca
entre estados (ex.: 16,8 -> 10,2 -> 6,3 hitches/min no mesmo estado limpo).
Ao falar de "cache frio / aquecimento / primeira partida pos-boot", so use como explicacao
se a captura mostrar hitches concentrados no comeco; caso contrario e desculpa.

## Aquecimento e patch
- Depois de patch do jogo ou driver de video, shaders recompilam por exposicao. Aparece
  como **eventos isolados e catastroficos (~1 s) no meio da partida**, nao como hitches no
  minuto 0. Conte ~3 partidas antes de comparar com a linha de base. Em D3D11 o cache e
  so o do driver; em D3D12/Vulkan o jogo tambem tem cache de PSO.
- Atualizar driver NVIDIA zera o cache de shader e reseta o perfil por app: nao atualize sem motivo.
