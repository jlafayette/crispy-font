package game

import "../shared/text"
import "../shared/utils"
import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:mem"
import gl "vendor:wasm/WebGL"
import "vendor:wasm/js"

main :: proc() {}

LINE1 :: "!\"#$%&'()*+,-./0123456789:;<=>?@"
LINE2 :: "ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`"
LINE3 :: "abcdefghijklmnopqrstuvwxyz{|}~"
ALL_CHARS :: "!\"#$%&'()*+,-./0123456789:;<=>?@\nABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`\nabcdefghijklmnopqrstuvwxyz{|}~"

State :: struct {
	started:      bool,
	writer_20:    text.Writer(len(ALL_CHARS)),
	writer_30:    text.Writer(len(ALL_CHARS)),
	writer_40:    text.Writer(len(ALL_CHARS)),
	shader:       TextShader,
	canvas_res:   [2]i32,
	canvas_pos:   [2]f32,
	canvas_size:  [2]f32,
	window_size:  [2]f32,
	dpr:          f32,
	aspect_ratio: f32,
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

	on_resize({})
	// canvas_w: i32 = gl.DrawingBufferWidth()
	// canvas_h: i32 = gl.DrawingBufferHeight()
	// g_state.canvas_w = canvas_w
	// g_state.canvas_h = canvas_h
	canvas_w := g_state.canvas_size.x
	canvas_h := g_state.canvas_size.y

	{
		y: i32 = 20
		text.writer_init(
			&g_state.writer_20,
			.A20,
			20,
			y,
			ALL_CHARS,
			false,
			canvas_w,
			false,
		) or_return
		y += g_state.writer_20.overall_height + 30
		text.writer_init(
			&g_state.writer_30,
			.A30,
			20,
			y,
			ALL_CHARS,
			false,
			canvas_w,
			false,
		) or_return
		y += g_state.writer_30.overall_height + 40
		text.writer_init(
			&g_state.writer_40,
			.A40,
			20,
			y,
			ALL_CHARS,
			false,
			canvas_w,
			false,
		) or_return
	}

	text_shader_init(&g_state.shader)

	fmt.println("adding event listeners")
	js.add_window_event_listener(.Key_Down, {}, on_key_down)
	js.add_window_event_listener(.Resize, {}, on_resize)

	ok = check_gl_error()
	return
}

update :: proc(state: ^State, dt: f32) {
	// state.canvas_w = gl.DrawingBufferWidth()
	// state.canvas_h = gl.DrawingBufferHeight()
}

draw :: proc(dt: f32) -> (ok: bool) {
	on_resize({})
	canvas_w := g_state.canvas_size.x
	canvas_h := g_state.canvas_size.y
	// fmt.printf("canvas: %.2fx%.2f\n", canvas_w, canvas_h)

	// gl.Viewport(0, 0, i32(g_state.canvas_size.x), i32(g_state.canvas_size.y))
	gl.Viewport(0, 0, g_state.canvas_res.x, g_state.canvas_res.y)
	fmt.printf("viewport: 0,0,%dx%d\n", g_state.canvas_res.x, g_state.canvas_res.y)

	gl.ClearColor(0.2, 0.2, 0.2, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.ClearDepth(1)
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	// projection_mat := glm.mat4Ortho3d(0, g_state.canvas_size.x, g_state.canvas_size.y, 0, -1, 1)
	projection_mat := glm.mat4Ortho3d(
		0,
		f32(g_state.canvas_res.x),
		f32(g_state.canvas_res.y),
		0,
		-1,
		1,
	)
	// fmt.println(projection_mat)
	{
		uniforms: TextUniforms = {
			projection = projection_mat,
			color      = {1, 1, 1},
		}
		{
			writer := g_state.writer_20
			text_shader_use(
				g_state.shader,
				uniforms,
				writer.buffers.pos,
				writer.buffers.tex,
				writer.atlas.texture_info,
			) or_return
			text.writer_draw(&writer, canvas_w, canvas_h) or_return
		}
		{
			writer := g_state.writer_30
			text_shader_use(
				g_state.shader,
				uniforms,
				writer.buffers.pos,
				writer.buffers.tex,
				writer.atlas.texture_info,
			) or_return
			text.writer_draw(&writer, canvas_w, canvas_h) or_return
		}
		{
			writer := g_state.writer_40
			text_shader_use(
				g_state.shader,
				uniforms,
				writer.buffers.pos,
				writer.buffers.tex,
				writer.atlas.texture_info,
			) or_return
			text.writer_draw(&writer, canvas_w, canvas_h) or_return
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

