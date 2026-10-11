# COP5615 Fall 2026 — Project 2: Gossip Simulator

This project implements asynchronous Gossip and Push-Sum algorithms in Erlang using the Actor Model. It simulates information propagation and distributed aggregation across four network topologies.

## Author

- **Pradhyuman Singh Shekhawat**
  - UFID: 55742970
  - Email: pr.shekhawat@ufl.edu

## Project Overview

The simulator models a network of independent Erlang actors that communicate through asynchronous messages. It supports two algorithms:

- **Gossip:** An actor forwards a rumor to a randomly selected neighbor until its local reception threshold is reached.
- **Push-Sum:** Actors exchange portions of their sum and weight values to estimate the global average.

The network topology determines which actors can communicate directly. The simulator records convergence outcomes and elapsed time for different network sizes, algorithms, and topologies.

## Actor Model and Communication

Each simulated node runs as an independent Erlang process. Actors exchange messages rather than sharing mutable state.

The coordinator constructs the topology, starts the actors, initiates the selected algorithm, and collects the final outcome. A statistics process records actor updates and convergence information.

For Gossip, an actor forwards the rumor to a randomly selected neighbor while it remains active. The default reception threshold is 10, and the implementation also supports experiments with higher thresholds.

For Push-Sum, each actor maintains values \(s\) and \(w\). Initially, actor \(i\) has \(s=i\) and \(w=1\). When communicating, an actor sends half of its current \(s\) and \(w\) values to a randomly selected neighbor. Its estimate is the ratio \(s/w\). The implementation checks for three consecutive stable rounds using a tolerance of \(10^{-10}\).

## Project Structure


```text
project2/
├── README.md
├── src/
│   ├── actor.erl
│   ├── coordinator.erl
│   ├── project2.erl
│   ├── statistics.erl
│   └── topology.erl
├── test/
│   ├── actor_tests.erl
│   ├── gossip_tests.erl
│   └── topology_tests.erl
├── scripts/
│   ├── analyze_results.py
│   ├── build.sh
│   ├── create_report.py
│   ├── run_experiments.sh
│   └── run_gossip_threshold_experiments.sh
├── results/
│   ├── experiment_results.csv
│   ├── experiment_summary.csv
│   ├── gossip_followup_observations.csv
│   ├── gossip_threshold_experiments.csv
│   └── gossip_threshold_summary.csv
└── report/
    ├── project2_report.pdf
    ├── project2_report.tex
    ├── gossip_convergence.png
    ├── push-sum_convergence.png
    ├── gossip_threshold_success_rate.png
    ├── gossip_threshold_convergence.png
    └── uf_horizontal_logo_cropped.png
```

### Source Files

| Filename | Description |
|---|---|
| `src/project2.erl` | Command-line entry point for the simulator. |
| `src/actor.erl` | Implements Gossip and Push-Sum actor behavior. |
| `src/coordinator.erl` | Builds the simulation, starts actors, initiates the algorithm, and manages convergence. |
| `src/topology.erl` | Constructs the supported network topologies. |
| `src/statistics.erl` | Collects actor updates, convergence information, and timing statistics. |
| `test/topology_tests.erl` | Tests topology construction and invalid grid sizes. |
| `test/actor_tests.erl` | Tests actor registration. |
| `test/gossip_tests.erl` | Tests invalid simulator inputs. |
| `scripts/run_experiments.sh` | Runs the baseline experiment configurations. |
| `scripts/run_gossip_threshold_experiments.sh` | Runs Gossip experiments with different local reception thresholds. |
| `scripts/analyze_results.py` | Summarizes experiment data and generates graphs. |
| `scripts/build.sh` | Compiles the Erlang source and test files. |
| `scripts/create_report.py` | Report-generation helper, if retained in the final submission. |
| `results/experiment_results.csv` | Raw baseline experiment results. |
| `results/experiment_summary.csv` | Aggregated baseline results. |
| `results/gossip_threshold_experiments.csv` | Raw Gossip threshold experiment results. |
| `results/gossip_threshold_summary.csv` | Aggregated threshold experiment results. |
| `results/gossip_followup_observations.csv` | Additional observations from selected large-line-network runs. |
| `report/project2_report.pdf` | Experimental report with graphs and findings. |
| `report/project2_report.tex` | LaTeX source for the report. |

## Steps to Execute

### Build

Run the build script from the project root:

```bash
bash scripts/build.sh
```

Alternatively, compile the source and tests directly:

```bash
mkdir -p ebin
erlc -o ebin src/*.erl test/*.erl
```

### Command-Line Usage

The simulator accepts three arguments:

```text
project2 numNodes topology algorithm
```

The corresponding Erlang entry point is:

```erlang
project2:main(["numNodes", "topology", "algorithm"]).
```

**Supported topologies:**

```text
full
line
2D
imp2D
```

**Supported algorithms:**

```text
gossip
push-sum
```

For the grid-based topologies, the experiments use perfect-square network sizes.

### Example Executions

Run Gossip on a full network of four actors:

```bash
erl -noshell -pa ebin -eval \
'io:format("~n"), project2:main(["4", "full", "gossip"]), halt().'
```

Run Push-Sum on a line network of nine actors:

```bash
erl -noshell -pa ebin -eval \
'io:format("~n"), project2:main(["9", "line", "push-sum"]), halt().'
```

The simulator reports convergence information and elapsed execution time. Gossip may fail to converge within the configured timeout for some topologies and network sizes.

## Network Topologies

| Topology | Description |
|---|---|
| Full | Every actor can communicate directly with every other actor. |
| Line | Actors form a linear chain and communicate with adjacent actors. |
| 2D Grid | Actors are arranged in a square grid and communicate with grid neighbors. |
| Imperfect 2D Grid | A square grid with an additional randomly selected neighbor connection. |

## Testing & Experiments

### Unit Tests

Run the complete EUnit test suite:

```bash
erl -noshell -pa ebin -eval \
'case eunit:test([topology_tests, actor_tests, gossip_tests], [verbose]) of ok -> halt(0); _ -> halt(1) end.'
```

The final validation run completed with **all 10 tests passing**.

### Baseline Experiments

Run the baseline experiment script:

```bash
bash scripts/run_experiments.sh
```

The baseline dataset contains 144 trials covering two algorithms, four topologies, six network sizes, and three trials per configuration.

### Gossip Threshold Experiments

Run the additional threshold experiment:

```bash
bash scripts/run_gossip_threshold_experiments.sh
```

This experiment evaluates five reception thresholds: 10, 20, 50, 100, and 500, across four topologies, six network sizes, and three trials per configuration.

### Analyze Results

Generate summary tables and graphs:

```bash
python3 scripts/analyze_results.py
```

The analysis produces convergence-time graphs and threshold-experiment graphs in the `report/` directory.

## Experimental Results

### Baseline Results

The baseline experiments tested network sizes of 4, 9, 16, 25, 36, and 49 actors.

| Algorithm | Topology | Successful trials | Failed trials | Success rate |
|---|---|---:|---:|---:|
| Gossip | Full | 16/18 | 2 | 88.9% |
| Gossip | Line | 7/18 | 11 | 38.9% |
| Gossip | 2D | 7/18 | 11 | 38.9% |
| Gossip | Imperfect 2D | 9/18 | 9 | 50.0% |
| Push-Sum | Full | 18/18 | 0 | 100.0% |
| Push-Sum | Line | 18/18 | 0 | 100.0% |
| Push-Sum | 2D | 18/18 | 0 | 100.0% |
| Push-Sum | Imperfect 2D | 18/18 | 0 | 100.0% |

### Largest Successfully Tested Network

The following table reports the largest network size with at least one successful baseline trial for each topology and algorithm.

| Topology | Gossip | Push-Sum |
|---|---:|---:|
| Full | 49 actors | 49 actors |
| Line | 16 actors | 49 actors |
| 2D | 25 actors | 49 actors |
| Imperfect 2D | 25 actors | 49 actors |

These values indicate the largest successful configuration observed in the tested dataset; they do not guarantee that every trial at that size will converge.

### Gossip Reception Threshold

Across 360 threshold-experiment trials, the observed aggregate success rate increased with the reception threshold.

| Reception threshold | Successful trials | Failed trials | Success rate |
|---:|---:|---:|---:|
| 10 | 34 | 38 | 47.2% |
| 20 | 56 | 16 | 77.8% |
| 50 | 64 | 8 | 88.9% |
| 100 | 69 | 3 | 95.8% |
| 500 | 71 | 1 | 98.6% |

The results suggest that the local reception threshold has a substantial effect on Gossip convergence under the tested conditions. The report discusses topology effects, convergence time, experimental limitations, and the variability caused by randomized execution.

## Report

The project report is available at:

```text
report/project2_report.pdf
```

It includes the experimental methodology, baseline results, convergence-time graphs, threshold analysis, discussion, and limitations.

## What Is Working

- Asynchronous Gossip and Push-Sum algorithms.
- Full, line, 2D grid, and imperfect 2D grid topologies.
- Actor registration and centralized statistics collection.
- Convergence timing and timeout handling.
- Baseline and Gossip threshold experiments.
- Result summaries and graph generation.
- Parameter-controlled permanent connection failures, with failed connections removed from both endpoints.
- Network connectivity checks before running algorithms on the modified topology.
- Bonus experiments across 240 trials, covering two topologies, two algorithms, and six failure probabilities.
- EUnit validation, with all 14 tests passing in the final validation run.

## Bonus: Permanent Connection-Failure Model

Implemented a parameter-controlled permanent connection-failure model. Each undirected connection independently fails with probability `p`. Failed connections are removed from both endpoints, and network connectivity is checked before running Gossip or Push-Sum.

The bonus experiments evaluate the `full` and `2D` topologies using 240 trials across six failure probabilities. Results, observations, and plots are documented in `Report-bonus.pdf`.