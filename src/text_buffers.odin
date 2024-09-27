package game
import "../shared/utils"
import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"

TextBuffers :: struct {
	pos:     Buffer,
	tex:     Buffer,
	indices: EaBuffer,
}
Buffer :: utils.Buffer
EaBuffer :: utils.EaBuffer
buffer_init :: utils.buffer_init
ea_buffer_init :: utils.ea_buffer_init
ea_buffer_draw :: utils.ea_buffer_draw

