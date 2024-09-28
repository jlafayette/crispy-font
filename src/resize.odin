package game

foreign import odin_resize "odin_resize"


import "../shared/text"
import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "vendor:wasm/js"

CanvasSize :: struct {
	window_inner_width:  f32,
	window_inner_height: f32,
	rect_width:          f32,
	rect_height:         f32,
	rect_left:           f32,
	rect_top:            f32,
	dpr:                 f32,
}

update_canvas_size :: proc() -> CanvasSize {
	@(default_calling_convention = "contextless")
	foreign odin_resize {
		@(link_name = "updateCanvasSize")
		_updateCanvasSize :: proc(out: ^[7]f64) ---
	}
	out: [7]f64
	_updateCanvasSize(&out)
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

_prev_sizes: CanvasSize


resize :: proc() {
	sizes := update_canvas_size()
	if sizes.dpr != _prev_sizes.dpr {
		fmt.println("zoom changed")
	} else if sizes.window_inner_width != _prev_sizes.window_inner_width ||
	   sizes.window_inner_height != _prev_sizes.window_inner_height {
		fmt.println("window size changed")
	}
	// fmt.println("on_resize:", sizes)
	window_size: [2]f32 = {sizes.window_inner_width, sizes.window_inner_height}
	canvas_size: [2]f32 = {math.round(sizes.rect_width), math.round(sizes.rect_height)}
	canvas_pos: [2]f32 = {math.round(sizes.rect_left), math.round(sizes.rect_top)}
	canvas_res: [2]i32 = {
		i32(math.round(sizes.rect_width * sizes.dpr)),
		i32(math.round(sizes.rect_height * sizes.dpr)),
		// i32(math.round(sizes.rect_width)),
		// i32(math.round(sizes.rect_height)),
	}
	aspect_ratio: f32 = sizes.rect_width / sizes.rect_height

	g_state.window_size = window_size
	g_state.canvas_size = canvas_size
	g_state.canvas_pos = canvas_pos
	g_state.canvas_res = canvas_res
	g_state.aspect_ratio = aspect_ratio

	_prev_sizes = sizes

	// text.writer_update_buffer_data(&g_state.writer_20, canvas_size.x)
	// text.writer_update_buffer_data(&g_state.writer_30, canvas_size.x)
	// text.writer_update_buffer_data(&g_state.writer_40, canvas_size.x)
}

