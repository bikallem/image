# bikallem/image

`bikallem/image` is a MoonBit port of Go's `image`, `image/color`, `image/draw`, `image/png`, `image/jpeg`, and `image/gif` packages.

The module provides core image types, color models, drawing operations, and PNG/JPEG/GIF codecs, with parity work and tests tracked against vendored Go sources in [`vendor/go`](./vendor/go).

## Packages

Import the package you need directly:

- `bikallem/image/image`: core image types, geometry, image constructors, and the format registry
- `bikallem/image/color`: color types, models, conversions, and palettes
- `bikallem/image/draw`: compositing and Floyd-Steinberg drawing
- `bikallem/image/png`: PNG encode/decode
- `bikallem/image/jpeg`: JPEG encode/decode
- `bikallem/image/gif`: GIF encode/decode, animation support, and quantized encode options

Internal packages under `internal/` are implementation details and are not intended as public API.

## Install

Add the module to a MoonBit project:

```bash
moon add bikallem/image
```

## Quick Start

Codec-specific entry points are the simplest API:

```moonbit
import {
  "bikallem/image/image",
  "bikallem/image/color",
  "bikallem/image/png",
}

fn png_roundtrip() -> Unit raise {
  let img = @image.new_image_rgba(@image.rect(0, 0, 2, 2))
  img.set_rgba(0, 0, { r: b'\xff', g: b'\x00', b: b'\x00', a: b'\xff' })
  img.set_rgba(1, 0, { r: b'\x00', g: b'\xff', b: b'\x00', a: b'\xff' })
  img.set_rgba(0, 1, { r: b'\x00', g: b'\x00', b: b'\xff', a: b'\xff' })
  img.set_rgba(1, 1, { r: b'\xff', g: b'\xff', b: b'\xff', a: b'\xff' })

  let encoded = @png.encode(@image.AnyImage::RGBA(img))
  let decoded = @png.decode(encoded)
  let (r, g, b, a) = decoded.at(0, 0).rgba()
  ignore((r, g, b, a))
}
```

The `image` package also exposes a registry-based format sniffer:

```moonbit
import {
  "bikallem/image/image",
  "bikallem/image/png",
}

fn register_png() -> Unit {
  @image.register_format(
    "png",
    "\x89PNG\r\n\x1a\n",
    @png.decode,
    @png.decode_config,
  )
}
```

That registry is explicit. If you do not register formats yourself, call `@png.decode`, `@jpeg.decode`, or `@gif.decode` directly.

## Highlights

- Go-shaped image model with `RGBA`, `NRGBA`, `Gray`, `Paletted`, `YCbCr`, `CMYK`, and 16-bit variants
- PNG encode/decode with palette, transparency, interlace, and 16-bit support
- JPEG encode/decode with quality control and progressive decode support
- GIF decode for animated images plus generic encode with configurable color count, quantizer, and drawer
- Cross-codec parity tests and benchmarks against vendored Go implementations

## Scope

This repository ports codec behavior, image types, and package-level functionality. It does not aim to port Go's `io.Reader` / `io.Writer` APIs or generic streaming I/O surface.

The public codec APIs are intentionally `Bytes`-based:

- decoders take `Bytes`
- encoders return `Bytes`
- generic format registration in `image` is explicit rather than relying on Go-style package init behavior

Future parity work should treat I/O-surface differences as intentional unless the project scope changes.

## Development

Useful commands from the repository root:

```bash
moon test
moon check
moon fmt
moon info
make test
make bench
make parity
make callgrind
```

`make parity` runs the MoonBit parity harness and the cross-codec Go roundtrip checks in `bench/`.

## Repository Layout

- [`image`](./image): core image types and format registry
- [`color`](./color): color models and palettes
- [`draw`](./draw): compositing and Floyd-Steinberg drawing
- [`png`](./png): PNG codec
- [`jpeg`](./jpeg): JPEG codec
- [`gif`](./gif): GIF codec
- [`bench`](./bench): Go-side parity and benchmark helpers
- [`profile`](./profile): native profiling harness

## Status

Current module version: `0.1.0`

The current work has focused on bringing codec behavior and malformed-input handling in line with vendored Go sources while keeping MoonBit-native APIs for package boundaries and explicit registration.
