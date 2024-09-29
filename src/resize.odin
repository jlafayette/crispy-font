package game

foreign import odin_resize "odin_resize"


import "../shared/text"
import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "vendor:wasm/js"

SizeInfo :: struct {
	window_inner_width:  f32,
	window_inner_height: f32,
	rect_width:          f32,
	rect_height:         f32,
	rect_left:           f32,
	rect_top:            f32,
	dpr:                 f32,
}

update_size_info :: proc() -> SizeInfo {
	@(default_calling_convention = "contextless")
	foreign odin_resize {
		@(link_name = "updateSizeInfo")
		_updateSizeInfo :: proc(out: ^[7]f64) ---
	}
	out: [7]f64
	_updateSizeInfo(&out)
	return {
		window_inner_width = f32(out[0]),
		window_inner_height = f32(out[1]),
		rect_width = f32(out[2]),
		rect_height = f32(out[3]),
		rect_left = f32(out[4]),
		rect_top = f32(out[5]),
		dpr = f32(out[6]),
	}
}

on_resize :: proc(e: js.Event) {
	resize()
}

_prev_sizes: SizeInfo


resize :: proc() {
	sizes := update_size_info()
	if sizes.dpr != _prev_sizes.dpr {
		g_state.zoom_changed = true
	} else if sizes.window_inner_width != _prev_sizes.window_inner_width ||
	   sizes.window_inner_height != _prev_sizes.window_inner_height {
		g_state.size_changed = true
	}
	window_size: [2]f32 = {sizes.window_inner_width, sizes.window_inner_height}
	canvas_size: [2]f32 = {sizes.rect_width, sizes.rect_height}
	canvas_pos: [2]f32 = {sizes.rect_left, sizes.rect_top}
	canvas_res: [2]f32 = {sizes.rect_width * sizes.dpr, sizes.rect_height * sizes.dpr}
	aspect_ratio: f32 = sizes.rect_width / sizes.rect_height

	g_state.window_size = {i32(math.round(window_size.x)), i32(math.round(window_size.y))}
	g_state.canvas_size = {i32(math.round(canvas_size.x)), i32(math.round(canvas_size.y))}
	g_state.canvas_pos = {i32(math.round(canvas_pos.x)), i32(math.round(canvas_pos.y))}
	g_state.canvas_res = {i32(math.round(canvas_res.x)), i32(math.round(canvas_res.y))}
	g_state.aspect_ratio = aspect_ratio
	g_state.dpr = sizes.dpr

	_prev_sizes = sizes
}

