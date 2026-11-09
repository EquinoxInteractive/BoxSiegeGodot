class_name FxShaders
extends RefCounted
## Shader animasi skin karakter LV3 + gelombang scarf + shader korban finisher.
## Waktu disuplai lewat uniform `fx_t` (bukan TIME) supaya replay yang dijeda / dilambatkan ikut membeku / melambat.

const SKIN_COMMON := """
shader_type canvas_item;
uniform float fx_t = 0.0;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash21(i); float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0)); float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}
float inner(vec2 uv) {   // 0 di bingkai, 1 di dalam (bingkai tidak ikut bergoyang)
	return smoothstep(0.05, 0.11, uv.x) * smoothstep(0.05, 0.11, 1.0 - uv.x) * smoothstep(0.05, 0.11, uv.y) * smoothstep(0.05, 0.11, 1.0 - uv.y);
}
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
"""

const SKIN_CODE := {
	"solar": """
void fragment() {
	float m = inner(UV);
	vec2 uv = UV;
	uv.x += sin(uv.y * 20.0 + fx_t * 3.4) * 0.0065 * m;
	uv.y += sin(uv.x * 17.0 - fx_t * 2.6) * 0.0045 * m;
	vec4 c = texture(TEXTURE, uv);
	float pulse = 0.5 + 0.5 * sin(fx_t * 2.6);
	c.rgb *= 1.0 + 0.10 * pulse;
	float band = exp(-pow((uv.x + uv.y * 0.6 - fract(fx_t * 0.22) * 2.4 + 0.2) * 5.5, 2.0));
	c.rgb += band * vec3(1.0, 0.72, 0.25) * 0.5 * m;
	float fl = noise2(uv * 9.0 + vec2(0.0, -fx_t * 2.4));
	c.rgb += pow(luma(c.rgb), 2.0) * fl * vec3(0.35, 0.16, 0.0) * m;
	COLOR = c * COLOR;
}
""",
	"void": """
void fragment() {
	float m = inner(UV);
	vec2 d = UV - vec2(0.5, 0.53);
	float r = length(d) + 0.0001;
	vec2 uv = UV + normalize(d) * sin(r * 38.0 - fx_t * 4.2) * 0.0042 * m;
	vec4 c = texture(TEXTURE, uv);
	float sweep = exp(-pow((r - fract(fx_t * 0.28) * 0.8) * 16.0, 2.0));
	c.rgb += sweep * vec3(0.55, 0.15, 0.95) * 0.6 * m;
	c.rgb += vec3(0.16, 0.02, 0.28) * (0.5 + 0.5 * sin(fx_t * 1.7 + r * 8.0)) * m * 0.7;
	float g = step(0.985, hash21(vec2(floor(fx_t * 10.0), floor(UV.y * 28.0))));
	c.rgb = mix(c.rgb, c.rgb.bgr * 1.3, g * m);
	COLOR = c * COLOR;
}
""",
	"storm": """
void fragment() {
	float m = inner(UV);
	float flash = pow(max(0.0, sin(fx_t * 7.3) * sin(fx_t * 3.1 + 1.0)), 10.0);
	vec2 uv = UV + vec2((hash21(vec2(floor(fx_t * 24.0), UV.y * 40.0)) - 0.5) * 0.012 * flash, 0.0) * m;
	vec4 c = texture(TEXTURE, uv);
	c.rgb += vec3(0.55, 0.78, 1.0) * flash * 0.75 * m;
	float scan = exp(-pow((UV.y - fract(fx_t * 0.55)) * 14.0, 2.0));
	c.rgb += scan * vec3(0.22, 0.48, 0.95) * 0.6 * m;
	float ar = step(0.965, noise2(vec2(UV.x * 24.0, floor(fx_t * 14.0)))) * step(0.5, hash21(vec2(floor(fx_t * 14.0), 3.0)));
	c.rgb += ar * vec3(0.8, 0.9, 1.0) * 0.5 * m;
	COLOR = c * COLOR;
}
""",
	"holo": """
vec3 hue_shift(vec3 col, float a) {
	const vec3 k = vec3(0.57735);
	float ca = cos(a); float sa = sin(a);
	return col * ca + cross(k, col) * sa + k * dot(k, col) * (1.0 - ca);
}
void fragment() {
	float m = inner(UV);
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(c.rgb, hue_shift(c.rgb, fx_t * 1.4 + UV.x * 2.0), m);
	float band = exp(-pow((UV.x + UV.y - fract(fx_t * 0.28) * 3.0 + 0.6) * 6.0, 2.0));
	c.rgb += band * vec3(1.0) * 0.55 * m;
	float sp = step(0.992, hash21(floor(UV * 46.0) + floor(fx_t * 6.0)));
	c.rgb += sp * 0.8 * m;
	COLOR = c * COLOR;
}
""",
	"spirit": """
void fragment() {
	float m = inner(UV);
	vec2 uv = UV;
	uv.x += sin(uv.y * 7.0 + fx_t * 1.7) * 0.005 * m;
	uv.y += sin(uv.x * 6.0 + fx_t * 1.3) * 0.004 * m;
	vec4 c = texture(TEXTURE, uv);
	float br = 0.5 + 0.5 * sin(fx_t * 1.6);
	c.rgb += pow(luma(c.rgb), 3.0) * vec3(1.0, 0.45, 0.72) * (0.18 + 0.28 * br) * m;
	float band = exp(-pow((uv.y - fract(fx_t * 0.16)) * 7.0, 2.0));
	c.rgb += band * vec3(0.55, 1.0, 0.82) * 0.28 * m;
	float orb = smoothstep(0.93, 1.0, noise2(uv * 12.0 + vec2(fx_t * 0.4, -fx_t * 0.9)));
	c.rgb += orb * vec3(1.0, 0.8, 0.9) * 0.5 * m;
	COLOR = c * COLOR;
}
""",
}

## Gelombang untuk aksesoris kain (scarf): ujung kain bergoyang.
const WAVE_CODE := """
shader_type canvas_item;
uniform float fx_t = 0.0;
void fragment() {
	vec2 uv = UV;
	float k = smoothstep(0.55, 0.95, UV.y) * 0.9 + smoothstep(0.1, 0.9, UV.y) * 0.15;
	uv.x += sin(UV.y * 22.0 - fx_t * 5.0) * 0.012 * k;
	uv.y += sin(UV.x * 18.0 + fx_t * 3.5) * 0.006 * k;
	COLOR = texture(TEXTURE, uv) * COLOR;
}
"""

## Korban finisher: mode 0 = normal, 1 = pelarutan (dissolve dengan tepi menyala), 2 = glitch (potongan geser + RGB split)
const VICTIM_CODE := """
shader_type canvas_item;
uniform float fx_t = 0.0;
uniform int mode = 0;
uniform float amount = 0.0;
uniform vec4 edge_col : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
float hash21(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash21(i); float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0)); float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (mode == 1) {
		float n = noise2(UV * 11.0) * 0.6 + noise2(UV * 27.0) * 0.4;
		float th = amount * 1.2 - 0.1;
		if (n < th) { c.a = 0.0; }
		float edge = smoothstep(th, th + 0.09, n) * (1.0 - smoothstep(th + 0.09, th + 0.2, n));
		c.rgb = mix(c.rgb, edge_col.rgb, clamp(edge * 1.4, 0.0, 1.0));
		c.rgb += edge * edge_col.rgb * 0.7;
	} else if (mode == 2) {
		float row = floor(UV.y * 22.0);
		float rnd = hash21(vec2(row, floor(fx_t * 14.0)));
		float sh = (rnd - 0.5) * 0.28 * amount * step(0.45, rnd);
		vec4 r = texture(TEXTURE, UV + vec2(sh + 0.02 * amount, 0.0));
		vec4 g = texture(TEXTURE, UV + vec2(sh, 0.0));
		vec4 b = texture(TEXTURE, UV + vec2(sh - 0.02 * amount, 0.0));
		c = vec4(r.r, g.g, b.b, max(max(r.a, g.a), b.a));
		c.rgb += amount * 0.25 * step(0.9, hash21(vec2(row, fx_t)));
	}
	COLOR = c * tint * COLOR;
}
"""

static var _cache: Dictionary = {}


static func skin_material(style: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SKIN_COMMON + String(SKIN_CODE.get(style, SKIN_CODE["holo"]))
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


static func wave_material() -> ShaderMaterial:
	if not _cache.has("wave"):
		var sh := Shader.new()
		sh.code = WAVE_CODE
		_cache["wave"] = sh
	var m := ShaderMaterial.new()
	m.shader = _cache["wave"]
	return m


static func victim_material() -> ShaderMaterial:
	if not _cache.has("victim"):
		var sh := Shader.new()
		sh.code = VICTIM_CODE
		_cache["victim"] = sh
	var m := ShaderMaterial.new()
	m.shader = _cache["victim"]
	return m


static func add_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m
