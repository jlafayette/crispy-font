package game

import "../shared/text"
import "../shared/utils"
import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:mem"
import "core:strings"
import gl "vendor:wasm/WebGL"
import "vendor:wasm/js"

main :: proc() {}

ALL_CHARS :: "!\"#$%&'()*+,-./0123456789:;<=>?@\nABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`\nabcdefghijklmnopqrstuvwxyz{|}~"

State :: struct {
	started:      bool,
	writer_var:   text.Writer(len(ALL_CHARS)),
	writer_debug: text.Writer(64),
	writer_dpr:   text.Writer(9),
	writer_size:  text.Writer(32),
	writer_res:   text.Writer(32),
	shader:       TextShader,
	canvas_res:   [2]i32,
	canvas_pos:   [2]i32,
	canvas_size:  [2]i32,
	window_size:  [2]i32,
	dpr:          f32,
	aspect_ratio: f32,
	size_changed: bool,
	zoom_changed: bool,
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

	gl.CreateCurrentContextById("canvas-1", {}) or_return
	{
		es_major, es_minor: i32
		gl.GetESVersion(&es_major, &es_minor)
		fmt.println("es version:", es_major, es_minor)
	}
	resize()
	canvas_w := g_state.canvas_size.x
	canvas_h := g_state.canvas_size.y

	{
		{
			y: i32 = 50
			text.writer_init(
				&g_state.writer_var,
				20,
				20,
				y,
				ALL_CHARS,
				false,
				canvas_w,
				false,
			) or_return
		}
		{
			// x = canvas_w - str_width
			// y = 0
			writer := &g_state.writer_debug
			text.writer_init(writer, 20, 5, 5, "", false, canvas_w, false) or_return
		}
		{
			// x = canvas_w - str_width
			// y = 0
			writer := &g_state.writer_dpr
			str := "DPR: 0.00"
			size := text.get_size(str, .A20)
			text.writer_init(writer, 20, 5, 5, str, false, canvas_w, false) or_return
		}
		{
			writer := &g_state.writer_size
			str := "SIZE: 0.00 x 0.00"
			size := text.get_size(str, .A20)
			text.writer_init(
				writer,
				20,
				canvas_w - size.x - 5,
				5 + 20,
				str,
				false,
				canvas_w,
				false,
			) or_return
		}
		{
			writer := &g_state.writer_res
			str := "RES: 000.00 x 000.00"
			size := text.get_size(str, .A20)
			text.writer_init(
				writer,
				20,
				canvas_w - size.x - 5,
				canvas_h - size.y - 5,
				str,
				false,
				canvas_w,
				false,
			) or_return
		}
	}

	text_shader_init(&g_state.shader)

	fmt.println("adding event listeners")
	js.add_window_event_listener(.Key_Down, {}, on_key_down)
	js.add_window_event_listener(.Resize, {}, on_resize)

	ok = check_gl_error()
	return
}

update :: proc(state: ^State, dt: f32) {
	resize()
	if state.size_changed || state.zoom_changed {
		target := i32(math.round(state.dpr * 32))
		atlas_size, multiplier, px := text.get_closest_size(target)
		{
			writer := &state.writer_var
			text.writer_set_size(writer, target)
			size := text.writer_get_size(writer, state.canvas_res.x)

			x := state.canvas_res.x / 2 - size.x / 2
			y := state.canvas_res.y / 2 - size.y / 2

			text.writer_set_pos(writer, {x, y})
		}
		{
			writer := &state.writer_debug
			s := fmt.tprintf("Target: %d, Actual: %d", target, px)
			text.writer_set_text(writer, s)
			text.writer_set_pos(writer, {5, 5})
		}
		{
			writer := &state.writer_dpr
			s := fmt.tprintf("DPR: %.2f", state.dpr)
			text.writer_set_text(&state.writer_dpr, s)
			size := text.get_size(s, writer.size)
			text.writer_set_pos(&state.writer_dpr, {5, state.canvas_res.y - size.y - 5})
		}
		{
			writer := &state.writer_size
			s := fmt.tprintf("SIZE: %d x %d", state.canvas_size.x, state.canvas_size.y)
			text.writer_set_text(writer, s)
			size := text.get_size(s, writer.size)
			text.writer_set_pos(writer, {state.canvas_res.x - size.x - 5, 5})
		}
		{
			writer := &state.writer_res
			s := fmt.tprintf("RES: %d x %d", state.canvas_res.x, state.canvas_res.y)
			text.writer_set_text(writer, s)
			size := text.get_size(s, writer.size)
			text.writer_set_pos(
				writer,
				{state.canvas_res.x - size.x - 5, state.canvas_res.y - size.y - 5},
			)
		}
	}
	state.size_changed = false
	state.zoom_changed = false
}

draw :: proc(dt: f32) -> (ok: bool) {
	canvas_w := g_state.canvas_size.x
	canvas_h := g_state.canvas_size.y

	gl.Viewport(0, 0, g_state.canvas_res.x, g_state.canvas_res.y)

	gl.ClearColor(0.1, 0.1, 0.1, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.ClearDepth(1)
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	projection_mat := glm.mat4Ortho3d(
		0,
		f32(g_state.canvas_res.x),
		f32(g_state.canvas_res.y),
		0,
		-1,
		1,
	)
	{
		uniforms: TextUniforms = {
			projection = projection_mat,
			color      = {0.4, 0.7, 0.9},
		}
		{
			writer := g_state.writer_var
			text_shader_use(
				g_state.shader,
				uniforms,
				writer.buffers.pos,
				writer.buffers.tex,
				writer.atlas.texture_info,
			) or_return
			text.writer_draw(&writer, canvas_w) or_return
		}
		uniforms.color = {1, 1, 1}
		{
			writer := g_state.writer_debug
			text_shader_use(
				g_state.shader,
				uniforms,
				writer.buffers.pos,
				writer.buffers.tex,
				writer.atlas.texture_info,
			) or_return
			text.writer_draw(&writer, canvas_w) or_return
		}
		{
			writer := g_state.writer_dpr
			text_shader_use(
				g_state.shader,
				uniforms,
				writer.buffers.pos,
				writer.buffers.tex,
				writer.atlas.texture_info,
			) or_return
			text.writer_draw(&writer, canvas_w) or_return
		}
		{
			writer := g_state.writer_size
			text_shader_use(
				g_state.shader,
				uniforms,
				writer.buffers.pos,
				writer.buffers.tex,
				writer.atlas.texture_info,
			) or_return
			text.writer_draw(&writer, canvas_w) or_return
		}
		{
			writer := g_state.writer_res
			text_shader_use(
				g_state.shader,
				uniforms,
				writer.buffers.pos,
				writer.buffers.tex,
				writer.atlas.texture_info,
			) or_return
			text.writer_draw(&writer, canvas_w) or_return
		}
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

	update(&g_state, dt)

	ok := draw(dt)
	if (!ok) {return false}

	keep_going = check_gl_error()
	return
}

// --- input

on_key_down :: proc(e: js.Event) {
	// fmt.println("on_key_down:", e)
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

check_gl_error :: utils.check_gl_error

