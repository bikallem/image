#!/bin/bash
# bench.sh - Run MoonBit and Go benchmarks, display side-by-side table
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Map: "pkg/bench_name" -> Go function name
declare -A MB_TO_GO=(
  # Color
  [color/ycbcr_to_rgb/0]=YCbCrToRGB_0
  [color/ycbcr_to_rgb/128]=YCbCrToRGB_128
  [color/ycbcr_to_rgb/255]=YCbCrToRGB_255
  [color/rgb_to_ycbcr/0]=RGBToYCbCr_0
  [color/ycbcr_to_rgba/128]=YCbCrToRGBA_128
  [color/nycbcra_to_rgba/128]=NYCbCrAToRGBA_128
  # Image
  [image/at/rgba]=RGBAAt
  [image/set/rgba]=RGBASetRGBA
  [image/at/gray]=GrayAt
  [image/set/gray]=GraySetGray
  # Draw
  [draw/fill_src]=DrawFillSrc
  [draw/copy_src]=DrawCopySrc
  [draw/copy_over]=DrawCopyOver
  # PNG
  [png/decode_gray]=PNGDecodeGray
  [png/decode_rgb]=PNGDecodeRGB
  [png/encode_gray]=PNGEncodeGray
  [png/encode_rgb_opaque]=PNGEncodeRGBA
  # JPEG
  [jpeg/decode_baseline]=JPEGDecode
  [jpeg/encode_rgba]=JPEGEncodeRGBA
  # GIF
  [gif/decode]=GIFDecode
  [gif/encode_paletted]=GIFEncode
)

# Category display order
CATEGORIES=(color image draw png jpeg gif)

# Parse MoonBit mean time in µs
parse_mb_us() {
  local val unit
  val=$(echo "$1" | awk '{print $2}')
  unit=$(echo "$1" | awk '{print $3}')
  case "$unit" in
    µs) echo "$val" ;;
    ms) echo "$val * 1000" | bc ;;
    s)  echo "$val * 1000000" | bc ;;
    *)  echo "$val" ;;
  esac
}

# Parse Go ns/op -> µs
parse_go_us() {
  local ns
  ns=$(echo "$1" | awk '{for(i=1;i<=NF;i++) if($(i+1)=="ns/op") print $i}')
  [ -n "$ns" ] && echo "scale=2; $ns / 1000" | bc
}

# Format µs for display
fmt() {
  local us="$1"
  [ -z "$us" ] || [ "$us" = "0" ] && { echo "-"; return; }
  if [ "$(echo "$us < 1" | bc)" = "1" ]; then
    printf "%.0f ns" "$(echo "$us * 1000" | bc)"
  elif [ "$(echo "$us >= 1000" | bc)" = "1" ]; then
    printf "%.2f ms" "$(echo "scale=4; $us / 1000" | bc)"
  else
    printf "%.2f µs" "$us"
  fi
}

ratio() {
  local mb="$1" go="$2"
  [ -z "$mb" ] || [ -z "$go" ] || [ "$go" = "0" ] && { echo "-"; return; }
  printf "%.1fx" "$(echo "scale=1; $mb / $go" | bc)"
}

# --- Collect MoonBit results ---
declare -A MB_RESULTS
echo "Running MoonBit benchmarks..." >&2
mb_output=$(cd "$PROJECT_DIR" && moon bench --target native 2>&1)

current_pkg=""
while IFS= read -r line; do
  # Track current package from "[blem/image] bench <pkg>/..." lines
  if [[ "$line" =~ \[bikallem/image\]\ bench\ ([a-z]+)/ ]]; then
    current_pkg="${BASH_REMATCH[1]}"
    continue
  fi
  # Skip non-data lines
  [[ "$line" =~ ^(name|Total|\[) ]] && continue
  [[ "$line" =~ (µs|ms)\ *± ]] || continue
  name=$(echo "$line" | awk '{print $1}')
  us=$(parse_mb_us "$line")
  [ -n "$name" ] && [ -n "$us" ] && [ -n "$current_pkg" ] && \
    MB_RESULTS["$current_pkg/$name"]="$us"
done <<< "$mb_output"

# --- Collect Go results ---
declare -A GO_RESULTS
if command -v go &>/dev/null; then
  echo "Running Go benchmarks..." >&2
  go_output=$(cd "$SCRIPT_DIR" && go test -bench=. -count=1 -timeout 600s 2>&1) || true
  while IFS= read -r line; do
    fname=$(echo "$line" | awk '{print $1}' | sed 's/^Benchmark//; s/-[0-9]*$//')
    us=$(parse_go_us "$line")
    [ -n "$fname" ] && [ -n "$us" ] && GO_RESULTS["$fname"]="$us"
  done < <(echo "$go_output" | grep "ns/op")
else
  echo "(go not found — showing MoonBit-only results)" >&2
fi

# --- Print table ---
W_NAME=28; W_MB=12; W_GO=12; W_R=7
sep="$(printf '+%*s+%*s+%*s+%*s+' $((W_NAME+2)) '' $((W_MB+2)) '' $((W_GO+2)) '' $((W_R+2)) '' | tr ' ' '-')"

printf "\n%s\n" "$sep"
printf "| %-${W_NAME}s | %${W_MB}s | %${W_GO}s | %${W_R}s |\n" "Benchmark" "MoonBit" "Go" "Ratio"
printf "%s\n" "$sep"

for cat in "${CATEGORIES[@]}"; do
  printed_header=false
  # Gather and sort keys for this category
  keys=()
  for key in "${!MB_RESULTS[@]}"; do
    [[ "$key" == "$cat/"* ]] && keys+=("$key")
  done
  [ ${#keys[@]} -eq 0 ] && continue
  IFS=$'\n' sorted=($(sort <<< "${keys[*]}")); unset IFS

  for key in "${sorted[@]}"; do
    if ! $printed_header; then
      printf "| %-${W_NAME}s | %${W_MB}s | %${W_GO}s | %${W_R}s |\n" \
        "$(echo "$cat" | tr a-z A-Z)" "" "" ""
      printed_header=true
    fi
    short="${key#$cat/}"
    mb_us="${MB_RESULTS[$key]}"
    go_name="${MB_TO_GO[$key]:-}"
    go_us=""
    [ -n "$go_name" ] && go_us="${GO_RESULTS[$go_name]:-}"

    printf "| %-${W_NAME}s | %${W_MB}s | %${W_GO}s | %${W_R}s |\n" \
      "  $short" "$(fmt "$mb_us")" "$(fmt "$go_us")" "$(ratio "$mb_us" "$go_us")"
  done
  printf "%s\n" "$sep"
done

echo ""
echo "Ratio = MoonBit / Go (lower is better for MoonBit)"
