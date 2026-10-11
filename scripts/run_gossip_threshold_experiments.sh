#!/bin/bash
set -u

cd "$(dirname "$0")/.."
./scripts/build.sh || exit 1

mkdir -p results
CSV="results/gossip_threshold_experiments.csv"
TIMEOUT_SECONDS=35
THRESHOLDS=(10 20 50 100 500)
SIZES=(4 9 16 25 36 49)
TRIALS=3

echo "algorithm,topology,nodes,threshold,trial,status,convergence_us" > "$CSV"

for topology in full line 2D imp2D; do
    case "$topology" in
        full)  top_atom="full" ;;
        line)  top_atom="line" ;;
        2D)    top_atom="'2D'" ;;
        imp2D) top_atom="imp2D" ;;
    esac

    for threshold in "${THRESHOLDS[@]}"; do
        for nodes in "${SIZES[@]}"; do
            for trial in $(seq 1 "$TRIALS"); do
                echo "Gossip | $topology | $nodes nodes | threshold=$threshold | trial=$trial"

                output=$(perl -e 'alarm shift; exec @ARGV' \
                    "$TIMEOUT_SECONDS" \
                    erl -noshell -pa ebin -eval \
                    "io:format(\"EXPERIMENT_RESULT=~p~n\", [coordinator:run($nodes, $top_atom, gossip, $threshold)]), halt()." \
                    2>&1) || true

                duration=$(printf '%s\n' "$output" |
                    sed -n 's/.*EXPERIMENT_RESULT={ok,\([0-9][0-9]*\)}.*/\1/p' |
                    tail -n 1)

                if [ -n "$duration" ]; then
                    status="success"
                else
                    duration=""
                    status="failed"
                    printf '%s\n' "$output" | tail -n 4
                fi

                echo "gossip,$topology,$nodes,$threshold,$trial,$status,$duration" >> "$CSV"
            done
        done
    done
done

echo ""
echo "Threshold experiments complete."
echo "Results saved to $CSV"

awk -F, 'NR > 1 { count[$6]++ } END {
    for (s in count) print s ": " count[s]
}' "$CSV"
