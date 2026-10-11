import csv
from collections import defaultdict
from pathlib import Path

src = Path("results/bonus/failure_experiments.csv")
out = Path("report/bonus_generated.tex")
rows = list(csv.DictReader(src.open(newline="")))

if len(rows) != 240:
    raise SystemExit(f"Expected 240 trials; found {len(rows)}")

groups = defaultdict(list)
for r in rows:
    groups[(r["algorithm"], r["topology"],
             float(r["failure_probability"]))].append(r)

ps = [0.0, 0.1, 0.25, 0.5, 0.75, 1.0]
algs = ["gossip", "push-sum"]
tops = ["full", "2D"]

if len(groups) != 24 or any(len(v) != 10 for v in groups.values()):
    raise SystemExit("Expected 24 configurations with 10 trials each.")

def stat(alg, top, p):
    rr = groups[(alg, top, p)]
    count = lambda s: sum(r["status"] == s for r in rr)
    ts = [int(r["convergence_time_us"]) for r in rr
          if r["status"] == "success"
          and r["convergence_time_us"] not in ("", "-")]
    return count("success"), count("disconnected"), count("timeout"), count("error"), (
        sum(ts) / len(ts) if ts else None
    )

def num(v):
    return "--" if v is None else f"{v:.1f}"

lines = [
    r"\begin{table}[H]",
    r"\centering\small",
    r"\begin{tabular}{llrrrrr}",
    r"\toprule",
    r"Algorithm & Topology & $p$ & Success & Disconnected & Timeout & Mean time ($\mu$s) \\",
    r"\midrule",
]
for alg in algs:
    for top in tops:
        for p in ps:
            s, d, t, e, mean = stat(alg, top, p)
            lines.append(
                f"{alg.title()} & {top} & {p:g} & {s}/10 & {d}/10 & "
                f"{t}/10 & {num(mean)} " + r"\\"
            )
lines += [
    r"\bottomrule",
    r"\end{tabular}",
    r"\caption{Results for ten trials per configuration. Mean convergence time includes successful trials only.}",
    r"\end{table}",
    "",
]

# Four clearly separated panels: success and disconnection, each split by topology.
# X values are spread evenly for readability; tick labels show the actual p values.
xs = [0.0, 0.8, 1.6, 2.4, 3.2, 4.0]
series_style = {
    "gossip": ("UFBlue", "solid", "circle"),
    "push-sum": ("UFOrange", "dashed", "square"),
}

def plot_panel(top, metric):
    title = ("Successful convergence" if metric == "success"
             else "Disconnected networks")
    ylabel = "Success rate (\\%)" if metric == "success" else "Disconnected (\\%)"
    result = [
        r"\begin{minipage}{0.48\textwidth}",
        r"\centering",
        rf"\textbf{{{top} topology}}\\[2pt]",
        r"\begin{tikzpicture}[x=0.95cm,y=0.045cm]",
        r"\draw[->] (0,0) -- (4.35,0) node[right] {$p$};",
        r"\draw[->] (0,0) -- (0,108) node[above,align=center] {" + ylabel + "};",
    ]
    for y in [0, 20, 40, 60, 80, 100]:
        result.append(rf"\draw[gray!25] (0,{y}) -- (4.08,{y});")
        result.append(rf"\node[left] at (0,{y}) {{\scriptsize {y}}};")
    for x, p in zip(xs, ps):
        result.append(rf"\draw ({x},0) -- ({x},-2);")
        result.append(rf"\node[below] at ({x},-2) {{\scriptsize {p:g}}};")

    for alg in algs:
        color, dash, marker = series_style[alg]
        coords = []
        for x, p in zip(xs, ps):
            s, d, t, e, mean = stat(alg, top, p)
            value = s * 10 if metric == "success" else d * 10
            coords.append((x, value))
        path = " -- ".join(f"({x},{y})" for x, y in coords)
        result.append(rf"\draw[thick,{color},{dash}] {path};")
        for x, y in coords:
            if marker == "circle":
                result.append(rf"\filldraw[fill=white,draw={color},thick] ({x},{y}) circle (2.2pt);")
            else:
                result.append(rf"\filldraw[fill=white,draw={color},thick] ({x},{y}) rectangle ++(0.12,4.5);")
    result += [r"\end{tikzpicture}", r"\end{minipage}"]
    return "\n".join(result)

for metric, caption in [
    ("success", "Successful convergence rate as connection-failure probability increases."),
    ("disconnected", "Fraction of trials whose remaining graph was disconnected."),
]:
    lines += [
        r"\begin{figure}[H]",
        r"\centering",
        plot_panel("full", metric),
        r"\hfill",
        plot_panel("2D", metric),
        rf"\caption{{{caption} Each point summarizes ten trials.}}",
        r"\end{figure}",
        "",
    ]

out.write_text("\n".join(lines) + "\n")
print(f"Generated {out} from {len(rows)} measured trials.")
