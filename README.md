# COP5612 Fall 2026 — Project 2: Gossip Simulator

## Team

- Pradhyuman Singh Shekhawat

## Project

This project implements asynchronous Gossip and Push-Sum algorithms using Erlang actors. The simulator supports the required network topologies:

- Full network
- 2D grid
- Line
- Imperfect 2D grid

The implementation follows the project specification and the instructor's guidance that topology construction, randomized neighbor selection, local convergence, and centralized collection of simulation statistics are key parts of the project.

## Current status

Initial project skeleton and topology module implemented. Gossip, Push-Sum, statistics collection, timing, experiments, and the final report are still in progress.

## Command-line interface

```text
project2 numNodes topology algorithm
```

Supported topology values:

```text
full
2D
line
imp2D
```

Supported algorithms:

```text
gossip
push-sum
```

For the 2D-based topologies, this implementation follows the instructor's clarification and assumes a perfect-square number of actors.

## Directory structure

```text
src/       Erlang implementation
test/      EUnit tests
results/   Experimental data
report/    Final Report.pdf
scripts/   Experiment/helper scripts
```

## Build

```bash
mkdir -p ebin
erlc -o ebin src/*.erl test/*.erl
```

## Tests

```bash
erl -noshell -pa ebin -eval 'eunit:test(topology_tests, [verbose]), halt().'
```

## Planned deliverables

- Working Gossip implementation
- Working Push-Sum implementation
- All four required topologies
- Actor-based statistics collection
- Convergence-time measurement
- Experimental results for both algorithms and all topologies
- README documenting what works and the largest network handled for each combination
- `Report.pdf` with convergence-time graphs and experimental observations
