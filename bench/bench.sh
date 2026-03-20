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
  [color/rgb_to_ycbcr/Cb]=RGBToYCbCr_Cb
  [color/rgb_to_ycbcr/Cr]=RGBToYCbCr_Cr
  [color/ycbcr_to_rgba/0]=YCbCrToRGBA_0
  [color/ycbcr_to_rgba/128]=YCbCrToRGBA_128
  [color/ycbcr_to_rgba/255]=YCbCrToRGBA_255
  [color/nycbcra_to_rgba/0]=NYCbCrAToRGBA_0
  [color/nycbcra_to_rgba/128]=NYCbCrAToRGBA_128
  [color/nycbcra_to_rgba/255]=NYCbCrAToRGBA_255
  # Image
  [image/at/rgba]=RGBAAt
  [image/set/rgba]=RGBASetRGBA
  [image/at/rgba64]=RGBA64At
  [image/set/rgba64]=RGBA64SetRGBA64
  [image/at/nrgba]=NRGBAAt
  [image/set/nrgba]=NRGBASetNRGBA
  [image/at/nrgba64]=NRGBA64At
  [image/set/nrgba64]=NRGBA64SetNRGBA64
  [image/at/alpha]=AlphaAt
  [image/set/alpha]=AlphaSetAlpha
  [image/at/alpha16]=Alpha16At
  [image/set/alpha16]=Alpha16SetAlpha16
  [image/at/gray]=GrayAt
  [image/set/gray]=GraySetGray
  [image/at/gray16]=Gray16At
  [image/set/gray16]=Gray16SetGray16
  # Draw
  [draw/fill_over]=DrawFillOver
  [draw/fill_src]=DrawFillSrc
  [draw/copy_over]=DrawCopyOver
  [draw/copy_src]=DrawCopySrc
  [draw/nrgba_over]=DrawNRGBAOver
  [draw/nrgba_src]=DrawNRGBASrc
  [draw/ycbcr]=DrawYCbCr
  [draw/gray]=DrawGray
  [draw/glyph_over]=DrawGlyphOver
  [draw/generic_over]=DrawGenericOver
  [draw/generic_src]=DrawGenericSrc
  [draw/paletted_fill]=DrawPalettedFill
  [draw/paletted_rgba]=DrawPalettedRGBA
  # PNG
  [png/paeth]=PNGPaeth
  [png/decode_gray]=PNGDecodeGray
  [png/decode_nrgba_gradient]=PNGDecodeNRGBAGradient
  [png/decode_nrgba_opaque]=PNGDecodeNRGBAOpaque
  [png/decode_paletted]=PNGDecodePaletted
  [png/decode_rgb]=PNGDecodeRGB
  [png/encode_gray]=PNGEncodeGray
  [png/encode_nrgba]=PNGEncodeNRGBA
  [png/encode_paletted]=PNGEncodePaletted
  [png/encode_rgb_opaque]=PNGEncodeRGBA
  # JPEG
  # fdct/idct have no direct Go equivalent (Go doesn't export DCT functions)
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
  [ -n "$ns" ] && echo "scale=6; $ns / 1000" | bc
}

# Format µs for display
fmt() {
  local us="$1"
  [ -z "$us" ] && { echo "-"; return; }
  # bc may output ".001" without leading zero; normalize
  us=$(echo "$us" | sed 's/^\./0./')
  [ "$us" = "0" ] || [ "$us" = "0.000000" ] && { echo "-"; return; }
  if [ "$(echo "$us < 0.001" | bc)" = "1" ]; then
    printf "%.2f ns" "$(echo "scale=4; $us * 1000" | bc | sed 's/^\./0./')"
  elif [ "$(echo "$us < 1" | bc)" = "1" ]; then
    printf "%.0f ns" "$(echo "$us * 1000" | bc | sed 's/^\./0./')"
  elif [ "$(echo "$us >= 1000" | bc)" = "1" ]; then
    printf "%.2f ms" "$(echo "scale=4; $us / 1000" | bc | sed 's/^\./0./')"
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
# Right-align a string to exactly W visible characters.
# Compensates for multi-byte µ (2 bytes but 1 display column).
ralign() {
  local w="$1" s="$2"
  # Count how many µ characters (each is 2 bytes but 1 column)
  local n_mu
  n_mu=$(echo -n "$s" | grep -o 'µ' | wc -l)
  local pad=$((w + n_mu))
  printf "%${pad}s" "$s"
}

lalign() {
  local w="$1" s="$2"
  local n_mu
  n_mu=$(echo -n "$s" | grep -o 'µ' | wc -l)
  local pad=$((w + n_mu))
  printf "%-${pad}s" "$s"
}

W_NAME=28; W_MB=12; W_GO=12; W_R=7
sep="+$(printf '%*s' $((W_NAME+2)) '' | tr ' ' '-')+$(printf '%*s' $((W_MB+2)) '' | tr ' ' '-')+$(printf '%*s' $((W_GO+2)) '' | tr ' ' '-')+$(printf '%*s' $((W_R+2)) '' | tr ' ' '-')+"

print_row() {
  local name="$1" mb="$2" go="$3" ratio="$4"
  printf "| %s | %s | %s | %s |\n" \
    "$(lalign $W_NAME "$name")" \
    "$(ralign $W_MB "$mb")" \
    "$(ralign $W_GO "$go")" \
    "$(ralign $W_R "$ratio")"
}

printf "\n%s\n" "$sep"
print_row "Benchmark" "MoonBit" "Go" "Ratio"
printf "%s\n" "$sep"

for cat in "${CATEGORIES[@]}"; do
  printed_header=false
  keys=()
  for key in "${!MB_RESULTS[@]}"; do
    [[ "$key" == "$cat/"* ]] && keys+=("$key")
  done
  [ ${#keys[@]} -eq 0 ] && continue
  IFS=$'\n' sorted=($(sort <<< "${keys[*]}")); unset IFS

  for key in "${sorted[@]}"; do
    if ! $printed_header; then
      print_row "$(echo "$cat" | tr a-z A-Z)" "" "" ""
      printed_header=true
    fi
    short="${key#$cat/}"
    mb_us="${MB_RESULTS[$key]}"
    go_name="${MB_TO_GO[$key]:-}"
    go_us=""
    [ -n "$go_name" ] && go_us="${GO_RESULTS[$go_name]:-}"

    print_row "  $short" "$(fmt "$mb_us")" "$(fmt "$go_us")" "$(ratio "$mb_us" "$go_us")"
  done
  printf "%s\n" "$sep"
done

echo ""
echo "Ratio = MoonBit / Go (lower is better for MoonBit)"
