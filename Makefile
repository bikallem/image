.PHONY: test bench parity callgrind clean fmt check

# Run all tests
test:
	moon test --target native

# Run benchmarks (MoonBit vs Go side-by-side)
bench:
	bash bench/bench.sh

# Run parity tests with cross-codec roundtrip:
#   1. MoonBit decodes Go test images, checks pixel values
#   2. MoonBit encodes → writes roundtrip_moonbit.{png,jpeg,gif}
#   3. Go decodes MoonBit files (TestCrossCodecRoundtrip)
#   4. Go encodes → writes roundtrip_go.{png,jpeg,gif}
#   5. MoonBit decodes Go files
parity:
	@moon build --target native --release 2>&1 | tail -1
	@echo "=== Step 1: MoonBit parity + write roundtrip files ==="
	@./_build/native/release/build/profile/profile.exe | tee /tmp/parity.out
	@grep -q "^PASS" /tmp/parity.out || (echo "^^^ MOONBIT PARITY FAILED ^^^"; exit 1)
	@echo ""
	@echo "=== Step 2: Go cross-codec roundtrip ==="
	@cd bench && go test -run TestCrossCodecRoundtrip -v 2>&1 | grep -v "^=== RUN"
	@echo ""
	@echo "=== Step 3: MoonBit reads Go-encoded files ==="
	@./_build/native/release/build/profile/profile.exe | tee /tmp/parity2.out
	@grep -q "^PASS" /tmp/parity2.out || (echo "^^^ ROUNDTRIP FAILED ^^^"; exit 1)

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
