import csv
import os
import statistics
from collections import defaultdict

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

BASELINE_INPUT = "results/experiment_results.csv"
BASELINE_SUMMARY = "results/experiment_summary.csv"

THRESHOLD_INPUT = "results/gossip_threshold_experiments.csv"
THRESHOLD_SUMMARY = "results/gossip_threshold_summary.csv"

TOPOLOGIES = ["full", "line", "2D", "imp2D"]

os.makedirs("results", exist_ok=True)
os.makedirs("report", exist_ok=True)


def read_csv(path):
    if not os.path.exists(path):
        raise FileNotFoundError(
            f"Required dataset not found: {path}"
        )
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def write_summary(path, fields, rows):
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def summarize(rows, include_threshold=False):
    groups = defaultdict(list)

    for row in rows:
        key = (
            row["algorithm"],
            row["topology"],
            int(row["nodes"]),
        )
        if include_threshold:
            key += (int(row["threshold"]),)
        groups[key].append(row)

    summary = []

    for key, group in sorted(groups.items()):
        algorithm, topology, nodes = key[:3]
        threshold = key[3] if include_threshold else None

        successful = [
            int(row["convergence_us"])
            for row in group
            if row["status"] == "success"
            and row.get("convergence_us", "").strip()
        ]

        trials = len(group)
        successes = len(successful)

        item = {
            "algorithm": algorithm,
            "topology": topology,
            "nodes": nodes,
            "trials": trials,
            "successes": successes,
            "failures": trials - successes,
            "success_rate": round(successes / trials, 4),
            "mean_convergence_us": (
                round(statistics.mean(successful), 2)
                if successful else ""
            ),
            "stdev_convergence_us": (
                round(statistics.stdev(successful), 2)
                if len(successful) > 1 else ""
            ),
        }

        if include_threshold:
            item["threshold"] = threshold

        summary.append(item)

    return summary


def plot_baseline(summary):
    for algorithm in ["gossip", "push-sum"]:
        fig, ax = plt.subplots()

        for topology in TOPOLOGIES:
            rows = [
                row for row in summary
                if row["algorithm"] == algorithm
                and row["topology"] == topology
                and row["mean_convergence_us"] != ""
            ]
            rows.sort(key=lambda row: int(row["nodes"]))

            if rows:
                ax.plot(
                    [int(row["nodes"]) for row in rows],
                    [float(row["mean_convergence_us"]) for row in rows],
                    marker="o",
                    label=topology,
                )

        ax.set_title(
            f"{algorithm.title()}: Convergence Time vs. Network Size"
        )
        ax.set_xlabel("Number of nodes")
        ax.set_ylabel("Mean convergence time (microseconds)")
        ax.grid(True, alpha=0.3)
        if ax.lines:
            ax.legend(title="Topology")
        fig.tight_layout()
        fig.savefig(f"report/{algorithm}_convergence.png", dpi=180)
        plt.close(fig)


def plot_threshold_success(summary):
    fig, ax = plt.subplots()

    for topology in TOPOLOGIES:
        rows = [
            row for row in summary
            if row["topology"] == topology
        ]

        by_threshold = defaultdict(list)
        for row in rows:
            by_threshold[int(row["threshold"])].append(row)

        thresholds = sorted(by_threshold)
        rates = []

        for threshold in thresholds:
            trials = sum(
                int(row["trials"])
                for row in by_threshold[threshold]
            )
            successes = sum(
                int(row["successes"])
                for row in by_threshold[threshold]
            )
            rates.append(100 * successes / trials if trials else 0)

        if thresholds:
            ax.plot(
                thresholds, rates,
                marker="o", label=topology
            )

    ax.set_title("Gossip: Success Rate vs. Reception Threshold")
    ax.set_xlabel("Local reception threshold")
    ax.set_ylabel("Successful trials (%)")
    ax.set_ylim(0, 105)
    ax.grid(True, alpha=0.3)
    ax.legend(title="Topology")
    fig.tight_layout()
    fig.savefig("report/gossip_threshold_success_rate.png", dpi=180)
    plt.close(fig)


def plot_threshold_time(summary):
    fig, ax = plt.subplots()

    for topology in TOPOLOGIES:
        rows = [
            row for row in summary
            if row["topology"] == topology
            and row["mean_convergence_us"] != ""
        ]

        by_threshold = defaultdict(list)
        for row in rows:
            by_threshold[int(row["threshold"])].append(row)

        thresholds = sorted(by_threshold)
        means = []

        for threshold in thresholds:
            values = [
                float(row["mean_convergence_us"])
                for row in by_threshold[threshold]
                if row["mean_convergence_us"] != ""
            ]
            means.append(
                statistics.mean(values) if values else float("nan")
            )

        if thresholds:
            ax.plot(
                thresholds, means,
                marker="o", label=topology
            )

    ax.set_title("Gossip: Successful-Run Time vs. Reception Threshold")
    ax.set_xlabel("Local reception threshold")
    ax.set_ylabel("Mean convergence time (microseconds)")
    ax.grid(True, alpha=0.3)
    ax.legend(title="Topology")
    fig.tight_layout()
    fig.savefig("report/gossip_threshold_convergence.png", dpi=180)
    plt.close(fig)


def print_counts(label, rows):
    counts = defaultdict(int)
    for row in rows:
        counts[row["status"]] += 1

    print(f"\n{label}: {len(rows)} trials")
    for status, count in sorted(counts.items()):
        print(f"  {status}: {count}")


baseline_rows = read_csv(BASELINE_INPUT)
baseline_summary = summarize(baseline_rows)

write_summary(
    BASELINE_SUMMARY,
    [
        "algorithm", "topology", "nodes", "trials",
        "successes", "failures", "success_rate",
        "mean_convergence_us", "stdev_convergence_us",
    ],
    baseline_summary,
)

plot_baseline(baseline_summary)
print(f"Baseline summary saved to {BASELINE_SUMMARY}")

threshold_rows = read_csv(THRESHOLD_INPUT)
threshold_summary = summarize(
    threshold_rows, include_threshold=True
)

write_summary(
    THRESHOLD_SUMMARY,
    [
        "algorithm", "topology", "nodes", "threshold", "trials",
        "successes", "failures", "success_rate",
        "mean_convergence_us", "stdev_convergence_us",
    ],
    threshold_summary,
)

plot_threshold_success(threshold_summary)
plot_threshold_time(threshold_summary)

print(f"Threshold summary saved to {THRESHOLD_SUMMARY}")
print("Graphs saved in report/:")
print("  gossip_convergence.png")
print("  push-sum_convergence.png")
print("  gossip_threshold_success_rate.png")
print("  gossip_threshold_convergence.png")

print_counts("Baseline experiments", baseline_rows)
print_counts("Gossip threshold experiments", threshold_rows)

followup_path = "results/gossip_followup_observations.csv"
if os.path.exists(followup_path):
    followups = read_csv(followup_path)
    print(f"\nFollow-up observations recorded: {len(followups)}")
    print(f"See {followup_path}; these observations are kept separate "
          "from the randomized experiment totals.")
else:
    print(
        "\nFollow-up observations CSV not found; "
        "the main datasets were analyzed independently."
    )
