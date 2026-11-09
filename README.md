# pc-perf-audit

Skill para agentes (Claude Code e similares) que audita e ajusta a performance de **qualquer PC
Windows para qualquer jogo**, com metodo medido em vez de "tweaks de internet".

Destilada de meses de trabalho numa maquina real (Ryzen 7 5700X + RTX 2060, Valorant competitivo).
Inclui a lista do que foi **refutado por medicao** (para nao reaplicar mito), o protocolo de captura
com PresentMon e o catalogo de alavancas para Intel, AMD, NVIDIA, AMD Radeon e Intel Arc.

## Conteudo
- `SKILL.md` - regras e as 9 etapas (perfil -> inventario -> higiene -> linha de base -> diagnostico -> alavancas -> A/B -> congelar -> diario).
- `references/metodo.md` - protocolo, metricas, recortes, validacao de metrica.
- `references/diagnostico.md` - sintoma -> instrumento -> causa provavel.
- `references/catalogo-alavancas.md` - o que foi tentado, por camada e fabricante, com status (confirmado / refutado / hipotese).
- `references/jogos.md` - ficha por jogo, marcadores de log, perfis por genero/engine.
- `references/armadilhas.md` - erros de instrumento, raciocinio e PowerShell que ja custaram iteracao.
- `references/template-diario.md` - modelo do diario da maquina auditada.
- `scripts/inventario.ps1` - inventario somente leitura (PowerShell 5.1).
- `scripts/capturar.ps1` - captura PresentMon sem analisar.
- `scripts/analisar-frametime.py` - analise offline (Python 3, so stdlib).

## Instalar (Claude Code)
Copie a pasta para `~/.claude/skills/pc-perf-audit` (usuario) ou `<projeto>/.claude/skills/pc-perf-audit`.

## Avisos
- Os resultados sao de **uma maquina**; em outro PC trate o catalogo como hipoteses a testar.
- Mudancas de BIOS, registro e servicos podem causar instabilidade. Anote o valor original e como desfazer.
- Leia os termos do anti-cheat do seu jogo antes de usar ETW/overlays/ferramentas de baixo nivel.
- PresentMon: https://github.com/GameTechDev/PresentMon (baixe voce mesmo; nao vem no repo).
