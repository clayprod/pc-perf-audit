# Armadilhas ja pagas (cada uma custou pelo menos uma iteracao)

## A. Instrumento sujo produzindo numero limpo
1. **Recorte de ponta por contagem de quadros** apagava o balde que continha o travao
   (79% < corte de 80%); o script ainda favorecia as partidas ruins (trecho apagado tinha 2,9-3,6x
   mais hitch). Use mediana do frametime por balde.
2. **`> 1000 ms` descartado como "lixo"** escondeu todos os travoes de ~1,5 s por semanas.
   Teto de sanidade 60 s e linha propria `travoes > 50 ms` no resumo.
3. **Analise automatica rodando durante a partida** (23,7 s de CPU, 745 MB) por fatia. Capturar
   nao analisa; analise offline com jogo fechado.
4. **Coletor ligado so numa captura** (DPC por segundo) mudou a forma da distribuicao (muitos
   quadros medios sem nenhum de 14 ms). Instrumento novo no meio de uma serie quebra a serie.
5. **`MsCPUBusy` ≠ execucao.** Inclui espera/preempcao fora do Present. Para provar execucao,
   ETW de kernel.
6. **Sinais de apresentacao nao distinguem menu de partida** (Independent Flip 100%, FPS,
   nenhum outro processo apresentando). Use MB do processo / watts / log do jogo.
7. **Limiares absolutos envelhecem** (MB do jogo por patch). Use o degrau/forma, nao o valor.
8. **Mediana por nucleo de contador de DPC** = 0 sempre (quantizado em 1,56%); use media/`_total`.
   Conjunto `Processor Information` devolvia zero absoluto; testar o valor, nao confiar no nome.
   Contador traduzido (`\Processador(*)`) quebra em script ANSI com acento: liste via `Get-Counter -ListSet`.
9. **Virgula decimal**: `caixa-preta.csv` ponto (InvariantCulture); CSV do HWiNFO virgula (pt-BR). O
   `except` que engole `ValueError` zera a coluna inteira e parece "DPC baixo".
10. **Poll de foreground a 200 ms perde** flash de console (100-300 ms): use 50 ms.
11. **`INPUTSINK` em janela oculta** mede mouse a 8,000 ms cravado (falso 125 Hz); janela visivel.
12. **Medir latencia de memoria com jogo/launcher aberto** suja (80 vs 72 ns). L3 de controle denuncia.
13. **Contador de FPS do jogo = media de janela curta.** Nao reporte FPS/seg fixo como "o que ele ve".
14. **`CPU_Load` da caixa-preta nao e confiavel entre instancias**; cruze com watts.
15. **Alinhamento por quadro gigante**: um quadro de 3,5 s "engole" qualquer trecho; use baldes de 1 s.
16. **`PresentMon` nao tem relogio absoluto** (CPUStartTime relativo); alinhe por nome de arquivo +
    evento do log do jogo, refinado pelo carregamento do menu.
17. "% de um nucleo" tirado de contagem de amostras de perfil e invalido; so proporcoes dentro de um processo.
18. Trecho continuo de CPU tem de **quebrar em buraco de tempo** (>1,5 ms) senao entrar/sair de espera vira "50 ms no kernel".
19. IP de kernel estoura int64 (`array('Q')`); CSV do `tracerpt` = 6 GB para 575 MB de ETL.

## B. Raciocinio
1. **Atribuir causa sem A/B.** "Quem saiu e o culpado" e decisao, nao medicao; nao cite como fato.
2. **Mexer na maquina entre duas corridas** destroi o A/B, mesmo com mudancas "inocuas".
3. **Escolher so as capturas que confirmam a tese** para validar metrica nova. Valide contra todas.
4. **Base de comparacao contaminada** (periodo com tweak depois refutado). Filtre pelo estado, nao pela data.
5. **`Aplicado` ≠ `funcionando`.** Perfil NVAPI reportava "9 de 9 ok" sem efeito e ainda *sobrepunha* a
   escolha global do dono. Leia de volta e meça o efeito.
6. **Hipotese plausivel refutada tres vezes:** cache de shader saturado (256 MB cravados = tamanho a
   que o container chegou, nao teto), "mapa pesado do patch" (notas oficiais nao mudam rotacao),
   "folga de 1,5% do cap explica drops".
7. **Unidade**: tabela de ETW em % da maquina (16 threads) vs contexto em % de UM nucleo -> multiplique
   antes de comparar. `vgc` "dezenas de vezes mais pesado" era erro de unidade.
8. **Fantasma de plano de energia**: o plano alterna por design (Lasso); comparar jogo fechado contra
   registro de jogo aberto gera regressao falsa. Antes de testar uma variavel, confira que ela difere.
9. **Chave ausente ≠ valor.** Ausencia = padrao, e o padrao pode ser ligado (corpos) ou desligado
   (sombra). Confira no menu, nunca deduza.
10. **"Cache frio / primeira partida" como desculpa** sem captura que mostre hitches no comeco.
11. **Ler o aviso do script e citar o numero mesmo assim** (latencia de memoria com jogo aberto).
12. Concluir "a maquina esta no limite" (proibido; ver SKILL).
13. **Confundir freeze com dono segurando o botao de power** (6008 identico). Pergunte.
14. Afirmar "70 eventos WHEA" filtrando so por Id (colide com TPM, SMSS). Filtre por provedor.
15. **Hashear alvo largo demais** (blob de display) gera alarme eterno; hashear de menos cega a sonda.
16. Sonda que casa valor errado (`PlayerPerfShow*=1` quando ligado e `=2`) nasce cega.

## C. Scripts e shell no Windows (esta maquina e qualquer outra)
- **PowerShell 5.1**: sem `&&`, `||`, ternario, `??`. Encadear com `;` e `if ($?)`.
- `.ps1` sem BOM lido como **ANSI**: acento em literal quebra casamento. Scripts de producao em ASCII.
- **`[ \t]*$` nao casa fim de linha CRLF** (o `\r` sobra). Use `\s*$`.
- **Alias vence funcao** (`RV`, `H` ignorados em silencio).
- **`C:\tweak` contem `\t`**: em sed/python sem raw string/regex/heredoc vira tabulacao; `\U` vira SyntaxError.
- Backslash some em heredoc de Bash: escreva o script em arquivo (ferramenta Write), rode o arquivo,
  e sempre `[Parser]::ParseFile` depois de editar `.ps1`.
- **`cscript` EXECUTA** o .vbs, nao valida sintaxe. Valide com clone inocuo (`WScript.Echo`).
- **Nunca crie `.ps1` temporario na pasta cujos `.ps1` sao hasheados por sonda.** Scratchpad.
- **Tarefas SYSTEM sao invisiveis sem elevacao**; `Register-ScheduledTask` com principal SYSTEM reporta
  sucesso e nao persiste: `schtasks /create /xml`.
- **`Set-Service` nega mesmo elevado** em servicos protegidos (wuauserv, UsoSvc, DoSvc, WaaSMedicSvc,
  GamingServices): `Start=4` no registro; efeito no proximo boot.
- **Colar bloco de varias linhas** pode inverter a ordem. Para acao elevada, **uma linha**; filtro por nome > `-InstanceId` (o `&` quebra no cmd).
- `Get-CimInstance Win32_Process` custa 30-74 ms; `Get-Process -Name` um por nome ~56-129 ms
  (PS 5.1 enumera tudo); `GetProcesses()` + indice por nome ~8-13 ms. Isso importa dentro de vigia.
- `Win32_ProcessStopTrace` nao dispara para o jogo protegido por anti-cheat.
- Subscricao WMI permanente falha na entrega (3 de 3 aberturas); 4 bindings sao 2 fantasmas de enumeracao -
  nao tente limpar. Cubra com vigia periodica.
- `Get-Volume -DriveLetter` nao enxerga a ESP montada por `mountvol`; use `System.IO.DriveInfo`.
- `New-Item -Force` em chave de registro existente pode apagar valores: `Test-Path` antes.
- Backup do `.cena.bak` antes de testar `-Simular` gera "prova" falsa de que foi aplicado.
- Contadores `% tempo C2/C3` do Windows ficam em zero em Ryzen com C-state ligado ou desligado; use consumo ocioso na caixa-preta.
- `tweak-*` com acao trocada passa despercebida se a sonda hasheia so nome/estado: hasheie a **acao**.
- Dry-run: simulacao nao toca em disco.

## D. Congelar estado (estado-ouro)
- Congelar com jogo aberto grava `guardiao=DESLIGADA` e desvios de video como referencia.
- Congelar sem resolver desvios grava a regressao como ouro (ja ocorreu duas vezes na mesma noite).
- Run do HKCU recria entradas (Chrome autolaunch, Edge); a decisao e do `StartupApproved` + processo existe.
- Guardiao pausado durante partida e cura so a cada 30 min => janela de buraco. Vigia de 3 min cobre.
- Boot-enxuto/sem-update **nao sao "aplicar uma vez"**: rode `-Simular` apos instalar/atualizar Edge, Adobe, vendor, Windows.
- Sondas que so leem com elevacao: lista `$SO_ADMIN`, senao viram "(sumiu)".
