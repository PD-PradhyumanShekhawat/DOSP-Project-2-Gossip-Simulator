#!/bin/bash
set -u

cd "$(dirname "$0")/.."
./scripts/build.sh || exit 1

mkdir -p results
CSV="results/experiment_results.csv"

echo "algorithm,topology,nodes,trial,status,convergence_us" > "$CSV"

SIZES=(4 9 16 25 36 49)
TRIALS=3
TIMEOUT_SECONDS=35

for topology in full line 2D imp2D; do
    for algorithm in gossip push-sum; do
        for nodes in "${SIZES[@]}"; do
            for trial in $(seq 1 "$TRIALS"); do
                echo "Running: $algorithm | $topology | $nodes nodes | trial $trial"

                case "$topology" in
                    full)  top_atom="full" ;;
                    line)  top_atom="line" ;;
                    2D)    top_atom="'2D'" ;;
                    imp2D) top_atom="imp2D" ;;
                esac

                case "$algorithm" in
                    gossip)   alg_atom="gossip" ;;
                    push-sum) alg_atom="'push-sum'" ;;
                esac

                output=$(perl -e 'alarm shift; exec @ARGV' \
                    "$TIMEOUT_SECONDS" \
                    erl -noshell -pa ebin -eval \
                    "io:format(\"EXPERIMENT_RESULT={~p,~p}~n\", [coordinator:run($nodes, $top_atom, $alg_atom), ok]), halt()." \
                    2>&1) || true

                duration=$(printf '%s\n' "$output" |
                    sed -n 's/.*EXPERIMENT_RESULT={{ok,\([0-9][0-9]*\)},ok}.*/\1/p' |
                    tail -n 1)

                if [ -n "$duration" ]; then
                    status="success"
                else
                    duration=""
                    status="failed"
                    printf '%s\n' "$output" | tail -n 4
                fi

                echo "$algorithm,$topology,$nodes,$trial,$status,$duration" >> "$CSV"
            done
        done
    done
done

echo ""
echo "Experiment run complete."
echo "Results saved to $CSV"
echo ""
echo "Status counts:"
awk -F, 'NR > 1 { count[$5]++ } END { for (s in count) print s ": " count[s] }' "$CSV"
