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
	fmt.Printf("PNG: %dx%d\n", b.Dx(), b.Dy())
	var sum int64
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			r, g, bv, a := pngImg.At(x, y).RGBA()
			sum += int64(r) + int64(g) + int64(bv) + int64(a)
		}
	}
	fmt.Printf("PNG pixel checksum: %d\n", sum)
	r, g, bv, a := pngImg.At(0, 0).RGBA()
	fmt.Printf("PNG[0,0]: %d %d %d %d\n", r, g, bv, a)
	r, g, bv, a = pngImg.At(100, 75).RGBA()
	fmt.Printf("PNG[100,75]: %d %d %d %d\n", r, g, bv, a)

	// JPEG
	f2, _ := os.Open("../testdata/video-001.jpeg")
	jpegImg, err := jpeg.Decode(f2)
	f2.Close()
	if err != nil {
		t.Fatal(err)
	}
	jb := jpegImg.Bounds()
	fmt.Printf("JPEG: %dx%d\n", jb.Dx(), jb.Dy())
	var jsum int64
	for y := jb.Min.Y; y < jb.Max.Y; y++ {
		for x := jb.Min.X; x < jb.Max.X; x++ {
			r, g, bv, a := jpegImg.At(x, y).RGBA()
			jsum += int64(r) + int64(g) + int64(bv) + int64(a)
		}
	}
	fmt.Printf("JPEG pixel checksum: %d\n", jsum)
	r, g, bv, a = jpegImg.At(0, 0).RGBA()
	fmt.Printf("JPEG[0,0]: %d %d %d %d\n", r, g, bv, a)
	r, g, bv, a = jpegImg.At(100, 75).RGBA()
	fmt.Printf("JPEG[100,75]: %d %d %d %d\n", r, g, bv, a)

	// GIF
	f3, _ := os.Open("../testdata/video-001.gif")
	gifImg, err := gif.Decode(f3)
	f3.Close()
	if err != nil {
		t.Fatal(err)
	}
	gb := gifImg.Bounds()
	fmt.Printf("GIF: %dx%d\n", gb.Dx(), gb.Dy())
	r, g, bv, a = gifImg.At(0, 0).RGBA()
	fmt.Printf("GIF[0,0]: %d %d %d %d\n", r, g, bv, a)
	r, g, bv, a = gifImg.At(100, 75).RGBA()
	fmt.Printf("GIF[100,75]: %d %d %d %d\n", r, g, bv, a)
}
