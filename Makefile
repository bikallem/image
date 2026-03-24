.PHONY: test bench parity callgrind clean fmt check

# Run all tests
test:
	moon test --target native

# Run benchmarks (MoonBit vs Go side-by-side)
bench:
	bash bench/bench.sh

# Run parity tests — compares MoonBit pixel output against known Go values.
# Exits non-zero if any codec produces different pixels than Go.
parity:
	@moon build --target native --release 2>&1 | tail -1
	@./_build/native/release/build/profile/profile.exe | tee /tmp/parity.out
	@grep -q "^PASS" /tmp/parity.out || (echo ""; echo "^^^ PARITY FAILED ^^^"; exit 1)

# Run callgrind profiling
callgrind:
	@moon build --target native --release 2>&1 | tail -1
	valgrind --tool=callgrind --callgrind-out-file=/tmp/callgrind.out \
		./_build/native/release/build/profile/profile.exe 2>&1 | tail -3
	@echo ""
	@callgrind_annotate /tmp/callgrind.out 2>&1 | grep -E "^\s*[0-9,]+ \(" | head -20

# Format code
fmt:
	moon fmt

# Type check
check:
	moon check --target native

# Clean build artifacts
clean:
	moon clean
