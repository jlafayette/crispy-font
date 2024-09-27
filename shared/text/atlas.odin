package text

import "../utils"
import "core:bytes"
import "core:fmt"
import "core:image"
import "core:image/bmp"
import "core:image/png"
import gl "vendor:wasm/WebGL"

// Run assets/t.odin script first
atlas_20_data := #load("../../assets/data/data-20.jatlas")
atlas_30_data := #load("../../assets/data/data-30.jatlas")
atlas_40_data := #load("../../assets/data/data-40.jatlas")

Atlas :: struct {
	w:            i32,
	h:            i32,
	header:       Header,
	chars:        []Char,
	pixels:       [][1]u8,
	texture_info: TextureInfo,
}
Atlases :: [AtlasSize]Atlas
AtlasSize :: enum {
	A20,
	A30,
	A40,
}
TextureInfo :: utils.TextureInfo

g_atlases: Atlases
g_initialized: bool = false

@(private)
init :: proc(atlases: ^Atlases) -> (ok: bool) {
	if g_initialized {
		return true
	}
	for &a, size in g_atlases {
		atlas_data: []byte
		switch size {
		case .A20:
			atlas_data = atlas_20_data
		case .A30:
			atlas_data = atlas_30_data
		case .A40:
			atlas_data = atlas_40_data
		}
		header: Header
		chars: [dynamic]Char
		pixels: [dynamic][1]u8
		header, chars, pixels = decode(atlas_data, 1) or_return
		a.w = header.w
		a.h = header.h
		a.header = header
		a.chars = chars[:]
		a.pixels = pixels[:]
		a.texture_info.id = load_texture(a.w, a.h, pixels[:])
		a.texture_info.unit = gl.TEXTURE0
	}
	g_initialized = true
	return ok
}

@(private = "file")
load_texture :: proc(w, h: i32, pixels: [][1]u8) -> gl.Texture {
	alignment: i32 = 1
	gl.PixelStorei(gl.UNPACK_ALIGNMENT, alignment)
	texture := gl.CreateTexture()
	gl.BindTexture(gl.TEXTURE_2D, texture)
	gl.TexImage2DSlice(gl.TEXTURE_2D, 0, gl.ALPHA, w, h, 0, gl.ALPHA, gl.UNSIGNED_BYTE, pixels[:])
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, cast(i32)gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, cast(i32)gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, cast(i32)gl.LINEAR)
	return texture
}
@(private = "file")
is_power_of_two :: proc(n: int) -> bool {
	return (n & (n - 1)) == 0
}

