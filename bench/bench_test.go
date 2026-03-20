package testperf

import (
	"image"
	"image/color"
	"image/draw"
	"image/gif"
	"image/jpeg"
	"image/png"
	"math/rand"
	"os"
	"testing"
)

// --- Color Benchmarks ---

var sink8 uint8
var sink32 uint32

func BenchmarkYCbCrToRGB_0(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sink8, sink8, sink8 = color.YCbCrToRGB(0, 0, 0)
	}
}

func BenchmarkYCbCrToRGB_128(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sink8, sink8, sink8 = color.YCbCrToRGB(128, 128, 128)
	}
}

func BenchmarkYCbCrToRGB_255(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sink8, sink8, sink8 = color.YCbCrToRGB(255, 255, 255)
	}
}

func BenchmarkRGBToYCbCr_0(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sink8, sink8, sink8 = color.RGBToYCbCr(0, 0, 0)
	}
}

func BenchmarkRGBToYCbCr_Cb(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sink8, sink8, sink8 = color.RGBToYCbCr(0, 0, 255)
	}
}

func BenchmarkRGBToYCbCr_Cr(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sink8, sink8, sink8 = color.RGBToYCbCr(255, 0, 0)
	}
}

func BenchmarkYCbCrToRGBA_0(b *testing.B) {
	c := color.YCbCr{0, 0, 0}
	for i := 0; i < b.N; i++ {
		sink32, sink32, sink32, sink32 = c.RGBA()
	}
}

func BenchmarkYCbCrToRGBA_128(b *testing.B) {
	c := color.YCbCr{128, 128, 128}
	for i := 0; i < b.N; i++ {
		sink32, sink32, sink32, sink32 = c.RGBA()
	}
}

func BenchmarkYCbCrToRGBA_255(b *testing.B) {
	c := color.YCbCr{255, 255, 255}
	for i := 0; i < b.N; i++ {
		sink32, sink32, sink32, sink32 = c.RGBA()
	}
}

func BenchmarkNYCbCrAToRGBA_0(b *testing.B) {
	c := color.NYCbCrA{color.YCbCr{0, 0, 0}, 0xff}
	for i := 0; i < b.N; i++ {
		sink32, sink32, sink32, sink32 = c.RGBA()
	}
}

func BenchmarkNYCbCrAToRGBA_128(b *testing.B) {
	c := color.NYCbCrA{color.YCbCr{128, 128, 128}, 0xff}
	for i := 0; i < b.N; i++ {
		sink32, sink32, sink32, sink32 = c.RGBA()
	}
}

func BenchmarkNYCbCrAToRGBA_255(b *testing.B) {
	c := color.NYCbCrA{color.YCbCr{255, 255, 255}, 0xff}
	for i := 0; i < b.N; i++ {
		sink32, sink32, sink32, sink32 = c.RGBA()
	}
}

// --- Image Benchmarks ---

func BenchmarkRGBAAt(b *testing.B) {
	m := image.NewRGBA(image.Rect(0, 0, 10, 10))
	for i := 0; i < b.N; i++ {
		m.RGBAAt(4, 5)
	}
}

func BenchmarkRGBASetRGBA(b *testing.B) {
	m := image.NewRGBA(image.Rect(0, 0, 10, 10))
	c := color.RGBA{0xff, 0xff, 0xff, 0x13}
	for i := 0; i < b.N; i++ {
		m.SetRGBA(4, 5, c)
	}
}

func BenchmarkRGBA64At(b *testing.B) {
	m := image.NewRGBA64(image.Rect(0, 0, 10, 10))
	for i := 0; i < b.N; i++ {
		m.RGBA64At(4, 5)
	}
}

func BenchmarkRGBA64SetRGBA64(b *testing.B) {
	m := image.NewRGBA64(image.Rect(0, 0, 10, 10))
	c := color.RGBA64{0xffff, 0xffff, 0xffff, 0x1357}
	for i := 0; i < b.N; i++ {
		m.SetRGBA64(4, 5, c)
	}
}

func BenchmarkNRGBAAt(b *testing.B) {
	m := image.NewNRGBA(image.Rect(0, 0, 10, 10))
	for i := 0; i < b.N; i++ {
		m.NRGBAAt(4, 5)
	}
}

func BenchmarkNRGBASetNRGBA(b *testing.B) {
	m := image.NewNRGBA(image.Rect(0, 0, 10, 10))
	c := color.NRGBA{0xff, 0xff, 0xff, 0x13}
	for i := 0; i < b.N; i++ {
		m.SetNRGBA(4, 5, c)
	}
}

func BenchmarkNRGBA64At(b *testing.B) {
	m := image.NewNRGBA64(image.Rect(0, 0, 10, 10))
	for i := 0; i < b.N; i++ {
		m.NRGBA64At(4, 5)
	}
}

func BenchmarkNRGBA64SetNRGBA64(b *testing.B) {
	m := image.NewNRGBA64(image.Rect(0, 0, 10, 10))
	c := color.NRGBA64{0xffff, 0xffff, 0xffff, 0x1357}
	for i := 0; i < b.N; i++ {
		m.SetNRGBA64(4, 5, c)
	}
}

func BenchmarkAlphaAt(b *testing.B) {
	m := image.NewAlpha(image.Rect(0, 0, 10, 10))
	for i := 0; i < b.N; i++ {
		m.AlphaAt(4, 5)
	}
}

func BenchmarkAlphaSetAlpha(b *testing.B) {
	m := image.NewAlpha(image.Rect(0, 0, 10, 10))
	c := color.Alpha{0x13}
	for i := 0; i < b.N; i++ {
		m.SetAlpha(4, 5, c)
	}
}

func BenchmarkAlpha16At(b *testing.B) {
	m := image.NewAlpha16(image.Rect(0, 0, 10, 10))
	for i := 0; i < b.N; i++ {
		m.Alpha16At(4, 5)
	}
}

func BenchmarkAlpha16SetAlpha16(b *testing.B) {
	m := image.NewAlpha16(image.Rect(0, 0, 10, 10))
	c := color.Alpha16{0x13}
	for i := 0; i < b.N; i++ {
		m.SetAlpha16(4, 5, c)
	}
}

func BenchmarkGrayAt(b *testing.B) {
	m := image.NewGray(image.Rect(0, 0, 10, 10))
	for i := 0; i < b.N; i++ {
		m.GrayAt(4, 5)
	}
}

func BenchmarkGraySetGray(b *testing.B) {
	m := image.NewGray(image.Rect(0, 0, 10, 10))
	c := color.Gray{0x13}
	for i := 0; i < b.N; i++ {
		m.SetGray(4, 5, c)
	}
}

func BenchmarkGray16At(b *testing.B) {
	m := image.NewGray16(image.Rect(0, 0, 10, 10))
	for i := 0; i < b.N; i++ {
		m.Gray16At(4, 5)
	}
}

func BenchmarkGray16SetGray16(b *testing.B) {
	m := image.NewGray16(image.Rect(0, 0, 10, 10))
	c := color.Gray16{0x13}
	for i := 0; i < b.N; i++ {
		m.SetGray16(4, 5, c)
	}
}

// --- Draw Benchmarks ---

func BenchmarkDrawFillOver(b *testing.B) {
	r := image.Rect(0, 0, 256, 256)
	dst := image.NewRGBA(r)
	src := image.NewUniform(color.RGBA{0, 0, 0xff, 0xff})
	for i := 0; i < b.N; i++ {
		draw.Draw(dst, r, src, image.Point{}, draw.Over)
	}
}

func BenchmarkDrawFillSrc(b *testing.B) {
	r := image.Rect(0, 0, 256, 256)
	dst := image.NewRGBA(r)
	src := image.NewUniform(color.RGBA{0, 0, 0xff, 0xff})
	for i := 0; i < b.N; i++ {
		draw.Draw(dst, r, src, image.Point{}, draw.Src)
	}
}

func BenchmarkDrawCopyOver(b *testing.B) {
	r := image.Rect(0, 0, 256, 256)
	dst := image.NewRGBA(r)
	src := image.NewRGBA(r)
	for i := 0; i < b.N; i++ {
		draw.Draw(dst, r, src, image.Point{}, draw.Over)
	}
}

func BenchmarkDrawCopySrc(b *testing.B) {
	r := image.Rect(0, 0, 256, 256)
	dst := image.NewRGBA(r)
	src := image.NewRGBA(r)
	for i := 0; i < b.N; i++ {
		draw.Draw(dst, r, src, image.Point{}, draw.Src)
	}
}

func BenchmarkDrawNRGBAOver(b *testing.B) {
	r := image.Rect(0, 0, 256, 256)
	dst := image.NewRGBA(r)
	src := image.NewNRGBA(r)
	for y := 0; y < 256; y++ {
		for x := 0; x < 256; x++ {
			src.SetNRGBA(x, y, color.NRGBA{uint8(x), 0, 0, 0x80})
		}
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		draw.Draw(dst, r, src, image.Point{}, draw.Over)
	}
}

func BenchmarkDrawNRGBASrc(b *testing.B) {
	r := image.Rect(0, 0, 256, 256)
	dst := image.NewRGBA(r)
	src := image.NewNRGBA(r)
	for y := 0; y < 256; y++ {
		for x := 0; x < 256; x++ {
			src.SetNRGBA(x, y, color.NRGBA{uint8(x), 0, 0, 0x80})
		}
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		draw.Draw(dst, r, src, image.Point{}, draw.Src)
	}
}

func BenchmarkDrawYCbCr(b *testing.B) {
	r := image.Rect(0, 0, 256, 256)
	dst := image.NewRGBA(r)
	src := image.NewYCbCr(r, image.YCbCrSubsampleRatio444)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		draw.Draw(dst, r, src, image.Point{}, draw.Over)
	}
}

func BenchmarkDrawGray(b *testing.B) {
	r := image.Rect(0, 0, 256, 256)
	dst := image.NewRGBA(r)
	src := image.NewGray(r)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		draw.Draw(dst, r, src, image.Point{}, draw.Over)
	}
}

func BenchmarkDrawGlyphOver(b *testing.B) {
	r := image.Rect(0, 0, 256, 256)
	dst := image.NewRGBA(r)
	src := image.NewUniform(color.RGBA{0, 0, 0xff, 0xff})
	mask := image.NewAlpha(r)
	for y := 0; y < 256; y++ {
		for x := 0; x < 256; x++ {
			mask.SetAlpha(x, y, color.Alpha{0x80})
		}
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		draw.DrawMask(dst, r, src, image.Point{}, mask, image.Point{}, draw.Over)
	}
}

func BenchmarkDrawGenericOver(b *testing.B) {
	r := image.Rect(0, 0, 256, 256)
	dst := image.NewRGBA64(r)
	src := image.NewRGBA64(r)
	for i := 0; i < b.N; i++ {
		draw.Draw(dst, r, src, image.Point{}, draw.Over)
	}
}

func BenchmarkDrawGenericSrc(b *testing.B) {
	r := image.Rect(0, 0, 256, 256)
	dst := image.NewRGBA64(r)
	src := image.NewRGBA64(r)
	for i := 0; i < b.N; i++ {
		draw.Draw(dst, r, src, image.Point{}, draw.Src)
	}
}

func BenchmarkDrawPalettedFill(b *testing.B) {
	r := image.Rect(0, 0, 256, 256)
	pal := make(color.Palette, 256)
	for i := range pal {
		pal[i] = color.RGBA{uint8(i), uint8(i), uint8(i), 0xff}
	}
	dst := image.NewPaletted(r, pal)
	src := image.NewUniform(color.RGBA{0, 0, 0xff, 0xff})
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		draw.Draw(dst, r, src, image.Point{}, draw.Src)
	}
}

func BenchmarkDrawPalettedRGBA(b *testing.B) {
	r := image.Rect(0, 0, 256, 256)
	pal := make(color.Palette, 256)
	for i := range pal {
		pal[i] = color.RGBA{uint8(i), uint8(i), uint8(i), 0xff}
	}
	dst := image.NewPaletted(r, pal)
	src := image.NewRGBA(r)
	for y := 0; y < 256; y++ {
		for x := 0; x < 256; x++ {
			src.SetRGBA(x, y, color.RGBA{uint8(x), uint8(y), 0, 0xff})
		}
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		draw.Draw(dst, r, src, image.Point{}, draw.Src)
	}
}

// --- PNG Benchmarks ---

func loadFile(b *testing.B, path string) []byte {
	data, err := os.ReadFile(path)
	if err != nil {
		b.Skip(err)
	}
	return data
}

func BenchmarkPNGDecodeGray(b *testing.B) {
	data := loadFile(b, "../png/testdata/benchGray.png")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		png.Decode(newReader(data))
	}
}

func BenchmarkPNGDecodeNRGBAGradient(b *testing.B) {
	data := loadFile(b, "../png/testdata/benchNRGBA-gradient.png")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		png.Decode(newReader(data))
	}
}

func BenchmarkPNGDecodeNRGBAOpaque(b *testing.B) {
	data := loadFile(b, "../png/testdata/benchNRGBA-opaque.png")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		png.Decode(newReader(data))
	}
}

func BenchmarkPNGDecodePaletted(b *testing.B) {
	data := loadFile(b, "../png/testdata/benchPaletted.png")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		png.Decode(newReader(data))
	}
}

func BenchmarkPNGDecodeRGB(b *testing.B) {
	data := loadFile(b, "../png/testdata/benchRGB.png")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		png.Decode(newReader(data))
	}
}

func BenchmarkPNGEncodeGray(b *testing.B) {
	r := image.Rect(0, 0, 640, 480)
	m := image.NewGray(r)
	for y := 0; y < 480; y++ {
		for x := 0; x < 640; x++ {
			m.SetGray(x, y, color.Gray{uint8(x + y)})
		}
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		png.Encode(devNull{}, m)
	}
}

func BenchmarkPNGEncodeNRGBA(b *testing.B) {
	r := image.Rect(0, 0, 640, 480)
	m := image.NewNRGBA(r)
	for y := 0; y < 480; y++ {
		for x := 0; x < 640; x++ {
			a := byte(0xff)
			if (x+y)%10 == 0 {
				a = 0x80
			}
			m.SetNRGBA(x, y, color.NRGBA{uint8(x), uint8(y), uint8(x + y), a})
		}
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		png.Encode(devNull{}, m)
	}
}

func BenchmarkPNGEncodePaletted(b *testing.B) {
	r := image.Rect(0, 0, 640, 480)
	pal := make(color.Palette, 256)
	for i := range pal {
		pal[i] = color.RGBA{uint8(i), uint8(255 - i), 0x80, 0xff}
	}
	m := image.NewPaletted(r, pal)
	for y := 0; y < 480; y++ {
		for x := 0; x < 640; x++ {
			m.SetColorIndex(x, y, uint8((x+y)%256))
		}
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		png.Encode(devNull{}, m)
	}
}

func BenchmarkPNGDecodeInterlaced(b *testing.B) {
	data := loadFile(b, "../png/testdata/benchRGB-interlace.png")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		png.Decode(newReader(data))
	}
}

func BenchmarkPNGEncodeRGBA(b *testing.B) {
	r := image.Rect(0, 0, 640, 480)
	m := image.NewRGBA(r)
	for y := 0; y < 480; y++ {
		for x := 0; x < 640; x++ {
			m.SetRGBA(x, y, color.RGBA{uint8(x), uint8(y), uint8(x + y), 0xff})
		}
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		png.Encode(devNull{}, m)
	}
}

func BenchmarkPNGPaeth(b *testing.B) {
	// Mirror MoonBit paeth bench: 256*256 calls with c=128
	for i := 0; i < b.N; i++ {
		for a := 0; a < 256; a++ {
			for bv := 0; bv < 256; bv++ {
				sink8 = paeth(uint8(a), uint8(bv), 128)
			}
		}
	}
}

func paeth(a, b, c uint8) uint8 {
	p := int(a) + int(b) - int(c)
	pa := p - int(a)
	if pa < 0 {
		pa = -pa
	}
	pb := p - int(b)
	if pb < 0 {
		pb = -pb
	}
	pc := p - int(c)
	if pc < 0 {
		pc = -pc
	}
	if pa <= pb && pa <= pc {
		return a
	} else if pb <= pc {
		return b
	}
	return c
}

// --- JPEG Benchmarks ---

func BenchmarkJPEGDecode(b *testing.B) {
	data := loadFile(b, "../testdata/video-001.jpeg")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		jpeg.Decode(newReader(data))
	}
}

func BenchmarkJPEGDecodeProgressive(b *testing.B) {
	data := loadFile(b, "../testdata/video-001.progressive.jpeg")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		jpeg.Decode(newReader(data))
	}
}

func BenchmarkJPEGEncodeRGBA(b *testing.B) {
	r := image.Rect(0, 0, 640, 480)
	m := image.NewRGBA(r)
	for y := 0; y < 480; y++ {
		for x := 0; x < 640; x++ {
			m.SetRGBA(x, y, color.RGBA{uint8(x % 256), uint8(y % 256), uint8((x + y) % 256), 0xff})
		}
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		jpeg.Encode(devNull{}, m, nil)
	}
}

func BenchmarkJPEGFDCT(b *testing.B) {
	// Approximate: encode a minimal 8x8 image repeatedly
	m := image.NewRGBA(image.Rect(0, 0, 8, 8))
	rng := rand.New(rand.NewSource(42))
	for y := 0; y < 8; y++ {
		for x := 0; x < 8; x++ {
			m.SetRGBA(x, y, color.RGBA{uint8(rng.Intn(256)), uint8(rng.Intn(256)), uint8(rng.Intn(256)), 0xff})
		}
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		jpeg.Encode(devNull{}, m, nil)
	}
}

// --- GIF Benchmarks ---

func BenchmarkGIFDecode(b *testing.B) {
	data := loadFile(b, "../testdata/video-001.gif")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		gif.Decode(newReader(data))
	}
}

func BenchmarkGIFEncode(b *testing.B) {
	pal := make(color.Palette, 256)
	for i := range pal {
		pal[i] = color.RGBA{uint8(i), uint8(255 - i), 0x80, 0xff}
	}
	m := image.NewPaletted(image.Rect(0, 0, 256, 256), pal)
	for y := 0; y < 256; y++ {
		for x := 0; x < 256; x++ {
			m.SetColorIndex(x, y, uint8((x*17+y*13)%256))
		}
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		gif.Encode(devNull{}, m, nil)
	}
}

func BenchmarkGIFEncodeRGBA(b *testing.B) {
	m := image.NewRGBA(image.Rect(0, 0, 64, 64))
	for y := 0; y < 64; y++ {
		for x := 0; x < 64; x++ {
			m.SetRGBA(x, y, color.RGBA{uint8(x * 4), uint8(y * 4), 0x80, 0xff})
		}
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		gif.Encode(devNull{}, m, nil)
	}
}

// --- Helpers ---

type bytesReader struct {
	data []byte
	pos  int
}

func newReader(data []byte) *bytesReader {
	return &bytesReader{data: data}
}

func (r *bytesReader) Read(p []byte) (int, error) {
	if r.pos >= len(r.data) {
		return 0, os.ErrClosed
	}
	n := copy(p, r.data[r.pos:])
	r.pos += n
	return n, nil
}

type devNull struct{}

func (devNull) Write(p []byte) (int, error) {
	return len(p), nil
}
