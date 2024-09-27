package text

import "../utils"
import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:strings"
import gl "vendor:wasm/WebGL"
import "vendor:wasm/js"

Buffers :: struct {
	pos:          Buffer,
	tex:          Buffer,
	indices:      EaBuffer,
	_initialized: bool,
}
Buffer :: utils.Buffer
EaBuffer :: utils.EaBuffer
buffer_init :: utils.buffer_init
ea_buffer_init :: utils.ea_buffer_init
ea_buffer_draw :: utils.ea_buffer_draw

Writer :: struct(N: uint) {
	buf:        [N]u8,
	next_buf_i: int,
	str:        string,
	xpos:       i32,
	ypos:       i32,
	atlas:      ^Atlas,
	dyn:        bool,
	buffered:   bool,
	wrap:       bool,
	buffers:    Buffers,
}
writer_init :: proc(
	w: ^Writer($N),
	size: AtlasSize,
	xpos: i32,
	ypos: i32,
	str: string,
	dyn: bool,
	canvas_w: i32,
	wrap: bool,
) -> (
	ok: bool,
) {
	// w.str = "Hello WOdinlingssss!"
	init(&g_atlases)
	w.atlas = &g_atlases[size]
	w.str = str
	w.dyn = dyn
	w.wrap = wrap
	w.xpos = xpos
	w.ypos = ypos

	for i := 0; i < len(w.str); i += 1 {
		writer_add_char(w, w.str[i])
	}

	// buffers
	writer_update_buffer_data(w, canvas_w)


	// if w.dyn {
	// 	js.add_window_event_listener(.Key_Down, {}, on_key_down)
	// }
	return true
}
writer_destroy :: proc(w: ^Writer($N)) {

}
writer_update_buffer_data :: proc(w: ^Writer($N), canvas_w: i32) {
	fmt.println("writer_update_buffer_data:", w)
	fmt.printf("atlas %dx%d\n", w.atlas.w, w.atlas.h)
	data_len := w.next_buf_i
	if data_len < 1 {
		return
	}
	pos_data := make([][2]f32, data_len * 4, allocator = context.temp_allocator)
	tex_data := make([][2]f32, data_len * 4, allocator = context.temp_allocator)
	indices_data := make([][6]u16, data_len, allocator = context.temp_allocator)
	x: f32 = f32(w.xpos)
	y: f32 = f32(w.ypos)
	char_h := f32(w.atlas.h)
	line_gap := f32(w.atlas.h) / 2
	for ch_index := 0; ch_index < data_len; ch_index += 1 {
		i := ch_index * 4
		char := w.buf[ch_index]
		char_i := i32(char) - 33
		if char_i < 0 || int(char_i) > len(w.atlas.chars) {
			// fmt.printf("out of range '%v'(%d)\n", rune(char), i32(char))
			// render space...
			x += 8
			continue
		}
		ch: Char = w.atlas.chars[char_i]

		// wrap to new line if needed
		spacing := f32(w.atlas.h / 10)
		// spacing = 10
		if w.wrap {
			next_w: f32 = f32(ch.w) + spacing
			line_gap: f32 = f32(w.atlas.h) / 2
			if x + next_w >= f32(canvas_w) {
				x = f32(w.xpos)
				y += f32(w.atlas.h)
			}
		}

		px := x
		py := y
		pos_data[i + 0] = {px, py + char_h}
		pos_data[i + 1] = {px, py}
		pos_data[i + 2] = {px + f32(ch.w), py}
		pos_data[i + 3] = {px + f32(ch.w), py + char_h}
		x += f32(ch.w) + spacing

		w_mult := 1.0 / f32(w.atlas.w)
		tx := f32(ch.x) * w_mult
		ty: f32 = 0
		tx2 := tx + f32(ch.w) * w_mult
		ty2: f32 = 1
		tex_data[i + 0] = {tx, ty2}
		tex_data[i + 1] = {tx, ty}
		tex_data[i + 2] = {tx2, ty}
		tex_data[i + 3] = {tx2, ty2}
		fmt.printf("ch: %v, w:%d, x: %d, %.4f->%.4f\n", rune(char), ch.w, ch.x, tx, tx2)

		ii := ch_index
		indices_data[ii][0] = u16(i) + 0
		indices_data[ii][1] = u16(i) + 1
		indices_data[ii][2] = u16(i) + 2
		indices_data[ii][3] = u16(i) + 0
		indices_data[ii][4] = u16(i) + 2
		indices_data[ii][5] = u16(i) + 3
	}
	if w.buffers._initialized {
		{
			buffer: utils.Buffer = w.buffers.pos
			gl.BindBuffer(buffer.target, buffer.id)
			gl.BufferSubDataSlice(buffer.target, 0, pos_data)
		}
		{
			buffer: Buffer = w.buffers.tex
			gl.BindBuffer(buffer.target, buffer.id)
			gl.BufferSubDataSlice(buffer.target, 0, tex_data)
		}
		{
			buffer: EaBuffer = w.buffers.indices
			gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, buffer.id)
			gl.BufferSubDataSlice(gl.ELEMENT_ARRAY_BUFFER, 0, indices_data)
		}
	} else {
		w.buffers.pos = {
			size   = 2,
			type   = gl.FLOAT,
			target = gl.ARRAY_BUFFER,
			usage  = gl.STATIC_DRAW,
		}
		buffer_init(&w.buffers.pos, pos_data)

		w.buffers.tex = {
			size   = 2,
			type   = gl.FLOAT,
			target = gl.ARRAY_BUFFER,
			usage  = gl.STATIC_DRAW,
		}
		buffer_init(&w.buffers.tex, tex_data)

		w.buffers.indices = {
			usage = gl.STATIC_DRAW,
		}
		ea_buffer_init(&w.buffers.indices, indices_data)
		w.buffers._initialized = true
	}
	w.buffered = true
}
writer_draw :: proc(w: ^Writer($N), canvas_w: i32, canvas_h: i32) -> (ok: bool) {
	if !w.buffered {
		writer_update_buffer_data(w, canvas_w)
	}
	ea_buffer_draw(w.buffers.indices)
	return check_gl_error()
}
writer_add_char :: proc(w: ^Writer($N), char: u8) {
	if w.next_buf_i >= len(w.buf) {
		return
	}
	w.buf[w.next_buf_i] = char
	w.next_buf_i += 1
	w.buffered = false
}
writer_backspace :: proc(w: ^Writer($N)) {
	if w.next_buf_i == 0 {
		return
	}
	w.next_buf_i -= 1
	w.buffered = false
}

check_gl_error :: utils.check_gl_error

