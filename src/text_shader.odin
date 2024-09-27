package game

import "../shared/utils"
import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"

text_vert_source := #load("text.vert", string)
text_frag_source := #load("text.frag", string)

TextShader :: struct {
	program:      gl.Program,
	a_pos:        i32,
	a_tex:        i32,
	u_projection: i32,
	u_sampler:    i32,
	u_text_color: i32,
}
TextUniforms :: struct {
	projection: glm.mat4,
	color:      glm.vec3,
}
TextureInfo :: utils.TextureInfo

text_shader_init :: proc(s: ^TextShader) -> (ok: bool) {
	program: gl.Program
	program, ok = gl.CreateProgramFromStrings({text_vert_source}, {text_frag_source})
	if !ok {
		fmt.eprintln("Failed to create program")
		return false
	}
	s.program = program

	s.a_pos = gl.GetAttribLocation(program, "aPos")
	s.a_tex = gl.GetAttribLocation(program, "aTex")
	s.u_projection = gl.GetUniformLocation(program, "uProjection")
	s.u_sampler = gl.GetUniformLocation(program, "uSampler")
	s.u_text_color = gl.GetUniformLocation(program, "uTextColor")

	return check_gl_error()
}
text_shader_use :: proc(
	s: TextShader,
	u: TextUniforms,
	buffer_pos: Buffer,
	buffer_tex: Buffer,
	texture: TextureInfo,
) -> (
	ok: bool,
) {
	gl.UseProgram(s.program)
	// set attributes
	shader_set_attribute(s.a_pos, buffer_pos)
	shader_set_attribute(s.a_tex, buffer_tex)

	// set uniforms
	gl.UniformMatrix4fv(s.u_projection, u.projection)
	gl.Uniform3fv(s.u_text_color, u.color)

	// bind texture
	gl.ActiveTexture(texture.unit)
	gl.BindTexture(gl.TEXTURE_2D, texture.id)
	gl.Uniform1i(s.u_sampler, 0)

	return check_gl_error()
}
shader_set_attribute :: proc(index: i32, b: Buffer) {
	gl.BindBuffer(b.target, b.id)
	gl.VertexAttribPointer(index, b.size, b.type, false, 0, 0)
	gl.EnableVertexAttribArray(index)
}

