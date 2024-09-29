package glyph

import "core:fmt"
import "core:image"
import "core:image/bmp"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:os"

Pos :: [2]f32

Dir :: enum {
	CenterH,
	CenterV,
	Up,
	Down,
	Left,
	Right,
}
Cap :: enum {
	Square,
	TriUL,
	TriUR,
	TriLL,
	TriLR,
}
Point :: struct {
	pos: Pos,
	cap: Cap,
}

Line :: struct {
	start: Point,
	end:   Point,
	dir:   Dir,
}

Glyph :: struct {
	lines:        []Line,
	aspect_ratio: f32,
}

glyph_a :: proc() -> Glyph {
	g: Glyph
	g.lines = make([]Line, 5)
	g.aspect_ratio = 40.0 / 24.0
	xn: f32 = 1.0 / 24.0
	yn: f32 = 1.0 / 40.0
	tp: f32 = 11.0 / 40.0
	bt: f32 = 32.0 / 40.0
	lf: f32 = 4.0 / 24.0
	rt: f32 = 21.0 / 24.0
	mid: f32 = 20.5 / 40.0
	// top
	g.lines[0] = {
		start = {{lf + xn * 2, tp}, .TriUL},
		end   = {{rt, tp}, .TriUR},
		dir   = .Down,
	}
	// bottom
	g.lines[1] = {
		start = {{lf, bt}, .TriLL},
		end   = {{rt, bt}, .TriLR},
		dir   = .Up,
	}
	// mid
	g.lines[2] = {
		start = {{lf, mid}, .TriUL},
		end   = {{rt, mid}, .Square},
		dir   = .CenterH,
	}
	// left
	g.lines[3] = {
		start = {{lf, mid}, .TriUL},
		end   = {{lf, bt}, .TriLL},
		dir   = .Right,
	}
	// right
	g.lines[4] = {
		start = {{rt, tp}, .TriUR},
		end   = {{rt, bt}, .TriLR},
		dir   = .Left,
	}
	return g
}


_draw_pixel :: proc(pos: [2]f32, w, h: int, pixels: []u8) {
	px: [2]int
	px.x = math.clamp(0, w - 1, int(math.floor(pos.x * f32(w) - 0.01)))
	px.y = math.clamp(0, h - 1, int(math.floor(pos.y * f32(h) - 0.01)))
	i := px.y * w + px.x
	if i < 0 || i >= len(pixels) {
		fmt.printf("pixel index out of range: w:%d,h:%d x:%d,y:%d\n", w, h, px.x, px.y)
		return
	}
	pixels[i] = 255
}

_draw_line :: proc(line: Line, i, w, h: int, pixels: []u8) {
	// for each point, what's the closest pixel?
	// 0-1 -> 0-w-1
	distance: [2]f32 = {
		math.abs(line.start.pos.x - line.end.pos.x),
		math.abs(line.start.pos.y - line.end.pos.y),
	}
	px_x := cast(int)math.ceil(f32(w) * distance.x) * 2
	px_y := cast(int)math.ceil(f32(h) * distance.y) * 2
	// fmt.printf(
	// 	"line %d has distance (%.2f,%.2f) and len (%d,%d) pixels\n",
	// 	i,
	// 	distance.x,
	// 	distance.y,
	// 	px_x,
	// 	px_y,
	// )
	px: int = math.max(px_x, px_y)

	for t in 0 ..= px {
		tf := f32(t) / f32(px)
		pos := math.lerp(line.start.pos, line.end.pos, tf)
		_draw_pixel(pos, w, h, pixels)
	}
}

glyph_rasterize :: proc(g: Glyph, w, h, thickness: int) -> []u8 {
	pixels := make([]u8, w * h)
	px_size_w := 1.0 / f32(w)
	px_size_h := 1.0 / f32(h)
	for line_orig, i in g.lines {
		line := line_orig
		center_off: f32 = 0
		center_switch: f32 = 1
		for thick_i in 0 ..< thickness {
			// offset of the whole line
			if thick_i > 0 {
				dir: [2]f32
				switch line.dir {
				case .Up:
					dir = {0, -px_size_h}
				case .Down:
					dir = {0, px_size_h}
				case .Left:
					dir = {-px_size_w, 0}
				case .Right:
					dir = {px_size_w, 0}
				case .CenterH:
					{
						center_off += px_size_h
						dir = {0, center_off * center_switch}
						center_switch *= -1
					}
				case .CenterV:
					{
						center_off += px_size_w
						dir = {0, center_off * center_switch}
						center_switch *= -1
						dir = {center_off, 0}
					}
				}
				line.start.pos += dir
				line.end.pos += dir
			}
			// TODO: offset of the start end of the line (for tri caps)
			_draw_line(line, i, w, h, pixels)
		}
	}
	return pixels
}

write_to_file :: proc(pixels: []u8, w, h: int, output: string) -> bool {
	pixels3 := make([][3]u8, len(pixels))
	defer delete(pixels3)
	for px1, i in pixels {
		pixels3[i] = {px1, px1, px1}
	}
	img, ok := image.pixels_to_image(pixels3, w, h)
	if !ok {
		fmt.eprintln("Failed to convert pixels to image")
		return ok
	}
	err := bmp.save_to_file(output, &img)
	if err != nil {
		fmt.eprintln("Failed to save bmp with err:", err)
	}
	return true
}

write_to_file_combined :: proc(sizes: [][2]int, size_pixels: [][]u8, output: string) -> bool {

	// combine all the sizes
	w: int = 0
	h: int = 0
	spacing := 1
	for size in sizes {
		w += size.x + spacing
		h = math.max(h, size.y)
	}

	pixels := make([][3]u8, w * h)
	defer delete(pixels)

	dst_left_x := 0
	for i in 0 ..< len(sizes) {
		size := sizes[i]
		y_offset := (h - size.y) / 2
		src_pixels := size_pixels[i]
		for src_y in 0 ..< size.y {
			for src_x in 0 ..< size.x {
				dst_x := dst_left_x + src_x
				dst_y := src_y + y_offset
				dst_i := dst_y * w + dst_x
				v: u8 = src_pixels[src_y * size.x + src_x]
				pixels[dst_i] = {v, v, v}
			}
		}
		dst_left_x += size.x + spacing
	}

	img, ok := image.pixels_to_image(pixels, w, h)
	if !ok {
		fmt.eprintln("Failed to convert pixels to image")
		return ok
	}
	err := bmp.save_to_file(output, &img)
	if err != nil {
		fmt.eprintln("Failed to save bmp with err:", err)
	}
	return true
}

main :: proc() {
	a := glyph_a()
	N :: 16
	sizes: [N]int = {8, 10, 12, 14, 16, 18, 20, 24, 28, 32, 36, 40, 48, 60, 72, 96}
	dims: [N][2]int
	size_pixels: [N][]u8

	for size, i in sizes {
		dims[i] = {cast(int)math.round(f32(size) * 0.6), size}
		w := dims[i].x
		h := dims[i].y
		thickness := cast(int)math.round(f32(h) / 10.0)
		size_pixels[i] = glyph_rasterize(a, w, h, thickness)
		write_to_file(size_pixels[i], w, h, fmt.tprintf("glyphs/a_%d.bmp", h))
	}
	write_to_file_combined(dims[:], size_pixels[:], fmt.tprintf("glyphs/combined.bmp"))
}

