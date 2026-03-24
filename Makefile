.PHONY: test bench parity callgrind clean fmt check

# Run all tests
test:
	moon test --target native

# Run benchmarks (MoonBit vs Go side-by-side)
bench:
	bash bench/bench.sh

# Run parity tests (compare MoonBit vs Go pixel output)
parity: parity-moonbit parity-go
	@echo ""
	@echo "=== Compare output above: MoonBit vs Go pixel values should match ==="

parity-moonbit:
	@echo "=== MoonBit ==="
	moon build --target native --release 2>&1 | tail -1
	./_build/native/release/build/profile/profile.exe

parity-go:
	@echo "=== Go ==="
	cd bench && go test -run TestParity -v 2>&1 | grep -v "^=== RUN\|^--- PASS\|^PASS\|^ok"

# Run callgrind profiling
callgrind:
	moon build --target native --release 2>&1 | tail -1
	valgrind --tool=callgrind --callgrind-out-file=/tmp/callgrind.out \
		./_build/native/release/build/profile/profile.exe 2>&1 | tail -3
	@echo ""
	callgrind_annotate /tmp/callgrind.out 2>&1 | grep -E "^\s*[0-9,]+ \(" | head -20

# Format code
fmt:
	moon fmt

# Type check
check:
	moon check --target native

# Clean build artifacts
clean:
	moon clean
