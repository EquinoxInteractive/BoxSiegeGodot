extends Control
## Peta level CAMPAIGN: 5 chapter x 10 dunia x 5 level. Tiap DUNIA tampil sebagai satu panel besar (satu "tab").
## Geser ke kiri / kanan (drag mouse, roda mouse, panah di sisi, tab di bawah, D-pad, Q / E atau L1 / R1) untuk pindah dunia.
## Saat naik level (mis. menamatkan level 5 sebuah dunia) peta otomatis membuka tab dunia berikutnya lengkap dengan animasi buka kunci.
## Bintang & skor terbaik tersimpan di user://campaign.cfg (lihat CampaignData).

const PAGER_X := 0.0
const PAGER_Y := 198.0
const PAGER_W := 1280.0
const PAGER_H := 394.0

## Ingatan antar-kunjungan (static): dunia & level terbuka terakhir yang dilihat pemain di peta.
## Dipakai untuk menganimasikan perpindahan otomatis ke tab berikutnya setelah naik level.
static var _prev_world: int = -1
static var _prev_unlocked: int = -1
## Level pertama yang dimainkan sejak terakhir membuka peta (diisi saat tombol CONTINUE / level dipilih, dihapus saat peta dibuka).
## Kalau pemain terus lanjut beberapa level tanpa kembali ke peta, animasi berjalan dimulai dari level ini.
static var _streak_start: int = -1

var bg: UIKit.FxBackground
var prompt: UIKit.PromptBar
var status: UIKit.PadStatus
var pager: WorldPager
var btn_continue: UIKit.FancyButton
var info: InfoBar
var fighter_card: FighterCard
var fighter: Dictionary = {}    # {"character": int, "weapon": String} yang sedang dipakai
var _last_lock_msg: int = -1000  # waktu notifikasi LOCKED terakhir (ms), mencegah dobel

var save: Dictionary = {}
var lvls: Array = []            # cache CampaignData.levels() (fungsi itu membangun ulang seluruh daftar tiap dipanggil)
var _boss: Dictionary = {}      # cache: nomor level -> apakah level BOSS
var focus: int = 1              # -4 kartu fighter, -3 pilih chapter, -2 tombol lanjut, 1..250 level
var last_tile: int = 1
var leaving := false
var _world: int = -1            # dunia yang sedang tampil (0..9 di dalam chapter)
var chapter: int = 0            # chapter yang sedang tampil (0..4)
var chapter_nav: ChapterNav
var fx_layer: UnlockFx          # perayaan buka kunci MAP baru & CHAPTER baru (lapisan paling atas)


func off() -> int:
	return chapter * CampaignData.CHAPTER_SIZE


func lv(n: int) -> Dictionary:
	return lvls[clampi(n, 1, lvls.size()) - 1]


func is_boss(n: int) -> bool:
	return bool(_boss.get(n, false))


# ================================================================== pager dunia
## Satu panel besar per dunia (5 level). Panel aktif di tengah, panel tetangga mengintip di kiri / kanan.
## Posisi `pos` mengikuti `target` dengan pegas teredam kritis (tanpa goyang & tanpa patah), dan bisa di-drag langsung.
class WorldPager extends Control:
	signal node_clicked(level: int)
	signal node_hovered(level: int)
	signal page_requested(world: int)
	signal unlock_arrived

	const PW := 900.0              # lebar panel dunia
	const PH := 346.0              # tinggi panel dunia
	const STEP := 860.0            # jarak antar panel
	const CUT := 28.0              # sudut miring panel
	const TAB_Y := 356.0
	const TAB_W := 150.0
	const TAB_H := 30.0
	const TAB_GAP := 8.0
	const FILL_DUR := 1.7           # lama garis terisi menuju level yang baru terbuka
	const UNLOCK_TOTAL := 4.0
	const NODE_Y := [232.0, 188.0, 228.0, 186.0, 214.0]

	var hub
	var t: float = 0.0
	var pos: float = 0.0
	var vel: float = 0.0
	var enter: Array[float] = []
	var target: int = 0:
		set(v):
			if v == target:
				return
			target = v
			if v >= 0 and v < enter.size():
				enter[v] = 0.0
	var anim: Dictionary = {}      # level -> 0..1 (fokus)
	var tab_anim: Array[float] = []
	var arrow_anim: Array[float] = [0.0, 0.0]
	var name_fs: Dictionary = {}
	var tab_fs: Array[int] = []
	var hold_lock: int = -1        # level yang masih ditampilkan terkunci sampai animasi buka kunci
	var held: Dictionary = {}      # level -> true: tampil terkunci / jalur belum terisi sampai animasi berjalan tiba di sana
	var fill_dur: float = FILL_DUR # lama garis terisi untuk satu langkah (dipendekkan kalau jalannya panjang)
	var unlock_node: int = -1
	var unlock_t: float = -1.0
	var fx_plain: bool = true      # false = level pembuka MAP / CHAPTER baru: efek lingkaran biasa diganti UnlockFx

	var _pressed := false
	var _dragging := false
	var _press_x: float = 0.0
	var _press_pos: float = 0.0
	var _hover_tab: int = -1
	var _hover_arrow: int = -1
	var _wheel_ms: int = 0

	func _init() -> void:
		size = Vector2(1280.0, 394.0)
		custom_minimum_size = size
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		for i in CampaignData.WORLDS.size():
			enter.append(1.0)
			tab_anim.append(0.0)
			tab_fs.append(15)

	func _ready() -> void:
		for i in CampaignData.WORLDS.size():
			var fs: int = 16
			var nm: String = String(CampaignData.WORLDS[i]["name"])
			while fs > 10 and UIKit.text_w(nm, fs) > tab_w() - 26.0:
				fs -= 1
			tab_fs[i] = fs
		for n in range(1, CampaignData.TOTAL_LEVELS + 1):
			var f: int = 16
			var s: String = String(hub.lv(n)["name"])
			while f > 10 and UIKit.text_w(s, f) > 168.0:
				f -= 1
			name_fs[n] = f

	# ------------------------------------------------------------------ kontrol dari luar
	func set_page(w: int, intro_delay: float = 0.0) -> void:
		target = w
		pos = float(w)
		vel = 0.0
		enter[w] = -intro_delay
		tab_anim[w] = 1.0

	## Dorongan kecil saat sudah di ujung (kampanye pertama / terakhir): panel bergoyang lalu kembali.
	func nudge(dir: int) -> void:
		vel += float(dir) * 1.6

	func reset_enter() -> void:
		for i in enter.size():
			enter[i] = 0.0

	func fire_unlock() -> void:
		if hold_lock < 1:
			return
		unlock_node = hold_lock       # node tetap tampil terkunci sampai garis selesai terisi
		unlock_t = 0.0

	## Satu langkah animasi: garis terisi dari level (n - 1) menuju level n (sesama dunia).
	## Untuk level pertama dunia baru tidak ada garis; dur hanya jeda sebelum efek unlock.
	func walk_to(n: int, dur: float, plain: bool = true) -> void:
		fill_dur = dur
		fx_plain = plain
		unlock_node = n
		unlock_t = 0.0

	## Posisi layar (koordinat hub) pusat node level n pada panel dunianya (untuk efek di UnlockFx).
	func node_screen(n: int) -> Vector2:
		var w: int = CampaignData.world_of(n)
		var k: int = n - CampaignData.chapter_of(n) * CampaignData.CHAPTER_SIZE - int(CampaignData.WORLDS[w]["levels"][0])
		var xf: Dictionary = page_xf(w)
		return position + (xf["o"] as Vector2) + node_pos(clampi(k, 0, 4)) * float(xf["s"])

	## Poligon panel dunia w dalam koordinat layar (hub).
	func page_poly_screen(w: int) -> PackedVector2Array:
		var xf: Dictionary = page_xf(w)
		var o: Vector2 = position + (xf["o"] as Vector2)
		var sc: float = float(xf["s"])
		var out := PackedVector2Array()
		for p in _page_poly():
			out.append(o + p * sc)
		return out

	func is_held(n: int) -> bool:
		return n == hold_lock or held.has(n)

	# ------------------------------------------------------------------ geometri
	func page_xf(i: int) -> Dictionary:
		var d: float = float(i) - pos
		var ad: float = absf(d)
		var near: float = clampf(ad, 0.0, 1.0)
		var s: float = lerpf(1.0, 0.82, near)
		var cx: float = size.x * 0.5 + d * STEP
		var o := Vector2(cx - PW * s * 0.5, 6.0 + PH * (1.0 - s) * 0.5 + 8.0 * near)
		var a: float = 1.0 - 0.5 * near - 0.5 * clampf(ad - 1.0, 0.0, 1.0)
		return {"o": o, "s": s, "a": a}

	func node_pos(k: int) -> Vector2:
		return Vector2(96.0 + float(k) * 177.0, float(NODE_Y[k]))

	func node_radius(n: int) -> float:
		return 50.0 if hub.is_boss(n) else 40.0

	## Lebar tab menyesuaikan jumlah dunia (10 dunia harus tetap muat di layar 1280).
	func tab_w() -> float:
		var n: float = float(maxi(tab_anim.size(), 1))
		return minf(TAB_W, (size.x - 40.0 - TAB_GAP * (n - 1.0)) / n)

	func tab_rect(j: int) -> Rect2:
		var tw: float = tab_w()
		var x0: float = (size.x - (float(tab_anim.size()) * tw + float(tab_anim.size() - 1) * TAB_GAP)) * 0.5
		return Rect2(x0 + float(j) * (tw + TAB_GAP), TAB_Y, tw, TAB_H)

	func arrow_center(idx: int) -> Vector2:
		return Vector2(28.0 if idx == 0 else size.x - 28.0, 178.0)

	func _ca(c: Color, a: float) -> Color:
		return Color(c.r, c.g, c.b, c.a * a)

	func _rnd(i: int, k: int) -> float:
		return fposmod(sin(float(i) * 12.9898 + float(k) * 78.233) * 43758.5453, 1.0)

	func _back(x: float) -> float:
		var u: float = clampf(x, 0.0, 1.0) - 1.0
		return 1.0 + 2.70158 * u * u * u + 1.70158 * u * u

	# ------------------------------------------------------------------ input
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_pressed = true
					_dragging = false
					_press_x = mb.position.x
					_press_pos = pos
				elif _pressed:
					_pressed = false
					if _dragging:
						_end_drag()
					else:
						_click(mb.position)
					_dragging = false
			elif mb.pressed:
				var dir: int = 0
				if mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					dir = 1
				elif mb.button_index == MOUSE_BUTTON_WHEEL_LEFT or mb.button_index == MOUSE_BUTTON_WHEEL_UP:
					dir = -1
				if dir != 0:
					var now: int = Time.get_ticks_msec()
					if now - _wheel_ms > 220:
						_wheel_ms = now
						var nw: int = target + dir
						if nw < 0 or nw >= CampaignData.WORLDS.size():
							nudge(dir)
						else:
							page_requested.emit(nw)
		elif event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			if _pressed:
				var dx: float = mm.position.x - _press_x
				if not _dragging and absf(dx) > 12.0:
					_dragging = true
				if _dragging:
					var raw: float = _press_pos - dx / STEP
					var maxp: float = float(CampaignData.WORLDS.size() - 1)
					if raw < 0.0:
						raw *= 0.35
					elif raw > maxp:
						raw = maxp + (raw - maxp) * 0.35
					pos = raw
			else:
				_hover(mm.position)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			_hover_tab = -1
			_hover_arrow = -1
			_pressed = false
			if _dragging:
				_dragging = false
				_end_drag()

	func _end_drag() -> void:
		var d: float = pos - _press_pos
		var nt: int = target
		if d > 0.16:
			nt = target + 1
		elif d < -0.16:
			nt = target - 1
		nt = clampi(nt, 0, CampaignData.WORLDS.size() - 1)
		if nt != target:
			page_requested.emit(nt)

	func _hit_node(p: Vector2) -> int:
		if absf(pos - float(target)) > 0.3:
			return -1
		var xf: Dictionary = page_xf(target)
		var o: Vector2 = xf["o"]
		var s: float = float(xf["s"])
		var lp: Vector2 = (p - o) / s
		var first: int = int(CampaignData.WORLDS[target]["levels"][0]) + hub.off()
		for k in 5:
			var n: int = first + k
			if lp.distance_to(node_pos(k)) <= node_radius(n) + 8.0:
				return n
		return -1

	func _hit_tab(p: Vector2) -> int:
		for j in tab_anim.size():
			if tab_rect(j).grow(2.0).has_point(p):
				return j
		return -1

	func _hit_arrow(p: Vector2) -> int:
		for idx in 2:
			var c: Vector2 = arrow_center(idx)
			if Rect2(c - Vector2(34.0, 70.0), Vector2(68.0, 140.0)).has_point(p):
				var nw: int = target + (-1 if idx == 0 else 1)
				if nw >= 0 and nw < CampaignData.WORLDS.size():
					return idx
		return -1

	func _hover(p: Vector2) -> void:
		_hover_tab = _hit_tab(p)
		_hover_arrow = _hit_arrow(p)
		var n: int = _hit_node(p)
		if n > 0:
			node_hovered.emit(n)
		var over_page: bool = false
		for i in [target - 1, target + 1]:
			if i >= 0 and i < CampaignData.WORLDS.size():
				var xf: Dictionary = page_xf(i)
				var o: Vector2 = xf["o"]
				if Rect2(o, Vector2(PW, PH) * float(xf["s"])).has_point(p):
					over_page = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if (n > 0 or _hover_tab >= 0 or _hover_arrow >= 0 or over_page) else Control.CURSOR_ARROW

	func _click(p: Vector2) -> void:
		var ar: int = _hit_arrow(p)
		if ar >= 0:
			page_requested.emit(target + (-1 if ar == 0 else 1))
			return
		var tb: int = _hit_tab(p)
		if tb >= 0:
			if tb != target:
				page_requested.emit(tb)
			return
		var n: int = _hit_node(p)
		if n > 0:
			node_clicked.emit(n)
			return
		for i in [target - 1, target + 1]:
			if i >= 0 and i < CampaignData.WORLDS.size():
				var xf: Dictionary = page_xf(i)
				var o: Vector2 = xf["o"]
				if Rect2(o, Vector2(PW, PH) * float(xf["s"])).has_point(p):
					page_requested.emit(i)
					return

	# ------------------------------------------------------------------ animasi
	func _process(d: float) -> void:
		t += d
		if _dragging:
			vel = 0.0
		else:
			# smooth damp (pegas teredam kritis): mulus, tidak melewati target, tidak patah
			var omega: float = 11.5
			var x: float = omega * d
			var e: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
			var change: float = pos - float(target)
			var temp: float = (vel + omega * change) * d
			vel = (vel - omega * temp) * e
			pos = float(target) + (change + temp) * e
		var foc: int = int(hub.focus)
		for n in range(1, CampaignData.TOTAL_LEVELS + 1):
			var goal: float = 1.0 if foc == n else 0.0
			anim[n] = lerpf(float(anim.get(n, 0.0)), goal, minf(d * 14.0, 1.0))
		for j in tab_anim.size():
			tab_anim[j] = lerpf(tab_anim[j], 1.0 if j == target else 0.0, minf(d * 12.0, 1.0))
		for idx in 2:
			arrow_anim[idx] = lerpf(arrow_anim[idx], 1.0 if _hover_arrow == idx else 0.0, minf(d * 14.0, 1.0))
		for i in enter.size():
			if enter[i] < 2.0:
				enter[i] += d
		if unlock_t >= 0.0:
			unlock_t += d
			if hold_lock == unlock_node and unlock_t >= fill_dur:
				hold_lock = -1            # garis sampai: node terbuka + efek
				unlock_arrived.emit()
			if held.has(unlock_node) and unlock_t >= fill_dur:
				held.erase(unlock_node)   # animasi berjalan tiba di level ini: terbuka + efek
				unlock_arrived.emit()
			if unlock_t > UNLOCK_TOTAL:
				unlock_t = -1.0
				unlock_node = -1
				hold_lock = -1
				held.clear()
		queue_redraw()

	# ------------------------------------------------------------------ gambar
	func _draw() -> void:
		var order: Array[int] = []
		for i in CampaignData.WORLDS.size():
			if absf(float(i) - pos) < 1.6:
				order.append(i)
		order.sort_custom(func(a: int, b: int) -> bool: return absf(float(a) - pos) > absf(float(b) - pos))
		for i in order:
			_draw_page(i)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_arrows()
		_draw_tabs()

	func _page_poly() -> PackedVector2Array:
		return PackedVector2Array([
			Vector2(CUT, 0.0), Vector2(PW, 0.0), Vector2(PW, PH - CUT),
			Vector2(PW - CUT, PH), Vector2(0.0, PH), Vector2(0.0, CUT),
		])

	func _draw_page(i: int) -> void:
		var xf: Dictionary = page_xf(i)
		var o: Vector2 = xf["o"]
		var s: float = float(xf["s"])
		var a: float = float(xf["a"])
		var wd: Dictionary = CampaignData.WORLDS[i]
		var id: String = String(wd["id"])
		var pal: Array = Global.MAP_PALETTES[id]
		var acc: Color = pal[2]
		var first: int = int(wd["levels"][0]) + hub.off()
		var last: int = int(wd["levels"][1]) + hub.off()
		var unlocked: int = int(hub.save["unlocked"])
		var stars_d: Dictionary = hub.save["stars"]
		var center: float = 1.0 - clampf(absf(float(i) - pos), 0.0, 1.0)
		var ent: float = enter[i]
		draw_set_transform(o, 0.0, Vector2(s, s))
		var pts: PackedVector2Array = _page_poly()

		# bayangan & latar peta (gambar stage, berparalaks mengikuti geseran)
		draw_colored_polygon(UIKit.slanted(PW, PH, 0.0, 10.0, 14.0), Color(0, 0, 0, 0.45 * a))
		var tex: Texture2D = Global.map_background(id)
		if tex != null:
			var ta: float = float(tex.get_width()) / float(tex.get_height())
			var pa: float = PW / PH
			var fu: float = 1.0
			var fv: float = 1.0
			if ta > pa:
				fu = pa / ta
			else:
				fv = ta / pa
			fu *= 0.86
			fv *= 0.86
			var su: float = clampf(-(float(i) - pos), -1.0, 1.0) * (1.0 - fu) * 0.45
			var sv: float = sin(t * 0.3 + float(i)) * (1.0 - fv) * 0.4
			var uvs := PackedVector2Array()
			var cols := PackedColorArray()
			for p in pts:
				uvs.append(Vector2(0.5 + (p.x / PW - 0.5) * fu + su, 0.5 + (p.y / PH - 0.5) * fv + sv))
				cols.append(Color(1, 1, 1, a))
			draw_polygon(pts, cols, uvs, tex)
		else:
			draw_colored_polygon(pts, _ca(pal[1], a))
		# gradasi gelap supaya teks & node terbaca
		var shade := PackedColorArray()
		var dark: Color = Color(pal[0]).darkened(0.55)
		for p in pts:
			var k: float = p.y / PH
			shade.append(Color(dark.r, dark.g, dark.b, lerpf(0.30, 0.82, k) * a))
		draw_polygon(pts, shade)

		# partikel suasana (salju turun, bara naik, debu melayang)
		var falling: bool = id == "snow" or id == "factory"
		for q in 18:
			var seed_i: int = q + i * 31
			var sp: float = 10.0 + 26.0 * _rnd(seed_i, 3)
			var yy: float = fposmod(_rnd(seed_i, 2) * PH + (t * sp if falling else -t * sp), PH)
			var xx: float = _rnd(seed_i, 1) * PW + sin(t * 0.7 + float(q)) * 12.0
			var life: float = sin(yy / PH * PI)
			draw_circle(Vector2(xx, yy), 1.6 + 3.2 * _rnd(seed_i, 4), Color(acc.r, acc.g, acc.b, 0.5 * life * a))

		# kilau menyapu panel aktif
		if center > 0.5:
			var sx: float = (fposmod(t * 0.22 + float(i) * 0.37, 1.8) - 0.35) * PW
			var band := PackedVector2Array([Vector2(sx + 90.0, 0.0), Vector2(sx + 170.0, 0.0), Vector2(sx + 80.0, PH), Vector2(sx, PH)])
			for piece in Geometry2D.intersect_polygons(band, pts):
				draw_colored_polygon(piece, Color(1, 1, 1, 0.06 * a * center))

		# bingkai
		var pulse: float = 0.78 + 0.22 * sin(t * 2.2)
		draw_polyline(UIKit.closed(pts), Color(acc.r, acc.g, acc.b, 0.9 * a * lerpf(0.7, pulse, center)), 3.0, true)
		draw_line(Vector2(CUT + 4.0, 3.0), Vector2(CUT + 150.0, 3.0), _ca(acc.lightened(0.3), a), 5.0)
		draw_line(Vector2(PW - CUT - 4.0, PH - 3.0), Vector2(PW - CUT - 150.0, PH - 3.0), _ca(acc.lightened(0.3), a), 5.0)

		# judul dunia
		var hdr: float = clampf(ent * 2.2, 0.0, 1.0)
		var hx: float = -34.0 * (1.0 - _back(hdr))
		var ha: float = a * hdr
		UIKit.text_in(self, ("WORLD %d" % (i + 1)) if hub.chapter == 0 else ("CH%d  WORLD %d" % [hub.chapter + 1, i + 1]), Rect2(34.0 + hx, 14.0, 240.0, 22.0), 18, _ca(acc, 0.95 * ha), HORIZONTAL_ALIGNMENT_LEFT, 4, Color(0, 0, 0, ha))
		UIKit.text_in(self, String(wd["name"]), Rect2(34.0 + hx, 34.0, 560.0, 64.0), 54, Color(1, 1, 1, ha), HORIZONTAL_ALIGNMENT_LEFT, 8, Color(0, 0, 0, ha))

		# ringkasan dunia (bintang & kemajuan)
		var star_sum: int = 0
		for n in range(first, last + 1):
			star_sum += int(stars_d.get(n, 0))
		var world_locked: bool = first > unlocked or held.has(first)   # tetap tampil terkunci sampai efek unlock berjalan
		if world_locked:
			UIKit.draw_lock(self, Vector2(PW - 150.0, 54.0), 30.0, Color(1, 1, 1, 0.55 * ha))
			UIKit.text_in(self, "LOCKED", Rect2(PW - 270.0, 30.0, 240.0, 44.0), 34, Color(1, 1, 1, 0.6 * ha), HORIZONTAL_ALIGNMENT_RIGHT, 6, Color(0, 0, 0, ha))
		else:
			var stxt: String = "%d / %d" % [star_sum, (last - first + 1) * 3]
			var tw: float = UIKit.text_w(stxt, 36)
			var sc := Vector2(PW - 30.0 - tw - 24.0, 54.0 + sin(t * 3.0) * 1.5)
			draw_colored_polygon(CampaignData.star_points(sc + Vector2(2, 3), 15.0), Color(0, 0, 0, 0.5 * ha))
			draw_colored_polygon(CampaignData.star_points(sc, 15.0, t * 0.5), Color(1.0, 0.82, 0.25, ha))
			UIKit.text_in(self, stxt, Rect2(PW - 270.0, 30.0, 240.0, 44.0), 36, Color(1, 1, 1, ha), HORIZONTAL_ALIGNMENT_RIGHT, 7, Color(0, 0, 0, ha))
		for k in 5:
			var n2: int = first + k
			var seg := Rect2(PW - 224.0 + float(k) * 40.0, 86.0, 34.0, 8.0)
			var sc2: Color = Color(1, 1, 1, 0.16)
			if int(stars_d.get(n2, 0)) > 0:
				sc2 = Color(0.29, 0.89, 0.63, 1.0)
			elif n2 == unlocked:
				sc2 = Color(acc, 0.55 + 0.45 * sin(t * 5.0))
			elif n2 < unlocked:
				sc2 = Color(acc, 0.5)
			draw_rect(seg, _ca(sc2, ha))

		# jalur antar level
		_draw_path(i, first, acc, a, unlocked, stars_d)
		# node level
		for k in 5:
			_draw_node(first + k, k, acc, a, ent, unlocked, stars_d)
		if world_locked:
			UIKit.text_in(self, "CLEAR THE PREVIOUS WORLD TO UNLOCK", Rect2(0.0, PH - 40.0, PW, 26.0), 20, Color(1, 1, 1, 0.55 * a), HORIZONTAL_ALIGNMENT_CENTER, 5, Color(0, 0, 0, a))

	func _path_pt(a: Vector2, b: Vector2, u: float) -> Vector2:
		return Vector2(lerpf(a.x, b.x, u), lerpf(a.y, b.y, smoothstep(0.0, 1.0, u)))

	## Garis terisi dari awal sampai pecahan f (0..1) dengan kepala bercahaya di ujungnya.
	func _draw_fill(pa: Vector2, pb: Vector2, f: float, acc: Color, a: float) -> void:
		var dense := PackedVector2Array()
		var upto: float = clampf(f, 0.0, 1.0) * 40.0
		var full: int = int(floor(upto))
		for m in range(0, full + 1):
			dense.append(_path_pt(pa, pb, float(m) / 40.0))
		if full < 40:
			dense.append(_path_pt(pa, pb, upto / 40.0))
		if dense.size() < 2:
			return
		draw_polyline(dense, _ca(acc, 0.4), 12.0, true)
		draw_polyline(dense, _ca(acc.lightened(0.3), a), 6.0, true)
		draw_polyline(dense, Color(1, 1, 1, 0.55 * a), 2.0, true)
		if f < 1.0:
			var head: Vector2 = dense[dense.size() - 1]
			var pl: float = 0.6 + 0.4 * sin(t * 18.0)
			draw_circle(head, 16.0 * pl + 6.0, Color(acc.r, acc.g, acc.b, 0.28 * a))
			draw_circle(head, 8.0, Color(1, 1, 1, 0.9 * a))
			draw_circle(head, 4.0, _ca(acc.lightened(0.4), a))

	func _draw_path(i: int, first: int, acc: Color, a: float, unlocked: int, stars_d: Dictionary) -> void:
		var last: int = first + 4
		var anim_on: bool = unlock_node >= first and unlock_node <= last and unlock_t >= 0.0
		var fill: float = smoothstep(0.0, 1.0, clampf(unlock_t / fill_dur, 0.0, 1.0)) if anim_on else 0.0
		# (tidak ada jalur antar-dunia: level pertama dunia baru langsung terbuka dengan efek unlock saja)
		for k in 4:
			var pa: Vector2 = node_pos(k)
			var pb: Vector2 = node_pos(k + 1)
			var n_next: int = first + k + 1
			var reached: bool = unlocked >= n_next and not is_held(n_next)
			var dense := PackedVector2Array()
			for m in 41:
				dense.append(_path_pt(pa, pb, float(m) / 40.0))
			draw_polyline(dense, Color(0, 0, 0, 0.55 * a), 11.0, true)
			if reached:
				draw_polyline(dense, _ca(acc, 0.35), 9.0, true)
				draw_polyline(dense, _ca(acc.lightened(0.25), a), 5.0, true)
				for m in 2:
					var u: float = fposmod(t * 0.4 + float(k) * 0.23 + float(m) * 0.5, 1.0)
					var dp: Vector2 = _path_pt(pa, pb, u)
					draw_circle(dp, 6.0, Color(1, 1, 1, 0.22 * a))
					draw_circle(dp, 3.2, Color(1, 1, 1, 0.95 * a))
			else:
				var acc_len: float = 0.0
				var off: float = t * 22.0
				for m in 40:
					var seg_len: float = dense[m].distance_to(dense[m + 1])
					if fposmod(acc_len - off, 26.0) < 15.0:
						draw_line(dense[m], dense[m + 1], Color(1, 1, 1, 0.3 * a), 4.0)
					acc_len += seg_len
			if anim_on and n_next == unlock_node:
				# garis perlahan terisi dari level sebelumnya menuju level berikutnya (juga di atas jalur yang sudah terbuka)
				_draw_fill(pa, pb, fill, acc, a)
				if fill < 0.25:
					var fl: float = 1.0 - fill / 0.25
					draw_arc(pa, node_radius(n_next - 1) + 8.0 + 14.0 * (1.0 - fl), 0.0, TAU, 40, Color(acc.r, acc.g, acc.b, 0.8 * fl * a), 3.0, true)

	func _draw_node(n: int, k: int, acc: Color, a: float, ent: float, unlocked: int, stars_d: Dictionary) -> void:
		var boss: bool = hub.is_boss(n)
		var locked: bool = n > unlocked or is_held(n)
		var st: int = int(stars_d.get(n, 0))
		var af: float = float(anim.get(n, 0.0))
		var nr: float = clampf((ent - float(k) * 0.07) / 0.35, 0.0, 1.0)
		if nr <= 0.0:
			return
		var pop: float = _back(nr) * (1.0 + 0.16 * af)
		var na: float = a * minf(nr * 2.0, 1.0)
		var fx_t: float = unlock_t - fill_dur
		if n == unlock_node and fx_t >= 0.0:
			pop *= 1.0 + 0.3 * sin(minf(fx_t / 0.6, 1.0) * PI)
		var c: Vector2 = node_pos(k)
		if not locked:
			c.y += sin(t * 2.2 + float(n) * 0.9) * 2.5
		var base_r: float = node_radius(n)
		var r: float = base_r * pop
		var current: bool = (n == unlocked and st == 0 and not locked)

		if boss:
			draw_colored_polygon(_gear(c + Vector2(4.0, 7.0), r), Color(0, 0, 0, 0.45 * na))
		else:
			draw_circle(c + Vector2(4.0, 7.0), r, Color(0, 0, 0, 0.45 * na))
		if af > 0.01:
			draw_circle(c, r + 20.0, Color(acc.r, acc.g, acc.b, 0.14 * af * na))
		if current:
			for m in 2:
				var ph: float = fposmod(t * 0.9 + float(m) * 0.5, 1.0)
				draw_arc(c, r + 6.0 + 24.0 * ph, 0.0, TAU, 44, Color(acc.r, acc.g, acc.b, (1.0 - ph) * 0.75 * na), 3.0, true)

		var body: Color = Color(0.1, 0.1, 0.16, 0.96)
		var edge: Color = Color(1, 1, 1, 0.2)
		if not locked:
			body = Color(0.08, 0.1, 0.18, 0.96).lerp(acc, 0.28)
			edge = Color(acc, 0.95)
			if boss:
				body = Color(0.26, 0.06, 0.08, 0.97)
				edge = Color("ff4040")
			if st > 0:
				body = body.lerp(Color("4be3a0"), 0.16)
				edge = Color("4be3a0")
		if af > 0.01:
			edge = edge.lerp(Color.WHITE, af * (0.6 + 0.4 * sin(t * 10.0)))
		if boss:
			var gear: PackedVector2Array = _gear(c, r)
			draw_colored_polygon(gear, _ca(body, na))
			draw_polyline(UIKit.closed(gear), _ca(edge, na), 3.0 + 2.0 * af, true)
		else:
			draw_circle(c, r, _ca(body, na))
			draw_arc(c, r, 0.0, TAU, 48, _ca(edge, na), 3.0 + 2.0 * af, true)
		draw_arc(c, r - 8.0, PI * 1.12, PI * 1.88, 18, Color(1, 1, 1, 0.16 * na), 3.0, true)

		if af > 0.01:
			var rot: float = t * 1.6
			for q in 6:
				var a0: float = rot + float(q) * TAU / 6.0
				draw_arc(c, r + 11.0 + 3.0 * sin(t * 5.0), a0, a0 + 0.55, 10, Color(1, 1, 1, af * na), 3.0, true)

		if locked:
			UIKit.draw_lock(self, c, 30.0 * pop, Color(1, 1, 1, 0.4 * na))
		else:
			var fs: int = 52 if boss else 44
			var ny: float = c.y - (9.0 if boss else 0.0)
			UIKit.text_in(self, str(CampaignData.local_n(n)), Rect2(c.x - 40.0, ny - 28.0, 80.0, 56.0), fs, Color(1, 1, 1, na), HORIZONTAL_ALIGNMENT_CENTER, 7, Color(0, 0, 0, na))
			if boss:
				UIKit.text_in(self, "BOSS", Rect2(c.x - 40.0, c.y + 14.0, 80.0, 22.0), 16, Color(1.0, 0.25, 0.25, na), HORIZONTAL_ALIGNMENT_CENTER, 4, Color(0, 0, 0, na))
			# bintang
			for q in 3:
				var sp := Vector2(c.x + (float(q) - 1.0) * 26.0, c.y + base_r + 17.0)
				var gold: bool = q < st
				var tw_s: float = 9.5 + (1.4 * sin(t * 3.0 + float(q) * 1.3 + float(n)) if gold else 0.0)
				draw_colored_polygon(CampaignData.star_points(sp + Vector2(1, 2), tw_s), Color(0, 0, 0, 0.45 * na))
				draw_colored_polygon(CampaignData.star_points(sp, tw_s), Color(1.0, 0.82, 0.25, na) if gold else Color(1, 1, 1, 0.16 * na))
			# rank terbaik
			var rank: int = int((hub.save["grades"] as Dictionary).get(n, 0))
			if st > 0 and rank > 0:
				_draw_rank_badge(c + Vector2(r * 0.78, -r * 0.78), rank, na)
		# nama level
		UIKit.text_in(self, String(hub.lv(n)["name"]), Rect2(c.x - 90.0, c.y + base_r + 31.0, 180.0, 20.0), int(name_fs.get(n, 14)), Color(1, 1, 1, (0.3 if locked else 0.85) * na), HORIZONTAL_ALIGNMENT_CENTER, 4, Color(0, 0, 0, na))
		# penunjuk "level berikutnya"
		if current:
			var by: float = c.y - base_r - 20.0 + sin(t * 4.0) * 4.0
			var tri := PackedVector2Array([Vector2(c.x - 11.0, by - 8.0), Vector2(c.x + 11.0, by - 8.0), Vector2(c.x, by + 7.0)])
			draw_colored_polygon(tri, Color(1.0, 0.82, 0.25, na))
			draw_polyline(UIKit.closed(tri), Color(0, 0, 0, 0.7 * na), 2.0, true)
		# efek buka kunci
		if fx_plain and n == unlock_node and fx_t >= 0.0 and fx_t <= 1.6:
			var u: float = clampf(fx_t / 1.6, 0.0, 1.0)
			draw_arc(c, base_r + u * 120.0, 0.0, TAU, 56, Color(1.0, 0.9, 0.4, (1.0 - u) * 0.9), 4.0, true)
			for q in 10:
				var ang: float = float(q) * TAU / 10.0 + 0.3
				var dist: float = base_r + u * 110.0
				draw_circle(c + Vector2(cos(ang), sin(ang)) * dist, 5.0 * (1.0 - u), Color(1.0, 0.85, 0.3, 1.0 - u))

	## Gerigi level BOSS: statis dan simetris kiri-kanan & atas-bawah (satu gigi tepat di atas, bawah, kiri, kanan).
	## Gigi berbentuk trapesium dengan lembah melengkung, jumlah gigi kelipatan 4 agar sumbu simetri terjaga.
	func _gear(c: Vector2, r: float, teeth: int = 12) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var step: float = TAU / float(teeth)
		var r_in: float = r * 0.87
		for q in teeth:
			var th: float = -PI * 0.5 + float(q) * step      # gigi pertama tepat di atas
			var hw_b: float = step * 0.27                     # setengah lebar gigi di pangkal
			var hw_t: float = step * 0.15                     # setengah lebar gigi di ujung
			pts.append(c + Vector2(cos(th - hw_b), sin(th - hw_b)) * r_in)
			pts.append(c + Vector2(cos(th - hw_t), sin(th - hw_t)) * r)
			pts.append(c + Vector2(cos(th + hw_t), sin(th + hw_t)) * r)
			pts.append(c + Vector2(cos(th + hw_b), sin(th + hw_b)) * r_in)
			# lembah antar gigi: titik tengah di lingkar dalam supaya tidak terlihat bersudut
			var vm: float = th + step * 0.5
			pts.append(c + Vector2(cos(vm), sin(vm)) * r_in)
		return pts

	func _draw_rank_badge(c: Vector2, rank: int, a: float) -> void:
		var col: Color = CampaignData.grade_color(rank)
		var rad: float = 13.0
		if rank >= 4:
			var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
			draw_circle(c, rad + 5.0 + 2.0 * pulse, Color(col.r, col.g, col.b, (0.16 + 0.12 * pulse) * a))
		draw_circle(c + Vector2(1.5, 2.5), rad, Color(0, 0, 0, 0.45 * a))
		draw_circle(c, rad, _ca(col.darkened(0.55), a))
		draw_arc(c, rad, 0.0, TAU, 28, _ca(col, a), 2.5, true)
		UIKit.text_in(self, CampaignData.grade_letter(rank), Rect2(c.x - 18.0, c.y - 18.0, 36.0, 36.0), 20, _ca(col.lightened(0.35), a), HORIZONTAL_ALIGNMENT_CENTER, 4, Color(0, 0, 0, a))

	func _draw_arrows() -> void:
		for idx in 2:
			var dir: int = -1 if idx == 0 else 1
			var nw: int = target + dir
			if nw < 0 or nw >= CampaignData.WORLDS.size():
				continue
			var acc: Color = Global.MAP_PALETTES[String(CampaignData.WORLDS[nw]["id"])][2]
			var hv: float = arrow_anim[idx]
			var c: Vector2 = arrow_center(idx)
			var bob: float = sin(t * 3.0) * 3.0 * float(dir)
			var rad: float = 24.0 + 4.0 * hv
			draw_circle(c, rad + 8.0, Color(acc.r, acc.g, acc.b, 0.12 + 0.12 * hv))
			draw_circle(c, rad, Color(0.03, 0.03, 0.09, 0.82))
			draw_arc(c, rad, 0.0, TAU, 32, Color(acc.r, acc.g, acc.b, 0.8 + 0.2 * hv), 3.0, true)
			UIKit.draw_chevron(self, c + Vector2(bob, 0.0), 10.0, dir, Color(1, 1, 1, 0.8 + 0.2 * hv))

	func _draw_tabs() -> void:
		var unlocked: int = int(hub.save["unlocked"])
		var n_tabs: int = tab_anim.size()
		for j in n_tabs:
			var wd: Dictionary = CampaignData.WORLDS[j]
			var acc: Color = Global.MAP_PALETTES[String(wd["id"])][2]
			var an: float = tab_anim[j]
			var hv: float = 1.0 if j == _hover_tab else 0.0
			var r: Rect2 = tab_rect(j)
			r.position.y -= 4.0 * an
			var pts: PackedVector2Array = UIKit.slanted(r.size.x, r.size.y, 10.0, r.position.x, r.position.y)
			draw_colored_polygon(UIKit.slanted(r.size.x, r.size.y, 10.0, r.position.x + 2.0, r.position.y + 3.0), Color(0, 0, 0, 0.4))
			var fill: Color = Color(0.04, 0.05, 0.12, 0.88).lerp(acc, 0.12 * hv).lerp(acc.darkened(0.1), an)
			draw_colored_polygon(pts, fill)
			draw_polyline(UIKit.closed(pts), Color(acc.r, acc.g, acc.b, 0.35 + 0.4 * hv + 0.25 * an), 2.0, true)
			var locked: bool = int(wd["levels"][0]) + hub.off() > unlocked or held.has(int(wd["levels"][0]) + hub.off())
			var tc: Color = Color(0.04, 0.04, 0.1).lerp(Color(1, 1, 1, 0.78), 1.0 - an)
			if locked:
				UIKit.draw_lock(self, Vector2(r.position.x + 22.0, r.position.y + r.size.y * 0.5), 14.0, Color(1, 1, 1, 0.4))
				tc = Color(1, 1, 1, 0.4)
			UIKit.text_in(self, String(wd["name"]), Rect2(r.position.x + 10.0, r.position.y, r.size.x - 20.0, r.size.y), tab_fs[j], tc, HORIZONTAL_ALIGNMENT_CENTER, 0)
		# garis penanda yang meluncur mulus mengikuti posisi geser
		var lo: int = clampi(int(floor(pos)), 0, n_tabs - 1)
		var hi: int = clampi(lo + 1, 0, n_tabs - 1)
		var fr: float = clampf(pos - float(lo), 0.0, 1.0)
		var r_lo: Rect2 = tab_rect(lo)
		var r_hi: Rect2 = tab_rect(hi)
		var ux: float = lerpf(r_lo.position.x, r_hi.position.x, fr)
		var c_lo: Color = Global.MAP_PALETTES[String(CampaignData.WORLDS[lo]["id"])][2]
		var c_hi: Color = Global.MAP_PALETTES[String(CampaignData.WORLDS[hi]["id"])][2]
		var uc: Color = c_lo.lerp(c_hi, fr)
		draw_rect(Rect2(ux + 6.0, TAB_Y + TAB_H + 3.0, tab_w() - 12.0, 3.0), uc)
		draw_rect(Rect2(ux - 2.0, TAB_Y + TAB_H + 1.0, tab_w() + 4.0, 7.0), Color(uc.r, uc.g, uc.b, 0.2))


# ================================================================== pilih chapter
## Pelat pemilih chapter di atas peta: panah kiri / kanan, judul chapter (meluncur saat berganti) dan 5 chip nomor chapter.
##  - Pindah chapter: klik panah / chip, roda mouse di atas pelat, TAB / PageUp / PageDown, atau kiri-kanan saat pelat terpilih.
##  - Chip: angka = chapter terbuka, gembok = masih terkunci, bintang kecil = chapter sudah tamat.
##  - Arahkan kursor ke sebuah chip untuk melihat nama chapter itu tanpa berpindah.
## Ukuran pelat (452 x 80) dipilih supaya tidak menyentuh banner CAMPAIGN (kiri), kartu fighter (kanan) maupun status P1-P4.
class ChapterNav extends Control:
	signal step(dir: int)
	signal jump(chapter: int)
	signal hovered
	const ACCENTS := [Color("ffd23f"), Color("ff8a3a"), Color("ff4a6a"), Color("b36bff"), Color("4fd8ff")]
	const PW := 452.0
	const PH := 80.0
	const ARROW_R := 21.0
	const CHIP_W := 30.0
	const CHIP_H := 18.0
	const CHIP_GAP := 8.0
	const CHIP_Y := 55.0
	const SLIDE_T := 0.3
	var hub
	var t: float = 0.0
	var selected := false
	var sel_a: float = 0.0         # animasi halus 0..1 untuk sorotan kursor (keyboard / gamepad / mouse)
	var _hv: int = 0               # -1 panah kiri, 1 panah kanan
	var _hv_chip: int = -1         # chip yang sedang disorot kursor
	var _press: int = 0            # panah yang baru ditekan (efek mengecil sebentar)
	var _press_t: float = 0.0
	var _shown: int = -1           # chapter yang judulnya sedang tampil
	var _prev: int = 0
	var _anim: float = 1.0         # 0..1 progres geser judul
	var _dir: int = 1
	var _acc: Color = ACCENTS[0]
	var _bump: float = 0.0         # getar singkat saat sudah di ujung (tidak ada chapter lagi)
	var _bump_dir: int = 0
	var _pop_c: int = -1           # chip chapter yang sedang merayakan buka kunci
	var _pop_t: float = -1.0
	var _sb := StyleBoxFlat.new()

	func _init() -> void:
		size = Vector2(PW, PH)
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_sb.set_corner_radius_all(5)

	func bump(dir: int) -> void:
		_bump = 1.0
		_bump_dir = dir

	func _process(d: float) -> void:
		t += d
		if hub != null:
			var c: int = hub.chapter
			if _shown < 0:
				_shown = c
				_acc = ACCENTS[c]
			elif c != _shown:
				_prev = _shown
				_dir = 1 if c > _shown else -1
				_shown = c
				_anim = 0.0
			_acc = _acc.lerp(ACCENTS[_shown], minf(1.0, d * 12.0))
		_anim = minf(1.0, _anim + d / SLIDE_T)
		sel_a = lerpf(sel_a, 1.0 if selected else 0.0, minf(d * 14.0, 1.0))
		_press_t = maxf(0.0, _press_t - d * 6.0)
		_bump = maxf(0.0, _bump - d * 4.0)
		if _pop_t >= 0.0:
			_pop_t += d
			if _pop_t > 2.4:
				_pop_t = -1.0
				_pop_c = -1
		queue_redraw()

	# ------------------------------------------------------------------ geometri & status
	func _arrow_c(dir: int) -> Vector2:
		return Vector2(38.0, 31.0) if dir < 0 else Vector2(PW - 38.0, 31.0)

	func _chip_rect(i: int) -> Rect2:
		var total: float = float(CampaignData.CHAPTERS) * CHIP_W + float(CampaignData.CHAPTERS - 1) * CHIP_GAP
		return Rect2((PW - total) * 0.5 + float(i) * (CHIP_W + CHIP_GAP), CHIP_Y, CHIP_W, CHIP_H)

	func _hit_arrow(p: Vector2) -> int:
		for dir in [-1, 1]:
			if p.distance_to(_arrow_c(dir)) <= ARROW_R + 6.0:
				return dir
		return 0

	func _hit_chip(p: Vector2) -> int:
		for i in CampaignData.CHAPTERS:
			if _chip_rect(i).grow(4.0).has_point(p):
				return i
		return -1

	func _locked(c: int) -> bool:
		if hub.pager != null and hub.pager.held.has(CampaignData.chapter_first(c)):
			return true            # chapter baru: gembok tetap tampil sampai efek unlock berjalan
		return int(hub.save["unlocked"]) < CampaignData.chapter_first(c)

	## Chip chapter yang baru terbuka "meledak" (membesar, gelombang, kilauan).
	func celebrate(c: int) -> void:
		_pop_c = c
		_pop_t = 0.0

	func _cleared(c: int) -> bool:
		return int((hub.save["stars"] as Dictionary).get(CampaignData.chapter_last(c), 0)) > 0

	func _stars(c: int) -> int:
		var n: int = 0
		for lvl in range(CampaignData.chapter_first(c), CampaignData.chapter_last(c) + 1):
			n += int((hub.save["stars"] as Dictionary).get(lvl, 0))
		return n

	# ------------------------------------------------------------------ input
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var p: Vector2 = (event as InputEventMouseMotion).position
			_hv = _hit_arrow(p)
			_hv_chip = _hit_chip(p)
			hovered.emit()
		elif event is InputEventMouseButton and event.pressed:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				var d: int = _hit_arrow(mb.position)
				if d != 0:
					_press = d
					_press_t = 1.0
					step.emit(d)
					return
				var ci: int = _hit_chip(mb.position)
				if ci >= 0 and ci != int(hub.chapter):
					jump.emit(ci)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				step.emit(-1)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				step.emit(1)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			_hv = 0
			_hv_chip = -1

	# ------------------------------------------------------------------ gambar
	func _draw_title(ch: int, a: float, off: float) -> void:
		if a <= 0.01:
			return
		var acc: Color = ACCENTS[ch]
		var ink := Color(0, 0, 0, a)
		UIKit.text_in(self, "CHAPTER %d" % (ch + 1), Rect2(66.0 + off, 5.0, PW - 132.0, 30.0), 28, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 6, ink)
		UIKit.text_in(self, CampaignData.chapter_name(ch), Rect2(66.0 + off, 34.0, PW - 132.0, 18.0), 16, Color(acc.lightened(0.25), 0.96 * a), HORIZONTAL_ALIGNMENT_CENTER, 5, ink)

	## Titik pada jarak `dist` di sepanjang garis tertutup `pts` (dipakai untuk cahaya yang berkeliling di tepi pelat).
	func _along(pts: PackedVector2Array, dist: float) -> Vector2:
		var n: int = pts.size()
		var total: float = 0.0
		for i in n:
			total += pts[i].distance_to(pts[(i + 1) % n])
		var d: float = fposmod(dist, total)
		for i in n:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % n]
			var seg: float = a.distance_to(b)
			if d <= seg:
				return a.lerp(b, d / maxf(seg, 0.001))
			d -= seg
		return pts[0]

	func _draw_lock(c: Vector2, col: Color) -> void:
		draw_rect(Rect2(c.x - 5.0, c.y - 1.0, 10.0, 8.0), col)
		draw_arc(Vector2(c.x, c.y - 1.0), 3.4, PI, TAU, 10, col, 1.8, true)

	func _draw() -> void:
		if hub == null:
			return
		var ch: int = hub.chapter
		var acc: Color = _acc
		var shake: float = sin(t * 70.0) * 5.0 * _bump * float(_bump_dir)
		# --- pelat
		var pts := UIKit.slanted(PW - 10.0, PH - 8.0, 14.0, 5.0 + shake, 3.0)
		var pulse: float = 0.5 + 0.5 * sin(t * 6.0)
		draw_colored_polygon(UIKit.slanted(PW - 10.0, PH - 8.0, 14.0, 5.0 + shake, 7.0), Color(0, 0, 0, 0.5))
		if sel_a > 0.01:
			# sorotan kursor: cahaya emas lebar di belakang pelat + dua bingkai berdenyut di luar pelat
			for k in 4:
				var gk: float = float(k + 1) * 3.0
				draw_colored_polygon(UIKit.slanted(PW - 10.0 + gk * 2.0, PH - 8.0 + gk * 2.0, 14.0, 5.0 + shake - gk, 3.0 - gk), Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, sel_a * (0.05 + 0.03 * pulse) * (5.0 - float(k)) * 0.5))
			draw_polyline(UIKit.closed(UIKit.slanted(PW - 2.0, PH, 16.0, 1.0 + shake, 1.0)), Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, sel_a * (0.35 + 0.35 * pulse)), 3.0, true)
		var fill: Color = Color(0.05, 0.06, 0.14, 0.95).lerp(acc, 0.14 + 0.16 * sel_a)
		draw_colored_polygon(pts, fill)
		if sel_a > 0.01:
			# kilau tipis menyapu pelat
			var sx: float = (fposmod(t * 0.55, 1.6) - 0.3) * PW
			var band := PackedVector2Array([Vector2(sx + 40.0, 0.0), Vector2(sx + 100.0, 0.0), Vector2(sx + 60.0, PH), Vector2(sx, PH)])
			for piece in Geometry2D.intersect_polygons(band, pts):
				draw_colored_polygon(piece, Color(1, 1, 1, 0.10 * sel_a))
		# garis tepi: warna aksen -> putih-emas tebal saat terpilih
		var edge: Color = Color(acc.r, acc.g, acc.b, 1.0).lerp(Color(1.0, 0.93, 0.55, 1.0), sel_a)
		draw_polyline(UIKit.closed(pts), edge, 3.0 + 3.0 * sel_a, true)
		if sel_a > 0.01:
			draw_polyline(UIKit.closed(UIKit.slanted(PW - 10.0 - 8.0, PH - 8.0 - 8.0, 14.0, 9.0 + shake, 7.0)), Color(1, 1, 1, 0.22 * sel_a), 1.5, true)
			# cahaya yang berkeliling di tepi pelat
			var run_pts := UIKit.slanted(PW - 10.0, PH - 8.0, 14.0, 5.0 + shake, 3.0)
			var base_d: float = t * 330.0
			for ti in 10:
				var tp: Vector2 = _along(run_pts, base_d - float(ti) * 9.0)
				var ta: float = (1.0 - float(ti) / 10.0) * sel_a
				draw_circle(tp, 7.0 - 0.4 * float(ti), Color(1.0, 0.85, 0.3, 0.30 * ta))
				draw_circle(tp, 3.6 - 0.2 * float(ti), Color(1, 1, 1, 0.95 * ta))
		# --- judul (meluncur ke arah panah yang ditekan)
		var e: float = 1.0 - pow(1.0 - _anim, 3.0)
		if _anim < 1.0:
			_draw_title(_prev, 1.0 - e, -float(_dir) * 46.0 * e + shake)
		_draw_title(_shown, e, float(_dir) * 46.0 * (1.0 - e) + shake)
		# --- panah: chevron polos tanpa lingkaran, ditaruh di dalam pelat supaya tidak menabrak tepi miring
		for dir in [-1, 1]:
			var ok: bool = ch + dir >= 0 and ch + dir < CampaignData.CHAPTERS
			var hv: float = 1.0 if (_hv == dir and ok) else 0.0
			var pr: float = _press_t if _press == dir else 0.0
			var sa: float = sel_a if ok else 0.0
			var a: float = 0.9 if ok else 0.22
			var sc: float = (1.0 + 0.18 * hv) * (1.0 - 0.15 * pr)
			var nudge: float = sin(t * 6.0) * 1.5 * sa * float(dir) if ok else 0.0
			var c2: Vector2 = _arrow_c(dir) + Vector2(shake + nudge, 0.0)
			var col: Color = Color(1, 1, 1, a).lerp(Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, a), maxf(sa, hv))
			var hh: float = 11.0 * sc
			var dd: float = 6.5 * sc
			var chev := PackedVector2Array([
				c2 + Vector2(-float(dir) * dd, -hh), c2 + Vector2(float(dir) * dd, 0.0), c2 + Vector2(-float(dir) * dd, hh),
			])
			draw_polyline(chev, Color(0, 0, 0, 0.45 * a), 6.0, true)     # bayangan tipis agar tetap terbaca
			draw_polyline(chev, col, 3.5, true)
		# --- chip nomor chapter
		for i in CampaignData.CHAPTERS:
			var r: Rect2 = _chip_rect(i)
			r.position.x += shake
			var is_cur: bool = i == ch
			var hv_c: bool = i == _hv_chip
			var lk: bool = _locked(i)
			var ca: Color = ACCENTS[i]
			var popping: bool = i == _pop_c and _pop_t >= 0.0
			if popping:
				r = r.grow(7.0 * sin(clampf(_pop_t / 0.7, 0.0, 1.0) * PI))
				var fu: float = clampf(1.0 - _pop_t / 0.5, 0.0, 1.0)
				if fu > 0.0:
					draw_rect(r.grow(12.0), Color(1, 1, 1, 0.5 * fu))
			if hv_c and not is_cur:
				r.position.y -= 2.0
				draw_rect(r.grow(5.0), Color(ca.r, ca.g, ca.b, 0.16))
			_sb.set_border_width_all(2)
			if is_cur:
				_sb.bg_color = acc
				_sb.border_color = Color(1, 1, 1, 0.95)
			else:
				_sb.bg_color = Color(0.04, 0.05, 0.12, 0.92).lerp(ca, 0.28 if hv_c else 0.0)
				_sb.border_color = Color(ca.r, ca.g, ca.b, (0.28 if lk else 0.7) + (0.25 if hv_c else 0.0))
			draw_style_box(_sb, r)
			var cc: Vector2 = r.get_center()
			if lk:
				_draw_lock(cc + Vector2(0, 0.5), Color(1, 1, 1, 0.55 if hv_c else 0.38))
			else:
				var tc: Color = Color(0.06, 0.05, 0.1) if is_cur else Color(1, 1, 1, 0.95)
				UIKit.text_in(self, "%d" % (i + 1), Rect2(r.position.x, r.position.y, r.size.x, r.size.y), 15, tc, HORIZONTAL_ALIGNMENT_CENTER, 0)
			if _cleared(i):
				draw_colored_polygon(CampaignData.star_points(Vector2(r.end.x - 1.0, r.position.y + 1.0), 6.0), UIKit.GOLD)
			if popping:
				for k in 3:
					var pu: float = clampf((_pop_t - 0.12 * float(k)) / 1.0, 0.0, 1.0)
					if pu > 0.0 and pu < 1.0:
						draw_rect(r.grow(3.0 + 26.0 * (1.0 - pow(1.0 - pu, 3.0))), Color(ca.r, ca.g, ca.b, (1.0 - pu) * 0.9), false, 3.0)
				for k in 8:
					var su: float = clampf((_pop_t - 0.05) / 1.1, 0.0, 1.0)
					if su > 0.0 and su < 1.0:
						var ang: float = float(k) * TAU / 8.0 + 0.4
						var sp: Vector2 = cc + Vector2(cos(ang), sin(ang)) * (14.0 + 34.0 * (1.0 - pow(1.0 - su, 3.0)))
						draw_circle(sp, 3.2 * (1.0 - su), Color(1.0, 0.9, 0.45, 1.0 - su))
		# --- keterangan chip yang disorot (di baris judul kedua)
		if _hv_chip >= 0 and _hv_chip != ch:
			var h: int = _hv_chip
			var tag: String = "LOCKED" if _locked(h) else ("CLEARED" if _cleared(h) else "%d / 150 STARS" % _stars(h))
			draw_rect(Rect2(66.0 + shake, 33.0, PW - 132.0, 21.0), Color(0.05, 0.06, 0.14, 0.97).lerp(acc, 0.1))
			UIKit.text_in(self, "%s   -   %s" % [CampaignData.chapter_name(h), tag], Rect2(66.0 + shake, 34.0, PW - 132.0, 18.0), 15, Color(ACCENTS[h].lightened(0.3), 0.98), HORIZONTAL_ALIGNMENT_CENTER, 5)


# ================================================================== kartu fighter
## Menunjukkan karakter & senjata yang sedang dipakai di CAMPAIGN. Klik kartu (atau kursor + ACCEPT) = ganti fighter.
class FighterCard extends Control:
	signal clicked
	signal hovered
	var fighter: Dictionary = {}
	var t: float = 0.0
	var selected: bool = false      # kursor (keyboard / gamepad) sedang berada di kartu ini
	var sel_a: float = 0.0          # animasi halus 0..1 untuk sorotan

	func _init() -> void:
		size = Vector2(390, 124)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void: hovered.emit())

	func _process(d: float) -> void:
		t += d
		sel_a = lerpf(sel_a, 1.0 if selected else 0.0, minf(d * 14.0, 1.0))
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit()

	func _fit(tex: Texture2D, box: Rect2) -> Rect2:
		if tex == null:
			return box
		var sc: float = minf(box.size.x / float(tex.get_width()), box.size.y / float(tex.get_height()))
		var sz := Vector2(float(tex.get_width()), float(tex.get_height())) * sc
		return Rect2(box.get_center() - sz * 0.5, sz)

	func _draw() -> void:
		if fighter.is_empty():
			return
		var ch: int = int(fighter["character"])
		var wid: String = String(fighter["weapon"])
		var wdata: Dictionary = Global.WEAPONS[wid]
		var col: Color = Global.PLAYER_COLORS[0]
		# pelat kartu
		var pts := UIKit.slanted(size.x, size.y, 16, 0.0, 0.0)
		draw_colored_polygon(UIKit.slanted(size.x, size.y, 16, 4.0, 5.0), Color(0, 0, 0, 0.5))
		draw_colored_polygon(pts, Color(0.05, 0.07, 0.15, 0.94).lerp(col, 0.12))
		draw_polyline(UIKit.closed(pts), Color(col.lightened(0.2), 0.9).lerp(UIKit.GOLD, sel_a), 3.0 + 2.0 * sel_a, true)
		if sel_a > 0.01:
			# sorotan kursor: bingkai emas berdenyut di luar pelat
			var pulse: float = 0.5 + 0.5 * sin(t * 6.0)
			var gpts := UIKit.slanted(size.x + 12.0, size.y + 12.0, 16, -6.0, -6.0)
			draw_polyline(UIKit.closed(gpts), Color(UIKit.GOLD, sel_a * (0.35 + 0.35 * pulse)), 3.0, true)
		# kilau tipis menyapu pelat
		var sx: float = (fposmod(t * 0.35, 2.0) - 0.3) * size.x
		var band := PackedVector2Array([Vector2(sx + 30.0, 0.0), Vector2(sx + 70.0, 0.0), Vector2(sx + 40.0, size.y), Vector2(sx, size.y)])
		for piece in Geometry2D.intersect_polygons(band, pts):
			draw_colored_polygon(piece, Color(1, 1, 1, 0.06))
		# potret karakter
		var pr := Rect2(16.0, 14.0, 96.0, 96.0)
		var bpts := UIKit.slanted(pr.size.x, pr.size.y, 10, pr.position.x, pr.position.y)
		var lc: Color = col.lightened(0.2)
		var dc: Color = col.darkened(0.65)
		draw_polygon(bpts, PackedColorArray([lc, lc, dc, dc]))
		draw_polyline(UIKit.closed(bpts), Color(1, 1, 1, 0.6), 2.0, true)
		var ctex: Texture2D = Cosmetics.char_tex(ch, Cosmetics.last_cskin(ch))
		var cr: Rect2 = _fit(ctex, pr.grow(-8.0))
		cr.position.y += sin(t * 2.6) * 2.5
		if ctex != null:
			draw_texture_rect(ctex, cr, false)
		# teks
		var x0: float = 128.0
		var avail: float = size.x - x0 - 20.0
		UIKit.text_in(self, "FIGHTER", Rect2(x0, 8.0, 200.0, 18.0), 14, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT, 3)
		var cname: String = Global.character_name(0, ch)
		var fs: int = 30
		while fs > 16 and UIKit.text_w(cname, fs) > avail:
			fs -= 2
		UIKit.text_in(self, cname, Rect2(x0, 24.0, avail, 38.0), fs, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 6)
		draw_rect(Rect2(x0, 66.0, avail, 2.0), Color(1, 1, 1, 0.18))
		UIKit.text_in(self, "WEAPON", Rect2(x0, 68.0, 200.0, 16.0), 13, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT, 3)
		# senjata
		var gbox := Rect2(x0, 84.0, 100.0, 32.0)
		var gtex: Texture2D = Cosmetics.weapon_tex(wid, Cosmetics.last_wskin(wid))
		var gr: Rect2 = _fit(gtex, gbox)
		if gtex != null:
			draw_texture_rect(gtex, gr, false)
		var wcol: Color = wdata.get("color", UIKit.GOLD)
		UIKit.text_in(self, String(wdata["name"]), Rect2(x0 + 108.0, 82.0, avail - 108.0, 22.0), 22, wcol, HORIZONTAL_ALIGNMENT_LEFT, 5)
		var am: int = int(wdata.get("ammo", -1))
		UIKit.text_in(self, "UNLIMITED" if am < 0 else "%d AMMO" % am, Rect2(x0 + 108.0, 102.0, avail - 108.0, 16.0), 14, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT, 3)


# ================================================================== info bawah
class InfoBar extends Control:
	var hub
	func _init() -> void:
		size = Vector2(1200, 34)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var f: int = int(hub.focus)
		var s: String = ""
		if f >= 1:
			var lv: Dictionary = hub.lv(f)
			s = "%s  -  %s" % [CampaignData.level_text(f), String(lv["name"])]
			if hub.is_boss(f):
				s += "   [BOSS]"
			if f > int(hub.save["unlocked"]):
				s += "   LOCKED - CLEAR THE PREVIOUS LEVEL"
			else:
				var best: int = int((hub.save["best"] as Dictionary).get(f, 0))
				s += "   WAVES %d" % (lv["waves"] as Array).size()
				if best > 0:
					s += "   BEST %d" % best
				var rk: int = int((hub.save["grades"] as Dictionary).get(f, 0))
				if rk > 0 and int((hub.save["stars"] as Dictionary).get(f, 0)) > 0:
					s += "   RANK %s" % CampaignData.grade_letter(rk)
		elif f == -2:
			s = "RESUME YOUR RUN WITH ALL PERKS AND LIVES" if not (hub.save["run"] as Dictionary).is_empty() else "START A NEW CAMPAIGN FROM LEVEL 1"
		elif f == -3:
			s = "CHAPTER %d  -  %s      (LEFT / RIGHT, TAB OR PAGE UP / DOWN TO SWITCH)" % [hub.chapter + 1, CampaignData.chapter_name(hub.chapter)]
		else:
			s = "CHANGE YOUR FIGHTER AND WEAPON"
		UIKit.text_in(self, s, Rect2(0, 0, size.x, size.y), 24, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_LEFT, 6)


# ================================================================== efek buka kunci MAP & CHAPTER
## Lapisan layar penuh (paling atas, tidak menangkap mouse) untuk dua perayaan yang SENGAJA dibuat berbeda:
##  - MAP baru     : efek "di dalam panel" berwarna aksen dunia: kilau pemindai menyapu panel, bingkai menyala,
##                   gembok pecah, gelombang belah ketupat, kilauan, pita "NEW MAP UNLOCKED" dan lencana "NEW" di tab dunia.
##  - CHAPTER baru : efek sinematik layar penuh berwarna aksen chapter: kilat, layar meredup, sinar berputar, gelombang kejut,
##                   layar bergetar, confetti, dan pita lebar "NEW CHAPTER UNLOCKED" + chip chapter yang meledak.
## Posisi node dihitung langsung dari WorldPager, jadi efek selalu tepat di level yang baru terbuka.
class UnlockFx extends Control:
	const MAP_DUR := 2.8
	const CH_DUR := 4.0
	const GOLD := Color(1.0, 0.82, 0.25)
	var hub
	var pager
	var nav
	var fx: Array = []
	var _rng := RandomNumberGenerator.new()
	var _shake_base: Vector2 = Vector2.ZERO
	var _shaking := false
	var _was_active := false

	func _init() -> void:
		size = Vector2(1280.0, 720.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rng.randomize()

	# ------------------------------------------------------------------ pemicu
	func play_map(n: int) -> void:
		var w: int = CampaignData.world_of(n)
		var acc: Color = Global.MAP_PALETTES[String(CampaignData.WORLDS[w]["id"])][2]
		var shards: Array = []
		for q in 9:
			shards.append({"a": _rng.randf() * TAU, "s": _rng.randf_range(110.0, 230.0), "r": _rng.randf() * TAU,
				"rv": _rng.randf_range(-9.0, 9.0), "z": _rng.randf_range(4.0, 8.0)})
		var sparks: Array = []
		for q in 18:
			sparks.append({"a": _rng.randf() * TAU, "d": _rng.randf_range(50.0, 190.0), "dl": _rng.randf_range(0.05, 0.9),
				"z": _rng.randf_range(6.0, 13.0), "g": _rng.randf() < 0.4})
		fx.append({"kind": "map", "t": 0.0, "n": n, "w": w, "acc": acc, "shards": shards, "sparks": sparks})

	func play_chapter(n: int) -> void:
		var ch: int = CampaignData.chapter_of(n)
		var acc: Color = ChapterNav.ACCENTS[ch]
		var shards: Array = []
		for q in 12:
			shards.append({"a": _rng.randf() * TAU, "s": _rng.randf_range(220.0, 520.0), "r": _rng.randf() * TAU,
				"rv": _rng.randf_range(-11.0, 11.0), "z": _rng.randf_range(6.0, 12.0)})
		var pal: Array = [acc, acc.lightened(0.35), GOLD, Color.WHITE, acc.lightened(0.6)]
		var conf: Array = []
		for q in 135:
			var cannon: int = q % 3        # 0 = dari node, 1 = meriam kiri-bawah, 2 = meriam kanan-bawah
			var org: Vector2 = Vector2(-1.0, -1.0)
			var ang: float = _rng.randf_range(-PI * 0.92, -PI * 0.08)
			var spd: float = _rng.randf_range(380.0, 940.0)
			if cannon == 1:
				org = Vector2(-10.0, 730.0)
				ang = _rng.randf_range(-PI * 0.42, -PI * 0.2)
				spd = _rng.randf_range(820.0, 1250.0)
			elif cannon == 2:
				org = Vector2(1290.0, 730.0)
				ang = _rng.randf_range(-PI * 0.8, -PI * 0.58)
				spd = _rng.randf_range(820.0, 1250.0)
			conf.append({"o": org, "a": ang, "s": spd, "r": _rng.randf() * TAU, "rv": _rng.randf_range(-8.0, 8.0),
				"w": _rng.randf_range(12.0, 22.0), "h": _rng.randf_range(7.0, 12.0), "c": pal[_rng.randi() % pal.size()],
				"dl": (0.12 if cannon == 0 else 0.5) + _rng.randf() * 0.25, "life": _rng.randf_range(2.2, 3.0)})
		fx.append({"kind": "chapter", "t": 0.0, "n": n, "ch": ch, "acc": acc, "shards": shards, "conf": conf})

	# ------------------------------------------------------------------ waktu
	func _process(d: float) -> void:
		var shake := Vector2.ZERO
		var i: int = fx.size() - 1
		while i >= 0:
			var e: Dictionary = fx[i]
			e["t"] = float(e["t"]) + d
			var tt: float = float(e["t"])
			if tt > (CH_DUR if String(e["kind"]) == "chapter" else MAP_DUR):
				fx.remove_at(i)
			elif String(e["kind"]) == "chapter":
				var amp: float = 9.0 * pow(clampf(1.0 - tt / 0.55, 0.0, 1.0), 2.0)
				shake += Vector2(sin(tt * 93.0), cos(tt * 71.0)) * amp
			i -= 1
		if shake != Vector2.ZERO:
			if not _shaking:
				_shake_base = hub.position
				_shaking = true
			hub.position = _shake_base + shake
		elif _shaking:
			hub.position = _shake_base
			_shaking = false
		var active: bool = not fx.is_empty()
		if active or _was_active:
			queue_redraw()
		_was_active = active

	func _exit_tree() -> void:
		if _shaking and hub != null:
			hub.position = _shake_base

	# ------------------------------------------------------------------ util
	func _eo(x: float) -> float:
		return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)

	func _ei(x: float) -> float:
		var u: float = clampf(x, 0.0, 1.0)
		return u * u * u

	func _eb(x: float) -> float:
		var u: float = clampf(x, 0.0, 1.0) - 1.0
		return 1.0 + 2.70158 * u * u * u + 1.70158 * u * u

	func _sparkle(c: Vector2, r: float, rot: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for q in 8:
			var rad: float = r if q % 2 == 0 else r * 0.28
			var a: float = rot + float(q) * PI / 4.0
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
		return pts

	func _shard(c: Vector2, rot: float, z: float, col: Color) -> void:
		var pts := PackedVector2Array([Vector2(0.0, -z), Vector2(z * 0.8, z * 0.7), Vector2(-z * 0.8, z * 0.7)])
		var out := PackedVector2Array()
		for p in pts:
			out.append(c + p.rotated(rot))
		draw_colored_polygon(out, col)

	func _draw_shards(c: Vector2, shards: Array, t: float, life: float, col: Color) -> void:
		var f: float = 1.0 - clampf(t / life, 0.0, 1.0)
		if f <= 0.0:
			return
		for s in shards:
			var dir := Vector2(cos(float(s["a"])), sin(float(s["a"])))
			var p: Vector2 = c + dir * float(s["s"]) * _eo(t / life) + Vector2(0.0, 320.0 * t * t)
			_shard(p, float(s["r"]) + float(s["rv"]) * t, float(s["z"]) * (0.6 + 0.4 * f), Color(col.r, col.g, col.b, f))

	func _draw() -> void:
		if hub == null or pager == null:
			return
		for e in fx:
			if String(e["kind"]) == "chapter":
				_draw_chapter(e)
			else:
				_draw_map(e)

	# ================================================================== MAP BARU
	func _draw_map(e: Dictionary) -> void:
		var t: float = float(e["t"])
		var acc: Color = e["acc"]
		var w: int = int(e["w"])
		var c: Vector2 = pager.node_screen(int(e["n"]))
		var poly: PackedVector2Array = pager.page_poly_screen(w)
		var bb := Rect2(poly[0], Vector2.ZERO)
		for p in poly:
			bb = bb.expand(p)
		# 1) panel menyala sebentar + kilau pemindai menyapu dari kiri ke kanan
		var tint: float = clampf(1.0 - t / 1.1, 0.0, 1.0)
		if tint > 0.0:
			draw_colored_polygon(poly, Color(acc.r, acc.g, acc.b, 0.22 * tint))
		var su: float = clampf(t / 1.0, 0.0, 1.0)
		if su > 0.0 and su < 1.0:
			var x0: float = lerpf(bb.position.x - 220.0, bb.end.x + 60.0, smoothstep(0.0, 1.0, su))
			var env: float = sin(su * PI)
			var band := PackedVector2Array([Vector2(x0 + 110.0, bb.position.y), Vector2(x0 + 230.0, bb.position.y), Vector2(x0 + 120.0, bb.end.y), Vector2(x0, bb.end.y)])
			for piece in Geometry2D.intersect_polygons(band, poly):
				draw_colored_polygon(piece, Color(1, 1, 1, 0.20 * env))
			var core := PackedVector2Array([Vector2(x0 + 160.0, bb.position.y), Vector2(x0 + 188.0, bb.position.y), Vector2(x0 + 78.0, bb.end.y), Vector2(x0 + 50.0, bb.end.y)])
			for piece2 in Geometry2D.intersect_polygons(core, poly):
				draw_colored_polygon(piece2, Color(acc.lightened(0.6), 0.55 * env))
		# 2) bingkai panel menyala
		var bf: float = clampf(1.0 - t / 1.5, 0.0, 1.0)
		if bf > 0.0:
			var cl: PackedVector2Array = UIKit.closed(poly)
			draw_polyline(cl, Color(acc.r, acc.g, acc.b, 0.35 * bf), 16.0, true)
			draw_polyline(cl, Color(acc.lightened(0.55), bf), 5.0, true)
		# 3) gembok membesar lalu lenyap + pecahannya
		var lu: float = clampf(t / 0.4, 0.0, 1.0)
		if lu < 1.0:
			UIKit.draw_lock(self, c + Vector2(0.0, -6.0 * lu), 30.0 * (1.0 + 0.9 * _eo(lu)), Color(1, 1, 1, 0.9 * (1.0 - lu)))
		_draw_shards(c, e["shards"], t, 0.95, Color(1, 1, 1))
		# 4) gelombang belah ketupat (bukan lingkaran) berputar berlawanan arah
		var cols: Array = [Color(1, 1, 1), acc, acc.lightened(0.45)]
		for k in 3:
			var du: float = clampf((t - 0.05 - 0.17 * float(k)) / 0.95, 0.0, 1.0)
			if du > 0.0 and du < 1.0:
				var rr: float = 38.0 + 200.0 * _eo(du)
				var rot: float = (0.55 if k % 2 == 0 else -0.55) * du
				var dm := PackedVector2Array()
				for q in 4:
					dm.append(c + Vector2(0.0, -rr).rotated(rot + float(q) * PI * 0.5))
				var cc: Color = cols[k]
				draw_polyline(UIKit.closed(dm), Color(cc.r, cc.g, cc.b, (1.0 - du) * 0.95), 5.0 - 3.0 * du, true)
		# 5) kilauan naik
		for s in e["sparks"]:
			var u: float = clampf((t - float(s["dl"])) / 1.2, 0.0, 1.0)
			if u > 0.0 and u < 1.0:
				var sp: Vector2 = c + Vector2(cos(float(s["a"])), sin(float(s["a"]))) * float(s["d"]) * _eo(u) + Vector2(0.0, -46.0 * u)
				var rz: float = float(s["z"]) * sin(u * PI)
				var scol: Color = GOLD if bool(s["g"]) else acc.lightened(0.5)
				if rz > 1.5:        # terlalu kecil = poligon degenerate (gagal triangulasi)
					draw_circle(sp, rz * 1.6, Color(scol.r, scol.g, scol.b, 0.18))
					draw_colored_polygon(_sparkle(sp, rz, u * 3.0), Color(1, 1, 1, 0.95))
		# 6) pita "NEW MAP UNLOCKED" meluncur dari kiri di bawah judul dunia
		var xf: Dictionary = pager.page_xf(w)
		var po: Vector2 = pager.position + (xf["o"] as Vector2)
		var ps: float = float(xf["s"])
		var rin: float = _eb(clampf((t - 0.25) / 0.55, 0.0, 1.0))
		var rout: float = _ei(clampf((t - 2.1) / 0.55, 0.0, 1.0))
		var rx: float = -(1.0 - rin) * 400.0 - rout * 400.0
		var ra: float = 1.0 - rout
		if ra > 0.01 and rin > 0.0:
			draw_set_transform(po, 0.0, Vector2(ps, ps))
			var rp := UIKit.slanted(336.0, 30.0, 12.0, 34.0 + rx, 102.0)
			draw_colored_polygon(UIKit.slanted(336.0, 30.0, 12.0, 38.0 + rx, 106.0), Color(0, 0, 0, 0.45 * ra))
			draw_colored_polygon(rp, Color(0.03, 0.04, 0.10, 0.94 * ra).lerp(acc.darkened(0.3), 0.35))
			draw_polyline(UIKit.closed(rp), Color(acc.lightened(0.4), ra), 2.5, true)
			draw_rect(Rect2(34.0 + rx + 4.0, 102.0, 8.0, 30.0), Color(acc.r, acc.g, acc.b, ra))
			draw_colored_polygon(CampaignData.star_points(Vector2(34.0 + rx + 34.0, 117.0), 10.0, t * 2.2), Color(GOLD.r, GOLD.g, GOLD.b, ra))
			UIKit.text_in(self, "NEW MAP UNLOCKED", Rect2(34.0 + rx + 52.0, 102.0, 280.0, 30.0), 20, Color(1, 1, 1, ra), HORIZONTAL_ALIGNMENT_LEFT, 4, Color(0, 0, 0, ra))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 7) tab dunia di bawah: gelombang + lencana "NEW" melayang
		var tr: Rect2 = pager.tab_rect(w)
		tr.position += pager.position
		tr.position.y -= 4.0
		for k in 2:
			var tu: float = clampf((t - 0.05 - 0.22 * float(k)) / 0.85, 0.0, 1.0)
			if tu > 0.0 and tu < 1.0:
				var gr: Rect2 = tr.grow(3.0 + 24.0 * _eo(tu))
				draw_polyline(UIKit.closed(UIKit.slanted(gr.size.x, gr.size.y, 10.0, gr.position.x, gr.position.y)), Color(acc.r, acc.g, acc.b, (1.0 - tu) * 0.9), 3.0, true)
		var ba: float = _eo(clampf((t - 0.3) / 0.3, 0.0, 1.0)) * (1.0 - _ei(clampf((t - 2.2) / 0.5, 0.0, 1.0)))
		if ba > 0.01:
			var bw := Vector2(46.0, 20.0)
			var bp := Vector2(tr.get_center().x - bw.x * 0.5, tr.position.y - 28.0 + sin(t * 8.0) * 2.5)
			var bpts := UIKit.slanted(bw.x, bw.y, 6.0, bp.x, bp.y)
			draw_colored_polygon(bpts, Color(1.0, 0.25, 0.3, 0.95 * ba))
			draw_polyline(UIKit.closed(bpts), Color(1, 1, 1, ba), 2.0, true)
			UIKit.text_in(self, "NEW", Rect2(bp.x, bp.y, bw.x, bw.y), 14, Color(1, 1, 1, ba), HORIZONTAL_ALIGNMENT_CENTER, 0)

	# ================================================================== CHAPTER BARU
	func _draw_chapter(e: Dictionary) -> void:
		var t: float = float(e["t"])
		var acc: Color = e["acc"]
		var ch: int = int(e["ch"])
		var c: Vector2 = pager.node_screen(int(e["n"]))
		# 1) layar meredup (pelat pemilih chapter dibiarkan terang supaya chip yang meledak terlihat)
		var dim: float = 0.42 * clampf(t / 0.3, 0.0, 1.0) * (1.0 - clampf((t - (CH_DUR - 0.8)) / 0.8, 0.0, 1.0))
		if dim > 0.0:
			var dc := Color(0.0, 0.0, 0.04, dim)
			var nr := Rect2(nav.position, nav.size)
			draw_rect(Rect2(-40.0, -40.0, nr.position.x + 40.0, 800.0), dc)
			draw_rect(Rect2(nr.end.x, -40.0, 1320.0 - nr.end.x, 800.0), dc)
			draw_rect(Rect2(nr.position.x, -40.0, nr.size.x, nr.position.y + 40.0), dc)
			draw_rect(Rect2(nr.position.x, nr.end.y, nr.size.x, 760.0 - nr.end.y), dc)
		# 2) sinar berputar dari node
		var ru: float = clampf(t / 0.55, 0.0, 1.0)
		var rf: float = ru * (1.0 - clampf((t - 1.8) / 1.2, 0.0, 1.0))
		if rf > 0.0:
			var ln: float = 1150.0 * _eo(ru)
			for q in 14:
				var a0: float = t * 0.32 + float(q) * TAU / 14.0
				var hw: float = 0.07
				var p2: Vector2 = c + Vector2(cos(a0 - hw), sin(a0 - hw)) * ln
				var p3: Vector2 = c + Vector2(cos(a0 + hw), sin(a0 + hw)) * ln
				var rc: Color = acc.lightened(0.55) if q % 2 == 0 else GOLD
				draw_polygon(PackedVector2Array([c, p2, p3]), PackedColorArray([Color(rc.r, rc.g, rc.b, 0.42 * rf), Color(rc.r, rc.g, rc.b, 0.0), Color(rc.r, rc.g, rc.b, 0.0)]))
		# 3) inti cahaya + gelombang kejut berlapis
		var gl: float = clampf(1.0 - t / 0.9, 0.0, 1.0)
		if gl > 0.0:
			draw_circle(c, 90.0 * (1.0 - gl * 0.4), Color(1, 1, 1, 0.5 * gl))
			draw_circle(c, 170.0 * (1.0 - gl * 0.3), Color(acc.r, acc.g, acc.b, 0.25 * gl))
		var rcols: Array = [Color.WHITE, acc.lightened(0.4), GOLD, acc]
		for k in 4:
			var du: float = clampf((t - 0.14 * float(k)) / 1.15, 0.0, 1.0)
			if du > 0.0 and du < 1.0:
				var rc2: Color = rcols[k]
				draw_arc(c, 30.0 + 820.0 * _eo(du), 0.0, TAU, 96, Color(rc2.r, rc2.g, rc2.b, (1.0 - du) * 0.9), 10.0 * (1.0 - du) + 1.5, true)
		# 4) gembok besar pecah
		var lu: float = clampf(t / 0.45, 0.0, 1.0)
		if lu < 1.0:
			UIKit.draw_lock(self, c + Vector2(0.0, -10.0 * lu), 30.0 * (1.0 + 1.8 * _eo(lu)), Color(1, 1, 1, 0.95 * (1.0 - lu)))
		_draw_shards(c, e["shards"], t, 1.3, Color(1, 1, 1))
		# 5) pita lebar di tengah peta
		var bin: float = clampf((t - 0.25) / 0.6, 0.0, 1.0)
		var bout: float = clampf((t - (CH_DUR - 1.1)) / 0.55, 0.0, 1.0)
		var open: float = maxf(_eb(bin) * (1.0 - _ei(bout)), 0.0)
		var bh: float = 160.0 * open
		var bcy: float = 372.0
		if bh > 2.0:
			var top: float = bcy - bh * 0.5
			var bot: float = bcy + bh * 0.5
			var c1: Color = Color(0.03, 0.04, 0.11, 0.95).lerp(acc.darkened(0.45), 0.55)
			var c2: Color = Color(0.02, 0.02, 0.07, 0.96)
			draw_polygon(PackedVector2Array([Vector2(-40.0, top), Vector2(1320.0, top), Vector2(1320.0, bot), Vector2(-40.0, bot)]), PackedColorArray([c1, c1, c2, c2]))
			# garis serong yang bergerak
			if bh > 60.0:
				for k in 22:
					var sx: float = fposmod(float(k) * 70.0 + t * 110.0, 1540.0) - 120.0
					draw_colored_polygon(PackedVector2Array([Vector2(sx, top), Vector2(sx + 26.0, top), Vector2(sx - 22.0, bot), Vector2(sx - 48.0, bot)]), Color(acc.r, acc.g, acc.b, 0.07))
			# kilat menyapu pita
			var shu: float = clampf((t - 0.9) / 0.7, 0.0, 1.0)
			if shu > 0.0 and shu < 1.0 and bh > 60.0:
				var shx: float = lerpf(-300.0, 1500.0, smoothstep(0.0, 1.0, shu))
				draw_colored_polygon(PackedVector2Array([Vector2(shx + 120.0, top), Vector2(shx + 260.0, top), Vector2(shx + 140.0, bot), Vector2(shx, bot)]), Color(1, 1, 1, 0.20))
			# garis kecepatan
			for k in 16:
				var rs: float = fposmod(sin(float(k) * 12.9898) * 43758.5453, 1.0)
				var ys: float = top + 8.0 + rs * maxf(bh - 16.0, 1.0)
				var xs: float = fposmod(rs * 1700.0 + t * (1300.0 + rs * 1100.0), 1800.0) - 260.0
				draw_line(Vector2(xs, ys), Vector2(xs + 90.0 + rs * 140.0, ys), Color(1, 1, 1, 0.2 * open), 2.0)
			# tepi atas & bawah
			draw_rect(Rect2(-40.0, top - 4.0, 1360.0, 7.0), Color(acc.r, acc.g, acc.b, 1.0))
			draw_rect(Rect2(-40.0, bot - 3.0, 1360.0, 7.0), Color(acc.r, acc.g, acc.b, 1.0))
			draw_rect(Rect2(-40.0, top + 4.0, 1360.0, 2.0), Color(1, 1, 1, 0.7))
			draw_rect(Rect2(-40.0, bot - 5.0, 1360.0, 2.0), Color(1, 1, 1, 0.7))
			# teks
			var ta: float = clampf((open - 0.55) / 0.45, 0.0, 1.0)
			if ta > 0.0:
				var slide: float = (1.0 - _eo((t - 0.55) / 0.5)) * -140.0
				UIKit.text_in(self, "NEW CHAPTER UNLOCKED", Rect2(slide, bcy - 62.0, 1280.0, 30.0), 24, Color(acc.lightened(0.5), ta), HORIZONTAL_ALIGNMENT_CENTER, 5, Color(0, 0, 0, ta))
				var pc := Vector2(640.0, bcy + 2.0)
				var pop: float = 1.0 + 0.38 * (1.0 - _eo((t - 0.5) / 0.45))
				draw_set_transform_matrix(Transform2D(0.0, Vector2(pop, pop), 0.0, pc) * Transform2D(0.0, Vector2.ONE, 0.0, -pc))
				UIKit.text_in(self, "CHAPTER %d" % (ch + 1), Rect2(0.0, bcy - 36.0, 1280.0, 80.0), 82, Color(1, 1, 1, ta), HORIZONTAL_ALIGNMENT_CENTER, 10, Color(0, 0, 0, ta))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				UIKit.text_in(self, CampaignData.chapter_name(ch), Rect2(-slide, bcy + 44.0, 1280.0, 34.0), 32, Color(acc.lightened(0.3), ta), HORIZONTAL_ALIGNMENT_CENTER, 6, Color(0, 0, 0, ta))
				# bintang kecil di kiri-kanan judul
				for sd in [-1.0, 1.0]:
					var spc := Vector2(640.0 + sd * 330.0, bcy)
					draw_colored_polygon(CampaignData.star_points(spc, 20.0 + 3.0 * sin(t * 6.0), t * 1.5 * sd), Color(GOLD.r, GOLD.g, GOLD.b, ta))
		# 6) confetti
		for p in e["conf"]:
			var tt: float = t - float(p["dl"])
			var life: float = float(p["life"])
			if tt <= 0.0 or tt > life:
				continue
			var org: Vector2 = p["o"]
			var base: Vector2 = c if org.x < -0.5 else org
			var dir := Vector2(cos(float(p["a"])), sin(float(p["a"])))
			var pos: Vector2 = base + dir * float(p["s"]) * (1.0 - exp(-tt * 1.6)) / 1.6 + Vector2(0.0, 0.5 * 760.0 * tt * tt)
			var fa: float = clampf((life - tt) / 0.5, 0.0, 1.0)
			var rot: float = float(p["r"]) + float(p["rv"]) * tt
			var hw: float = maxf(float(p["w"]) * 0.5 * absf(cos(tt * 9.0 + float(p["r"]))), 0.8)
			var hh: float = float(p["h"]) * 0.5
			var pcol: Color = p["c"]
			var cp := PackedVector2Array()
			for corner in [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]:
				cp.append(pos + (corner as Vector2).rotated(rot))
			draw_colored_polygon(cp, Color(pcol.r, pcol.g, pcol.b, fa))
		# 7) kilat putih di awal (paling atas)
		var fl: float = clampf(1.0 - t / 0.4, 0.0, 1.0)
		if fl > 0.0:
			var fc: Color = Color.WHITE.lerp(acc, 0.3)
			draw_rect(Rect2(-40.0, -40.0, 1360.0, 800.0), Color(fc.r, fc.g, fc.b, 0.75 * fl * fl))


func _ready() -> void:
	theme = Global.ui_theme
	Global.campaign_mode = true
	Global.play_music("menu")
	save = CampaignData.load_save()
	lvls = CampaignData.levels()
	for n in range(1, CampaignData.TOTAL_LEVELS + 1):
		var b := false
		for wave in lv(n)["waves"]:
			for e in wave:
				if bool((CampaignData.ENEMIES[String(e[0])] as Dictionary).get("boss", false)):
					b = true
		_boss[n] = b

	var unlocked: int = int(save["unlocked"])
	var tgt: int = unlocked
	if not (save["run"] as Dictionary).is_empty():
		tgt = clampi(int(save["run"]["level"]), 1, CampaignData.TOTAL_LEVELS)
	last_tile = tgt

	# perpindahan otomatis ke tab berikutnya setelah naik level: mulai dari dunia terakhir yang dilihat, lalu geser
	chapter = CampaignData.chapter_of(tgt)
	var tgt_world: int = CampaignData.world_of(tgt)
	var start_world: int = tgt_world
	var slide: bool = false
	if _prev_world >= 0 and absi(_prev_world - tgt_world) == 1:
		start_world = _prev_world
		slide = true
	var unlock_new: bool = _prev_unlocked > 0 and unlocked > _prev_unlocked
	var old_unlocked: int = _prev_unlocked
	_prev_unlocked = unlocked
	# animasi berjalan: dari level pertama yang dimainkan (sejak peta terakhir dibuka) sampai level terbuka terbaru
	var journey_a: int = -1
	if unlock_new:
		journey_a = unlocked - 1
		if _streak_start >= 1 and _streak_start < unlocked:
			journey_a = _streak_start
		start_world = CampaignData.world_of(journey_a)
		chapter = CampaignData.chapter_of(journey_a)
		slide = false
	_streak_start = -1   # peta dibuka = rangkaian main berakhir; animasi berikutnya mulai dari awal lagi

	bg = UIKit.FxBackground.new()
	add_child(bg)
	_world = start_world
	_prev_world = start_world
	_set_world_bg(int(CampaignData.WORLDS[start_world]["levels"][0]) + chapter * CampaignData.CHAPTER_SIZE, 0.0)

	var title := UIKit.Banner.new("CAMPAIGN", 52)
	title.position = Vector2(40, 18)
	add_child(title)

	status = UIKit.PadStatus.new()
	status.position = Vector2(1280 - 350 - 14, 14)
	status.shown = 1
	add_child(status)

	var stars: int = CampaignData.total_stars(save)
	var stat := UIKit.label("STARS %d / %d      HI-SCORE %d" % [stars, CampaignData.TOTAL_LEVELS * 3, int(save["hi_score"])], 24, Color(1, 1, 1, 0.9), 6)
	stat.position = Vector2(46, 92)
	add_child(stat)

	chapter_nav = ChapterNav.new()
	chapter_nav.hub = self
	chapter_nav.position = Vector2(372, 10)     # x 372..824: tidak menyentuh banner CAMPAIGN (kiri) maupun kartu fighter (x >= 850)
	chapter_nav.step.connect(_change_chapter)
	chapter_nav.jump.connect(_goto_chapter)
	chapter_nav.hovered.connect(func() -> void: _set_focus(-3))
	add_child(chapter_nav)

	var has_run: bool = not (save["run"] as Dictionary).is_empty()
	var label: String = "CONTINUE  -  %s" % CampaignData.level_text(int(save["run"]["level"])) if has_run else "NEW GAME"
	btn_continue = UIKit.FancyButton.new(label, Vector2(430, 56), 32)
	btn_continue.position = Vector2(40, 134)
	btn_continue.activated.connect(_on_continue)
	btn_continue.hovered.connect(func() -> void: _set_focus(-2))
	add_child(btn_continue)

	# karakter & senjata yang sedang dipakai (diingat dari pilihan sebelumnya)
	fighter = CampaignData.saved_fighter()
	if fighter.is_empty():
		if Global.selections.size() >= 1:
			fighter = {"character": int(Global.selections[0]["character"]), "weapon": String(Global.selections[0]["weapon"])}
		else:
			fighter = {"character": 0, "weapon": "smith"}
	fighter_card = FighterCard.new()
	fighter_card.fighter = fighter
	fighter_card.position = Vector2(850, 66)
	fighter_card.clicked.connect(_on_fighter)
	fighter_card.hovered.connect(func() -> void: _set_focus(-4))
	add_child(fighter_card)

	pager = WorldPager.new()
	pager.hub = self
	pager.position = Vector2(PAGER_X, PAGER_Y)
	pager.node_clicked.connect(_on_tile_clicked)
	pager.node_hovered.connect(func(n: int) -> void: _set_focus(n))
	pager.page_requested.connect(_on_page_requested)
	pager.unlock_arrived.connect(func() -> void: Global.play_sfx("star", -4.0))
	add_child(pager)
	pager.set_page(start_world, 0.25)
	if unlock_new and unlocked >= 1 and unlocked <= CampaignData.TOTAL_LEVELS:
		for n in range(maxi(old_unlocked + 1, journey_a + 1), unlocked + 1):
			pager.held[n] = true   # level yang baru terbuka tampil terkunci sampai animasi berjalan tiba

	info = InfoBar.new()
	info.hub = self
	info.position = Vector2(46, 604)
	add_child(info)

	prompt = UIKit.make_prompt(self)
	_update_prompts()
	UIInput.pressed.connect(_on_input)

	fx_layer = UnlockFx.new()
	fx_layer.hub = self
	fx_layer.pager = pager
	fx_layer.nav = chapter_nav
	add_child(fx_layer)             # paling atas: efek buka kunci MAP & CHAPTER

	# kursor awal: level yang akan dimainkan (kalau akan menggeser otomatis, mulai dari ujung dunia sebelumnya)
	var init_focus: int = tgt
	if slide:
		init_focus = chapter * CampaignData.CHAPTER_SIZE + (int(CampaignData.WORLDS[start_world]["levels"][1]) if start_world < tgt_world else int(CampaignData.WORLDS[start_world]["levels"][0]))
	if journey_a > 0:
		init_focus = journey_a
	_set_focus(init_focus, false)
	_play_intro()
	if journey_a > 0:
		_journey_sequence(journey_a, unlocked, tgt)
	elif slide:
		_auto_sequence(tgt, slide, false)


func _unhandled_key_input(event: InputEvent) -> void:
	if leaving or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_PAGEUP:
			_change_chapter(-1)
		KEY_PAGEDOWN:
			_change_chapter(1)


func _exit_tree() -> void:
	if UIInput.pressed.is_connected(_on_input):
		UIInput.pressed.disconnect(_on_input)


func _play_intro() -> void:
	var items: Array[Control] = [btn_continue, fighter_card]
	for k in items.size():
		var it: Control = items[k]
		var base: Vector2 = it.position
		it.position = base + Vector2(-80, 0)
		it.modulate.a = 0.0
		var tw := UIKit.tw(it)
		tw.set_parallel(true)
		tw.tween_property(it, "position", base, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.08 * k)
		tw.tween_property(it, "modulate:a", 1.0, 0.25).set_delay(0.08 * k)
	if chapter_nav != null:
		var nbase: Vector2 = chapter_nav.position
		chapter_nav.position = nbase + Vector2(0, -26)
		chapter_nav.modulate.a = 0.0
		var nt := UIKit.tw(chapter_nav)
		nt.set_parallel(true)
		nt.tween_property(chapter_nav, "position", nbase, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.05)
		nt.tween_property(chapter_nav, "modulate:a", 1.0, 0.3).set_delay(0.05)
	pager.modulate.a = 0.0
	pager.position.y += 34.0
	var gt := UIKit.tw(pager)
	gt.set_parallel(true)
	gt.tween_property(pager, "modulate:a", 1.0, 0.4).set_delay(0.12)
	gt.tween_property(pager, "position:y", PAGER_Y, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.12)


## Setelah naik level: geser otomatis ke tab dunia berikutnya, lalu buka kunci level baru dengan efek.
func _auto_sequence(tgt: int, slide: bool, unlock_new: bool) -> void:
	await get_tree().create_timer(0.85).timeout
	if leaving or not is_inside_tree():
		return
	if slide:
		Global.play_sfx("ui_whoosh", -8.0, 1.15)
		_set_focus(tgt, false)
		await get_tree().create_timer(0.95).timeout
		if leaving or not is_inside_tree():
			return
	if unlock_new:
		pager.fire_unlock()
		Global.play_sfx("ui_whoosh", -10.0, 0.75)


## Berjalan pelan dari level pertama yang dimainkan (a) sampai level terbuka terbaru (b), satu level demi satu level.
## Berpindah dunia otomatis kalau jalurnya melewati batas dunia. Kursor ikut berjalan.
func _journey_sequence(a: int, b: int, tgt: int) -> void:
	await get_tree().create_timer(0.85).timeout
	if leaving or not is_inside_tree():
		return
	var count: int = b - a
	var seg: float = 1.7 if count <= 1 else (1.1 if count <= 6 else 0.8)
	for n in range(a + 1, b + 1):
		if CampaignData.world_of(n) != CampaignData.world_of(n - 1):
			Global.play_sfx("ui_whoosh", -8.0, 1.15)
			_set_focus(n, false)
			await get_tree().create_timer(0.95).timeout
		else:
			_set_focus(n, false)
		if leaving or not is_inside_tree():
			return
		# Level pertama di dunia baru: tidak ada jalan menuju ke sana. Setelah panel selesai bergeser,
		# level langsung terbuka (jeda singkat lalu efek unlock), sama seperti level yang baru terbuka.
		var new_world: bool = CampaignData.world_of(n) != CampaignData.world_of(n - 1)
		# dua jenis perayaan berbeda: MAP baru (dunia berikutnya di chapter yang sama) & CHAPTER baru (level pertama chapter)
		var kind: String = ""
		if new_world:
			kind = "chapter" if CampaignData.chapter_of(n) != CampaignData.chapter_of(n - 1) else "map"
		var dur: float = seg
		if kind == "map":
			dur = 0.6
		elif kind == "chapter":
			dur = 0.9
		pager.walk_to(n, dur, kind == "")
		if kind != "":
			_fire_unlock_fx(kind, n, dur)
		elif n == b:
			Global.play_sfx("ui_whoosh", -10.0, 0.75)
		var hold: float = 0.05
		if kind == "map":
			hold = 0.4 if n == b else 2.0          # beri waktu efek tampil sebelum lanjut berjalan ke level berikutnya
		elif kind == "chapter":
			hold = 0.4 if n == b else 3.2
		await get_tree().create_timer(dur + hold).timeout
		if leaving or not is_inside_tree():
			return
	if not leaving:
		_set_focus(tgt, false)



## Menyalakan perayaan buka kunci setelah `delay` detik (saat gembok node terbuka): MAP baru atau CHAPTER baru.
func _fire_unlock_fx(kind: String, n: int, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if leaving or not is_inside_tree() or fx_layer == null:
		return
	if kind == "chapter":
		fx_layer.play_chapter(n)
		if chapter_nav != null:
			chapter_nav.celebrate(CampaignData.chapter_of(n))
		Global.play_sfx("match_fanfare", -3.0)
		Global.play_sfx("wall_impact", -4.0, 0.7)
		Global.play_sfx("ui_allready", -6.0, 0.9)
	else:
		fx_layer.play_map(n)
		Global.play_sfx("perk_open", -5.0, 1.1)
		Global.play_sfx("star", -6.0, 1.25)


func _set_world_bg(level: int, dur: float = 0.45) -> void:
	var w: int = CampaignData.world_of(level)
	var id: String = String(CampaignData.WORLDS[w]["id"])
	var pal: Array = Global.MAP_PALETTES[id]
	bg.set_palette(pal[0], pal[1], pal[2], dur)
	bg.set_image(Global.map_background(id), 0.78, dur)


# ------------------------------------------------------------------ navigasi
func _set_focus(f: int, sound: bool = true) -> void:
	if leaving:
		return
	var old: int = focus
	focus = f
	btn_continue.set_selected(f == -2)
	if fighter_card != null:
		fighter_card.selected = (f == -4)
	if chapter_nav != null:
		chapter_nav.selected = (f == -3)
	if f >= 1:
		last_tile = f
		var w: int = CampaignData.world_of(f)
		var c: int = CampaignData.chapter_of(f)
		if c != chapter:
			chapter = c
			_world = w
			_prev_world = w
			pager.reset_enter()
			pager.set_page(w, 0.05)   # chapter baru: seluruh peta muncul lagi dari awal
			_set_world_bg(f, 0.3)
		elif w != _world:
			_world = w
			_prev_world = w
			pager.target = w          # panel dunia meluncur ke tab yang baru
			_set_world_bg(f)
	if sound and f != old:
		Global.play_sfx("ui_hover", -8.0)


## Level yang paling masuk akal dimainkan di sebuah dunia: level terbuka pertama yang belum selesai (kalau tidak ada, level pertama).
func _best_level(w: int) -> int:
	var first: int = int(CampaignData.WORLDS[w]["levels"][0]) + off()
	var last: int = int(CampaignData.WORLDS[w]["levels"][1]) + off()
	var unlocked: int = int(save["unlocked"])
	for n in range(first, last + 1):
		if n <= unlocked and int((save["stars"] as Dictionary).get(n, 0)) == 0:
			return n
	return first


func _on_page_requested(w: int) -> void:
	if leaving:
		return
	w = clampi(w, 0, CampaignData.WORLDS.size() - 1)
	if w == _world:
		return
	Global.play_sfx("ui_whoosh", -12.0, 1.2)
	_set_focus(_best_level(w), false)


func _move(dx: int, dy: int) -> void:
	if focus == -3:
		if dx != 0:
			_change_chapter(dx)
		elif dy > 0:
			_set_focus(-2)
		return
	if focus == -4:
		# kartu fighter (klik untuk ganti fighter): kiri = tombol lanjut, atas = pilih chapter, bawah = peta level
		if dx < 0:
			_set_focus(-2)
		elif dy < 0:
			_set_focus(-3)
		elif dy > 0:
			_set_focus(last_tile)
		return
	if focus < 1:
		if dx > 0 and focus == -2:
			_set_focus(-4)          # dari tombol lanjut, kanan = kartu fighter
		elif dy > 0:
			_set_focus(last_tile)
		elif dy < 0:
			_set_focus(-3)
		return
	if dx != 0:
		var n: int = focus + dx
		if n < 1 or n > CampaignData.TOTAL_LEVELS:
			pager.nudge(dx)
			Global.play_sfx("ui_error", -14.0)
			return
		if CampaignData.world_of(n) != CampaignData.world_of(focus):
			Global.play_sfx("ui_whoosh", -12.0, 1.2)
		_set_focus(n)
		return
	if dy < 0:
		var w: int = CampaignData.world_of(focus)
		var col: int = focus - off() - int(CampaignData.WORLDS[w]["levels"][0])
		_set_focus(-2 if col <= 1 else -4)


## Level yang paling masuk akal dimainkan di sebuah chapter (level terbuka pertama yang belum selesai).
func _best_chapter_level(c: int) -> int:
	var unlocked: int = int(save["unlocked"])
	var first: int = CampaignData.chapter_first(c)
	for n in range(first, CampaignData.chapter_last(c) + 1):
		if n <= unlocked and int((save["stars"] as Dictionary).get(n, 0)) == 0:
			return n
	return first


func _change_chapter(dir: int, wrap: bool = false) -> void:
	if leaving:
		return
	var nc: int = chapter + dir
	if wrap:
		nc = posmod(nc, CampaignData.CHAPTERS)
	if nc < 0 or nc >= CampaignData.CHAPTERS:
		pager.nudge(dir)
		if chapter_nav != null:
			chapter_nav.bump(dir)
		Global.play_sfx("ui_error", -14.0)
		return
	Global.play_sfx("ui_whoosh", -8.0, 1.0 if dir > 0 else 0.9)
	var keep: int = focus
	_set_focus(_best_chapter_level(nc), false)
	if keep == -3:
		_set_focus(-3, false)
	if int(save["unlocked"]) < CampaignData.chapter_first(nc):
		UIInput.toast("CHAPTER %d" % (nc + 1), "Clear chapter %d to unlock it" % nc, Color("ffb86b"))


## Loncat langsung ke chapter c (klik chip nomor di pelat chapter).
func _goto_chapter(c: int) -> void:
	if leaving or c == chapter:
		return
	_change_chapter(c - chapter)


func _step_world(dir: int) -> void:
	var nw: int = _world + dir
	if nw < 0 or nw >= CampaignData.WORLDS.size():
		pager.nudge(dir)
		Global.play_sfx("ui_error", -14.0)
		return
	_on_page_requested(nw)


func _on_input(_source: int, action: StringName) -> void:
	if leaving:
		return
	match action:
		&"left":
			_move(-1, 0)
		&"right":
			_move(1, 0)
		&"up":
			_move(0, -1)
		&"down":
			_move(0, 1)
		&"prev":
			_step_world(-1)
		&"next":
			_step_world(1)
		&"accept", &"fire":
			_activate()
		&"extra":
			_change_chapter(1, true)
		&"alt":
			_change_chapter(-1)
		&"start":
			_on_continue()
		&"back":
			_on_back()


func _update_prompts() -> void:
	prompt.set_prompts([[&"dpad", "MOVE"], [&"prev", "PREV WORLD"], [&"next", "NEXT WORLD"], [&"extra", "CHAPTER"], [&"accept", "PLAY"], [&"back", "BACK"]])


func _activate() -> void:
	if focus == -3:
		_change_chapter(1, true)
	elif focus == -2:
		_on_continue()
	elif focus == -4:
		_on_fighter()
	else:
		_on_tile_clicked(focus)


# ------------------------------------------------------------------ aksi
func _on_tile_clicked(n: int) -> void:
	if leaving:
		return
	if n > int(save["unlocked"]):
		var now: int = Time.get_ticks_msec()
		if now - _last_lock_msg < 400:
			return          # klik/tombol yang sama terbaca dua kali (accept + fire): cukup satu notifikasi
		_last_lock_msg = now
		Global.play_sfx("ui_error", -6.0)
		UIInput.toast("LOCKED", "Clear level %d first" % int(save["unlocked"]), Color("ff7a7a"))
		return
	_start(_fresh_run(n))


func _on_continue() -> void:
	if leaving:
		return
	var r: Dictionary = save["run"]
	if r.is_empty():
		_start(_fresh_run(1))
	else:
		_start(r.duplicate(true))


func _fresh_run(n: int) -> Dictionary:
	var run: Dictionary = CampaignData.new_run()
	run["level"] = n
	if n > 1:
		# mulai dari level tengah: dapat perk awal supaya seimbang dengan level itu
		var rng := RandomNumberGenerator.new()
		rng.seed = 7919 * n
		var perks: Dictionary = run["perks"]
		for i in int((n - 1) / 3):
			var pick: Array[String] = CampaignData.roll_perks(perks, rng, 3)
			if not pick.is_empty():
				perks[pick[0]] = int(perks.get(pick[0], 0)) + 1
	CampaignData.mark_checkpoint(run)
	run["ckpt_lives"] = CampaignData.START_LIVES
	return run


func _start(run: Dictionary) -> void:
	if leaving:
		return
	leaving = true
	_streak_start = int(run["level"])                         # level pertama yang dimainkan (awal animasi berjalan nanti)
	_prev_world = CampaignData.world_of(int(run["level"]))    # kembali nanti: geser dari dunia tempat level ini dimainkan
	Global.play_sfx("ui_start")
	Global.campaign_run = run
	Global.campaign_mode = true
	Global.player_count = 1
	Global.selections = [fighter.duplicate()]    # pastikan level memakai fighter yang tampil di kartu
	Global.goto("campaign")


func _on_fighter() -> void:
	if leaving:
		return
	leaving = true
	Global.campaign_mode = true
	Global.player_count = 1
	Global.selections = [fighter.duplicate()]    # layar pilih membuka dengan kursor di pilihan saat ini
	Global.goto("select")


func _on_back() -> void:
	if leaving:
		return
	leaving = true
	Global.play_sfx("ui_back", -5.0)
	Global.goto("menu")
