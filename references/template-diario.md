# Modelo de diario / AGENTS.md da maquina auditada

Copie para a raiz do projeto da maquina (ex.: `<pasta>\AGENTS.md`) e preencha. Regras:
- Documento **canonico unico**; o `CLAUDE.md` so importa `@AGENTS.md`.
- Cronologico para historico, mas com uma secao **"Onde estamos"** no topo, consolidada.
- Retrate erros com bloco `> RETRATADO em <data>` no topo da secao errada; nao apague.
- Cada afirmacao leva etiqueta: MEDIDO / HIPOTESE / LITERATURA(fonte) / DECISAO-DONO.

```
# <pasta> - ajuste de <PC do fulano> para <jogo>

## Objetivo e o que "melhor" significa
- Objetivo: <ex.: maquina nunca ser o fator limitante; ranked competitivo>
- Regra de ouro dele: <ex.: performance e lei, visual e opcao>
- Inegociaveis (nao mexer nem argumentar): <sens, DPI, resolucao, vibrance, apps abertos...>
- Informacao competitiva que nao se corta: <audio de passo, sombra...>
- Como ele quer ser tratado: <decida sem perguntar; confirme so irreversivel>

## Ambiente
SO/build | shell | CPU | GPU | RAM (velocidade real, tensao) | placa + BIOS (data) | monitor/refresh | audio | anti-cheat

## Sintomas originais (numerados) e estado de cada um

## Linha de base (por CENARIO - nunca misture DM e 5v5)
| cenario | data | hitches/min | pior quadro | graves >20 ms | 1% low | 0,1% low | desvio min/min | veredito dele |

## ESTADO APROVADO (o que se protege)
BIOS: ...  | Windows: ... | Drivers: versoes congeladas | Sondas: lista | Congelado em <data>, <N> sondas, 0 fora

## NAO REOFERECA - refutado por medicao nesta maquina
| ajuste | data | numero | veredito |

## Hipoteses em aberto (ordenadas por prob x custo x reversibilidade)

## Pendente (em ordem)

## Armadilhas pagas (so as especificas desta maquina)

## Ferramental (script -> para que serve)

## Decisoes do dono (citacao + data) - nao se reabrem
```

## Entradas de diario por experimento
```
### <data> <alavanca>
Hipotese: ...  Variavel unica: ...  Valor original: ...  Aplicado: ...  Desfazer: ...
Capturas: <arquivo1> <arquivo2> (mapa, estado)  Resultado: tabela
Veredito mensuravel: ADOTAR/REVERTER/SEM VEREDITO  Veredito julgavel (dele): "..."
Retratacoes: ...
```
