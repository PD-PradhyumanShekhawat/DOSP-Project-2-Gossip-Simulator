#!/usr/bin/env python3
"""Run repeated DOSP failure-probability experiments and generate CSVs/plots."""
import csv, os, subprocess, time
from pathlib import Path
from statistics import mean
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parent
EBIN = ROOT / "ebin"
OUT = ROOT / "results" / "bonus"
OUT.mkdir(parents=True, exist_ok=True)

# Keep this first experiment compact enough to finish before the deadline.
TOPOLOGIES = [("full", 9), ("2D", 9)]
ALGORITHMS = ["gossip", "push-sum"]
PROBABILITIES = [0.0, 0.1, 0.25, 0.5]
TRIALS = 3
TIMEOUT_SECONDS = 8  # coordinator timeout should be set to 8s for run/6 below

def erl_atom(s):
    return "'" + s + "'" if s in ("2D", "push-sum") else s

def run_one(n, topology, algorithm, p):
    expr = (
        f'case coordinator:run({n}, {erl_atom(topology)}, {erl_atom(algorithm)}, '
        f'10, {p}, {TIMEOUT_SECONDS * 1000}) of '
        f'{{ok, T}} -> io:format("RESULT=success;~p~n", [T]); '
        f'{{error, R}} -> io:format("RESULT=failure;~p~n", [R]) end, halt().'
    )
    start = time.monotonic()
    try:
        proc = subprocess.run(
            ["erl", "-noshell", "-pa", str(EBIN), "-eval", expr],
            capture_output=True, text=True, timeout=TIMEOUT_SECONDS + 3
        )
        elapsed = time.monotonic() - start
        combined = proc.stdout + "\n" + proc.stderr
        marker = next((line for line in combined.splitlines() if "RESULT=" in line), "")
        if "RESULT=success;" in marker:
            raw = marker.split("RESULT=success;", 1)[1].strip()
            try: convergence_us = int(raw)
            except ValueError: convergence_us = None
            return "success", convergence_us, elapsed, ""
        if "RESULT=failure;" in marker:
            reason = marker.split("RESULT=failure;", 1)[1].strip()
            return "failure", None, elapsed, reason
        return "error", None, elapsed, (combined[-1200:] or f"exit={proc.returncode}")
    except subprocess.TimeoutExpired:
        return "error", None, time.monotonic() - start, "external_process_timeout"

rows = []
total = len(TOPOLOGIES) * len(ALGORITHMS) * len(PROBABILITIES) * TRIALS
idx = 0
for topology, n in TOPOLOGIES:
    for algorithm in ALGORITHMS:
        for p in PROBABILITIES:
            for trial in range(1, TRIALS + 1):
                idx += 1
                status, conv_us, wall, reason = run_one(n, topology, algorithm, p)
                row = {
                    "topology": topology, "nodes": n, "algorithm": algorithm,
                    "failure_probability": p, "trial": trial, "status": status,
                    "convergence_time_us": conv_us, "wall_time_s": round(wall, 3),
                    "failure_reason": reason
                }
                rows.append(row)
                print(f"[{idx}/{total}] {topology} n={n} {algorithm} p={p} trial={trial}: {status}"
                      + (f" ({conv_us} us)" if conv_us is not None else f" ({reason})"), flush=True)

raw_path = OUT / "failure_experiments.csv"
with raw_path.open("w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    writer.writeheader(); writer.writerows(rows)

summary = []
keys = sorted({(r["topology"], r["nodes"], r["algorithm"], r["failure_probability"]) for r in rows})
for topology, n, algorithm, p in keys:
    group = [r for r in rows if (r["topology"], r["nodes"], r["algorithm"], r["failure_probability"]) ==
             (topology, n, algorithm, p)]
    successes = [r for r in group if r["status"] == "success"]
    times = [r["convergence_time_us"] for r in successes if r["convergence_time_us"] is not None]
    summary.append({
        "topology": topology, "nodes": n, "algorithm": algorithm,
        "failure_probability": p, "trials": len(group), "successes": len(successes),
        "success_rate": len(successes) / len(group),
        "mean_convergence_time_us_successes_only": round(mean(times), 2) if times else "",
        "failures": sum(r["status"] == "failure" for r in group),
        "errors": sum(r["status"] == "error" for r in group)
    })
summary_path = OUT / "failure_summary.csv"
with summary_path.open("w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=list(summary[0].keys()))
    writer.writeheader(); writer.writerows(summary)

# Success rate by p, one plot per algorithm.
for algorithm in ALGORITHMS:
    fig, ax = plt.subplots()
    for topology, _n in TOPOLOGIES:
        series = [r for r in summary if r["algorithm"] == algorithm and r["topology"] == topology]
        series.sort(key=lambda r: r["failure_probability"])
        ax.plot([r["failure_probability"] for r in series], [r["success_rate"] for r in series],
                marker="o", label=topology)
    ax.set(xlabel="Transient link-failure probability (p)", ylabel="Convergence success rate",
           title=f"{algorithm}: convergence under transient link failures", ylim=(-0.05, 1.05))
    ax.grid(True, alpha=0.3); ax.legend()
    fig.tight_layout()
    fig.savefig(OUT / f"{algorithm.replace('-', '_')}_failure_success_rate.png", dpi=180)
    plt.close(fig)

# Mean convergence time only among successful runs; failed runs are never encoded as zero.
for algorithm in ALGORITHMS:
    fig, ax = plt.subplots()
    for topology, _n in TOPOLOGIES:
        series = [r for r in summary if r["algorithm"] == algorithm and r["topology"] == topology]
        series.sort(key=lambda r: r["failure_probability"])
        xs = [r["failure_probability"] for r in series if r["mean_convergence_time_us_successes_only"] != ""]
        ys = [r["mean_convergence_time_us_successes_only"] for r in series if r["mean_convergence_time_us_successes_only"] != ""]
        if xs: ax.plot(xs, ys, marker="o", label=topology)
    ax.set(xlabel="Transient link-failure probability (p)",
           ylabel="Mean convergence time among successful trials (microseconds)",
           title=f"{algorithm}: convergence time when convergence succeeds")
    ax.grid(True, alpha=0.3)
    if ax.lines: ax.legend()
    fig.tight_layout()
    fig.savefig(OUT / f"{algorithm.replace('-', '_')}_failure_convergence_time.png", dpi=180)
    plt.close(fig)

print(f"\nRaw results: {raw_path}")
print(f"Summary:     {summary_path}")
print(f"Plots:       {OUT}")
