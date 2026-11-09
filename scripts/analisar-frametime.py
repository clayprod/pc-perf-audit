#!/usr/bin/env python3
"""Analise offline de CSV do PresentMon (1.x ou 2.x), so stdlib.

Uso:
  python analisar-frametime.py cap1.csv [cap2.csv ...] [--app EXE] [--aquecimento 60]
         [--hitch-ms N] [--alvo-fps 300] [--sem-recorte] [--json saida.json]

Decisoes herdadas de erros reais (ver references/armadilhas.md):
  * Recorte de ponta por MEDIANA do frametime por balde de 10 s (nunca por contagem de quadros).
  * Teto de sanidade 60 s (um quadro de 1 s nao e lixo: e o travao procurado).
  * Todo descarte e contado e impresso.
  * 1%/0,1% low por PERCENTIL do frametime (p99/p99,9), nao media do pior 1%.
  * Hitch = frametime > mediana + 8 ms (~11 ms a 300 FPS). Sobrescreva com --hitch-ms.
Rode com o jogo FECHADO (a analise tambem e carga).
"""
import argparse
import csv
import json
import statistics
import sys

FT_COLS = ["MsBetweenPresents", "msBetweenPresents", "FrameTime", "MsFrameTime"]
CPU_COLS = ["MsCPUBusy", "CPUBusy", "msCPUBusy"]
GPU_COLS = ["MsGPUBusy", "GPUBusy", "msGPUBusy"]
LAT_COLS = ["MsClickToPhotonLatency", "ClickToPhotonLatency", "MsInputLatency"]
MODE_COLS = ["PresentMode"]
APP_COLS = ["Application", "ProcessName"]
SANIDADE_MS = 60000.0
BALDE_S = 10.0


def achar(cols, header):
    for c in cols:
        if c in header:
            return c
    return None


def pct(sorted_vals, p):
    """Percentil por interpolacao linear (p em 0..100) sobre lista ja ordenada."""
    if not sorted_vals:
        return float("nan")
    k = (len(sorted_vals) - 1) * p / 100.0
    f = int(k)
    c = min(f + 1, len(sorted_vals) - 1)
    return sorted_vals[f] + (sorted_vals[c] - sorted_vals[f]) * (k - f)


def num(s):
    try:
        return float(s)
    except (TypeError, ValueError):
        try:
            return float(str(s).replace(",", "."))
        except ValueError:
            return None


def ler(caminho, app):
    with open(caminho, newline="", encoding="utf-8-sig") as fh:
        rd = csv.DictReader(fh)
        header = rd.fieldnames or []
        cft, ccpu, cgpu = achar(FT_COLS, header), achar(CPU_COLS, header), achar(GPU_COLS, header)
        clat, cmode, capp = achar(LAT_COLS, header), achar(MODE_COLS, header), achar(APP_COLS, header)
        if not cft:
            sys.exit("ERRO: nao achei coluna de frametime em %s (colunas: %s)" % (caminho, ", ".join(header[:20])))
        linhas = list(rd)
    if capp:
        if not app:
            cont = {}
            for r in linhas:
                cont[r[capp]] = cont.get(r[capp], 0) + 1
            app = max(cont, key=cont.get)
        linhas = [r for r in linhas if r[capp].lower() == app.lower()]
    ft, cpu, gpu, lat, modo = [], [], [], [], []
    descartados = 0
    for r in linhas:
        v = num(r[cft])
        if v is None or v <= 0 or v > SANIDADE_MS:
            descartados += 1
            continue
        ft.append(v)
        cpu.append(num(r[ccpu]) if ccpu else None)
        gpu.append(num(r[cgpu]) if cgpu else None)
        lat.append(num(r[clat]) if clat else None)
        modo.append(r[cmode] if cmode else "?")
    return dict(app=app, ft=ft, cpu=cpu, gpu=gpu, lat=lat, modo=modo, descartados=descartados,
                cols=dict(ft=cft, cpu=ccpu, gpu=cgpu, lat=clat))


def analisar(d, aquecimento, hitch_ms, alvo_fps, recorte):
    ft = d["ft"]
    if not ft:
        return None
    # eixo do tempo = soma cumulativa (robusto a diferencas de coluna de tempo entre versoes)
    t, acc = [], 0.0
    for v in ft:
        acc += v / 1000.0
        t.append(acc)
    total_s = acc
    idx = [i for i in range(len(ft)) if t[i] >= aquecimento]
    n_aquec = len(ft) - len(idx)

    # recorte de ponta por mediana de balde (so as bordas)
    cortado_ini = cortado_fim = 0.0
    if recorte and idx:
        med_g = statistics.median(ft[i] for i in idx)
        baldes = {}
        for i in idx:
            baldes.setdefault(int(t[i] // BALDE_S), []).append(i)
        chaves = sorted(baldes)
        ok = {k: statistics.median(ft[i] for i in baldes[k]) <= 1.35 * med_g for k in chaves}
        ini, fim = 0, len(chaves) - 1
        while ini <= fim and not ok[chaves[ini]]:
            ini += 1
        while fim >= ini and not ok[chaves[fim]]:
            fim -= 1
        manter = set(chaves[ini:fim + 1])
        cortado_ini = ini * BALDE_S
        cortado_fim = (len(chaves) - 1 - fim) * BALDE_S
        idx = [i for i in idx if int(t[i] // BALDE_S) in manter]
    if len(idx) < 100:
        return dict(erro="poucos quadros apos recortes (%d)" % len(idx))

    f = [ft[i] for i in idx]
    seg = sum(f) / 1000.0
    minutos = seg / 60.0
    fs = sorted(f)
    p50 = pct(fs, 50)
    h = hitch_ms if hitch_ms else p50 + 8.0
    hit = [i for i in idx if ft[i] > h]
    graves = [i for i in idx if ft[i] > 20]
    muito = [i for i in idx if ft[i] > 50]

    # hitches por minuto (baldes de 60 s contados a partir do inicio do trecho)
    t0 = t[idx[0]]
    por_min = {}
    for i in idx:
        por_min.setdefault(int((t[i] - t0) // 60), [0, 0.0])[1] += ft[i] / 1000.0
        if ft[i] > h:
            por_min[int((t[i] - t0) // 60)][0] += 1
    taxas = [c / (s / 60.0) for c, s in (v for k, v in sorted(por_min.items())) if s >= 30.0]

    def med(lst):
        v = [x for x in lst if x is not None]
        return statistics.median(v) if v else None

    cpu_i = [d["cpu"][i] for i in idx]
    gpu_i = [d["gpu"][i] for i in idx]
    lat_i = [d["lat"][i] for i in idx if d["lat"][i] is not None]
    cpu_h = [d["cpu"][i] for i in hit if d["cpu"][i] is not None]
    gpu_h = [d["gpu"][i] for i in hit if d["gpu"][i] is not None]
    cpu_bound_hit = None
    if hit and d["cpu"][hit[0]] is not None:
        cpu_bound_hit = sum(1 for i in hit if d["cpu"][i] is not None and d["cpu"][i] >= 0.8 * ft[i]) / len(hit)

    modos = {}
    for i in idx:
        modos[d["modo"][i]] = modos.get(d["modo"][i], 0) + 1

    r = dict(
        app=d["app"], quadros=len(idx), segundos=round(seg, 1), aquecimento_s=aquecimento, quadros_aquecimento=n_aquec,
        recorte_ini_s=cortado_ini, recorte_fim_s=cortado_fim, descartados_invalidos=d["descartados"],
        fps_medio=round(len(f) / seg, 1), p50_ms=round(p50, 3), p90_ms=round(pct(fs, 90), 3),
        p99_ms=round(pct(fs, 99), 3), p999_ms=round(pct(fs, 99.9), 3),
        low1_fps=round(1000.0 / pct(fs, 99), 1), low01_fps=round(1000.0 / pct(fs, 99.9), 1),
        pior_ms=round(fs[-1], 2), limiar_hitch_ms=round(h, 2),
        hitches=len(hit), hitches_por_min=round(len(hit) / minutos, 1),
        graves_20ms=len(graves), travoes_50ms=len(muito),
        travoes_50ms_instantes_s=[round(t[i] - t0, 1) for i in muito[:20]],
        pior_travao_ms=round(max((ft[i] for i in muito), default=0), 1),
        segundos_travados_50ms=round(sum(ft[i] for i in muito) / 1000.0, 2),
        hitches_por_min_minuto_a_minuto=[round(x, 1) for x in taxas],
        desvio_minuto_a_minuto=round(statistics.pstdev(taxas), 2) if len(taxas) > 1 else None,
        cpu_mediana_ms=med(cpu_i), gpu_mediana_ms=med(gpu_i),
        cpu_mediana_nos_hitches_ms=med(cpu_h), gpu_mediana_nos_hitches_ms=med(gpu_h),
        fracao_hitches_cpu_bound=round(cpu_bound_hit, 2) if cpu_bound_hit is not None else None,
        latencia_pior_ms=round(max(lat_i), 1) if lat_i else None,
        latencia_p99_ms=round(pct(sorted(lat_i), 99), 1) if lat_i else None,
        present_mode={k: round(100.0 * v / len(idx), 1) for k, v in sorted(modos.items(), key=lambda kv: -kv[1])},
    )
    if alvo_fps:
        orc = 1000.0 / alvo_fps
        r["pct_quadros_acima_orcamento"] = round(100.0 * sum(1 for x in f if x > orc) / len(f), 1)
        # segundos/min abaixo de 0.9*alvo, janela deslizante ~0.5 s
        janela, acc2, ini2, soma = 0.5, 0.0, 0, 0.0
        abaixo = 0.0
        fl = [ft[i] for i in idx]
        for j in range(len(fl)):
            soma += fl[j] / 1000.0
            while soma > janela and ini2 < j:
                soma -= fl[ini2] / 1000.0
                ini2 += 1
            if soma >= janela * 0.99 and (j - ini2 + 1) / soma < 0.9 * alvo_fps:
                abaixo += fl[j] / 1000.0
        r["seg_por_min_abaixo_90pct_alvo"] = round(abaixo / minutos, 1)
    return r


def leitura(r):
    msg = []
    c, g, ft = r["cpu_mediana_ms"], r["gpu_mediana_ms"], r["p50_ms"]
    if c is not None and g is not None:
        if g >= 0.9 * ft:
            msg.append("GPU-bound na mediana (GPU %.2f ms de %.2f ms)." % (g, ft))
        else:
            msg.append("CPU-bound/limitado por cap: CPU %.2f ms, GPU %.2f ms por quadro (GPU ociosa %.0f%%)." % (c, g, max(0, 100 - 100 * g / ft)))
    if r["fracao_hitches_cpu_bound"] is not None and r["hitches"]:
        msg.append("%.0f%% dos hitches tem CPU >= 80%% do quadro (thread de CPU fazendo o trabalho a mais)." % (100 * r["fracao_hitches_cpu_bound"]))
    if r["travoes_50ms"]:
        msg.append("%d travoes > 50 ms (pior %.0f ms, %.2f s no total). Confira SE caem no meio da partida ou em transicoes (round/fim de partida)." % (r["travoes_50ms"], r["pior_travao_ms"], r["segundos_travados_50ms"]))
    if r["desvio_minuto_a_minuto"] is not None and r["desvio_minuto_a_minuto"] > 4:
        msg.append("Variancia minuto a minuto alta (%.1f): a percepcao de inconsistencia vem daqui." % r["desvio_minuto_a_minuto"])
    pm = r["present_mode"]
    top = next(iter(pm), "?")
    if "Independent" not in top and top != "?":
        msg.append("PresentMode dominante = %s: o DWM pode estar compondo (latencia/custo). Esperado: Hardware: Independent Flip / Direct Flip." % top)
    return msg


def imprimir(nome, r):
    print("=" * 78)
    print(nome)
    if "erro" in r:
        print("  ERRO:", r["erro"])
        return
    print("  app=%s | %d quadros | %.1f s analisados (aquecimento %d s; recorte ini %.0f s, fim %.0f s; invalidos %d)" % (
        r["app"], r["quadros"], r["segundos"], r["aquecimento_s"], r["recorte_ini_s"], r["recorte_fim_s"], r["descartados_invalidos"]))
    print("  FPS medio %.1f | p50 %.2f ms | p90 %.2f | p99 %.2f | p99.9 %.2f | pior %.1f ms" % (
        r["fps_medio"], r["p50_ms"], r["p90_ms"], r["p99_ms"], r["p999_ms"], r["pior_ms"]))
    print("  1%% low (p99) %.0f FPS | 0.1%% low (p99.9) %.0f FPS" % (r["low1_fps"], r["low01_fps"]))
    print("  [METRICA PRINCIPAL] hitches > %.1f ms: %d = %.1f/min | desvio min a min %s | por minuto %s" % (
        r["limiar_hitch_ms"], r["hitches"], r["hitches_por_min"], r["desvio_minuto_a_minuto"], r["hitches_por_min_minuto_a_minuto"]))
    print("  graves > 20 ms: %d | travoes > 50 ms: %d (pior %.0f ms, %.2f s) em t=%s" % (
        r["graves_20ms"], r["travoes_50ms"], r["pior_travao_ms"], r["segundos_travados_50ms"], r["travoes_50ms_instantes_s"]))
    print("  CPU med %s ms | GPU med %s ms | nos hitches: CPU %s GPU %s | latencia pior %s ms (p99 %s)" % (
        r["cpu_mediana_ms"], r["gpu_mediana_ms"], r["cpu_mediana_nos_hitches_ms"], r["gpu_mediana_nos_hitches_ms"],
        r["latencia_pior_ms"], r["latencia_p99_ms"]))
    if "pct_quadros_acima_orcamento" in r:
        print("  quadros acima do orcamento do cap: %.1f%% | seg/min abaixo de 90%% do alvo (janela 0.5 s): %.1f" % (
            r["pct_quadros_acima_orcamento"], r["seg_por_min_abaixo_90pct_alvo"]))
    print("  PresentMode:", r["present_mode"])
    for m in leitura(r):
        print("  * " + m)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("csv", nargs="+")
    ap.add_argument("--app", help="nome exato do exe (padrao: o que mais apresentou)")
    ap.add_argument("--aquecimento", type=float, default=60.0, help="segundos iniciais descartados (padrao 60)")
    ap.add_argument("--hitch-ms", type=float, default=None, help="limiar de hitch em ms (padrao: mediana + 8)")
    ap.add_argument("--alvo-fps", type=float, default=None, help="cap/alvo de FPS para o orcamento por quadro")
    ap.add_argument("--sem-recorte", action="store_true", help="nao cortar carregamento/placar das pontas")
    ap.add_argument("--json", help="grava os resultados em JSON")
    a = ap.parse_args()

    res = {}
    for c in a.csv:
        d = ler(c, a.app)
        r = analisar(d, a.aquecimento, a.hitch_ms, a.alvo_fps, not a.sem_recorte)
        if r is None:
            print("Sem dados em", c)
            continue
        res[c] = r
        imprimir(c, r)
    if len(res) > 1:
        print("=" * 78)
        print("%-44s %7s %8s %8s %8s %6s" % ("captura", "hit/min", "pior ms", "grav>20", "0.1%low", "desv"))
        for c, r in res.items():
            if "erro" in r:
                continue
            print("%-44s %7.1f %8.1f %8d %8.0f %6s" % (c[-44:], r["hitches_por_min"], r["pior_ms"], r["graves_20ms"], r["low01_fps"], r["desvio_minuto_a_minuto"]))
        print("Lembrete: compare so capturas do MESMO mapa/modo e estado conhecido; duas corridas por estado.")
    if a.json:
        with open(a.json, "w", encoding="utf-8") as fh:
            json.dump(res, fh, indent=2, ensure_ascii=False)


if __name__ == "__main__":
    main()
