extends Node
## Autoload "GameCursor": kursor mouse kustom bergaya futuristik (anak panah kristal neon).
## - Gambar kursor dibuat lewat kode (tanpa file gambar), jadi tidak ada aset yang perlu ditambah.
## - SEMUA bentuk kursor (panah, tangan/pointer, teks, dll) dipetakan ke gambar yang sama,
##   jadi kursor tetap sama di semua tombol dan tidak berubah menjadi pointer.
## - Saat tombol mouse ditekan, kursor menyala lebih terang (efek klik).
## - Warna kursor bisa diganti (SETTINGS > CURSOR COLOR). Pilihan disimpan di Global.cursor_color.

const SIZE := 48            # ukuran gambar kursor (piksel layar)
const GRID := 32.0          # ukuran kanvas gambar logis (titik-titik poligon di bawah memakai skala ini)
const SS := 4               # supersampling untuk tepi yang halus
const SHAPE_COUNT := 17     # jumlah bentuk kursor bawaan Godot (CURSOR_ARROW .. CURSOR_HELP)

## Pilihan warna: [nama, hue (0..1), pengali saturasi]. Urutan = indeks Global.cursor_color.
const PALETTES := [
	["CYAN", 0.53, 1.0],
	["SKY BLUE", 0.60, 1.0],
	["VIOLET", 0.75, 1.0],
	["MAGENTA", 0.88, 1.0],
	["RED", 0.99, 1.0],
	["ORANGE", 0.07, 1.0],
	["GOLD", 0.13, 1.0],
	["LIME", 0.28, 1.0],
	["MINT", 0.42, 1.0],
	["WHITE", 0.0, 0.0],
]

# Poligon kursor: ujung, sayap kanan, lekukan tengah, sayap bawah (ujung = titik klik / hotspot)
var _poly := PackedVector2Array([
	Vector2(4.0, 4.0), Vector2(27.0, 10.0), Vector2(13.0, 13.0), Vector2(10.0, 27.0)
])
var _tip := Vector2(4.0, 4.0)

var _pal: int = 0
var _cache := {}            # "palet_hot_ukuran" -> ImageTexture (untuk preview)
var _images := {}           # "palet_hot_ukuran" -> Image (untuk kursor asli)
var _img_normal: Image
var _img_hot: Image
var _hot := false
var _applied_once := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pal = clampi(Global.cursor_color, 0, PALETTES.size() - 1)
	_img_normal = _image(_pal, false, SIZE)
	_img_hot = _image(_pal, true, SIZE)
	_apply(false)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		# Roda scroll dikirim Godot sebagai "tombol ditekan"; harus diabaikan, kalau tidak kursor
		# berkedip seperti diklik dan patah-patah setiap scroll.
		if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT \
				and mb.button_index != MOUSE_BUTTON_MIDDLE:
			return
		if mb.pressed:
			_apply(true)
		elif Input.get_mouse_button_mask() == 0:
			_apply(false)


## Daftar nama warna (untuk baris pengaturan).
func palette_names() -> Array:
	var out: Array = []
	for p in PALETTES:
		out.append(String(p[0]))
	return out


## Ganti warna kursor SEKARANG juga (dipakai SETTINGS: langsung terlihat sebelum disimpan).
func set_palette(i: int) -> void:
	_pal = clampi(i, 0, PALETTES.size() - 1)
	_img_normal = _image(_pal, false, SIZE)
	_img_hot = _image(_pal, true, SIZE)
	_applied_once = false
	_apply(_hot)


## Gambar kursor untuk palet / keadaan / ukuran tertentu (di-cache). Dipakai juga oleh kotak PREVIEW di SETTINGS.
func texture(pal: int, hot: bool, size: int) -> ImageTexture:
	var p: int = clampi(pal, 0, PALETTES.size() - 1)
	var key := "%d_%d_%d" % [p, 1 if hot else 0, size]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_image(p, hot, size))
	return _cache[key]


## Image kursor untuk palet / keadaan / ukuran tertentu (di-cache).
func _image(pal: int, hot: bool, size: int) -> Image:
	var key := "%d_%d_%d" % [pal, 1 if hot else 0, size]
	if not _images.has(key):
		_images[key] = _render(pal, hot, size)
	return _images[key]


## Pasang gambar kursor ke SEMUA bentuk kursor Godot.
func _apply(hot: bool) -> void:
	if _img_normal == null:
		return
	if hot == _hot and _applied_once:
		return
	_hot = hot
	_applied_once = true
	var img: Image = _img_hot if hot else _img_normal
	var hotspot: Vector2 = _tip * (float(SIZE) / GRID)
	for s in range(SHAPE_COUNT):
		Input.set_custom_mouse_cursor(img, s as Input.CursorShape, hotspot)


# ------------------------------------------------------------------ MENGGAMBAR KURSOR

func _edge_dist(p: Vector2) -> float:
	var best := 1e9
	var n := _poly.size()
	for i in range(n):
		var c: Vector2 = Geometry2D.get_closest_point_to_segment(p, _poly[i], _poly[(i + 1) % n])
		best = minf(best, p.distance_to(c))
	return best


func _render(pal: int, hot: bool, size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var sc: float = float(size) / GRID
	var h: float = float(PALETTES[pal][1])
	var sm: float = float(PALETTES[pal][2])

	# warna turunan dari hue palet
	var glow_col := Color.from_hsv(h, 0.75 * sm, 1.0)
	var rim_col := Color.from_hsv(h, 0.15 * sm, 1.0)
	var c_hi := Color.from_hsv(h, 0.22 * sm, 1.0)
	var c_mid := Color.from_hsv(h, 0.90 * sm, 0.95)
	var c_d1 := Color.from_hsv(h, 0.88 * sm, 0.85)
	var c_d2 := Color.from_hsv(h, 0.90 * sm, 0.45)
	if sm <= 0.0:   # putih / perak
		c_mid = Color(0.75, 0.78, 0.82)
		c_d1 = Color(0.50, 0.53, 0.58)
		c_d2 = Color(0.20, 0.22, 0.27)
	var white := Color(1.0, 1.0, 1.0)
	var glow_amp: float = 0.55
	if hot:
		glow_col = glow_col.lerp(white, 0.6)
		rim_col = white
		glow_amp = 0.85

	for y in range(size):
		for x in range(size):
			var g := Vector2((x + 0.5) / sc, (y + 0.5) / sc)
			var ins: bool = Geometry2D.is_point_in_polygon(g, _poly)
			var d: float = _edge_dist(g)

			# cakupan bentuk (anti-alias hanya dihitung dekat tepi supaya cepat)
			var cov := 0.0
			if d > 1.0:
				cov = 1.0 if ins else 0.0
			else:
				var hits := 0
				for sy in range(SS):
					for sx in range(SS):
						var sp := Vector2((x + (sx + 0.5) / SS) / sc, (y + (sy + 0.5) / SS) / sc)
						if Geometry2D.is_point_in_polygon(sp, _poly):
							hits += 1
				cov = float(hits) / float(SS * SS)

			# cahaya neon di luar (dan sedikit di dalam) bentuk
			var ga: float = glow_amp * 0.5 if ins else glow_amp * exp(-d / 1.7)
			var out_rgb := Vector3(glow_col.r, glow_col.g, glow_col.b)
			var out_a: float = ga

			if cov > 0.0:
				var t: float = clampf(g.distance_to(_tip) / 24.0, 0.0, 1.0)
				var col: Color
				if g.x - g.y >= 0.0:
					col = c_hi.lerp(c_mid, t)     # sisi atas (terang)
				else:
					col = c_d1.lerp(c_d2, t)      # sisi bawah (gelap)
				# garis kilau di tengah (rusuk kristal)
				var rd: float = absf(g.x - g.y) / 1.414
				var ridge: float = clampf(1.0 - rd / 1.2, 0.0, 1.0) * (1.0 - t * 0.7)
				col = col.lerp(white, ridge * 0.6)
				# tepi terang
				var inner: float = d if ins else 0.0
				var rim: float = clampf(1.0 - inner / 1.3, 0.0, 1.0)
				col = col.lerp(rim_col, rim * 0.85)
				if hot:
					col = col.lerp(white, 0.25)
				# gabungkan bentuk di atas cahaya
				var a_o: float = cov + out_a * (1.0 - cov)
				if a_o > 0.0:
					var cs := Vector3(col.r, col.g, col.b)
					out_rgb = (cs * cov + out_rgb * out_a * (1.0 - cov)) / a_o
					out_a = a_o

			img.set_pixel(x, y, Color(
				clampf(out_rgb.x, 0.0, 1.0), clampf(out_rgb.y, 0.0, 1.0),
				clampf(out_rgb.z, 0.0, 1.0), clampf(out_a, 0.0, 1.0)))

	return img
