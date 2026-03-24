package testperf

import (
	"bytes"
	"fmt"
	"image"
	"image/color"
	"image/gif"
	"image/jpeg"
	"image/png"
	"math"
	"os"
	"testing"
)

// TestParity checks Go decode values (used as reference by MoonBit parity).
func TestParity(t *testing.T) {
	// PNG
	f, err := os.Open("../testdata/video-001.png")
	if err != nil {
		t.Fatal(err)
	}
	pngImg, err := png.Decode(f)
	f.Close()
	if err != nil {
		t.Fatal(err)
	}
	b := pngImg.Bounds()
	var sum int64
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			r, g, bv, a := pngImg.At(x, y).RGBA()
			sum += int64(r) + int64(g) + int64(bv) + int64(a)
		}
	}
	r, g, bv, a := pngImg.At(0, 0).RGBA()
	r2, g2, bv2, a2 := pngImg.At(100, 75).RGBA()
	fmt.Printf("PNG %dx%d checksum=%d [0,0]=%d,%d,%d,%d [100,75]=%d,%d,%d,%d\n",
		b.Dx(), b.Dy(), sum, r, g, bv, a, r2, g2, bv2, a2)

	// JPEG
	f2, _ := os.Open("../testdata/video-001.jpeg")
	jpegImg, _ := jpeg.Decode(f2)
	f2.Close()
	jb := jpegImg.Bounds()
	var jsum int64
	for y := jb.Min.Y; y < jb.Max.Y; y++ {
		for x := jb.Min.X; x < jb.Max.X; x++ {
			r, g, bv, a := jpegImg.At(x, y).RGBA()
			jsum += int64(r) + int64(g) + int64(bv) + int64(a)
		}
	}
	fmt.Printf("JPEG %dx%d checksum=%d\n", jb.Dx(), jb.Dy(), jsum)

	// GIF
	f3, _ := os.Open("../testdata/video-001.gif")
	gifImg, _ := gif.Decode(f3)
	f3.Close()
	gb := gifImg.Bounds()
	r, g, bv, a = gifImg.At(0, 0).RGBA()
	r2, g2, bv2, a2 = gifImg.At(100, 75).RGBA()
	fmt.Printf("GIF %dx%d [0,0]=%d,%d,%d,%d [100,75]=%d,%d,%d,%d\n",
		gb.Dx(), gb.Dy(), r, g, bv, a, r2, g2, bv2, a2)
}

// TestCrossCodecRoundtrip tests MoonBit-encode → Go-decode interop.
// MoonBit writes encoded files to testdata/roundtrip_*, Go reads them back.
func TestCrossCodecRoundtrip(t *testing.T) {
	// --- MoonBit PNG → Go decode ---
	pngData, err := os.ReadFile("../testdata/roundtrip_moonbit.png")
	if err != nil {
		t.Skip("no roundtrip_moonbit.png — run MoonBit parity first")
	}
	pngImg, err := png.Decode(bytes.NewReader(pngData))
	if err != nil {
		t.Fatalf("Go can't decode MoonBit PNG: %v", err)
	}
	b := pngImg.Bounds()
	fmt.Printf("MoonBit PNG → Go: %dx%d\n", b.Dx(), b.Dy())
	// Verify pixel content matches known reference
	r, g, bv, a := pngImg.At(0, 0).RGBA()
	fmt.Printf("  [0,0]=%d,%d,%d,%d\n", r, g, bv, a)
	if r != 32125 || g != 3598 || bv != 514 || a != 65535 {
		t.Errorf("MoonBit PNG pixel mismatch at [0,0]: got %d,%d,%d,%d want 32125,3598,514,65535", r, g, bv, a)
	}

	// --- MoonBit JPEG → Go decode ---
	jpegData, err := os.ReadFile("../testdata/roundtrip_moonbit.jpeg")
	if err != nil {
		t.Skip("no roundtrip_moonbit.jpeg")
	}
	jpegImg, err := jpeg.Decode(bytes.NewReader(jpegData))
	if err != nil {
		t.Fatalf("Go can't decode MoonBit JPEG: %v", err)
	}
	jb := jpegImg.Bounds()
	fmt.Printf("MoonBit JPEG → Go: %dx%d\n", jb.Dx(), jb.Dy())

	// --- MoonBit GIF → Go decode ---
	gifData, err := os.ReadFile("../testdata/roundtrip_moonbit.gif")
	if err != nil {
		t.Skip("no roundtrip_moonbit.gif")
	}
	gifImg, err := gif.Decode(bytes.NewReader(gifData))
	if err != nil {
		t.Fatalf("Go can't decode MoonBit GIF: %v", err)
	}
	gb := gifImg.Bounds()
	fmt.Printf("MoonBit GIF → Go: %dx%d\n", gb.Dx(), gb.Dy())

	// --- Go encode → MoonBit decode (write files for MoonBit to read) ---
	// Create a small test image
	img := image.NewRGBA(image.Rect(0, 0, 32, 32))
	for y := 0; y < 32; y++ {
		for x := 0; x < 32; x++ {
			img.SetRGBA(x, y, color.RGBA{uint8(x * 8), uint8(y * 8), 128, 255})
		}
	}
	// Go PNG encode
	var pngBuf bytes.Buffer
	png.Encode(&pngBuf, img)
	os.WriteFile("../testdata/roundtrip_go.png", pngBuf.Bytes(), 0644)
	// Go JPEG encode
	var jpegBuf bytes.Buffer
	jpeg.Encode(&jpegBuf, img, &jpeg.Options{Quality: 90})
	os.WriteFile("../testdata/roundtrip_go.jpeg", jpegBuf.Bytes(), 0644)
	// Go GIF encode
	pal := make(color.Palette, 256)
	for i := range pal {
		pal[i] = color.RGBA{uint8(i), uint8(i), uint8(i), 255}
	}
	palImg := image.NewPaletted(image.Rect(0, 0, 32, 32), pal)
	for y := 0; y < 32; y++ {
		for x := 0; x < 32; x++ {
			palImg.SetColorIndex(x, y, uint8((x+y)%256))
		}
	}
	var gifBuf bytes.Buffer
	gif.Encode(&gifBuf, palImg, nil)
	os.WriteFile("../testdata/roundtrip_go.gif", gifBuf.Bytes(), 0644)
	fmt.Println("Go encoded roundtrip_go.{png,jpeg,gif}")

	// Compute Go's reference checksums for the 32x32 test image
	var goSum int64
	for y := 0; y < 32; y++ {
		for x := 0; x < 32; x++ {
			r, g, bv, a := img.At(x, y).RGBA()
			goSum += int64(r) + int64(g) + int64(bv) + int64(a)
		}
	}
	fmt.Printf("Go 32x32 source checksum=%d\n", goSum)

	// Decode our own PNG back to verify
	reDecoded, _ := png.Decode(bytes.NewReader(pngBuf.Bytes()))
	var reSum int64
	for y := 0; y < 32; y++ {
		for x := 0; x < 32; x++ {
			r, g, bv, a := reDecoded.At(x, y).RGBA()
			reSum += int64(r) + int64(g) + int64(bv) + int64(a)
		}
	}
	if goSum != reSum {
		t.Errorf("Go PNG roundtrip checksum mismatch: %d != %d", goSum, reSum)
	}

	// PSNR of JPEG roundtrip
	jpegDecoded, _ := jpeg.Decode(bytes.NewReader(jpegBuf.Bytes()))
	var mse float64
	npix := 0
	for y := 0; y < 32; y++ {
		for x := 0; x < 32; x++ {
			r1, g1, b1, _ := img.At(x, y).RGBA()
			r2, g2, b2, _ := jpegDecoded.At(x, y).RGBA()
			dr := float64(r1) - float64(r2)
			dg := float64(g1) - float64(g2)
			db := float64(b1) - float64(b2)
			mse += dr*dr + dg*dg + db*db
			npix++
		}
	}
	mse /= float64(npix * 3)
	psnr := 10 * math.Log10(65535*65535/mse)
	fmt.Printf("Go JPEG roundtrip PSNR: %.1f dB\n", psnr)
	if psnr < 30 {
		t.Errorf("Go JPEG PSNR too low: %.1f dB", psnr)
	}
}
