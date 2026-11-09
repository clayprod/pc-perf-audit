---
name: pc-perf-audit
description: Audita e ajusta a performance de qualquer PC Windows para jogo competitivo (stutter, 1% low, hitches, latencia, freeze, corte de audio) com metodo medido - inventario de hardware/software/BIOS, captura de frametime com PresentMon, diagnostico CPU vs GPU, catalogo de alavancas para Intel/AMD/NVIDIA/AMD GPU, teste A/B reversivel e congelamento do estado aprovado. Use quando o usuario pedir para otimizar, diagnosticar ou "tunar" um PC de jogo, replicar essa analise em outra maquina ou outro jogo, ou investigar microstutter, FPS instavel, travamentos ou latencia.
---

# pc-perf-audit - auditoria de performance medida, para qualquer PC

Destilado de meses de trabalho numa maquina real (Ryzen 7 5700X + RTX 2060, Valorant
competitivo). **Serve para qualquer jogo, qualquer CPU (Intel/AMD) e qualquer GPU
(NVIDIA/AMD/Intel):** o metodo e agnostico; o que muda por jogo (exe, config, log, anti-cheat,
cenario de reclamacao) esta em `references/jogos.md`. O que vale aqui e o **metodo** e o
**catalogo do que ja foi medido**; os numeros daquela maquina sao exemplos, **nao** receita
para outra. Quando um exemplo citar Valorant, leia como "exemplo de um jogo".

## Regras que valem mais que qualquer tweak

1. **Voce nao decide o que e melhor para o dono. Voce monta o teste.** Hipotese, mudanca
   reversivel, ele joga, voce colhe o veredito.
2. **Dois tipos de veredito, nunca misturar:**
   - *Mensuravel* (frametime, 1% low, hitches, latencia, estabilidade): decide **o numero**.
   - *Julgavel* (nitidez, contraste, som, "feel", visibilidade): decide **so o dono**, uma
     mudanca por vez. Reporte as duas coisas separadas.
3. **Uma variavel por vez. Uma corrida so nao decide nada.** Minimo duas corridas, 
   descartar o aquecimento, olhar o desvio minuto a minuto, nao so a media.
4. **Nao bateu a linha de base? Reverte.** Ganho visual nao compra queda de frametime
   (a menos que o dono diga o contrario, e mesmo assim meca e reporte o custo).
5. **Caminho que nao paga nada, sempre.** Antes de propor algo que custa CPU/GPU/latencia/
   risco, procure a mesma coisa numa camada mais perto da saida de video ou que nao cobra
   (ex.: vibrance digital no painel em vez de filtro por quadro; escalonar na GPU em vez
   de no monitor; limitador de FPS nativo do jogo em vez de limitador no driver; fechar
   app em vez de mexer em prioridade).
6. **NUNCA conclua "a maquina esta entregando o que pode".** "Onde esta o custo" e "da para
   executa-lo mais rapido" sao perguntas diferentes: codigo serial roda mais rapido com
   clock efetivo maior, latencia de memoria menor, menos disputa de cache.
7. **Evidencia antes de afirmacao.** Teoria plausivel ja derrubou varias rodadas. Nao
   apresente hipotese como resultado, nao declare ganho sem medicao.
8. **O instrumento tambem e carga.** Medidor, coletor, vigia, overlay, e **o proprio agente**
   (Claude, terminal, PowerShell) gastam CPU. Durante uma captura: nao use a maquina.
9. **Quando a medicao discorda do usuario por dias, suspeite da medicao antes da percepcao
   dele.** Isso se repetiu 4 vezes (ver `references/armadilhas.md`).
10. **Confirme so o que e arriscado ou irreversivel** (firmware, BIOS, seguranca, apagar
    dados). O resto: escolha, diga o porque em uma linha, siga.
11. **Reversibilidade:** antes de qualquer mudanca, registre o valor original e o comando
    de desfazer. Nada de dry-run que deixa rastro; simulacao nao toca em disco.

## Etapas (siga na ordem; cada uma tem criterio de saida)

### Etapa 0 - Perfil e objetivo (entrevista curta)
Pergunte (de uma vez, com `AskUserQuestion`, nao em conversa longa):
- Jogo(s) principal(is), modo (competitivo/casual), meta (FPS alvo, taxa do monitor). **Para cada jogo
  preencha a ficha de `references/jogos.md`** (exe, API, engine, config, log, anti-cheat, modo de teste).
- Sintomas: microstutter, queda na troca de tiro, freeze total, BSOD, corte de audio, input
  lag, cintilacao/serrilhado, tela preta. **Qual minuto/mapa/momento?** (ancora a captura)
- **Inegociaveis do dono** (nao se mexe nem se argumenta): sensibilidade, DPI, resolucao,
  modo de tela esticado, mira, vibrance, apps que ele precisa abertos (ex.: Discord).
- O que ele ja tentou e o que ja ficou bom/ruim. Houve um dia "perfeito"? Quando?
- Anti-cheat do jogo (Vanguard, EAC, BattlEye, FACEIT): limita afinidade, prioridade,
  injecao de overlay e drivers de terceiros. Veja `references/catalogo-alavancas.md` sec. 11.
**Saida:** perfil escrito no diario (modelo em `references/template-diario.md`).

### Etapa 1 - Inventario (somente leitura)
Rode `scripts/inventario.ps1 -Saida <pasta>` (PowerShell 5.1, de preferencia **elevado**;
sem elevacao alguns campos saem vazios e o script avisa). Ele coleta CPU, GPU, RAM (velocidade
configurada x nominal, tensao), BIOS/placa, SO, plano de energia e EPP, MPO, HAGS, VBS/HVCI,
Modo de Jogo, GameDVR, Secure Boot, Defender, servicos de update, NICs, discos, monitores,
resolucao/refresh, startup, servicos e processos de terceiros, overlays conhecidos, e contagem
de eventos 6008/1001/WHEA. Leia `inventario.txt` e **classifique a plataforma**:
`CPU: AMD Zen2/3/4/5 (X3D?) | Intel Core hibrido (P+E) | Intel Core nao-hibrido`,
`GPU: NVIDIA | AMD | Intel Arc | iGPU`. Isso escolhe as secoes do catalogo.
**Saida:** tabela "item -> valor -> normal? -> hipotese" no diario. Nao mude nada ainda.

### Etapa 2 - Higiene do ambiente (o que roda durante a partida)
Objetivo: ambiente de partida **conhecido e limpo**. Use o inventario + `Get-Process`.
- Liste o que consome CPU em segundo plano (navegador, launcher, cloud sync, updaters,
  overlays, RGB, capturadores, o proprio agente). Separe: *fechar*, *impedir de nascer*,
  *deixar* (decisao do dono).
- Prefira **impedir de nascer** (StartupApproved, politica, permissao de segundo plano de app
  da Store) a matar a cada N minutos. Cheque se o item da sua lista **casa de verdade** com o
  nome do processo (um `'WhatsApp'` que nunca casou `WhatsApp.Root` sobreviveu 17 dias).
- Updaters/servicos que religam sozinhos (Windows Update, vendor updaters): decida contencao
  e **verifique que ela persiste** (veja armadilhas: instalador recria tarefa/servico).
- Overlays que injetam DLL no `Present` (RTSS/Afterburner OSD, Discord overlay, Steam,
  GeForce, Medal, OBS hook): custo pequeno mas na thread de render. Liste, nao mate sem o
  dono saber; medir o efeito e opcional (nesta maquina o ganho nao foi demonstravel).
**Saida:** lista de "apps durante a partida" + mecanismo de contencao + como verificar.

### Etapa 3 - Linha de base medida
Protocolo completo em `references/metodo.md`. Resumo:
1. Jogo fechado, maquina assentada (5+ min apos boot), nada novo aberto.
2. `scripts/capturar.ps1 -Processo <exe> -Segundos 420 -Rotulo <texto>` durante uma
   partida real **no modo/mapa de reclamacao** (DM descartavel se o PresentMon for risco).
   A captura **nao analisa** (analise em CPU/RAM durante a partida e carga).
3. Depois da partida, jogo fechado: `python scripts/analisar-frametime.py <csv>`.
4. **Duas corridas no minimo**, mesmo mapa. A primeira apos boot/patch/driver e fria.
5. Pergunte o veredito (nota/frase) e anote **ao lado** do numero. Com 8+ capturas e
   vereditos, valide qual metrica correlaciona (posto) com o que ele sente e use essa.
**Saida:** linha de base por cenario (DM e 5v5 sao diferentes!) com hitches/min, pior
quadro, 1%/0,1% low, p99, desvio por minuto, e o veredito dele.

### Etapa 4 - Diagnostico
Arvore em `references/diagnostico.md`. Perguntas na ordem:
1. CPU-bound ou GPU-bound? (`MsCPUBusy` vs `MsGPUBusy`, mediana e nos quadros ruins)
2. O problema e **media** ou **cauda**? (hitches/min, pior quadro, graves >20 ms)
3. Os hitches tem gatilho? (troca de round, carregamento, respawn, mapa, habilidade, fim de
   partida, patch/driver recente = shader recompilando) - cruze com o log do jogo.
4. Algo externo disputa? (traco de kernel/ETW; ISR/DPC; I/O de disco; memoria livre;
   temperatura e clock) - **so conclua com instrumento certo**.
5. Se for freeze/BSOD/corte de audio, e outra arvore (hardware/estabilidade/radio).
**Saida:** hipoteses ordenadas por (probabilidade x custo de testar x reversibilidade).

### Etapa 5 - Alavancas (do mais barato ao mais caro)
Consulte `references/catalogo-alavancas.md`, **so as secoes da plataforma detectada**, e
**a lista de refutados antes de propor qualquer coisa**. Ordem de ataque:
1. Camada que nao cobra: scanout/display (escala na GPU, vibrance digital, tempo de resposta
   do monitor), Windows (MPO, plano de energia/EPP, update contido, apps de fundo).
2. Velocidade do nucleo que roda a thread do jogo: EPP/boost, limites de energia, SMT/E-cores,
   latencia e tensao de memoria, FCLK/ring, Curve Optimizer/undervolt, resfriamento.
3. Estabilidade: tensao de memoria, XMP/DOCP, BIOS, C-states, fonte, temperatura.
4. Config do jogo: so o que reduz **CPU por personagem** (sombras, corpos, contadores);
   respeitando os inegociaveis e o que e informacao competitiva (som, sombra de inimigo).
5. Rede/audio/perifericos: medir antes; tweaks de rede ja pioraram 5x.
Para cada alavanca: valor original, comando de aplicar, comando de desfazer, hipotese
mensuravel e o que **o dono** precisa julgar.

### Etapa 6 - Teste A/B e veredito
Para cada alavanca (uma por vez): aplicar -> **duas** capturas no mesmo cenario -> comparar
contra a linha de base **do mesmo mapa/modo** -> perguntar o que ele sentiu -> decidir:
`ADOTAR | REVERTER | SEM VEREDITO (mais dados)`. Registre mesmo as refutadas, com o numero:
a lista de refutados e o ativo mais valioso do projeto.
Regra de comparacao: **filtre a linha de base pelo estado da maquina, nao pela data.**
Se mexeu em algo entre duas corridas, a serie virou anedota - refaca.

### Etapa 7 - Congelar o estado aprovado
Quando o dono disser "ta bom, nao quero que regrida": fotografe o estado (BIOS, drivers,
servicos, tarefas, registro, energia, config do jogo, startup) numa lista de **sondas** com
valor esperado, rode-a periodicamente e depois de patch/driver/BIOS. Regras:
- **Antes de congelar, rode a comparacao sem congelar e resolva cada desvio** (deliberado
  -> congela; regressao -> conserta). Congelar com desvio grava a regressao como ouro.
- Congele com o jogo **fechado** e com a sessao elevada.
- Sonda que gera falso alarme ensina a ignorar sonda: investigue o historico do valor.
- Sonda com nome/valor de chave errado e pior que sonda ausente: confira contra o arquivo real.
- Documente o que uma gravacao de BIOS/CMOS zerado desfaz em silencio (SMT, C-state, DOCP,
  tensao de DRAM, Secure Boot, Resizable BAR, PBO) e o roteiro de volta.

### Etapa 8 - Documentacao viva
Mantenha um diario (`references/template-diario.md`): estado atual, linha de base, **lista
de refutados**, armadilhas pagas, pendencias em ordem. Corrija entradas erradas **com
retratacao explicita no topo**, nao apagando - o historico de erros evita reincidencia.

## Como entregar resultados ao usuario
- Em pt-BR (ou o idioma do dono), direto. Uma linha de porque por decisao.
- Tabela por captura: cenario, hitches/min, pior quadro, graves >20 ms, 1%/0,1% low, desvio,
  veredito dele. Separe "o que o numero diz" de "o que so voce pode dizer".
- Nunca reporte FPS por segundo fixo como "o que ele ve": o contador do jogo usa janela curta.
- Marque cada afirmacao: `MEDIDO`, `HIPOTESE`, `LITERATURA (fonte)`, `DECISAO DO DONO`.

## Arquivos desta skill
- `references/metodo.md` - protocolo de captura, metricas, recortes, validacao de metrica.
- `references/jogos.md` - ficha por jogo, marcadores de log, perfis por genero/engine, o que e universal x especifico.
- `references/diagnostico.md` - arvore de sintomas -> instrumento -> causa provavel.
- `references/catalogo-alavancas.md` - tudo que foi tentado/medido, por camada e fabricante.
- `references/armadilhas.md` - erros de instrumento e de raciocinio que ja custaram iteracao.
- `references/template-diario.md` - modelo do diario/AGENTS.md da maquina auditada.
- `scripts/inventario.ps1` - inventario somente leitura (PS 5.1, ASCII).
- `scripts/capturar.ps1` - captura PresentMon sem analisar + snapshots de processos.
- `scripts/analisar-frametime.py` - analise offline robusta (Python 3 stdlib).
