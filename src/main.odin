package game

import "../shared/text"
import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:mem"
import gl "vendor:wasm/WebGL"
import "vendor:wasm/js"

main :: proc() {}

WriterSet :: struct {
	w:        i32,
	h:        i32,
	writer_1: text.Writer(len(LINE1)),
	writer_2: text.Writer(len(LINE2)),
	writer_3: text.Writer(len(LINE3)),
}
init_writer_set :: proc(
	ws: ^WriterSet,
	size: text.AtlasSize,
	canvas_w: i32,
	pos: [2]i32,
) -> (
	y_pos: i32,
	ok: bool,
) {
	text.writer_init(&ws.writer_1, size, pos.x, pos.y, LINE1, false, canvas_w, false) or_return
	line_offset := i32(f32(ws.writer_1.atlas.h) * 1.2)
	text.writer_init(
		&ws.writer_2,
		size,
		pos.x,
		pos.y + line_offset,
		LINE2,
		false,
		canvas_w,
		false,
	) or_return
	text.writer_init(
		&ws.writer_3,
		size,
		pos.x,
		pos.y + line_offset * 2,
		LINE3,
		false,
		canvas_w,
		false,
	) or_return
	return pos.y + line_offset * 3, true
}
draw_writer_set :: proc(ws: ^WriterSet, w, h: i32, uniforms: TextUniforms) -> (ok: bool) {
	text_shader_use(
		g_state.shader,
		uniforms,
		ws.writer_1.buffers.pos,
		ws.writer_1.buffers.tex,
		ws.writer_1.atlas.texture_info,
	) or_return
	text.writer_draw(&ws.writer_1, w, h) or_return
	text_shader_use(
		g_state.shader,
		uniforms,
		ws.writer_2.buffers.pos,
		ws.writer_2.buffers.tex,
		ws.writer_2.atlas.texture_info,
	) or_return
	text.writer_draw(&ws.writer_2, w, h) or_return
	text_shader_use(
		g_state.shader,
		uniforms,
		ws.writer_3.buffers.pos,
		ws.writer_3.buffers.tex,
		ws.writer_3.atlas.texture_info,
	) or_return
	text.writer_draw(&ws.writer_3, w, h) or_return
	return true
}

LINE1 :: "!\"#$%&'()*+,-./0123456789:;<=>?@"
LINE2 :: "@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`"
LINE3 :: "abcdefghijklmnopqrstuvwxyz{|}~"
State :: struct {
	started:       bool,
	writer_20_set: WriterSet,
	writer_30_set: WriterSet,
	writer_40_set: WriterSet,
	shader:        TextShader,
}
g_state: State = {}

temp_arena_buffer: [mem.Megabyte]byte
temp_arena: mem.Arena = {
	data = temp_arena_buffer[:],
}
temp_arena_allocator := mem.arena_allocator(&temp_arena)

arena_buffer: [mem.Megabyte * 4]byte
arena: mem.Arena = {
	data = arena_buffer[:],
}
arena_allocator := mem.arena_allocator(&arena)

start :: proc() -> (ok: bool) {
	g_state.started = true

	if ok = gl.CreateCurrentContextById("canvas-1", {.stencil}); !ok {
		return ok
	}
	{
		es_major, es_minor: i32
		gl.GetESVersion(&es_major, &es_minor)
		fmt.println("es version:", es_major, es_minor)
	}

	canvas_w: i32 = gl.DrawingBufferWidth()
	canvas_h: i32 = gl.DrawingBufferHeight()

	{
		y: i32 = 20
		y, ok = init_writer_set(&g_state.writer_20_set, .A20, canvas_w, {20, y})
		if !ok {
			fmt.println("error")
			return ok
		}
		y = init_writer_set(&g_state.writer_30_set, .A30, canvas_w, {20, y + 40}) or_return
		y = init_writer_set(&g_state.writer_40_set, .A40, canvas_w, {20, y + 40}) or_return
	}
	// js.add_window_event_listener(.Key_Down, {}, on_key_down)

	text_shader_init(&g_state.shader)

	ok = check_gl_error()
	return
}

draw :: proc(dt: f32) -> (ok: bool) {

	canvas_w: i32 = gl.DrawingBufferWidth()
	canvas_h: i32 = gl.DrawingBufferHeight()

	gl.ClearColor(0.2, 0.2, 0.2, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.ClearDepth(1)
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	projection_mat := glm.mat4Ortho3d(0, f32(canvas_w), f32(canvas_h), 0, -1, 1)
	{
		uniforms: TextUniforms = {
			projection = projection_mat,
			color      = {1, 1, 1},
		}
		draw_writer_set(&g_state.writer_20_set, canvas_w, canvas_h, uniforms) or_return
		draw_writer_set(&g_state.writer_30_set, canvas_w, canvas_h, uniforms) or_return
		draw_writer_set(&g_state.writer_40_set, canvas_w, canvas_h, uniforms) or_return
	}
	return true
}

@(export)
step :: proc(dt: f32) -> (keep_going: bool) {
	context.allocator = arena_allocator
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	if !g_state.started {
		if keep_going = start(); !keep_going {return}
	}

	ok := draw(dt)
	if (!ok) {return false}

	keep_going = check_gl_error()
	return
}

// --- input

on_key_down :: proc(e: js.Event) {
	// w := &g_state.writer3
	// if !w.dyn {
	// 	return
	// }
	// if e.key.code == "Backspace" {
	// 	fmt.println("backspace")
	// 	text.writer_backspace(w)
	// 	return
	// }
	// if len(e.key.key) != 1 {
	// 	return
	// }
	// fmt.println("code:", e.key.code, "key:", e.key.key)
	// text.writer_add_char(w, e.key.key[0])
}

// --- utils

check_gl_error :: proc() -> (ok: bool) {
	err := gl.GetError()
	if err != gl.NO_ERROR {
		fmt.eprintln("WebGL error:", err)
		return false
	}
	return true
}

