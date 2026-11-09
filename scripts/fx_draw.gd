class_name FxDraw
extends RefCounted
## Pustaka gambar EFEK kosmetik. Semua partikel dihitung ANALITIK dari waktu `t` (tanpa menyimpan state):
## posisi partikel = fungsi(t, indeks, siklus). Akibatnya efek yang sama bisa digambar di game, Shop, Inventory
## dan Replay, dan selalu konsisten (replay dijeda -> efek ikut berhenti, loncat waktu -> tidak ada sisa partikel).
##
## Satuan:
##   char_fx  : "kotak karakter" 180x180, titik (0,0) = tengah badan.
##   weapon_fx: piksel, titik (0,0) = genggaman, +x = arah laras, panjang senjata = `length`.
##   acc_fx   : sama seperti char_fx (sprite aksesoris memakai kotak karakter 180x180 sebagai acuan).


# ================================================================== utilitas
## Pengali ukuran partikel (titik, garis, bintang...). 1.0 = preview besar (Shop/Inventory); di dalam game karakter hanya ~60 px
## (kotak 180 diperkecil 1/3) sehingga FxNode / FxAccSprite memasang K lebih besar supaya efeknya tetap terbaca.
static var K: float = 1.0


static func circ(ci: CanvasItem, p: Vector2, r: float, c: Color) -> void:
	ci.draw_circle(p, r * K, c)


static func lin(ci: CanvasItem, a: Vector2, b: Vector2, c: Color, w: float = 1.0) -> void:
	ci.draw_line(a, b, c, w * K)


static func arc_(ci: CanvasItem, cen: Vector2, r: float, a0: float, a1: float, n: int, c: Color, w: float = 1.0, aa: bool = false) -> void:
	ci.draw_arc(cen, r, a0, a1, n, c, w * K, aa)


static func h(i: float, salt: float = 0.0) -> float:
	return fposmod(sin(i * 12.9898 + salt * 78.233) * 43758.5453, 1.0)


## (u, siklus) partikel ke-i dari n dengan umur `life` detik: u = 0..1 progres hidupnya.
static func ph(t: float, i: int, n: int, life: float) -> Vector2:
	var x: float = t / life + float(i) / float(n)
	return Vector2(fposmod(x, 1.0), floorf(x))


static func rnd(i: int, cyc: float, salt: float) -> float:
	return h(float(i) + cyc * 17.31, salt)


static func ca(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, clampf(a, 0.0, 1.0))


static func hue(hh: float, a: float = 1.0, s: float = 0.6, v: float = 1.0) -> Color:
	return Color.from_hsv(fposmod(hh, 1.0), s, v, a)


static func glow_dot(ci: CanvasItem, p: Vector2, r: float, c: Color) -> void:
	r *= K
	ci.draw_circle(p, r * 2.6, ca(c, c.a * 0.12))
	ci.draw_circle(p, r * 1.6, ca(c, c.a * 0.28))
	ci.draw_circle(p, r, c)


static func star4(ci: CanvasItem, p: Vector2, r: float, c: Color) -> void:
	r *= K
	if r <= 0.05:
		return
	var q: float = r * 0.22
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(q, -q), p + Vector2(r, 0), p + Vector2(q, q),
		p + Vector2(0, r), p + Vector2(-q, q), p + Vector2(-r, 0), p + Vector2(-q, -q)]), c)


static func diamond(ci: CanvasItem, p: Vector2, rx: float, ry: float, c: Color, ang: float = 0.0) -> void:
	var pts := PackedVector2Array([Vector2(0, -ry * K), Vector2(rx * K, 0), Vector2(0, ry * K), Vector2(-rx * K, 0)])
	for k in pts.size():
		pts[k] = p + pts[k].rotated(ang)
	ci.draw_colored_polygon(pts, c)


static func petal(ci: CanvasItem, p: Vector2, r: float, ang: float, c: Color) -> void:
	r *= K
	var pts := PackedVector2Array()
	for k in 8:
		var a: float = float(k) / 8.0 * TAU
		pts.append(p + Vector2(cos(a) * r, sin(a) * r * 0.55).rotated(ang))
	ci.draw_colored_polygon(pts, c)


static func heart(ci: CanvasItem, p: Vector2, s: float, c: Color) -> void:
	s *= K
	var pts := PackedVector2Array()
	for k in 18:
		var a: float = float(k) / 18.0 * TAU
		var x: float = 16.0 * pow(sin(a), 3.0)
		var y: float = -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
		pts.append(p + Vector2(x, y) * (s / 16.0))
	ci.draw_colored_polygon(pts, c)


static func bolt(ci: CanvasItem, a: Vector2, b: Vector2, seed_: float, c: Color, w: float, segs: int = 7, jit: float = 8.0) -> void:
	var pts := PackedVector2Array()
	pts.append(a)
	var d: Vector2 = b - a
	var nrm: Vector2 = d.orthogonal().normalized()
	for k in range(1, segs):
		var f: float = float(k) / float(segs)
		pts.append(a + d * f + nrm * (h(float(k), seed_) - 0.5) * 2.0 * jit)
	pts.append(b)
	w *= K
	ci.draw_polyline(pts, ca(c, c.a * 0.28), w * 3.0, true)
	ci.draw_polyline(pts, c, w, true)
	ci.draw_polyline(pts, ca(Color.WHITE, c.a), maxf(w * 0.4, 1.0), true)


## posisi orbit: x, y, kedalaman (sin: >0 = di depan karakter)
static func orbit(t: float, speed: float, phase: float, rx: float, ry: float, cy: float = 0.0) -> Vector3:
	var a: float = t * speed + phase
	return Vector3(cos(a) * rx, sin(a) * ry + cy, sin(a))


static func ellipse_arc(ci: CanvasItem, rx: float, ry: float, tilt: float, a0: float, a1: float, c: Color, w: float) -> void:
	var pts := PackedVector2Array()
	var n: int = 24
	for k in n + 1:
		var a: float = lerpf(a0, a1, float(k) / float(n))
		pts.append(Vector2(cos(a) * rx, sin(a) * ry).rotated(tilt))
	ci.draw_polyline(pts, c, w, true)


static func ray_tri(ci: CanvasItem, ang: float, len_: float, spread: float, c: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(cos(ang - spread), sin(ang - spread)) * len_,
		Vector2(cos(ang + spread), sin(ang + spread)) * len_]), c)


# ================================================================== SKIN KARAKTER (LV2 partikel, LV3 animasi)
## front = true: lapisan depan (partikel, benda yang lewat di depan); false: lapisan belakang (aura, sinar, sisi belakang orbit).
static func char_fx(ci: CanvasItem, skin: String, lv: int, t: float, front: bool) -> void:
	if lv < 2:
		return
	var cs: Array = FxCatalog.char_colors(skin)
	var c1: Color = cs[0]
	var c2: Color = cs[1]
	var c3: Color = cs[2]
	match skin:
		"storm_caller": _c_storm(ci, lv, t, front, c1, c2, c3)
		"spirit_bloom": _c_spirit(ci, lv, t, front, c1, c2, c3)
		"prismatic": _c_prism(ci, lv, t, front)
		"solar_flare": _c_solar(ci, lv, t, front, c1, c2, c3)
		"void_walker": _c_void(ci, lv, t, front, c1, c2, c3)


static func _c_storm(ci: CanvasItem, lv: int, t: float, front: bool, c1: Color, c2: Color, c3: Color) -> void:
	if front:
		for i in 18:
			var p: Vector2 = ph(t, i, 18, 0.8)
			var a: float = rnd(i, p.y, 1.0) * TAU
			var r0: float = 30.0 + rnd(i, p.y, 2.0) * 56.0
			var dir := Vector2(cos(a), sin(a))
			var pos: Vector2 = dir * r0 + dir * p.x * 30.0
			var ln: float = 11.0 * (1.0 - p.x)
			var c: Color = c2.lerp(c3, p.x)
			lin(ci, pos, pos + dir * ln, ca(c, 1.0 - p.x), 2.4)
			circ(ci, pos, 1.6, ca(c3, 1.0 - p.x))
		for k in 4:
			var q: float = t * 1.6 + float(k) * 0.27
			var f: float = fposmod(q, 1.0)
			if f < 0.22:
				var sd: float = floorf(q) * 7.0 + float(k)
				var ang: float = h(float(k), sd) * TAU
				var s0 := Vector2(cos(ang), sin(ang)) * 84.0
				var s1: Vector2 = s0 + Vector2(cos(ang + 1.0 + h(sd, 3.0)), sin(ang + 1.0 + h(sd, 3.0))) * 26.0
				bolt(ci, s0, s1, sd, ca(c1, 1.0 - f / 0.22), 2.0, 4, 5.0)
		if lv >= 3:
			for k in 3:
				var o: Vector3 = orbit(t, 2.3, float(k) * TAU / 3.0, 100.0, 56.0, 0.0)
				if o.z >= 0.0:
					glow_dot(ci, Vector2(o.x, o.y), 5.0, ca(c1, 0.95))
					circ(ci, Vector2(o.x, o.y), 2.0, c3)
			var sd2: float = floorf(t * 8.0)
			for k in 3:
				var o1: Vector3 = orbit(t, 2.3, float(k) * TAU / 3.0, 100.0, 56.0, 0.0)
				var o2: Vector3 = orbit(t, 2.3, float(k + 1) * TAU / 3.0, 100.0, 56.0, 0.0)
				if o1.z >= 0.0 and o2.z >= 0.0 and h(sd2, float(k)) > 0.45:
					bolt(ci, Vector2(o1.x, o1.y), Vector2(o2.x, o2.y), sd2 + float(k), ca(c1, 0.8), 1.6, 6, 7.0)
			var cyc: float = floorf(t / 2.6)
			var qq: float = fposmod(t, 2.6)
			if qq < 0.22:
				var rx: float = (h(cyc, 5.0) - 0.5) * 130.0
				var fl: float = 1.0 - qq / 0.22
				bolt(ci, Vector2(rx, -150.0), Vector2(rx * 0.3, -6.0), cyc * 3.0 + floorf(qq * 40.0), ca(c1, fl), 5.0, 9, 12.0)
	else:
		if lv >= 3:
			arc_(ci, Vector2.ZERO, 98.0 + 3.0 * sin(t * 4.0), 0.0, TAU, 48, ca(c1, 0.22 + 0.1 * sin(t * 9.0)), 4.0, true)
			for k in 3:
				var o: Vector3 = orbit(t, 2.3, float(k) * TAU / 3.0, 100.0, 56.0, 0.0)
				if o.z < 0.0:
					glow_dot(ci, Vector2(o.x, o.y), 4.0, ca(c1, 0.6))


static func _c_spirit(ci: CanvasItem, lv: int, t: float, front: bool, c1: Color, c2: Color, c3: Color) -> void:
	if front:
		for i in 14:
			var p: Vector2 = ph(t, i, 14, 3.2)
			var x0: float = (rnd(i, p.y, 1.0) - 0.5) * 190.0
			var pos := Vector2(x0 + sin(p.x * TAU * 1.5 + rnd(i, p.y, 2.0) * 6.0) * 14.0, -105.0 + p.x * 210.0)
			var ang: float = p.x * TAU * 2.0 + rnd(i, p.y, 3.0) * 6.0
			var c: Color = c1.lerp(Color.WHITE, rnd(i, p.y, 4.0) * 0.5)
			petal(ci, pos, 5.0 + 3.0 * rnd(i, p.y, 5.0), ang, ca(c, sin(p.x * PI) * 0.95))
		for i in 8:
			var p: Vector2 = ph(t, i, 8, 2.8)
			var pos := Vector2((rnd(i, p.y, 1.0) - 0.5) * 170.0 + sin(p.x * 9.0 + float(i)) * 6.0, 95.0 - p.x * 195.0)
			var c: Color = c2.lerp(c3, rnd(i, p.y, 2.0))
			glow_dot(ci, pos, 1.6 + 1.8 * rnd(i, p.y, 3.0), ca(c, sin(p.x * PI)))
		if lv >= 3:
			for k in 3:
				for j in 7:
					var o: Vector3 = orbit(t - float(j) * 0.07, 1.4, float(k) * TAU / 3.0, 100.0, 54.0, -4.0)
					if o.z >= 0.0:
						var fade: float = 1.0 - float(j) / 7.0
						glow_dot(ci, Vector2(o.x, o.y), 4.6 * fade + 0.8, ca(c2.lerp(c3, fade), fade * 0.9))
	else:
		if lv >= 3:
			var br: float = 0.5 + 0.5 * sin(t * 1.6)
			for k in 4:
				ci.draw_circle(Vector2.ZERO, 108.0 - float(k) * 14.0 + 5.0 * br, ca(c2, 0.05 + 0.03 * br))
			for k in 3:
				for j in 7:
					var o: Vector3 = orbit(t - float(j) * 0.07, 1.4, float(k) * TAU / 3.0, 100.0, 54.0, -4.0)
					if o.z < 0.0:
						var fade: float = 1.0 - float(j) / 7.0
						glow_dot(ci, Vector2(o.x, o.y), 3.4 * fade + 0.6, ca(c2, fade * 0.55))


static func _c_prism(ci: CanvasItem, lv: int, t: float, front: bool) -> void:
	if front:
		for i in 16:
			var p: Vector2 = ph(t, i, 16, 1.2)
			var pos := Vector2((rnd(i, p.y, 1.0) - 0.5) * 190.0, (rnd(i, p.y, 2.0) - 0.5) * 190.0)
			var sz: float = sin(p.x * PI) * (4.0 + 8.0 * rnd(i, p.y, 3.0))
			star4(ci, pos, sz, hue(rnd(i, p.y, 4.0) + t * 0.25, 1.0, 0.45, 1.0))
		for i in 8:
			var p: Vector2 = ph(t, i, 8, 1.8)
			var a: float = rnd(i, p.y, 1.0) * TAU
			var pos: Vector2 = Vector2(cos(a), sin(a)) * (70.0 + p.x * 45.0)
			glow_dot(ci, pos, 2.6 * (1.0 - p.x) + 0.6, hue(rnd(i, p.y, 2.0) + t * 0.2, 1.0 - p.x))
		if lv >= 3:
			for k in 4:
				var o: Vector3 = orbit(t, 1.7, float(k) * TAU / 4.0, 100.0, 46.0, 0.0)
				if o.z >= 0.0:
					diamond(ci, Vector2(o.x, o.y), 6.0, 10.0, hue(t * 0.4 + float(k) * 0.25, 0.95, 0.5, 1.0), sin(t * 3.0 + float(k)) * 0.5)
					glow_dot(ci, Vector2(o.x, o.y), 2.0, Color(1, 1, 1, 0.9))
	else:
		if lv >= 3:
			for k in 8:
				ray_tri(ci, t * 0.35 + float(k) * TAU / 8.0, 150.0, 0.09, hue(float(k) / 8.0 + t * 0.15, 0.17, 0.7, 1.0))
			for k in 4:
				var o: Vector3 = orbit(t, 1.7, float(k) * TAU / 4.0, 100.0, 46.0, 0.0)
				if o.z < 0.0:
					diamond(ci, Vector2(o.x, o.y), 4.5, 8.0, hue(t * 0.4 + float(k) * 0.25, 0.6, 0.5, 1.0), sin(t * 3.0 + float(k)) * 0.5)


static func _c_solar(ci: CanvasItem, lv: int, t: float, front: bool, c1: Color, c2: Color, c3: Color) -> void:
	if front:
		for i in 24:
			var p: Vector2 = ph(t, i, 24, 1.5)
			var pos := Vector2((rnd(i, p.y, 1.0) - 0.5) * 170.0 + sin(p.x * 7.0 + rnd(i, p.y, 2.0) * 6.0) * 8.0, 90.0 - p.x * 205.0)
			var r: float = (1.2 + 2.4 * rnd(i, p.y, 3.0)) * (1.0 - p.x * 0.6)
			var c: Color = c1.lerp(c2, p.x)
			if r > 2.0:
				glow_dot(ci, pos, r, ca(c, 1.0 - p.x))
			else:
				circ(ci, pos, r, ca(c3.lerp(c, p.x), 1.0 - p.x))
		for i in 6:
			var p: Vector2 = ph(t, i, 6, 0.6)
			var a: float = rnd(i, p.y, 1.0) * TAU
			var dir := Vector2(cos(a), sin(a))
			var s0: Vector2 = dir * (76.0 + p.x * 26.0)
			lin(ci, s0, s0 + dir * 9.0 * (1.0 - p.x), ca(c3, 1.0 - p.x), 2.4)
		if lv >= 3:
			for k in 9:
				var x: float = -80.0 + float(k) * 20.0
				var hh: float = 24.0 + 10.0 * sin(t * 7.0 + float(k) * 1.7) + 6.0 * sin(t * 11.0 + float(k))
				var sw: float = sin(t * 5.0 + float(k)) * 4.0
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 10.0, 92.0), Vector2(x + sw, 92.0 - hh), Vector2(x + 10.0, 92.0)]), ca(c2, 0.55))
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 5.0, 92.0), Vector2(x + sw * 0.6, 92.0 - hh * 0.62), Vector2(x + 5.0, 92.0)]), ca(c3, 0.6))
	else:
		if lv >= 3:
			var pu: float = 0.5 + 0.5 * sin(t * 2.2)
			for k in 12:
				ray_tri(ci, t * 0.5 + float(k) * TAU / 12.0, 150.0 + 12.0 * pu, 0.12, ca(c1, 0.20))
			for k in 3:
				ci.draw_circle(Vector2.ZERO, 112.0 - float(k) * 12.0 + 6.0 * pu, ca(c1, 0.05))


static func _c_void(ci: CanvasItem, lv: int, t: float, front: bool, c1: Color, c2: Color, c3: Color) -> void:
	if front:
		for i in 20:
			var p: Vector2 = ph(t, i, 20, 1.9)
			var a: float = rnd(i, p.y, 1.0) * TAU + p.x * 3.2
			var r: float = 125.0 * (1.0 - p.x) + 14.0
			var pos := Vector2(cos(a) * r, sin(a) * r * 0.9)
			var al: float = minf(1.0, p.x * 3.0) * 0.95
			var c: Color = c1.lerp(c2, p.x)
			glow_dot(ci, pos, 3.0 * (1.0 - p.x) + 1.0, ca(c, al))
			circ(ci, pos, 1.0, ca(c3, al))
		for i in 5:
			var p: Vector2 = ph(t, i, 5, 2.4)
			var a: float = rnd(i, p.y, 1.0) * TAU
			var s0: Vector2 = Vector2(cos(a), sin(a)) * (90.0 - p.x * 30.0)
			var tg: Vector2 = Vector2(-sin(a), cos(a)) * 16.0
			lin(ci, s0, s0 + tg, ca(c1, sin(p.x * PI) * 0.8), 2.0)
		if lv >= 3:
			for i in 30:
				var a: float = float(i) * TAU / 30.0 + t * (0.9 + 0.5 * float(i % 3))
				if sin(a) > 0.0:
					var pos: Vector2 = Vector2(cos(a) * 112.0, sin(a) * 30.0).rotated(-0.25)
					glow_dot(ci, pos, 1.6 + 1.4 * h(float(i)), ca(c1.lerp(c2, h(float(i), 2.0)), 0.95))
			ellipse_arc(ci, 112.0, 30.0, -0.25, 0.0, PI, ca(c2, 0.35), 2.0)
	else:
		if lv >= 3:
			for i in 30:
				var a: float = float(i) * TAU / 30.0 + t * (0.9 + 0.5 * float(i % 3))
				if sin(a) <= 0.0:
					var pos: Vector2 = Vector2(cos(a) * 112.0, sin(a) * 30.0).rotated(-0.25)
					glow_dot(ci, pos, 1.4 + 1.2 * h(float(i)), ca(c1.lerp(c2, h(float(i), 2.0)), 0.7))
			ellipse_arc(ci, 112.0, 30.0, -0.25, PI, TAU, ca(c2, 0.28), 2.0)
			for k in 2:
				var u: float = fposmod(t / 2.2 + float(k) * 0.5, 1.0)
				arc_(ci, Vector2.ZERO, 135.0 - u * 95.0, 0.0, TAU, 40, ca(c2, sin(u * PI) * 0.5), 2.5, true)


# ================================================================== SENJATA (LV2 partikel)
## Digambar di sekitar senjata. Origin = genggaman, +x = laras, `length` = panjang senjata (piksel).
static func weapon_fx(ci: CanvasItem, fam: String, c1: Color, c2: Color, t: float, length: float) -> void:
	var L: float = maxf(length, 20.0)
	var mid := Vector2(L * 0.5, 0.0)
	match fam:
		"void":
			for i in 10:
				var p: Vector2 = ph(t, i, 10, 1.2)
				var st := Vector2(L * 0.5 + (rnd(i, p.y, 1.0) - 0.5) * (L + 28.0), (rnd(i, p.y, 2.0) - 0.5) * 34.0)
				var pos: Vector2 = st.lerp(mid, p.x)
				var al: float = minf(1.0, p.x * 3.0)
				glow_dot(ci, pos, 1.6 * (1.0 - p.x * 0.5) + 0.4, ca(c1.lerp(c2, p.x), al))
			for i in 3:
				var p: Vector2 = ph(t, i, 3, 1.1)
				var x: float = L * rnd(i, p.y, 3.0)
				ci.draw_line(Vector2(x, 2.0), Vector2(x + 2.0, 2.0 - 12.0 * p.x), ca(c1, (1.0 - p.x) * 0.8), 1.6)
		"storm":
			for i in 8:
				var p: Vector2 = ph(t, i, 8, 0.5)
				var x: float = L * rnd(i, p.y, 1.0)
				var a: float = rnd(i, p.y, 2.0) * TAU
				var s0 := Vector2(x, (rnd(i, p.y, 3.0) - 0.5) * 8.0)
				var dir := Vector2(cos(a), sin(a))
				ci.draw_line(s0 + dir * p.x * 8.0, s0 + dir * (p.x * 8.0 + 4.0 * (1.0 - p.x)), ca(c2.lerp(Color.WHITE, p.x), 1.0 - p.x), 1.6)
			var q: float = t * 3.4
			var f: float = fposmod(q, 1.0)
			if f < 0.5:
				var sd: float = floorf(q)
				var x0: float = (h(sd, 1.0)) * L * 0.6
				bolt(ci, Vector2(x0, (h(sd, 2.0) - 0.5) * 8.0), Vector2(x0 + 14.0 + h(sd, 3.0) * 8.0, (h(sd, 4.0) - 0.5) * 14.0), sd, ca(c1, 1.0 - f * 2.0), 1.4, 4, 3.0)
		"dragon", "magma":
			for i in 10:
				var p: Vector2 = ph(t, i, 10, 1.1)
				var pos := Vector2(L * rnd(i, p.y, 1.0) + sin(p.x * 6.0 + float(i)) * 2.0, 3.0 - p.x * 22.0)
				ci.draw_circle(pos, (0.9 + 1.5 * rnd(i, p.y, 2.0)) * (1.0 - p.x * 0.5), ca(c1.lerp(c2, p.x), 1.0 - p.x))
			var fl: float = 5.0 + 2.0 * sin(t * 18.0)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(L, -3.0), Vector2(L + fl + 2.0, 0.0), Vector2(L, 3.0)]), ca(c2, 0.55))
		"cyber":
			for i in 9:
				var p: Vector2 = ph(t, i, 9, 0.6)
				var gx: float = floorf(L * rnd(i, p.y, 1.0) / 2.0) * 2.0
				var gy: float = floorf(((rnd(i, p.y, 2.0) - 0.5) * 20.0) / 2.0) * 2.0
				var sz: float = 2.0 + floorf(rnd(i, p.y, 3.0) * 2.0)
				ci.draw_rect(Rect2(gx + p.x * 6.0, gy - p.x * 8.0, sz, sz), ca(c1 if rnd(i, p.y, 4.0) > 0.4 else c2, 1.0 - p.x))
			var gq: float = floorf(t * 9.0)
			if h(gq, 7.0) > 0.7:
				ci.draw_rect(Rect2(L * h(gq, 1.0) * 0.5, (h(gq, 2.0) - 0.5) * 10.0, L * 0.4, 1.4), ca(c2, 0.8))
		"crystal":
			for i in 8:
				var p: Vector2 = ph(t, i, 8, 0.9)
				var pos := Vector2(L * rnd(i, p.y, 1.0), (rnd(i, p.y, 2.0) - 0.5) * 12.0)
				star4(ci, pos, sin(p.x * PI) * 3.8, ca(c2, 1.0))
			for i in 4:
				var p: Vector2 = ph(t, i, 4, 1.3)
				var pos := Vector2(L * rnd(i, p.y, 5.0), 3.0 + p.x * 16.0)
				diamond(ci, pos, 1.3, 2.4, ca(c1, 1.0 - p.x), p.x * 3.0)
		"holy":
			for i in 8:
				var p: Vector2 = ph(t, i, 8, 1.6)
				var pos := Vector2(L * rnd(i, p.y, 1.0) + sin(p.x * 7.0 + float(i)) * 3.0, 2.0 - p.x * 20.0)
				petal(ci, pos, 2.6, p.x * 5.0 + float(i), ca(c2.lerp(c1, rnd(i, p.y, 2.0)), sin(p.x * PI)))
			for i in 4:
				var p: Vector2 = ph(t, i, 4, 0.9)
				star4(ci, Vector2(L * rnd(i, p.y, 6.0), (rnd(i, p.y, 7.0) - 0.5) * 10.0), sin(p.x * PI) * 3.0, ca(c1, 1.0))
		"blossom":
			for i in 8:
				var p: Vector2 = ph(t, i, 8, 1.5)
				var pos := Vector2(L * rnd(i, p.y, 1.0) + sin(p.x * 6.0 + float(i)) * 3.0, -8.0 + p.x * 26.0)
				petal(ci, pos, 2.8, p.x * 6.0 + float(i), ca(c1.lerp(c2, rnd(i, p.y, 2.0) * 0.6), sin(p.x * PI)))
		"nova":
			for i in 8:
				var p: Vector2 = ph(t, i, 8, 1.0)
				star4(ci, Vector2(L * rnd(i, p.y, 1.0), (rnd(i, p.y, 2.0) - 0.5) * 22.0), sin(p.x * PI) * 3.6, ca(c1.lerp(Color.WHITE, 0.5), 1.0))
			for k in 3:
				var o: Vector3 = orbit(t, 3.0, float(k) * TAU / 3.0, L * 0.62, 9.0, 0.0)
				glow_dot(ci, mid + Vector2(o.x, o.y), 1.4, ca(c2, 0.95))
		"venom":
			for i in 7:
				var p: Vector2 = ph(t, i, 7, 1.3)
				var pos := Vector2(L * rnd(i, p.y, 1.0), 2.0 - p.x * 16.0)
				ci.draw_arc(pos, 1.4 + 1.8 * p.x, 0.0, TAU, 10, ca(c1, 1.0 - p.x), 1.2, true)
			for i in 3:
				var p: Vector2 = ph(t, i, 3, 0.9)
				ci.draw_circle(Vector2(L * rnd(i, p.y, 4.0), 5.0 + p.x * p.x * 18.0), 1.4, ca(c2, 1.0 - p.x))
		"jackpot":
			for i in 5:
				var p: Vector2 = ph(t, i, 5, 1.2)
				var pos := Vector2(L * rnd(i, p.y, 1.0), 2.0 - p.x * 20.0)
				var sx: float = absf(cos(t * 9.0 + float(i))) * 2.6 + 0.4
				ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(-sx, -2.6), pos + Vector2(sx, -2.6), pos + Vector2(sx, 2.6), pos + Vector2(-sx, 2.6)]), ca(c1, 1.0 - p.x))
			for i in 4:
				var p: Vector2 = ph(t, i, 4, 0.8)
				star4(ci, Vector2(L * rnd(i, p.y, 6.0), (rnd(i, p.y, 7.0) - 0.5) * 10.0), sin(p.x * PI) * 3.2, ca(c2, 1.0))
		"prism":
			for i in 10:
				var p: Vector2 = ph(t, i, 10, 0.9)
				star4(ci, Vector2(L * rnd(i, p.y, 1.0), (rnd(i, p.y, 2.0) - 0.5) * 12.0), sin(p.x * PI) * 3.8, hue(rnd(i, p.y, 3.0) + t * 0.3, 1.0, 0.5, 1.0))
			var sx2: float = fposmod(t * 0.9, 1.0) * L
			ci.draw_line(Vector2(sx2, -6.0), Vector2(sx2 - 4.0, 6.0), hue(t * 0.6, 0.55, 0.5, 1.0), 2.0)
		"meteor":
			for i in 8:
				var p: Vector2 = ph(t, i, 8, 1.1)
				var a: float = rnd(i, p.y, 1.0) * TAU + p.x * 2.5
				var pos := Vector2(L * 0.5 + cos(a) * (L * 0.3 + p.x * 10.0), sin(a) * (5.0 + p.x * 9.0))
				var sz: float = 1.3 + 1.5 * rnd(i, p.y, 2.0)
				ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(-sz, -sz * 0.6), pos + Vector2(sz, -sz * 0.8), pos + Vector2(sz * 0.7, sz), pos + Vector2(-sz * 0.8, sz * 0.7)]), ca(c1.darkened(0.55), 1.0 - p.x))
				glow_dot(ci, pos, sz * 0.8, ca(c1.lerp(c2, p.x), 1.0 - p.x))
			for i in 4:
				var p: Vector2 = ph(t, i, 4, 0.9)
				glow_dot(ci, Vector2(L * rnd(i, p.y, 5.0), 2.0 - p.x * 20.0), 1.3 * (1.0 - p.x) + 0.4, ca(c2, 1.0 - p.x))
		"tsunami":
			for i in 7:
				var p: Vector2 = ph(t, i, 7, 1.2)
				var pos := Vector2(L * rnd(i, p.y, 1.0) + sin(p.x * 6.0 + float(i)) * 2.0, 3.0 - p.x * 20.0)
				ci.draw_arc(pos, 1.5 + 2.0 * p.x, 0.0, TAU, 10, ca(c2, 1.0 - p.x), 1.2, true)
				ci.draw_circle(pos + Vector2(-0.6, -0.6), 0.5, ca(Color.WHITE, 0.8 * (1.0 - p.x)))
			for i in 4:
				var p: Vector2 = ph(t, i, 4, 0.8)
				ci.draw_circle(Vector2(L * rnd(i, p.y, 4.0), -2.0 + p.x * p.x * 16.0), 1.3, ca(c1, 1.0 - p.x))
		"reaper":
			for i in 6:
				var p: Vector2 = ph(t, i, 6, 1.5)
				var x: float = L * rnd(i, p.y, 1.0) + sin(p.x * 5.0 + float(i)) * 3.0
				var y: float = 2.0 - p.x * 24.0
				var al: float = sin(p.x * PI)
				ci.draw_circle(Vector2(x, y), 2.4 * (0.6 + 0.4 * al), ca(c2, 0.55 * al))
				ci.draw_line(Vector2(x, y + 1.5), Vector2(x - 1.5, y + 8.0), ca(c1, 0.6 * al), 1.6)
				glow_dot(ci, Vector2(x - 0.8, y - 0.4), 0.7, ca(Color.BLACK, 0.9 * al))
		"portal":
			for i in 5:
				var p: Vector2 = ph(t, i, 5, 1.0)
				var pos := Vector2(L * rnd(i, p.y, 1.0), (rnd(i, p.y, 2.0) - 0.5) * 10.0)
				ci.draw_arc(pos, 1.0 + 5.5 * p.x, 0.0, TAU, 12, ca(c1.lerp(c2, p.x), 1.0 - p.x), 1.4, true)
				ci.draw_arc(pos, 0.6 + 3.0 * p.x, p.x * 6.0, p.x * 6.0 + PI, 8, ca(c2, 1.0 - p.x), 1.2, true)
		"sands":
			for i in 12:
				var p: Vector2 = ph(t, i, 12, 1.0)
				var pos := Vector2(L * rnd(i, p.y, 1.0) + p.x * 14.0, (rnd(i, p.y, 2.0) - 0.5) * 8.0 + sin(p.x * 7.0 + float(i)) * 3.0 + p.x * 4.0)
				ci.draw_rect(Rect2(pos, Vector2(1.6, 1.6)), ca(c1.lerp(Color.WHITE, rnd(i, p.y, 3.0) * 0.4), 1.0 - p.x))
			for i in 3:
				var p: Vector2 = ph(t, i, 3, 1.3)
				glow_dot(ci, Vector2(L * rnd(i, p.y, 6.0), 1.0 - p.x * 8.0), 1.2, ca(c2, sin(p.x * PI) * 0.8))
		"firework":
			for i in 5:
				var p: Vector2 = ph(t, i, 5, 0.7)
				var cen := Vector2(L * rnd(i, p.y, 1.0), (rnd(i, p.y, 2.0) - 0.5) * 8.0)
				var cc: Color = hue(rnd(i, p.y, 3.0) + t * 0.2, 1.0, 0.55, 1.0) if i % 2 == 0 else c1
				for k in 6:
					var a: float = float(k) * TAU / 6.0 + p.y
					ci.draw_line(cen + Vector2(cos(a), sin(a)) * p.x * 3.0, cen + Vector2(cos(a), sin(a)) * (p.x * 7.0 + 2.0), ca(cc, 1.0 - p.x), 1.2)
				glow_dot(ci, cen, 1.2 * (1.0 - p.x) + 0.3, ca(c2, 1.0 - p.x))
		"orbital":
			var sx3: float = fposmod(t * 0.8, 1.0) * L
			ci.draw_line(Vector2(sx3, -7.0), Vector2(sx3, 7.0), ca(c1, 0.75), 1.4)
			ci.draw_line(Vector2(sx3 - 3.0, -7.0), Vector2(sx3 - 3.0, 7.0), ca(c1, 0.25), 3.0)
			for i in 4:
				var p: Vector2 = ph(t, i, 4, 0.9)
				var pos := Vector2(L * rnd(i, p.y, 1.0), (rnd(i, p.y, 2.0) - 0.5) * 12.0)
				var q: float = 3.0 * (1.0 - p.x) + 1.0
				ci.draw_line(pos + Vector2(-q, -q), pos + Vector2(-q, q), ca(c2, sin(p.x * PI)), 1.0)
				ci.draw_line(pos + Vector2(q, -q), pos + Vector2(q, q), ca(c2, sin(p.x * PI)), 1.0)
				ci.draw_rect(Rect2(pos - Vector2(0.8, 0.8), Vector2(1.6, 1.6)), ca(c1, sin(p.x * PI)))
		"hex":
			for i in 5:
				var p: Vector2 = ph(t, i, 5, 1.4)
				var pos := Vector2(L * rnd(i, p.y, 1.0), 1.0 - p.x * 20.0)
				var al: float = sin(p.x * PI)
				ci.draw_arc(pos, 3.0, 0.0, TAU, 10, ca(c1, al), 1.0, true)
				for k in 3:
					var a: float = float(k) * TAU / 3.0 + p.x * 4.0 - PI * 0.5
					ci.draw_line(pos + Vector2(cos(a), sin(a)) * 3.0, pos + Vector2(cos(a + TAU / 3.0), sin(a + TAU / 3.0)) * 3.0, ca(c2, al), 0.9)
			for i in 3:
				var p: Vector2 = ph(t, i, 3, 1.0)
				glow_dot(ci, Vector2(L * rnd(i, p.y, 5.0), (rnd(i, p.y, 6.0) - 0.5) * 8.0), 1.4 * sin(p.x * PI) + 0.2, ca(c1, 1.0))
		"balloon":
			for i in 6:
				var p: Vector2 = ph(t, i, 6, 1.5)
				var pos := Vector2(L * rnd(i, p.y, 1.0) + sin(p.x * 5.0 + float(i)) * 3.0, 2.0 - p.x * 24.0)
				var rr: float = 2.0 + 2.6 * rnd(i, p.y, 2.0)
				var cc2: Color = c1.lerp(c2, rnd(i, p.y, 3.0))
				ci.draw_arc(pos, rr, 0.0, TAU, 12, ca(cc2, 1.0 - p.x * 0.7), 1.4, true)
				ci.draw_circle(pos + Vector2(-rr * 0.35, -rr * 0.35), rr * 0.25, ca(Color.WHITE, 0.8 * (1.0 - p.x)))
			for i in 4:
				var p: Vector2 = ph(t, i, 4, 1.0)
				ci.draw_rect(Rect2(Vector2(L * rnd(i, p.y, 4.0), -6.0 + p.x * 16.0), Vector2(2.0, 3.4)), ca(hue(rnd(i, p.y, 5.0), 1.0, 0.6, 1.0), 1.0 - p.x))
		"ufo":
			for k in 4:
				var on: float = 0.5 + 0.5 * sin(t * 6.0 + float(k) * 1.6)
				glow_dot(ci, Vector2(L * (0.2 + 0.2 * float(k)), 0.0), 1.2 + 1.0 * on, ca(c1 if k % 2 == 0 else c2, 0.4 + 0.6 * on))
			for i in 6:
				var p: Vector2 = ph(t, i, 6, 1.1)
				var pos := Vector2(L * rnd(i, p.y, 1.0) + sin(p.x * 8.0 + float(i)) * 1.5, 2.0 - p.x * 22.0)
				glow_dot(ci, pos, 1.4 * (1.0 - p.x) + 0.4, ca(c1, 1.0 - p.x))


## Jejak peluru untuk skin senjata LV2+. Origin = peluru, +x = arah tembak (belakang peluru = -x).
static func bullet_fx(ci: CanvasItem, fam: String, c1: Color, c2: Color, t: float) -> void:
	for i in 7:
		var p: Vector2 = ph(t, i, 7, 0.35)
		var back: float = p.x * 38.0
		var jy: float = (rnd(i, p.y, 1.0) - 0.5) * 12.0 * p.x
		var pos := Vector2(-back, jy)
		var al: float = 1.0 - p.x
		match fam:
			"cyber":
				ci.draw_rect(Rect2(pos.x, floorf(jy / 2.0) * 2.0, 3.0, 3.0), ca(c1 if i % 2 == 0 else c2, al))
			"crystal", "holy", "nova":
				star4(ci, pos, 3.4 * al, ca(c2.lerp(c1, 0.3), 1.0))
			"blossom":
				petal(ci, pos, 3.0, p.x * 6.0, ca(c1, al))
			"prism":
				glow_dot(ci, pos, 2.0 * al + 0.6, hue(p.x + t * 0.5, al))
			"jackpot":
				ci.draw_circle(pos, 1.8 * al + 0.4, ca(c1, al))
			"venom":
				ci.draw_arc(pos + Vector2(0, p.x * 8.0), 1.2 + 1.6 * p.x, 0.0, TAU, 8, ca(c1, al), 1.2, true)
			"storm":
				ci.draw_line(pos, pos + Vector2(-5.0, jy * 0.5), ca(c2, al), 1.6)
			"dragon", "magma":
				glow_dot(ci, pos + Vector2(0, -p.x * 5.0), 2.2 * al + 0.5, ca(c1.lerp(c2, p.x), al))
			"meteor":
				glow_dot(ci, pos + Vector2(0, -p.x * 4.0), 2.8 * al + 0.6, ca(c1.lerp(c2, p.x), al))
			"tsunami":
				ci.draw_arc(pos + Vector2(0, p.x * 6.0), 1.4 + 1.8 * p.x, 0.0, TAU, 8, ca(c2, al), 1.2, true)
			"reaper":
				glow_dot(ci, pos + Vector2(0, -p.x * 7.0), 2.2 * al + 0.6, ca(c1.lerp(c2, 0.4), al * 0.85))
			"portal":
				ci.draw_arc(pos, 1.5 + 4.0 * p.x, 0.0, TAU, 10, ca(c1.lerp(c2, p.x), al), 1.3, true)
			"sands":
				ci.draw_rect(Rect2(pos.x, pos.y + p.x * 5.0, 2.0, 2.0), ca(c1, al))
			"firework":
				star4(ci, pos, 3.2 * al, hue(rnd(i, p.y, 1.0) + t * 0.4, 1.0, 0.6, 1.0))
			"orbital":
				ci.draw_rect(Rect2(pos.x, pos.y - 1.0, 4.0 * al + 1.0, 2.0), ca(c1, al))
			"hex":
				diamond(ci, pos, 1.4 * al + 0.4, 2.8 * al + 0.6, ca(c1.lerp(c2, p.x), al), p.x * 3.0)
			"balloon":
				ci.draw_arc(pos + Vector2(0, -p.x * 8.0), 1.4 + 2.2 * p.x, 0.0, TAU, 10, ca(c1.lerp(c2, rnd(i, p.y, 2.0)), al), 1.3, true)
			"ufo":
				glow_dot(ci, pos, 2.0 * al + 0.5, ca(c1, al))
			_:
				glow_dot(ci, pos, 1.8 * al + 0.5, ca(c1.lerp(c2, p.x), al))


# ================================================================== AKSESORIS BERANIMASI
## Animasi transformasi sprite aksesoris: {"pos": Vector2, "rot": float, "scale": Vector2, "mod": Color}
static func acc_anim(aid: String, t: float) -> Dictionary:
	var pos := Vector2.ZERO
	var rot: float = 0.0
	var sc := Vector2.ONE
	var md := Color(1, 1, 1, 1)
	match aid:
		"starfall_crown":
			pos.y = sin(t * 2.2) * 2.5
			var pu: float = 1.0 + 0.08 * (0.5 + 0.5 * sin(t * 3.0))
			md = Color(pu, pu, pu, 1.0)
		"hellfire_horns":
			sc = Vector2(1.0 + 0.012 * sin(t * 9.0), 1.0 + 0.035 * sin(t * 13.0) + 0.02 * sin(t * 21.0))
			var fl: float = 1.0 + 0.12 * sin(t * 17.0)
			md = Color(fl, fl * 0.92, fl * 0.85, 1.0)
		"storm_cloud":
			pos = Vector2(sin(t * 1.3) * 4.0, sin(t * 2.0) * 3.0)
			var pf: float = 1.0 + 0.04 * sin(t * 2.6)
			sc = Vector2(pf, 1.0 / pf)
			var flash: float = pow(maxf(0.0, sin(t * 2.4)), 24.0)
			md = Color(1.0 + flash * 1.2, 1.0 + flash * 1.2, 1.0 + flash * 1.4, 1.0)
		"scan_visor":
			var bl: float = 1.0 + 0.12 * sin(t * 6.0)
			md = Color(bl, bl, bl, 1.0)
		"love_struck":
			var hb: float = pow(maxf(0.0, sin(t * 5.0)), 6.0)
			sc = Vector2.ONE * (1.0 + 0.07 * hb)
			md = Color(1.0 + 0.2 * hb, 1.0, 1.0 + 0.1 * hb, 1.0)
		"arc_core":
			var pr: float = 0.5 + 0.5 * sin(t * 4.0)
			md = Color(1.0 + 0.35 * pr, 1.0 + 0.35 * pr, 1.0 + 0.4 * pr, 1.0)
			pos.y = sin(t * 1.8) * 1.2
		"comet_scarf":
			rot = sin(t * 2.6) * 0.025
			pos = Vector2(sin(t * 2.0) * 1.5, sin(t * 3.1) * 1.0)
		"spirit_wings":
			var fp: float = sin(t * 3.0)
			sc = Vector2(1.0 + 0.09 * fp, 1.0 - 0.025 * fp)
			pos.y = -fp * 3.5
			md = Color(1, 1, 1, 0.82 + 0.18 * (0.5 + 0.5 * sin(t * 2.0)))
		"event_horizon":
			rot = t * 0.4
			var pe: float = 1.0 + 0.025 * sin(t * 2.2)
			sc = Vector2.ONE * pe
		"rocket_pack":
			pos = Vector2(sin(t * 61.0) * 0.7, sin(t * 53.0) * 0.9)
	return {"pos": pos, "rot": rot, "scale": sc, "mod": md}


## Partikel / objek tambahan aksesoris (koordinat = kotak karakter, titik (0,0) = tengah badan).
## Sudah ditaruh di dalam sprite aksesoris, jadi ikut posisi slot (mis. wajah mengikuti garis mata).
static func acc_fx(ci: CanvasItem, aid: String, t: float) -> void:
	var cs: Array = FxCatalog.acc_colors(aid)
	var c1: Color = cs[0]
	var c2: Color = cs[1]
	match aid:
		"starfall_crown":
			for k in 5:
				var o: Vector3 = orbit(t, 1.6, float(k) * TAU / 5.0, 82.0, 15.0, -118.0)
				var tw: float = 0.6 + 0.4 * sin(t * 6.0 + float(k) * 2.0)
				star4(ci, Vector2(o.x, o.y), (6.0 + 3.0 * o.z) * tw, ca(c2.lerp(Color.WHITE, 0.4), 0.55 + 0.45 * (o.z * 0.5 + 0.5)))
			for i in 5:
				var p: Vector2 = ph(t, i, 5, 1.0)
				star4(ci, Vector2((rnd(i, p.y, 1.0) - 0.5) * 100.0, -128.0 - rnd(i, p.y, 2.0) * 34.0), sin(p.x * PI) * 5.0, Color(1, 0.95, 0.6, 1))
		"hellfire_horns":
			for s in 2:
				var sx: float = 1.0 if s == 0 else -1.0
				for i in 7:
					var p: Vector2 = ph(t, i + s * 7, 14, 1.0)
					var pos := Vector2(sx * (96.0 - p.x * 10.0 + sin(p.x * 9.0 + float(i)) * 3.0), -150.0 - p.x * 32.0)
					var fl: float = (1.0 - p.x)
					glow_dot(ci, pos, 3.0 * fl + 0.6, ca(c2.lerp(c1, p.x), fl))
			var ff: float = 6.0 + 2.0 * sin(t * 18.0)
			for s in 2:
				var sx: float = 1.0 if s == 0 else -1.0
				ci.draw_colored_polygon(PackedVector2Array([Vector2(sx * 92.0, -146.0), Vector2(sx * 98.0, -146.0 - 14.0 - ff), Vector2(sx * 104.0, -146.0)]), ca(c2, 0.6))
		"storm_cloud":
			for i in 14:
				var p: Vector2 = ph(t, i, 14, 0.55)
				var x: float = -52.0 + rnd(i, p.y, 1.0) * 104.0
				var y0: float = -72.0
				lin(ci, Vector2(x, y0 + p.x * 70.0), Vector2(x - 2.0, y0 + p.x * 70.0 + 8.0), ca(Color(0.6, 0.78, 1.0), (1.0 - p.x) * 0.9), 1.6)
			var cyc: float = floorf(t / 2.6)
			var qq: float = fposmod(t, 2.6)
			if qq < 0.3:
				var fl: float = 1.0 - qq / 0.3
				var bx: float = (h(cyc, 3.0) - 0.5) * 40.0
				bolt(ci, Vector2(bx * 0.2, -72.0), Vector2(bx, -2.0), cyc + floorf(qq * 30.0), ca(c2, fl), 4.0, 8, 9.0)
				ci.draw_circle(Vector2(0, -110.0), 46.0, ca(Color(0.8, 0.9, 1.0), fl * 0.18))
		"scan_visor":
			var bx: float = sin(t * 2.2) * 70.0
			ci.draw_rect(Rect2(bx - 3.0, -48.0, 6.0, 38.0), ca(Color.WHITE, 0.85))
			ci.draw_rect(Rect2(bx - 9.0, -48.0, 18.0, 38.0), ca(c1, 0.28))
			ci.draw_rect(Rect2(bx - 18.0, -48.0, 36.0, 38.0), ca(c1, 0.10))
			var led: float = 0.5 + 0.5 * sin(t * 8.0)
			glow_dot(ci, Vector2(-88.0, -30.0), 2.2, ca(c1, 0.4 + 0.6 * led))
			glow_dot(ci, Vector2(88.0, -30.0), 2.2, ca(Color(1, 0.3, 0.3), 0.4 + 0.6 * (1.0 - led)))
		"love_struck":
			for i in 7:
				var p: Vector2 = ph(t, i, 7, 1.7)
				var side: float = -1.0 if rnd(i, p.y, 1.0) < 0.5 else 1.0
				var pos := Vector2(side * (34.0 + rnd(i, p.y, 2.0) * 22.0) + sin(p.x * 7.0 + float(i)) * 6.0, -42.0 - p.x * 70.0)
				heart(ci, pos, 5.0 + 4.0 * rnd(i, p.y, 3.0), ca(c1.lerp(c2, rnd(i, p.y, 4.0)), sin(p.x * PI)))
		"arc_core":
			var cc := Vector2(0, 126.0)
			var pr: float = 0.5 + 0.5 * sin(t * 4.0)
			glow_dot(ci, cc, 9.0 + 3.0 * pr, ca(c1, 0.55 + 0.3 * pr))
			for k in 6:
				var a: float = t * 2.5 + float(k) * TAU / 6.0
				var d := Vector2(cos(a), sin(a))
				lin(ci, cc + d * 21.0, cc + d * 29.0, ca(c2, 0.95), 2.4)
			var sd: float = floorf(t * 7.0)
			if h(sd, 3.0) > 0.5:
				var a2: float = h(sd, 5.0) * TAU
				var d2 := Vector2(cos(a2), sin(a2))
				bolt(ci, cc + d2 * 24.0, cc + d2 * 44.0, sd, ca(c1, 0.9), 1.6, 4, 5.0)
		"comet_scarf":
			for i in 10:
				var p: Vector2 = ph(t, i, 10, 1.3)
				var pos := Vector2(70.0 + p.x * 56.0 + sin(p.x * 8.0 + float(i)) * 3.0, 150.0 + p.x * 48.0 + (rnd(i, p.y, 1.0) - 0.5) * 18.0)
				star4(ci, pos, sin(p.x * PI) * 5.0, ca(c2, 1.0))
			for i in 4:
				var p: Vector2 = ph(t, i, 4, 1.5)
				glow_dot(ci, Vector2((rnd(i, p.y, 2.0) - 0.5) * 140.0, 90.0 + (rnd(i, p.y, 3.0) - 0.5) * 12.0), 1.6, ca(c1, sin(p.x * PI)))
		"spirit_wings":
			for i in 12:
				var p: Vector2 = ph(t, i, 12, 2.0)
				var side: float = -1.0 if (i % 2) == 0 else 1.0
				var pos := Vector2(side * (110.0 + p.x * 30.0 + rnd(i, p.y, 1.0) * 24.0), -80.0 + p.x * 130.0 + sin(p.x * 6.0 + float(i)) * 6.0)
				petal(ci, pos, 4.2, p.x * 4.0 + float(i), ca(c1.lerp(c2, rnd(i, p.y, 2.0)), sin(p.x * PI) * 0.9))
			for i in 6:
				var p: Vector2 = ph(t, i, 6, 1.1)
				var side: float = -1.0 if (i % 2) == 0 else 1.0
				star4(ci, Vector2(side * (100.0 + rnd(i, p.y, 3.0) * 60.0), -110.0 + rnd(i, p.y, 4.0) * 150.0), sin(p.x * PI) * 4.0, ca(Color.WHITE, 1.0))
		"event_horizon":
			for i in 26:
				var a: float = float(i) * TAU / 26.0 + t * (0.8 + 0.5 * float(i % 3))
				var rr: float = 108.0 + 6.0 * sin(t * 2.0 + float(i))
				glow_dot(ci, Vector2(cos(a), sin(a)) * rr, 1.6 + 1.3 * h(float(i)), ca(c1.lerp(c2, h(float(i), 4.0)), 0.9))
			for i in 8:
				var p: Vector2 = ph(t, i, 8, 2.0)
				var a: float = rnd(i, p.y, 1.0) * TAU + p.x * 4.0
				var r: float = 126.0 - p.x * 40.0
				glow_dot(ci, Vector2(cos(a), sin(a)) * r, 2.0 * (1.0 - p.x) + 0.6, ca(c2, sin(p.x * PI)))
		"rocket_pack":
			for s in 2:
				var sx: float = 1.0 if s == 0 else -1.0
				var nx: float = sx * 92.0
				var fh: float = 26.0 + 8.0 * sin(t * 30.0 + float(s) * 2.0) + 4.0 * sin(t * 47.0)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(nx - 8.0, 94.0), Vector2(nx, 94.0 + fh), Vector2(nx + 8.0, 94.0)]), ca(c2, 0.9))
				ci.draw_colored_polygon(PackedVector2Array([Vector2(nx - 5.0, 94.0), Vector2(nx, 94.0 + fh * 0.65), Vector2(nx + 5.0, 94.0)]), ca(c1, 0.95))
				ci.draw_colored_polygon(PackedVector2Array([Vector2(nx - 2.5, 94.0), Vector2(nx, 94.0 + fh * 0.35), Vector2(nx + 2.5, 94.0)]), ca(Color(1, 1, 0.85), 1.0))
				for i in 6:
					var p: Vector2 = ph(t, i + s * 6, 12, 0.5)
					var pos := Vector2(nx + (rnd(i + s * 6, p.y, 1.0) - 0.5) * 14.0, 100.0 + p.x * 56.0)
					circ(ci, pos, 2.0 * (1.0 - p.x) + 0.5, ca(c1.lerp(Color(0.6, 0.6, 0.65), p.x), (1.0 - p.x) * 0.9))
