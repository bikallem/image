package testperf

import (
	"image"
	"image/color"
	"image/draw"
	"image/gif"
	"image/jpeg"
	"image/png"
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

func BenchmarkYCbCrToRGBA_128(b *testing.B) {
	c := color.YCbCr{128, 128, 128}
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

// --- Draw Benchmarks ---

func BenchmarkDrawFillSrc(b *testing.B) {
	r := image.Rect(0, 0, 256, 256)
	dst := image.NewRGBA(r)
	src := image.NewUniform(color.RGBA{0, 0, 0xff, 0xff})
	for i := 0; i < b.N; i++ {
		draw.Draw(dst, r, src, image.Point{}, draw.Src)
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

func BenchmarkDrawCopyOver(b *testing.B) {
	r := image.Rect(0, 0, 256, 256)
	dst := image.NewRGBA(r)
	src := image.NewRGBA(r)
	for i := 0; i < b.N; i++ {
		draw.Draw(dst, r, src, image.Point{}, draw.Over)
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

// --- JPEG Benchmarks ---

func BenchmarkJPEGDecode(b *testing.B) {
	data := loadFile(b, "../testdata/video-001.jpeg")
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
	if r.pos >= len(r.data) {
		return n, nil
	}
	return n, nil
}

type devNull struct{}

func (devNull) Write(p []byte) (int, error) {
	return len(p), nil
}
