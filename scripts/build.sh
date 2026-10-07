#!/usr/bin/env bash
set -euo pipefail
mkdir -p ebin
erlc -o ebin src/*.erl test/*.erl
