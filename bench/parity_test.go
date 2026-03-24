package testperf

import (
	"fmt"
	"image/gif"
	"image/jpeg"
	"image/png"
	"os"
	"testing"
)

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
	jpegImg, err := jpeg.Decode(f2)
	f2.Close()
	if err != nil {
		t.Fatal(err)
	}
	jb := jpegImg.Bounds()
	var jsum int64
	for y := jb.Min.Y; y < jb.Max.Y; y++ {
		for x := jb.Min.X; x < jb.Max.X; x++ {
			r, g, bv, a := jpegImg.At(x, y).RGBA()
			jsum += int64(r) + int64(g) + int64(bv) + int64(a)
		}
	}
	r, g, bv, a = jpegImg.At(0, 0).RGBA()
	r2, g2, bv2, a2 = jpegImg.At(100, 75).RGBA()
	fmt.Printf("JPEG %dx%d checksum=%d [0,0]=%d,%d,%d,%d [100,75]=%d,%d,%d,%d\n",
		jb.Dx(), jb.Dy(), jsum, r, g, bv, a, r2, g2, bv2, a2)

	// GIF
	f3, _ := os.Open("../testdata/video-001.gif")
	gifImg, err := gif.Decode(f3)
	f3.Close()
	if err != nil {
		t.Fatal(err)
	}
	gb := gifImg.Bounds()
	r, g, bv, a = gifImg.At(0, 0).RGBA()
	r2, g2, bv2, a2 = gifImg.At(100, 75).RGBA()
	fmt.Printf("GIF %dx%d [0,0]=%d,%d,%d,%d [100,75]=%d,%d,%d,%d\n",
		gb.Dx(), gb.Dy(), r, g, bv, a, r2, g2, bv2, a2)
}
