# Aplicando o metodo a QUALQUER jogo

O metodo (PresentMon + hitches/min + A/B + estado congelado) nao depende do jogo. O que muda
por jogo e: **nome do exe, onde ficam config e log, quais eventos do log marcam round/fim de
partida, qual o anti-cheat, qual API grafica e qual o cenario de reclamacao.** Preencha esta
ficha na Etapa 0/1 para cada jogo.

## Ficha do jogo (preencher)
| campo | como descobrir |
|---|---|
| exe do processo | `Get-Process` com o jogo aberto; PresentMon sem filtro e olhar `Application` |
| API grafica | coluna `PresentRuntime`/`Runtime` do CSV (D3D11/D3D12/Vulkan); D3D11 = so cache do driver; D3D12/Vulkan = o jogo tem cache de PSO e tela "compilando shaders" |
| engine | pasta do jogo: `Engine\` + `.pak/.ucas` = Unreal; `UnityPlayer.dll` = Unity; `Source`/`bin\*.dll` = Source; `.rpf`/`.bundle` etc. |
| config do usuario | `%LOCALAPPDATA%`, `Documents\<jogo>`, `%APPDATA%`, pasta do Steam `userdata\<id>\<appid>\local\cfg`; **verifique se e por conta (nuvem) ou por maquina** |
| log do jogo | `Saved\Logs`, `output_log.txt`, `Player.log`, `console.log`, `%LOCALAPPDATA%\<jogo>\*.log`; veja se tem hora com ms e fuso (UTC?) |
| marcadores de evento | abra um log de uma partida e procure linhas que se repitam em: inicio/fim de round, abate/morte, respawn, carregamento de mapa, fim de partida, troca de mapa. Estes viram a "linha do tempo" cruzada com os hitches |
| anti-cheat | pasta do jogo/servicos: Vanguard, EasyAntiCheat, BattlEye, FACEIT, Ricochet, VAC, Javelin, Denuvo AC... Veja secao 11 do catalogo e **leia os termos do jogo antes de rodar qualquer ferramenta de kernel/ETW/overlay** |
| cap/Reflex/limitador | menu do jogo (Reflex, Anti-Lag, "Max FPS"); `autoexec`/ini |
| modos para medir | modo descartavel reproduzivel (treino, DM, bots, replay, benchmark integrado, custom game) e o modo real de reclamacao (ranqueada, battle royale, raide) |
| tela | fullscreen exclusivo, borderless, "fullscreen otimizado" do Windows (sem Independent Flip real?) |

## Descobrindo marcadores de evento em log desconhecido (receita)
1. Jogue 2 minutos fazendo uma acao conhecida (abater, morrer, abrir mapa) e anote a hora.
2. `Select-String` no log pela janela de +-2 s; nomes que se repetem a cada ocorrencia viram marcador.
3. Valide: a contagem do marcador bate com o que voce fez? Marcador que so grava *algumas* mortes
   e **incompleto** (ja aconteceu); nao conclua "morte nao correlaciona" com ele.
4. Alinhe os relogios: log em UTC vs captura em hora local; refine pelo carregamento do menu apos o fim.
5. Controle por **deslocamento circular aleatorio** (1000 sorteios) antes de dizer que evento X causa hitch.

## Perfis por genero / engine (hipoteses para o primeiro teste, nao conclusoes)
| tipo | o que costuma limitar | onde olhar primeiro |
|---|---|---|
| FPS tatico competitivo (Valorant, CS2, R6, Apex em baixa) | 1 thread de CPU (GameThread/main thread) + latencia de memoria; GPU ociosa | clock efetivo da thread, SMT/HT, E-cores, latencia de RAM, teto de energia, hitches de troca de round/spawn |
| Battle royale / mundo aberto (Fortnite, Warzone, PUBG) | CPU + streaming de assets + shaders (DX12) + VRAM | compilacao de shaders (apos patch/driver), disco/NVMe, VRAM, DX11 vs DX12, memoria dual channel |
| Unreal Engine (qualquer) | GameThread serial; PSO/shader stutter em DX12; `Saved\Logs` util | log do UE, `r.` cvars so se o jogo permitir (muitos bloqueiam), cache de shader |
| Unity | main thread + GC (picos periodicos de coleta de lixo) | picos regulares (FFT/periodo), `Player.log` |
| Source/Source 2 (CS2) | main thread, cap de FPS, `fps_max`, latencia de rede (tickrate) | Reflex/Anti-Lag, `cl_*` sao preferencia, MPO/flip |
| MOBA / RTS | CPU single-thread, rede | pouco ganho de GPU; foco em estabilidade e latencia |
| Simuladores (iRacing, MSFS, DCS) | CPU/memoria/VRAM, VR | cache L3 grande (X3D) ajuda; verifique VRAM e RAM livre |
| Jogos com Reflex nativo | latencia | Reflex On(+Boost), nunca dois limitadores |
| Jogos com anti-cheat de kernel agressivo | bloqueia ferramentas | medir so com PresentMon/HWiNFO assinados; sem injecao |

## O que e universal (nao depende do jogo)
- CPU-bound x GPU-bound pela comparacao `MsCPUBusy`/`MsGPUBusy`/frametime.
- Hitches > (mediana + 8 ms) por minuto, pior quadro, desvio minuto a minuto, 1%/0,1% low por percentil.
- Independent Flip, MPO, escala na GPU, plano de energia/EPP, update contido, apps de fundo, higiene de overlays.
- Estabilidade: tensao de RAM, BIOS, XMP, eventos 6008/1001/WHEA.
- Procedimento de A/B, refutados, estado congelado, diario.

## O que e especifico do jogo (nao copie sem testar)
- Limiar de hitch absoluto (11 ms so faz sentido a 300 FPS).
- Qual config grafica reduz CPU (no Valorant: sombras; em outro jogo: densidade de multidao, distancia de
  desenho, particulas, fisica, "view distance", NPCs; descubra por A/B de uma opcao por vez).
- Gatilhos de hitch (troca de round, respawn, carregamento de chunk, spawn de horda).
- Se ligar SMT/HT, E-cores, X3D: depende de quantas threads o jogo usa (jogos bem multithread preferem SMT on).
- Overlay de metricas nativo (nome das chaves no ini muda por jogo; **nunca invente chave de config**).
- O que e "informacao competitiva" para o dono (som, sombras, corpos, decals) varia por jogo: pergunte.

## Mapas de nomes (exemplo de como registrar codinomes internos)
Se o log usa codinome de mapa/nivel, mantenha uma tabela no diario (ex.: no Valorant, Juliett=Sunset,
Triad=Haven, Bonsai=Split, Pitt=Pearl, Jam=Lotus, Infinity=Abyss, Duality=Bind, Port=Icebox,
Foxtrot=Breeze, Canyon=Fracture). **Compare sempre no mesmo mapa/nivel**: mapa explicou 6 -> 34 hitches/min.
