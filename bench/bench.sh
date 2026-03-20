#!/bin/bash
# compare.sh - Run MoonBit and Go benchmarks side-by-side
set -e

echo "=== MoonBit Benchmarks ==="
cd "$(dirname "$0")/.."
moon bench --target native 2>&1 | grep -E "^name|µs|ms" || true
echo ""

echo "=== Go Benchmarks ==="
cd "$(dirname "$0")"
go test -bench=. -benchmem -count=1 -timeout 300s 2>&1 | grep -E "^Benchmark|ns/op" || true
echo ""

echo "=== Summary ==="
echo "Run 'moon bench --target native' for detailed MoonBit results"
echo "Run 'cd testperf && go test -bench=. -benchmem -count=5' for detailed Go results"
