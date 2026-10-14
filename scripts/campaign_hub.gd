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
const GATE := -5                # nilai `focus` saat kursor berada di dunia TERKUNCI (tampil sebagai gembok besar, bukan level)
var gate_level: int = -1        # level pertama dunia terkunci yang sedang disorot (berlaku saat focus == GATE)


func off() -> int:
	return chapter * CampaignData.CHAPTER_SIZE


func lv(n: int) -> Dictionary:
	return lvls[clampi(n, 1, lvls.size()) - 1]


func is_boss(n: int) -> bool:
	return bool(_boss.get(n, false))


## Dunia tempat level n berada masih TERKUNCI (level pertamanya belum terbuka di save). Dunia terkunci tidak punya level yang bisa disorot.
func world_locked(n: int) -> bool:
	return CampaignData.checkpoint_of(n) > int(save["unlocked"])


## Chapter c masih TERKUNCI (level pertamanya belum terbuka di save).
func chapter_locked(c: int) -> bool:
	return CampaignData.chapter_first(c) > int(save["unlocked"])


## Syarat membuka chapter c: chapter sebelumnya (nomor, nama, jumlah level yang sudah tamat 0..50).
func chapter_info(c: int) -> Dictionary:
	var pc: int = maxi(c - 1, 0)
	var unlocked: int = int(save["unlocked"])
	return {
		"pch": pc,
		"name": CampaignData.chapter_name(pc),
		"done": clampi(unlocked - CampaignData.chapter_first(pc), 0, CampaignData.CHAPTER_SIZE),
		"active": CampaignData.chapter_first(pc) <= unlocked,
	}


## Dunia tempat level n berada tampil tersegel (terkunci di save, atau segelnya belum pecah di animasi unlock).
func world_sealed_visual(n: int) -> bool:
	if pager != null:
		return pager.held.has(CampaignData.checkpoint_of(n)) or world_locked(n)
	return world_locked(n)


## Syarat membuka dunia yang level pertamanya `first`: dunia sebelumnya (nama, chapter, jumlah level yang sudah tamat 0..5).
func seal_info(first: int) -> Dictionary:
	if first <= 1:
		return {"name": "", "ch": 0, "done": 5, "active": false}
	var pl: int = first - 1                       # level terakhir (BOSS) dunia sebelumnya
	var pw: int = CampaignData.world_of(pl)
	var unlocked: int = int(save["unlocked"])
	return {
		"name": String(CampaignData.WORLDS[pw]["name"]),
		"ch": CampaignData.chapter_of(pl),
		"done": clampi(unlocked - (first - 5), 0, 5),
		"active": (first - 5) <= unlocked,           # dunia sebelumnya sedang bisa dimainkan
	}


## Digambar SEKALI ke SubViewport kecil untuk membuat atlas sprite mata rantai & jangkar (lihat WorldPager._bake_atlas).
## Tiap sel berisi satu lapisan putih (diwarnai lewat modulate); sel terakhir (jangkar) berwarna penuh.
class AtlasBake extends Node2D:
	func _draw() -> void:
		var w := Color.WHITE
		var sc := Vector2(2.0, 2.0)
		var ring := PackedVector2Array()
		var inner := PackedVector2Array()
		for q in 17:
			var th: float = float(q) * TAU / 16.0
			ring.append(Vector2(cos(th) * 15.5, sin(th) * 8.5))
			inner.append(Vector2(cos(th) * 11.0, sin(th) * 4.2))
		var hi := PackedVector2Array()
		for q in range(9, 16):
			hi.append(ring[q])
		for k in 4:
			draw_set_transform(Vector2(44.0, 28.0 + 56.0 * float(k)), 0.0, sc)
			match k:
				0: draw_polyline(ring, w, 6.0, true)
				1: draw_polyline(ring, w, 5.5, true)
				2: draw_polyline(inner, w, 1.6, true)
				3: draw_polyline(hi, w, 1.8, true)
		for k in 3:
			draw_set_transform(Vector2(44.0, 28.0 + 56.0 * float(4 + k)), 0.0, sc)
			match k:
				0: draw_line(Vector2(-10.5, 0.0), Vector2(10.5, 0.0), w, 9.0)
				1: draw_line(Vector2(-10.5, 0.0), Vector2(10.5, 0.0), w, 8.0)
				2: draw_line(Vector2(-9.0, 0.0), Vector2(9.0, 0.0), w, 2.2)
		for k in 6:
			draw_set_transform(Vector2(44.0, 392.0 + 88.0 * float(k) + 44.0), 0.0, sc)
			match k:
				0: draw_circle(Vector2.ZERO, 15.0, w)
				1: draw_circle(Vector2.ZERO, 15.0, w)
				2: draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, w, 2.5, true)
				3: draw_circle(Vector2.ZERO, 8.0, w)
				4: draw_circle(Vector2(-1.5, -1.5), 3.0, w)
				5:
					for q in 4:
						var bp: Vector2 = Vector2(cos(float(q) * PI * 0.5 + 0.785), sin(float(q) * PI * 0.5 + 0.785)) * 11.0
						draw_circle(bp, 1.7, w)


# ================================================================== pager dunia
## Satu panel besar per dunia (5 level). Panel aktif di tengah, panel tetangga mengintip di kiri / kanan.
## Posisi `pos` mengikuti `target` dengan pegas teredam kritis (tanpa goyang & tanpa patah), dan bisa di-drag langsung.
class WorldPager extends Control:
	signal node_clicked(level: int)
	signal node_hovered(level: int)
	signal page_requested(world: int)
	signal unlock_arrived
	signal vault_opened(level: int)         # segel dunia pecah (level pertama dunia itu): dipakai untuk suara & efek layar penuh
	signal sealed_clicked(world: int)       # panel dunia yang tersegel diklik / ditekan

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
	# ---- segel dunia terkunci (koordinat panel 900 x 346)
	const VC := Vector2(450.0, 186.0)       # pusat gembok besar
	const CH_A := [Vector2(34.0, 118.0), Vector2(866.0, 262.0)]    # rantai kiri-atas ke kanan-bawah
	const CH_B := [Vector2(34.0, 300.0), Vector2(866.0, 92.0)]     # rantai kiri-bawah ke kanan-atas
	const LINK := 25.0                      # jarak antar mata rantai
	const IRIS_START := 0.10                # detik sejak pecah sampai lingkaran pembuka mulai melebar
	const IRIS_DUR := 1.15                  # lama lingkaran pembuka melebar sampai menutup seluruh panel
	const IRIS_R := 600.0                   # radius akhir lingkaran pembuka
	const OPEN_DUR := 1.7                   # total animasi segel pecah (rantai jatuh + lingkaran pembuka)
	# ---- gerbang chapter terkunci (koordinat pager 1280 x 394)
	const GX := 90.0
	const GY := 6.0
	const GW := 1100.0
	const GC := Vector2(640.0, 172.0)       # pusat gembok raksasa
	const SWAP_DUR := 0.7                   # lama transisi antar chapter
	const SWAP_W := 320.0                   # jarak geser peta saat transisi chapter

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
	var open_t: Dictionary = {}    # level pertama dunia -> detik sejak segelnya pecah (>= 0 selama animasi)
	var rattle: Dictionary = {}    # level pertama dunia -> 0..1 getaran segel (saat ditolak / diklik)
	var vault_fx: Dictionary = {}  # level pertama dunia -> data acak pecahan gembok
	var _lat: Array = []           # cache garis pola belah ketupat segel (koordinat panel)
	var _stripes: Array = []       # cache garis-garis peringatan di tepi bawah segel
	var _glat: Array = []          # cache pola gerbang chapter
	var _gstripes: Array = []
	var _lat_ml := PackedVector2Array()   # garis belah ketupat sebagai pasangan titik (satu draw_multiline)
	var _stripes_mesh: ArrayMesh = null   # semua garis peringatan digabung jadi satu mesh (satu draw call)
	var _atlas: CanvasTexture = null      # atlas sprite mata rantai & jangkar (di-bake sekali, null = pakai gambar vektor)
	var _cur_xf := Transform2D.IDENTITY   # transform halaman yang sedang digambar
	var vch: int = -1              # chapter yang sedang digambar (-1 = chapter aktif hub); dipakai saat transisi antar chapter
	var xshift: float = 0.0        # geseran horizontal seluruh adegan (transisi chapter)
	var amul: float = 1.0          # pengali transparansi seluruh adegan (transisi chapter)
	var swap_t: float = 1.0        # 0..1 progres transisi chapter (1 = tidak sedang transisi)
	var swap_dir: int = 1
	var swap_from_ch: int = 0
	var swap_from_pos: float = 0.0
	var swap_enter_old: Array[float] = []

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
		# Ukuran huruf nama level: hasilnya disimpan di Global.hub_name_fs (sudah dihitung bertahap di latar belakang
		# saat menu menganggur), jadi membuka peta tidak perlu mengukur teks 250 kali lagi.
		for n in range(1, CampaignData.TOTAL_LEVELS + 1):
			if Global.hub_name_fs.has(n):
				name_fs[n] = int(Global.hub_name_fs[n])
				continue
			var f: int = 16
			var s: String = String(hub.lv(n)["name"])
			while f > 10 and UIKit.text_w(s, f) > 168.0:
				f -= 1
			name_fs[n] = f
			Global.hub_name_fs[n] = f
		_bake_atlas()

	# ------------------------------------------------------------------ atlas sprite (mata rantai & jangkar)
	## Mata rantai dan jangkar dulu digambar ulang sebagai polyline antialias di SETIAP frame (puluhan mata rantai x 4 lapis x tiap segel).
	## Itu ratusan draw call per segel. Di sini bentuknya digambar SEKALI ke tekstur kecil (supersample 2x), lalu dipakai sebagai sprite.
	## Tampilan identik; kalau baking gagal (mis. renderer dummy) kode lama (vektor) otomatis tetap dipakai.
	const AT_W := 88
	const AT_H := 920
	const FLAT_HALF := Vector2(22.0, 14.0)
	const ANCH_HALF := Vector2(22.0, 22.0)

	func _at_src(row: int) -> Rect2:
		return Rect2(0.0, 56.0 * float(row), 88.0, 56.0)

	func _anc_src(k: int) -> Rect2:
		return Rect2(0.0, 392.0 + 88.0 * float(k), 88.0, 88.0)

	## Atlas sekarang dibuat SEKALI per sesi game oleh Global.get_hub_atlas() (biasanya sudah siap sebelum peta dibuka,
	## karena dibuat di latar belakang saat menu menganggur). Dulu: di-bake ulang tiap peta dibuka + 81 ribu piksel
	## diproses satu-satu di thread utama -> lag. Kalau belum siap, peta memakai gambar vektor dulu lalu beralih otomatis.
	func _bake_atlas() -> void:
		var ct: CanvasTexture = await Global.get_hub_atlas()
		if ct != null and is_inside_tree():
			_atlas = ct

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

	## Level pertama (nomor global) dunia w pada chapter yang sedang tampil.
	func first_of(w: int) -> int:
		return int(CampaignData.WORLDS[w]["levels"][0]) + coff()

	## Chapter yang sedang digambar / diproses (selama transisi chapter, adegan lama memakai chapter lamanya).
	func view_ch() -> int:
		return hub.chapter if vch < 0 else vch

	func coff() -> int:
		return view_ch() * CampaignData.CHAPTER_SIZE

	## Chapter TERSEGEL: belum terbuka di save, atau level pertamanya masih ditahan sampai animasi unlock tiba.
	## Chapter tersegel menampilkan satu gerbang raksasa (bukan panel dunia).
	func chap_sealed(c: int = -1) -> bool:
		var ch: int = view_ch() if c < 0 else c
		var f: int = ch * CampaignData.CHAPTER_SIZE + 1
		return f > int(hub.save["unlocked"]) or held.has(f)

	## Pusat gembok gerbang chapter dalam koordinat layar (hub).
	func gate_screen() -> Vector2:
		return position + Vector2(GC.x + xshift, GC.y)

	## Transisi antar chapter: adegan chapter lama meluncur keluar & memudar, adegan baru meluncur masuk, disapu cahaya warna chapter.
	func swap_chapter(w: int, from_ch: int, dir: int) -> void:
		swap_from_ch = from_ch
		swap_from_pos = pos
		swap_enter_old = enter.duplicate()
		swap_dir = dir
		swap_t = 0.0
		reset_enter()
		set_page(w, 0.12)

	## Dunia tampil TERSEGEL: belum terbuka di save, atau level pertamanya masih ditahan sampai animasi unlock tiba.
	func sealed(w: int) -> bool:
		var f: int = first_of(w)
		return chap_sealed() or f > int(hub.save["unlocked"]) or held.has(f)

	## 0..1: seberapa dekat segel dunia ini dengan pecah (animasi "mengisi daya" sebelum segel dibuka).
	func charge_of(first: int) -> float:
		if unlock_t >= 0.0 and unlock_node == first and (held.has(first) or hold_lock == first):
			return clampf(unlock_t / maxf(fill_dur, 0.01), 0.0, 1.0)
		return 0.0

	## Gembok bergetar & rantai berderak (dipanggil saat pemain mencoba membuka dunia terkunci).
	func rattle_world(w: int) -> void:
		rattle[first_of(w)] = 1.0

	## Pusat gembok dunia w dalam koordinat layar (hub), untuk efek di UnlockFx.
	func vault_screen(w: int) -> Vector2:
		var xf: Dictionary = page_xf(w)
		return position + (xf["o"] as Vector2) + VC * float(xf["s"])

	func _in_page(w: int, p: Vector2) -> bool:
		var xf: Dictionary = page_xf(w)
		return Rect2(xf["o"] as Vector2, Vector2(PW, PH) * float(xf["s"])).has_point(p)

	## Segel level pertama sebuah dunia pecah: mulai animasi buka (lingkaran pembuka, rantai jatuh, isi dunia muncul bertahap).
	func _begin_open(n: int) -> void:
		var w: int = CampaignData.world_of(n)
		if n != first_of(w):
			return
		open_t[n] = 0.0
		enter[w] = -0.8
		if w == 0:
			for k in enter.size():
				enter[k] = -0.9 - 0.06 * float(k)      # gerbang chapter pecah: semua panel muncul bertahap setelah terbuka
		var rng := RandomNumberGenerator.new()
		rng.seed = 7001 + n * 13
		var shards: Array = []
		for q in 22:
			shards.append({"a": rng.randf() * TAU, "s": rng.randf_range(140.0, 460.0), "r": rng.randf() * TAU,
				"rv": rng.randf_range(-12.0, 12.0), "z": rng.randf_range(4.0, 10.0), "k": rng.randi() % 3})
		vault_fx[n] = {"shards": shards}
		vault_opened.emit(n)

	# ------------------------------------------------------------------ geometri
	func page_xf(i: int) -> Dictionary:
		var d: float = float(i) - pos
		var ad: float = absf(d)
		var near: float = clampf(ad, 0.0, 1.0)
		var s: float = lerpf(1.0, 0.82, near)
		var cx: float = size.x * 0.5 + d * STEP + xshift
		var o := Vector2(cx - PW * s * 0.5, 6.0 + PH * (1.0 - s) * 0.5 + 8.0 * near)
		var a: float = (1.0 - 0.5 * near - 0.5 * clampf(ad - 1.0, 0.0, 1.0)) * amul
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
				if not _dragging and absf(dx) > 12.0 and not chap_sealed():
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
		if sealed(target):
			return -1               # dunia tersegel: tidak ada node yang bisa disorot / diklik
		var xf: Dictionary = page_xf(target)
		var o: Vector2 = xf["o"]
		var s: float = float(xf["s"])
		var lp: Vector2 = (p - o) / s
		var first: int = int(CampaignData.WORLDS[target]["levels"][0]) + coff()
		for k in 5:
			var n: int = first + k
			if lp.distance_to(node_pos(k)) <= node_radius(n) + 8.0:
				return n
		return -1

	func _hit_tab(p: Vector2) -> int:
		if chap_sealed():
			return -1
		for j in tab_anim.size():
			if tab_rect(j).grow(2.0).has_point(p):
				return j
		return -1

	func _hit_arrow(p: Vector2) -> int:
		if chap_sealed():
			return -1
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
		var over_seal: bool = absf(pos - float(target)) < 0.3 and sealed(target) and (_in_gate(p) if chap_sealed() else _in_page(target, p))
		if over_seal:
			node_hovered.emit(first_of(target))     # kursor berpindah ke dunia terkunci ini (ditampilkan sebagai gembok)
		var over_page: bool = false
		for i in [target - 1, target + 1]:
			if i >= 0 and i < CampaignData.WORLDS.size() and not chap_sealed():
				var xf: Dictionary = page_xf(i)
				var o: Vector2 = xf["o"]
				if Rect2(o, Vector2(PW, PH) * float(xf["s"])).has_point(p):
					over_page = true
		if over_seal and _hover_tab < 0 and _hover_arrow < 0:
			mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		else:
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
		if absf(pos - float(target)) < 0.3 and sealed(target) and (_in_gate(p) if chap_sealed() else _in_page(target, p)):
			sealed_clicked.emit(target)           # klik di dunia / chapter tersegel: gembok bergetar + pemberitahuan
			return
		if chap_sealed():
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
				var hl: int = hold_lock
				hold_lock = -1            # garis sampai: node terbuka + efek
				unlock_arrived.emit()
				_begin_open(hl)
			if held.has(unlock_node) and unlock_t >= fill_dur:
				var hn: int = unlock_node
				held.erase(hn)            # animasi berjalan tiba di level ini: terbuka + efek
				unlock_arrived.emit()
				_begin_open(hn)
			if unlock_t > UNLOCK_TOTAL:
				unlock_t = -1.0
				unlock_node = -1
				hold_lock = -1            # (held TIDAK dihapus di sini: level yang belum dilewati animasi tetap tersegel)
		if swap_t < 1.0:
			swap_t = minf(1.0, swap_t + d / SWAP_DUR)
		for k in open_t.keys():
			open_t[k] = float(open_t[k]) + d
			if float(open_t[k]) > OPEN_DUR:
				open_t.erase(k)
				vault_fx.erase(k)
		for k in rattle.keys():
			rattle[k] = maxf(0.0, float(rattle[k]) - d * 1.5)
			if float(rattle[k]) <= 0.0:
				rattle.erase(k)
		queue_redraw()

	# ------------------------------------------------------------------ gambar
	func _draw() -> void:
		var cur: int = hub.chapter
		if swap_t < 1.0:
			var e: float = 1.0 - pow(1.0 - swap_t, 3.0)
			_draw_scene(swap_from_ch, swap_from_pos, swap_enter_old, -float(swap_dir) * SWAP_W * e, 1.0 - smoothstep(0.0, 0.55, swap_t))
			_draw_scene(cur, pos, enter, float(swap_dir) * SWAP_W * (1.0 - e), smoothstep(0.12, 0.7, swap_t))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_draw_swap_fx(cur)
		else:
			_draw_scene(cur, pos, enter, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not chap_sealed():
			_draw_arrows()
		_draw_tabs()
		if _warm_n < 6:
			_warm_pass()

	## PEMANASAN: gerbang tiap chapter, glyph huruf raksasa, dan jenis gambar baru (mesh, sprite, segitiga) digambar sekali dengan transparansi
	## nyaris nol, satu per frame, di awal layar dibuka. Jadi cache font, mesh, dan shader GPU-nya sudah siap sebelum pemain pindah chapter
	## (dulu semua itu baru dibuat pada perpindahan pertama = lag sesaat).
	var _warm_n: int = 0

	func _warm_pass() -> void:
		_warm_n += 1
		var s_amul: float = amul
		var s_vch: int = vch
		var s_xs: float = xshift
		var s_enter: Array[float] = enter
		amul = 0.02
		xshift = 0.0
		if _warm_n <= 4:
			var wch: int = clampi(_warm_n, 0, CampaignData.CHAPTERS - 1)
			vch = wch
			_draw_gate(wch, -1.0)
		elif _warm_n == 5:
			for ch in CampaignData.CHAPTERS:
				var ac: Color = chap_accent(ch)
				UIKit.text_in(self, str(ch + 1), Rect2(0.0, 20.0, size.x, 340.0), 300, Color(ac.r, ac.g, ac.b, 0.004), HORIZONTAL_ALIGNMENT_CENTER, 0)
				UIKit.text_in(self, str(ch + 1), Rect2(GX, GY - 6.0, GW, PH), 330, Color(ac.r, ac.g, ac.b, 0.004), HORIZONTAL_ALIGNMENT_CENTER, 0)
		amul = s_amul
		vch = s_vch
		xshift = s_xs
		enter = s_enter
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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
		var first: int = int(wd["levels"][0]) + coff()
		var last: int = int(wd["levels"][1]) + coff()
		var unlocked: int = int(hub.save["unlocked"])
		var stars_d: Dictionary = hub.save["stars"]
		var center: float = 1.0 - clampf(absf(float(i) - pos), 0.0, 1.0)
		var ent: float = enter[i]
		var sealed_now: bool = i > 0 and (first > unlocked or held.has(first))    # segel masih utuh: isi dunia TIDAK digambar sama sekali (dunia pertama dijaga gerbang chapter)
		var ot: float = float(open_t.get(first, -1.0)) if i > 0 else -1.0         # >= 0: segel sedang pecah
		var iris_p: float = clampf((ot - IRIS_START) / IRIS_DUR, 0.0, 1.0) if ot >= 0.0 else 0.0
		var seal_k: float = 1.0 if sealed_now else ((1.0 - iris_p) if ot >= 0.0 else 0.0)    # 1 = bingkai baja, 0 = bingkai warna dunia
		draw_set_transform(o, 0.0, Vector2(s, s))
		_cur_xf = Transform2D(0.0, Vector2(s, s), 0.0, o)
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

		if not sealed_now:
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

			# judul dunia
			var hdr: float = clampf(ent * 2.2, 0.0, 1.0)
			var hx: float = -34.0 * (1.0 - _back(hdr))
			var ha: float = a * hdr
			UIKit.text_in(self, (("WORLD %d" % (i + 1)) if view_ch() == 0 else ("CH%d  WORLD %d" % [view_ch() + 1, i + 1])), Rect2(34.0 + hx, 14.0, 240.0, 22.0), 18, _ca(acc, 0.95 * ha), HORIZONTAL_ALIGNMENT_LEFT, 4, Color(0, 0, 0, ha))
			UIKit.text_in(self, String(wd["name"]), Rect2(34.0 + hx, 34.0, 560.0, 64.0), 54, Color(1, 1, 1, ha), HORIZONTAL_ALIGNMENT_LEFT, 8, Color(0, 0, 0, ha))

			# ringkasan dunia (bintang & kemajuan)
			var star_sum: int = 0
			for n in range(first, last + 1):
				star_sum += int(stars_d.get(n, 0))
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

			# jalur antar level + node level
			_draw_path(i, first, acc, a * clampf(ent * 3.0, 0.0, 1.0), unlocked, stars_d)
			for k in 5:
				_draw_node(first + k, k, acc, a, ent, unlocked, stars_d)

		# segel (dunia terkunci / sedang dibuka): menutupi isi dunia sepenuhnya
		if sealed_now or ot >= 0.0:
			_draw_vault(i, first, pts, acc, a, ot, sealed_now, ent)

		# bingkai: baja saat tersegel, warna dunia saat terbuka
		var pulse: float = 0.78 + 0.22 * sin(t * 2.2)
		var fcol: Color = acc.lerp(Color(0.56, 0.62, 0.78), seal_k)
		draw_polyline(UIKit.closed(pts), Color(fcol.r, fcol.g, fcol.b, 0.9 * a * lerpf(0.7, pulse, center)), 3.0 + seal_k, true)
		draw_line(Vector2(CUT + 4.0, 3.0), Vector2(CUT + 150.0, 3.0), _ca(fcol.lightened(0.3), a), 5.0)
		draw_line(Vector2(PW - CUT - 4.0, PH - 3.0), Vector2(PW - CUT - 150.0, PH - 3.0), _ca(fcol.lightened(0.3), a), 5.0)

	# ================================================================== GERBANG CHAPTER TERKUNCI
	## Chapter yang belum terbuka menggantikan SELURUH peta (panel dunia, panah, tab) dengan satu GERBANG BAJA raksasa berwarna chapter:
	## angka chapter raksasa samar, tiga rantai tebal, gembok besar, dan pelat syarat (menamatkan chapter sebelumnya + progres 0..50 level).
	## Saat chapter terbuka gerbang pecah seperti segel dunia (gembok pecah, rantai jatuh, lingkaran cahaya) lalu peta chapter baru tersingkap.

	func chap_accent(ch: int) -> Color:
		return ChapterNav.ACCENTS[clampi(ch, 0, CampaignData.CHAPTERS - 1)]

	func _gate_poly() -> PackedVector2Array:
		var cut: float = 34.0
		return PackedVector2Array([Vector2(GX + cut, GY), Vector2(GX + GW, GY), Vector2(GX + GW, GY + PH - cut),
			Vector2(GX + GW - cut, GY + PH), Vector2(GX, GY + PH), Vector2(GX, GY + cut)])

	func _in_gate(p: Vector2) -> bool:
		return Rect2(Vector2(GX + xshift, GY), Vector2(GW, PH)).has_point(p)

	func _ensure_gate_cache() -> void:
		return   # pola gerbang tidak lagi dipakai untuk menggambar; dulu dihitung (puluhan potongan poligon) saat pertama kali gerbang muncul = lag
		if not _glat.is_empty():
			return
		var pts: PackedVector2Array = _gate_poly()
		for kk in range(-8, 40):
			var x0: float = GX + float(kk) * 52.0
			for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(x0, GY - 10.0), Vector2(x0 + PH + 20.0, GY + PH + 10.0)]), pts):
				_glat.append(seg)
			for seg2 in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(x0 + PH + 20.0, GY - 10.0), Vector2(x0, GY + PH + 10.0)]), pts):
				_glat.append(seg2)
		var band := PackedVector2Array([Vector2(GX + 8.0, GY + PH - 17.0), Vector2(GX + GW - 8.0, GY + PH - 17.0), Vector2(GX + GW - 8.0, GY + PH - 7.0), Vector2(GX + 8.0, GY + PH - 7.0)])
		for kk in range(0, 74):
			var sx: float = GX + 8.0 + float(kk) * 30.0
			var stripe := PackedVector2Array([Vector2(sx + 10.0, GY + PH - 17.0), Vector2(sx + 24.0, GY + PH - 17.0), Vector2(sx + 14.0, GY + PH - 7.0), Vector2(sx, GY + PH - 7.0)])
			for piece in Geometry2D.intersect_polygons(stripe, band):
				for piece2 in Geometry2D.intersect_polygons(piece, pts):
					if _tri_ok(piece2):
						_gstripes.append(piece2)

	func _draw_gate(ch: int, ot: float) -> void:
		_ensure_vault_cache()
		_ensure_gate_cache()
		var a: float = amul
		var first: int = ch * CampaignData.CHAPTER_SIZE + 1
		var acc: Color = chap_accent(ch)
		var pts: PackedVector2Array = _gate_poly()
		var opening: bool = ot >= 0.0
		var charge: float = charge_of(first)
		var rt: float = float(rattle.get(first, 0.0))
		var focus_here: bool = int(hub.focus) == -5 and int(hub.gate_level) == first
		var ir: float = 0.0
		var iris_p: float = 0.0
		if opening and ot > IRIS_START:
			iris_p = clampf((ot - IRIS_START) / (IRIS_DUR + 0.25), 0.0, 1.0)
			ir = (IRIS_R + 520.0) * (1.0 - pow(1.0 - iris_p, 3.0))
		var fade: float = (1.0 - clampf(ot / 0.22, 0.0, 1.0)) if opening else 1.0
		var gc: Color = Color(1.0, 0.5, 0.32).lerp(acc.lightened(0.35), 0.45)
		var xs := Vector2(xshift, 0.0)
		draw_set_transform(xs, 0.0, Vector2.ONE)
		if not opening:
			draw_colored_polygon(UIKit.slanted(GW, PH, 0.0, GX + 10.0, GY + 14.0), Color(0, 0, 0, 0.45 * a))
		# 1) alas baja gelap
		for piece in _vault_fill_polys(pts, ir, GC, Vector2(1280.0, 394.0)):
			var pp: PackedVector2Array = piece
			if not _tri_ok(pp):
				continue
			var cols := PackedColorArray()
			for p in pp:
				cols.append(_gate_col(p.y - GY, acc, a))
			draw_polygon(pp, cols)
		if fade > 0.01:
			# 2) dua daun pintu baja + celah tengah bercahaya + panah arah buka + angka chapter raksasa yang samar
			var hot: float = clampf(charge * 1.2 + rt * 0.5, 0.0, 1.0)
			_draw_gate_doors(acc, a * fade, hot, charge)
			UIKit.text_in(self, str(ch + 1), Rect2(GX, GY - 6.0, GW, PH), 330, Color(acc.r, acc.g, acc.b, 0.09 * a * fade), HORIZONTAL_ALIGNMENT_CENTER, 0)
			# 3) cahaya merembes dari emblem (warna chapter)
			var pl: float = 0.5 + 0.5 * sin(t * 2.0 + float(ch))
			var gk: float = (0.12 + 0.05 * pl + 0.5 * charge + 0.3 * rt + (0.08 if focus_here else 0.0)) * fade
			for g in 7:
				draw_circle(GC + Vector2(0.0, 6.0), 210.0 - 24.0 * float(g), Color(gc.r, gc.g, gc.b, gk * 0.07 * a))
			# 4) dua palang kunci yang melintang di atas celah pintu
			_draw_gate_bolts(acc, a * fade, hot, rt)
		# 5) emblem segel chapter (cincin reaktor berputar; pecah berkeping saat terbuka)
		_draw_gate_emblem(first, ch, a, acc, ot, charge, rt, focus_here, gc)
		# 6) pelat syarat + kursor
		if fade > 0.01:
			_draw_gate_plate(ch, first, acc, a * fade, focus_here)
			if focus_here and not opening:
				draw_set_transform(xs + GC + Vector2(0.0, 2.0), 0.0, Vector2(1.3, 1.3))
				_draw_reticle(a, Vector2.ZERO)
				draw_set_transform(xs, 0.0, Vector2.ONE)
		# 7) judul chapter versi terkunci
		var ent0: float = enter[0]
		var th: float = (1.0 - clampf(ot / 0.3, 0.0, 1.0)) if opening else clampf(ent0 * 2.2 + 0.4, 0.0, 1.0)
		var thx: float = 0.0 if opening else -34.0 * (1.0 - _back(th))
		var tal: float = a * th
		if tal > 0.01:
			UIKit.text_in(self, "CHAPTER %d" % (ch + 1), Rect2(GX + 34.0 + thx, GY + 12.0, 520.0, 66.0), 58, Color(0.78, 0.83, 0.95, 0.55 * tal), HORIZONTAL_ALIGNMENT_LEFT, 8, Color(0, 0, 0, tal))
			UIKit.text_in(self, CampaignData.chapter_name(ch), Rect2(GX + 36.0 + thx, GY + 74.0, 520.0, 30.0), 26, Color(acc.r, acc.g, acc.b, 0.6 * tal), HORIZONTAL_ALIGNMENT_LEFT, 5, Color(0, 0, 0, tal))
			_draw_gate_badge(acc, tal)
		# 8) tepi lingkaran cahaya yang melebar
		if opening and ir > 1.0:
			var ring := PackedVector2Array()
			for q in 97:
				var ang: float = float(q) * TAU / 96.0
				ring.append(GC + Vector2(cos(ang), sin(ang)) * ir)
			var ra: float = a * (1.0 - smoothstep(0.5, 1.0, iris_p))
			if ra > 0.01:
				var lt: Color = acc.lightened(0.5)
				for seg3 in Geometry2D.intersect_polyline_with_polygon(ring, pts):
					draw_polyline(seg3, Color(acc.r, acc.g, acc.b, 0.32 * ra), 24.0, true)
					draw_polyline(seg3, Color(lt.r, lt.g, lt.b, 0.9 * ra), 8.0, true)
					draw_polyline(seg3, Color(1, 1, 1, ra), 3.0, true)
		# bingkai gerbang (baja berlampu warna chapter)
		var seal_k: float = 1.0 if not opening else (1.0 - iris_p)
		var fcol: Color = acc.lerp(Color(0.56, 0.62, 0.78), 0.55 * seal_k)
		draw_polyline(UIKit.closed(pts), Color(fcol.r, fcol.g, fcol.b, 0.95 * a), 4.0, true)
		var inner_fr := PackedVector2Array()
		var fr_c := Vector2(GX + GW * 0.5, GY + PH * 0.5)
		for fp in pts:
			inner_fr.append(fr_c + (fp - fr_c) * Vector2((GW - 18.0) / GW, (PH - 18.0) / PH))
		draw_polyline(UIKit.closed(inner_fr), Color(acc.r, acc.g, acc.b, 0.30 * a * (1.0 - iris_p)), 1.5, true)
		draw_line(Vector2(GX + 38.0, GY + 3.0), Vector2(GX + 220.0, GY + 3.0), Color(fcol.lightened(0.3).r, fcol.lightened(0.3).g, fcol.lightened(0.3).b, a), 6.0)
		draw_line(Vector2(GX + GW - 38.0, GY + PH - 3.0), Vector2(GX + GW - 220.0, GY + PH - 3.0), Color(fcol.lightened(0.3).r, fcol.lightened(0.3).g, fcol.lightened(0.3).b, a), 6.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_gate_plate(ch: int, first: int, acc: Color, a: float, focus_here: bool) -> void:
		var info: Dictionary = hub.chapter_info(ch)
		var nm: String = "CHAPTER %d  -  %s" % [int(info["pch"]) + 1, String(info["name"])]
		var fs: int = 20
		var t1: String = "COMPLETE "
		var t3: String = " TO UNLOCK"
		var w1: float = UIKit.text_w(t1, fs)
		var w2: float = UIKit.text_w(nm, fs)
		var w3: float = UIKit.text_w(t3, fs)
		var pw: float = maxf(w1 + w2 + w3 + 84.0, 520.0)
		var pr := Rect2(GC.x - pw * 0.5, GY + 266.0, pw, 58.0)
		var edge: Color = Color(0.56, 0.62, 0.78, 0.85).lerp(acc.lightened(0.15), 0.6)
		if focus_here:
			edge = Color(1.0, 0.86, 0.36, 0.7 + 0.3 * sin(t * 6.0))
		draw_colored_polygon(UIKit.slanted(pr.size.x, pr.size.y, 14.0, pr.position.x + 3.0, pr.position.y + 4.0), Color(0, 0, 0, 0.5 * a))
		var ppts: PackedVector2Array = UIKit.slanted(pr.size.x, pr.size.y, 14.0, pr.position.x, pr.position.y)
		draw_colored_polygon(ppts, Color(0.025, 0.03, 0.07, 0.94 * a))
		draw_polyline(UIKit.closed(ppts), Color(edge.r, edge.g, edge.b, edge.a * a), 2.0, true)
		draw_rect(Rect2(pr.position.x + 20.0, pr.position.y + 7.0, 5.0, pr.size.y - 14.0), Color(acc.r, acc.g, acc.b, 0.95 * a))
		var tx: float = pr.position.x + 38.0 + (pr.size.x - 84.0 - (w1 + w2 + w3)) * 0.5
		var ty: float = pr.position.y + 4.0
		var lt: Color = acc.lightened(0.4)
		UIKit.text_in(self, t1, Rect2(tx, ty, w1 + 6.0, 26.0), fs, Color(1, 1, 1, 0.62 * a), HORIZONTAL_ALIGNMENT_LEFT, 3, Color(0, 0, 0, a))
		UIKit.text_in(self, nm, Rect2(tx + w1, ty, w2 + 6.0, 26.0), fs, Color(lt.r, lt.g, lt.b, a), HORIZONTAL_ALIGNMENT_LEFT, 3, Color(0, 0, 0, a))
		UIKit.text_in(self, t3, Rect2(tx + w1 + w2, ty, w3 + 6.0, 26.0), fs, Color(1, 1, 1, 0.62 * a), HORIZONTAL_ALIGNMENT_LEFT, 3, Color(0, 0, 0, a))
		# progres 50 level: 10 segmen (satu per dunia) yang terisi sebagian
		var done: int = int(info["done"])
		var cap: String = "%d / 50" % done
		var cw: float = UIKit.text_w(cap, 17)
		var seg_w: float = 36.0
		var gw: float = 10.0 * seg_w + 9.0 * 5.0 + 14.0 + cw
		var gx: float = pr.position.x + 38.0 + (pr.size.x - 84.0 - gw) * 0.5
		var gy: float = pr.position.y + 38.0
		for k in 10:
			var fillk: float = clampf(float(done - k * 5) / 5.0, 0.0, 1.0)
			var sr := Rect2(gx + float(k) * (seg_w + 5.0), gy, seg_w, 9.0)
			draw_rect(Rect2(sr.position + Vector2(1.5, 2.0), sr.size), Color(0, 0, 0, 0.5 * a))
			draw_rect(sr, Color(1, 1, 1, 0.14 * a))
			if fillk > 0.0:
				draw_rect(Rect2(sr.position, Vector2(sr.size.x * fillk, sr.size.y)), Color(0.29, 0.89, 0.63, a))
			elif bool(info["active"]) and k == int(done / 5):
				draw_rect(sr, Color(acc.r, acc.g, acc.b, (0.25 + 0.3 * sin(t * 5.0)) * a))
		UIKit.text_in(self, cap, Rect2(gx + 10.0 * (seg_w + 5.0) + 6.0, gy - 8.0, cw + 8.0, 26.0), 17, Color(1, 1, 1, 0.8 * a), HORIZONTAL_ALIGNMENT_LEFT, 3, Color(0, 0, 0, a))

	## Warna alas gerbang chapter: baja gelap bernuansa warna chapter (segel map tetap baja netral).
	func _gate_col(y: float, acc: Color, a: float) -> Color:
		var k: float = clampf(y / PH, 0.0, 1.0)
		var c: Color = Color(0.07, 0.085, 0.15).lerp(Color(0.025, 0.03, 0.065), k).lerp(acc.darkened(0.55), 0.22)
		return Color(c.r, c.g, c.b, 0.96 * a)

	## Dua daun pintu baja: celah tengah bercahaya, alur panel, paku keling, panah yang mengalir ke arah buka, dan siku sudut berwarna chapter.
	func _draw_gate_doors(acc: Color, a: float, hot: float, charge: float) -> void:
		if a <= 0.01:
			return
		var cx: float = GC.x
		var top: float = GY + 16.0
		var bot: float = GY + PH - 22.0
		var seam: float = 5.0 + 4.0 * charge
		var lit: float = 0.5 + 0.5 * sin(t * 2.2)
		var lt: Color = acc.lightened(0.3)
		var glow_a: float = 0.5 + 0.3 * lit + 0.5 * hot
		for sd in [-1.0, 1.0]:
			var side: float = sd
			var x_in: float = cx + side * seam
			var x_out: float = GX + 20.0 if side < 0.0 else GX + GW - 20.0
			var xa: float = minf(x_in, x_out)
			var xb: float = maxf(x_in, x_out)
			var leaf := PackedVector2Array([Vector2(xa, top), Vector2(xb, top), Vector2(xb, bot), Vector2(xa, bot)])
			var ctop: Color = Color(0.15, 0.18, 0.28).lerp(acc, 0.10)
			var cbot: Color = Color(0.055, 0.065, 0.12).lerp(acc.darkened(0.5), 0.12)
			draw_polygon(leaf, PackedColorArray([Color(ctop.r, ctop.g, ctop.b, a), Color(ctop.r, ctop.g, ctop.b, a), Color(cbot.r, cbot.g, cbot.b, a), Color(cbot.r, cbot.g, cbot.b, a)]))
			draw_polyline(UIKit.closed(leaf), Color(0.02, 0.025, 0.06, a), 3.0, true)
			draw_line(Vector2(xa + 3.0, top + 2.5), Vector2(xb - 3.0, top + 2.5), Color(1, 1, 1, 0.16 * a), 1.5)
			# alur panel (dua mendatar, satu tegak)
			for gy in [0.34, 0.68]:
				var yy: float = lerpf(top, bot, float(gy))
				draw_line(Vector2(xa + 4.0, yy), Vector2(xb - 4.0, yy), Color(0, 0, 0, 0.5 * a), 2.0)
				draw_line(Vector2(xa + 4.0, yy + 2.0), Vector2(xb - 4.0, yy + 2.0), Color(1, 1, 1, 0.07 * a), 1.0)
			var gxv: float = lerpf(x_in, x_out, 0.58)
			draw_line(Vector2(gxv, top + 4.0), Vector2(gxv, bot - 4.0), Color(0, 0, 0, 0.45 * a), 2.0)
			draw_line(Vector2(gxv + 2.0, top + 4.0), Vector2(gxv + 2.0, bot - 4.0), Color(1, 1, 1, 0.06 * a), 1.0)
			# paku keling di sisi dalam & luar daun (mesh di-cache; dibangun ulang hanya kalau celah tengah berubah)
			var rkey: float = x_in * side
			var rc: Dictionary = _riv_cache.get(side, {})
			if rc.is_empty() or float(rc["key"]) != rkey:
				var c_main: Array = []
				var c_hi: Array = []
				for k in 7:
					var ry: float = lerpf(top + 16.0, bot - 16.0, float(k) / 6.0)
					for rx in [x_in + side * 17.0, x_out - side * 14.0]:
						var rp := Vector2(float(rx), ry)
						c_main.append(rp)
						c_hi.append(rp + Vector2(-0.8, -0.8))
				rc = {"key": rkey, "main": _discs_mesh(c_main, 3.0), "hi": _discs_mesh(c_hi, 1.1)}
				_riv_cache[side] = rc
			draw_mesh(rc["main"], null, Transform2D.IDENTITY, Color(0.7, 0.75, 0.88, 0.8 * a))
			draw_mesh(rc["hi"], null, Transform2D.IDENTITY, Color(1, 1, 1, 0.75 * a))
			# lampu celah (garis cahaya vertikal di sisi dalam daun)
			draw_rect(Rect2(minf(x_in, x_in + side * 14.0), top, 14.0, bot - top), Color(acc.r, acc.g, acc.b, 0.10 * glow_a * a))
			draw_rect(Rect2(minf(x_in, x_in + side * 5.0), top, 5.0, bot - top), Color(lt.r, lt.g, lt.b, 0.8 * glow_a * a))
			# tiga panah (chevron) yang berdenyut bergantian ke arah luar = arah pintu membuka
			for k in 3:
				var cxp: float = cx + side * (150.0 + float(k) * 44.0)
				var wv: float = clampf(sin(t * 3.2 - float(k) * 1.15), 0.0, 1.0)
				var ca: float = (0.16 + 0.7 * wv) * a
				var chev := PackedVector2Array([Vector2(cxp - side * 10.0, GC.y - 17.0), Vector2(cxp, GC.y), Vector2(cxp - side * 10.0, GC.y + 17.0)])
				draw_polyline(chev, Color(0, 0, 0, 0.5 * ca), 9.0, true)
				draw_polyline(chev, Color(lt.r, lt.g, lt.b, ca), 5.0, true)
		# celah tengah yang gelap + garis cahaya tipis (menyala saat segel mau pecah)
		draw_rect(Rect2(cx - seam, top, seam * 2.0, bot - top), Color(0.01, 0.01, 0.03, a))
		draw_line(Vector2(cx, top), Vector2(cx, bot), Color(1.0, 0.9, 0.7, (0.25 + 0.6 * hot) * a), 1.5 + 2.0 * hot)
		# deretan segitiga di tepi bawah (pengganti garis bahaya milik segel map)
		var tv := PackedVector2Array()
		var tcl := PackedColorArray()
		for k in 28:
			var tx: float = GX + 80.0 + float(k) * 34.0
			var ta: float = 0.30 + 0.35 * (0.5 + 0.5 * sin(t * 2.4 - float(k) * 0.5))
			var tcol := Color(acc.r, acc.g, acc.b, ta * a)
			tv.append(Vector2(tx, GY + PH - 7.0))
			tv.append(Vector2(tx + 24.0, GY + PH - 7.0))
			tv.append(Vector2(tx + 12.0, GY + PH - 18.0))
			tcl.append(tcol)
			tcl.append(tcol)
			tcl.append(tcol)
		_tri_batch(tv, tcl)
		# siku sudut berwarna chapter
		var br: Color = Color(lt.r, lt.g, lt.b, 0.85 * a)
		var bk: Color = Color(0, 0, 0, 0.5 * a)
		var corners: Array = [
			PackedVector2Array([Vector2(GX + 14.0, GY + 62.0), Vector2(GX + 14.0, GY + 46.0), Vector2(GX + 46.0, GY + 14.0), Vector2(GX + 62.0, GY + 14.0)]),
			PackedVector2Array([Vector2(GX + GW - 62.0, GY + 14.0), Vector2(GX + GW - 14.0, GY + 14.0), Vector2(GX + GW - 14.0, GY + 62.0)]),
			PackedVector2Array([Vector2(GX + 14.0, GY + PH - 62.0), Vector2(GX + 14.0, GY + PH - 14.0), Vector2(GX + 62.0, GY + PH - 14.0)]),
			PackedVector2Array([Vector2(GX + GW - 14.0, GY + PH - 62.0), Vector2(GX + GW - 14.0, GY + PH - 46.0), Vector2(GX + GW - 46.0, GY + PH - 14.0), Vector2(GX + GW - 62.0, GY + PH - 14.0)]),
		]
		for cpl in corners:
			var cpp: PackedVector2Array = cpl
			draw_polyline(cpp, bk, 8.0, true)
			draw_polyline(cpp, br, 4.0, true)

	## Dua palang kunci tebal yang melintang di atas celah pintu (berguncang saat segel akan pecah).
	func _draw_gate_bolts(acc: Color, a: float, hot: float, rt: float) -> void:
		if a <= 0.01:
			return
		var shake: float = sin(t * 47.0) * (1.2 * hot + 3.0 * rt)
		var led: Color = acc.lightened(0.3).lerp(Color(1.0, 0.55, 0.3), hot)
		for yo in [-56.0, 56.0]:
			var y: float = GC.y + float(yo)
			var xa: float = GC.x - 262.0 + shake
			var xb: float = GC.x + 262.0 + shake
			var body := PackedVector2Array([Vector2(xa, y - 7.0), Vector2(xb, y - 7.0), Vector2(xb, y + 7.0), Vector2(xa, y + 7.0)])
			var sh := PackedVector2Array()
			for p in body:
				sh.append(p + Vector2(3.0, 5.0))
			draw_colored_polygon(sh, Color(0, 0, 0, 0.42 * a))
			var bt: Color = _steel(hot, led, 0.1)
			var bb: Color = Color(0.2, 0.23, 0.33).lerp(Color(0.55, 0.2, 0.14), hot * 0.4)
			draw_polygon(body, PackedColorArray([Color(bt.r, bt.g, bt.b, a), Color(bt.r, bt.g, bt.b, a), Color(bb.r, bb.g, bb.b, a), Color(bb.r, bb.g, bb.b, a)]))
			draw_polyline(UIKit.closed(body), Color(0.03, 0.04, 0.08, a), 2.5, true)
			draw_line(Vector2(xa + 3.0, y - 4.5), Vector2(xb - 3.0, y - 4.5), Color(1, 1, 1, 0.4 * a), 1.6)
			# garis penanda berjarak rapat di sepanjang palang
			var ticks := PackedVector2Array()
			for k in range(1, 26):
				var mx: float = xa + float(k) * ((xb - xa) / 26.0)
				ticks.append(Vector2(mx, y - 2.0))
				ticks.append(Vector2(mx, y + 6.0))
			draw_multiline(ticks, Color(0, 0, 0, 0.35 * a), 1.5)
			# blok pengunci di kedua ujung + lampu LED warna chapter
			for ex in [xa, xb]:
				var ec := Vector2(float(ex), y)
				var blk := Rect2(ec.x - 11.0, ec.y - 19.0, 22.0, 38.0)
				draw_rect(Rect2(blk.position + Vector2(2.5, 3.5), blk.size), Color(0, 0, 0, 0.42 * a))
				draw_rect(blk, Color(0.3, 0.34, 0.46, a))
				draw_rect(blk, Color(0.04, 0.05, 0.09, a), false, 2.5)
				draw_rect(Rect2(blk.position.x + 2.0, blk.position.y + 2.0, blk.size.x - 4.0, 3.0), Color(1, 1, 1, 0.3 * a))
				draw_circle(ec, 5.5, Color(0.04, 0.05, 0.09, a))
				draw_circle(ec, 3.6, Color(led.r, led.g, led.b, (0.55 + 0.45 * sin(t * 5.0 + ec.x * 0.01)) * a))

	## Emblem segel chapter: cincin reaktor berlampu (satu lampu = 1 / 12 progres chapter sebelumnya), cincin tick berputar, empat pengunci, inti bergembok.
	func _draw_gate_emblem(first: int, ch: int, a: float, acc: Color, ot: float, charge: float, rt: float, focus_here: bool, gc: Color) -> void:
		var c: Vector2 = GC + Vector2(0.0, 2.0)
		if ot >= 0.0:
			_draw_gate_emblem_broken(c, a, acc, ot, first, gc)
			return
		var amp: float = 2.4 * charge + 6.0 * rt
		var jig := Vector2.ZERO
		if amp > 0.0:
			jig = Vector2(sin(t * 61.0), cos(t * 53.0)) * amp
		c += jig + Vector2(0.0, sin(t * 1.6) * 1.5)
		var hot: float = clampf(charge + rt * 0.6, 0.0, 1.0)
		var info: Dictionary = hub.chapter_info(ch)
		var done: int = int(info["done"])
		var lit_n: int = int(floor(float(done) * 12.0 / 50.0))
		var R: float = 86.0
		var lt: Color = acc.lightened(0.35)
		var st: Color = _steel(hot, gc, 0.0).lerp(acc.lightened(0.2), 0.16)
		var glow: float = hot + (0.35 if focus_here else 0.0) + 0.12 * sin(t * 3.0)
		# bayangan + pendar warna chapter
		draw_circle(c + Vector2(5.0, 9.0), R + 8.0, Color(0, 0, 0, 0.4 * a))
		for g in 4:
			draw_circle(c, R + 26.0 - 7.0 * float(g), Color(acc.r, acc.g, acc.b, (0.035 + 0.05 * glow) * a))
		# empat pengunci (dogs) di sudut diagonal
		for q in 4:
			var ang: float = PI * 0.25 + float(q) * PI * 0.5
			var d := Vector2(cos(ang), sin(ang))
			var n := Vector2(-d.y, d.x)
			var dog := PackedVector2Array([c + d * (R - 12.0) + n * 14.0, c + d * (R + 16.0) + n * 11.0, c + d * (R + 16.0) - n * 11.0, c + d * (R - 12.0) - n * 14.0])
			var dsh := PackedVector2Array()
			for p in dog:
				dsh.append(p + Vector2(2.5, 4.0))
			draw_colored_polygon(dsh, Color(0, 0, 0, 0.4 * a))
			draw_polygon(dog, PackedColorArray([Color(st.r, st.g, st.b, a), Color(st.r * 0.8, st.g * 0.8, st.b * 0.8, a), Color(st.r * 0.55, st.g * 0.55, st.b * 0.55, a), Color(st.r * 0.7, st.g * 0.7, st.b * 0.7, a)]))
			draw_polyline(UIKit.closed(dog), Color(0.03, 0.04, 0.08, a), 2.5, true)
			var bolt_p: Vector2 = c + d * (R + 5.0)
			draw_circle(bolt_p, 3.6, Color(0.1, 0.12, 0.19, a))
			draw_circle(bolt_p + Vector2(-0.8, -0.8), 1.4, Color(0.85, 0.9, 1.0, 0.85 * a))
		# cincin baja luar
		draw_circle(c, R, Color(0.04, 0.05, 0.09, a))
		draw_arc(c, R - 5.0, 0.0, TAU, 72, Color(0.04, 0.05, 0.09, a), 13.0, true)
		draw_arc(c, R - 5.0, 0.0, TAU, 72, Color(st.r * 0.72, st.g * 0.72, st.b * 0.72, a), 10.0, true)
		draw_arc(c, R - 5.0, 0.0, TAU, 72, Color(st.r, st.g, st.b, a), 6.0, true)
		draw_arc(c, R - 8.0, PI * 1.05, PI * 1.6, 16, Color(1, 1, 1, 0.45 * a), 2.0, true)
		if focus_here:
			draw_arc(c, R + 3.0, 0.0, TAU, 72, Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, (0.65 + 0.35 * sin(t * 6.0)) * a), 3.0, true)
		draw_circle(c, R - 13.0, Color(0.035, 0.04, 0.08, a))
		# 12 lampu progres (hijau = sudah, berdenyut = berikutnya, redup = belum)
		for q in 12:
			var a0: float = -PI * 0.5 + float(q) * TAU / 12.0 + 0.09
			var a1: float = a0 + TAU / 12.0 - 0.18
			var lc: Color = Color(1, 1, 1, 0.10)
			if q < lit_n:
				lc = Color(0.29, 0.89, 0.63, 1.0)
			elif q == lit_n and bool(info["active"]):
				lc = Color(acc.r, acc.g, acc.b, 0.4 + 0.5 * sin(t * 5.0))
			draw_arc(c, 66.0, a0, a1, 6, Color(0, 0, 0, 0.55 * a), 12.0, true)
			if q < lit_n:
				draw_arc(c, 66.0, a0, a1, 6, Color(lc.r, lc.g, lc.b, 0.22 * a), 16.0, true)
			draw_arc(c, 66.0, a0, a1, 6, Color(lc.r, lc.g, lc.b, lc.a * a), 8.0, true)
		# cincin tick berputar (makin cepat saat segel dialiri daya)
		var rot: float = t * (0.35 + 3.0 * charge)
		var tk_long := PackedVector2Array()
		var tk_short := PackedVector2Array()
		for q in 36:
			var ta: float = rot + float(q) * TAU / 36.0
			var tl: float = 7.0 if q % 3 == 0 else 3.5
			var td := Vector2(cos(ta), sin(ta))
			var tgt: PackedVector2Array = tk_long if q % 3 == 0 else tk_short
			tgt.append(c + td * 50.0)
			tgt.append(c + td * (50.0 + tl))
		draw_multiline(tk_short, Color(lt.r, lt.g, lt.b, 0.4 * a), 2.0)
		draw_multiline(tk_long, Color(lt.r, lt.g, lt.b, 0.75 * a), 2.0)
		# tiga busur emas yang berputar berlawanan arah
		for q in 3:
			var ba: float = -t * (0.7 + 2.0 * charge) + float(q) * TAU / 3.0
			draw_arc(c, 40.0, ba, ba + 1.1, 10, Color(1.0, 0.85, 0.4, 0.8 * a), 3.0, true)
		# inti bercahaya + gembok kecil
		draw_circle(c, 33.0 + 4.0 * glow, Color(gc.r, gc.g, gc.b, (0.12 + 0.3 * glow) * a))
		draw_circle(c, 30.0, Color(acc.r * 0.28, acc.g * 0.28, acc.b * 0.28, a).lerp(Color(0.03, 0.03, 0.07, a), 0.4))
		draw_arc(c, 30.0, 0.0, TAU, 40, Color(lt.r, lt.g, lt.b, (0.7 + 0.3 * hot) * a), 3.0, true)
		var lkc: Color = Color(1.0, 0.9, 0.62, 0.96 * a) if focus_here else Color(0.9, 0.93, 1.0, 0.92 * a)
		UIKit.draw_lock(self, c + Vector2(0.0, 3.0), 38.0, lkc)
		# retakan bercahaya yang menjalar dari inti saat segel hampir pecah
		if charge > 0.3:
			var ck: float = clampf((charge - 0.3) / 0.7, 0.0, 1.0)
			for k in 5:
				var sa: float = float(k) * TAU / 5.0 + 0.3
				var sdv := Vector2(cos(sa), sin(sa))
				var snv := Vector2(-sdv.y, sdv.x)
				var cp := PackedVector2Array()
				var cn: int = maxi(2, int(ck * 6.0) + 1)
				for j in mini(cn, 6):
					var rr: float = 26.0 + float(j) * (R - 28.0) / 5.0
					cp.append(c + sdv * rr + snv * sin(float(j) * 2.1 + float(k) * 1.3) * 5.0)
				if cp.size() >= 2:
					draw_polyline(cp, Color(gc.r, gc.g, gc.b, 0.4 * a), 7.0, true)
					draw_polyline(cp, Color(1.0, 0.92, 0.7, a), 2.2, true)

	## Emblem pecah: kilatan, gelombang kejut, cincin terbelah dua, lampu & pengunci terlempar, lalu pecahan logam.
	func _draw_gate_emblem_broken(c: Vector2, a: float, acc: Color, te: float, first: int, gc: Color) -> void:
		var lt: Color = acc.lightened(0.35)
		var fl: float = clampf(1.0 - te / 0.34, 0.0, 1.0)
		if fl > 0.0:
			draw_circle(c, 70.0 + 190.0 * (1.0 - fl), Color(acc.r, acc.g, acc.b, 0.35 * fl * a))
			draw_circle(c, 45.0 + 110.0 * (1.0 - fl), Color(1, 1, 1, 0.85 * fl * a))
		# tiga gelombang kejut
		var wcols: Array = [Color.WHITE, lt, Color(1.0, 0.85, 0.4)]
		for k in 3:
			var wu: float = clampf((te - 0.05 * float(k)) / 0.8, 0.0, 1.0)
			if wu > 0.0 and wu < 1.0:
				var wc: Color = wcols[k]
				draw_arc(c, 40.0 + 430.0 * (1.0 - pow(1.0 - wu, 2.0)), 0.0, TAU, 72, Color(wc.r, wc.g, wc.b, (1.0 - wu) * 0.85 * a), 7.0 * (1.0 - wu) + 1.5, true)
		# cincin baja terbelah dua, jatuh berputar
		var al: float = a * clampf(1.0 - (te - 0.1) / 0.8, 0.0, 1.0)
		if al > 0.01:
			for hf in 2:
				var sg: float = -1.0 if hf == 0 else 1.0
				var oc: Vector2 = c + Vector2(sg * (60.0 * te + 70.0 * te * te), 400.0 * te * te - 40.0 * te)
				var a_s: float = (PI * 0.5 if hf == 0 else -PI * 0.5) + sg * 1.4 * te
				draw_arc(oc, 81.0, a_s, a_s + PI, 24, Color(0.04, 0.05, 0.09, al), 13.0, true)
				draw_arc(oc, 81.0, a_s, a_s + PI, 24, Color(0.58, 0.63, 0.75, al), 7.0, true)
		# 12 lampu & 4 pengunci terlempar keluar
		var al2: float = a * clampf(1.0 - (te - 0.06) / 0.85, 0.0, 1.0)
		if al2 > 0.01:
			var u: float = clampf(te / 0.9, 0.0, 1.0)
			var dist: float = 300.0 * (1.0 - pow(1.0 - u, 2.0))
			for q in 12:
				var am: float = -PI * 0.5 + (float(q) + 0.5) * TAU / 12.0
				var dm := Vector2(cos(am), sin(am))
				var pc: Vector2 = c + dm * (66.0 + dist) + Vector2(0.0, 320.0 * te * te)
				var rot: float = am + (3.5 if q % 2 == 0 else -3.5) * te
				var dd := Vector2(cos(rot), sin(rot))
				var nn := Vector2(-dd.y, dd.x)
				var chunk := PackedVector2Array([pc - dd * 13.0 - nn * 6.0, pc + dd * 13.0 - nn * 6.0, pc + dd * 13.0 + nn * 6.0, pc - dd * 13.0 + nn * 6.0])
				var qc: Color = Color(0.29, 0.89, 0.63) if q % 3 == 0 else Color(lt.r, lt.g, lt.b)
				draw_colored_polygon(chunk, Color(qc.r, qc.g, qc.b, al2))
			for q in 4:
				var ag: float = PI * 0.25 + float(q) * PI * 0.5
				var dg := Vector2(cos(ag), sin(ag))
				var pg: Vector2 = c + dg * ((86.0 + 2.0) + dist * 1.25) + Vector2(0.0, 360.0 * te * te)
				var rg: float = ag + (4.0 if q % 2 == 0 else -4.0) * te
				var gd := Vector2(cos(rg), sin(rg))
				var gn := Vector2(-gd.y, gd.x)
				var dogp := PackedVector2Array([pg - gd * 14.0 - gn * 12.0, pg + gd * 14.0 - gn * 10.0, pg + gd * 14.0 + gn * 10.0, pg - gd * 14.0 + gn * 12.0])
				draw_colored_polygon(dogp, Color(0.5, 0.55, 0.68, al2))
				draw_polyline(UIKit.closed(dogp), Color(0.04, 0.05, 0.09, al2), 2.5, true)
		# gembok inti membesar lalu menghilang
		var al3: float = a * clampf(1.0 - te / 0.4, 0.0, 1.0)
		if al3 > 0.01:
			UIKit.draw_lock(self, c + Vector2(0.0, 3.0), 38.0 * (1.0 + 1.6 * te), Color(1.0, 0.95, 0.75, al3))
		# pecahan logam (memakai data acak yang sudah dibuat saat segel pecah)
		var fx: Dictionary = vault_fx.get(first, {})
		var lf: float = clampf(1.0 - te / 1.1, 0.0, 1.0)
		if lf > 0.0 and fx.has("shards"):
			for sd in fx["shards"]:
				var dir := Vector2(cos(float(sd["a"])), sin(float(sd["a"])))
				var p: Vector2 = c + dir * float(sd["s"]) * (1.0 - pow(1.0 - clampf(te / 1.1, 0.0, 1.0), 2.0)) + Vector2(0.0, 380.0 * te * te)
				var z: float = float(sd["z"]) * (0.5 + 0.5 * lf)
				var kk: int = int(sd["k"])
				var scol: Color = Color(0.7, 0.75, 0.88) if kk == 0 else (Color(0.3, 0.33, 0.44) if kk == 1 else lt)
				var tri := PackedVector2Array([Vector2(0.0, -z), Vector2(z * 0.8, z * 0.7), Vector2(-z * 0.8, z * 0.7)])
				var op := PackedVector2Array()
				for tp in tri:
					op.append(p + tp.rotated(float(sd["r"]) + float(sd["rv"]) * te))
				draw_colored_polygon(op, Color(scol.r, scol.g, scol.b, lf * a))

	## Lencana "SEALED" bersegi enam di pojok kanan atas gerbang (beda dengan label LOCKED milik segel map).
	func _draw_gate_badge(acc: Color, a: float) -> void:
		var r := Rect2(GX + GW - 292.0, GY + 26.0, 256.0, 46.0)
		draw_colored_polygon(UIKit.slanted(r.size.x, r.size.y, 12.0, r.position.x + 3.0, r.position.y + 4.0), Color(0, 0, 0, 0.5 * a))
		var bp: PackedVector2Array = UIKit.slanted(r.size.x, r.size.y, 12.0, r.position.x, r.position.y)
		draw_colored_polygon(bp, Color(0.025, 0.03, 0.07, 0.9 * a))
		draw_polyline(UIKit.closed(bp), Color(acc.r, acc.g, acc.b, 0.85 * a), 2.0, true)
		var hc := Vector2(r.position.x + 36.0, r.position.y + r.size.y * 0.5)
		var hex := PackedVector2Array()
		for q in 6:
			var ang: float = float(q) * TAU / 6.0 + PI / 6.0
			hex.append(hc + Vector2(cos(ang), sin(ang)) * 17.0)
		draw_colored_polygon(hex, Color(acc.r, acc.g, acc.b, 0.28 * a))
		var hl: Color = acc.lightened(0.3)
		draw_polyline(UIKit.closed(hex), Color(hl.r, hl.g, hl.b, 0.9 * a), 2.5, true)
		UIKit.draw_lock(self, hc + Vector2(0.0, 1.5), 19.0, Color(1, 1, 1, 0.8 * a))
		UIKit.text_in(self, "SEALED", Rect2(r.position.x + 64.0, r.position.y, r.size.x - 76.0, r.size.y), 30, Color(1, 1, 1, 0.62 * a), HORIZONTAL_ALIGNMENT_LEFT, 5, Color(0, 0, 0, a))

	## Tab dunia saat chapter terkunci: semua tersegel, nama disembunyikan, tidak bisa diklik.
	func _draw_tabs_sealed() -> void:
		var acc: Color = chap_accent(hub.chapter)
		for j in tab_anim.size():
			var r: Rect2 = tab_rect(j)
			var pts: PackedVector2Array = UIKit.slanted(r.size.x, r.size.y, 10.0, r.position.x, r.position.y)
			draw_colored_polygon(UIKit.slanted(r.size.x, r.size.y, 10.0, r.position.x + 2.0, r.position.y + 3.0), Color(0, 0, 0, 0.4))
			draw_colored_polygon(pts, Color(0.035, 0.04, 0.09, 0.9))
			draw_polyline(UIKit.closed(pts), Color(0.5, 0.56, 0.72, 0.4).lerp(Color(acc.r, acc.g, acc.b, 0.55), 0.5), 2.0, true)
			_draw_lock_label(Rect2(r.position.x + 14.0, r.position.y, r.size.x - 28.0, r.size.y), "???", tab_fs[j], 14.0, Color(acc.lightened(0.45).r, acc.lightened(0.45).g, acc.lightened(0.45).b, 0.42), 0, Color.BLACK, r.size.x - 28.0, false, 7.0)
		draw_rect(Rect2(tab_rect(0).position.x, TAB_Y + TAB_H + 3.0, tab_rect(tab_anim.size() - 1).end.x - tab_rect(0).position.x, 2.0), Color(acc.r, acc.g, acc.b, 0.25))

	# ------------------------------------------------------------------ satu "adegan" chapter (dipakai juga untuk transisi antar chapter)
	func _draw_scene(ch: int, p: float, ent: Array[float], xs: float, am: float) -> void:
		var s_pos: float = pos
		var s_ent: Array[float] = enter
		vch = ch
		pos = p
		enter = ent
		xshift = xs
		amul = am
		if chap_sealed(ch):
			_draw_gate(ch, -1.0)
		else:
			var order: Array[int] = []
			for i in CampaignData.WORLDS.size():
				if absf(float(i) - pos) < 1.6:
					order.append(i)
			order.sort_custom(func(a: int, b: int) -> bool: return absf(float(a) - pos) > absf(float(b) - pos))
			for i in order:
				_draw_page(i)
			var cot: float = float(open_t.get(ch * CampaignData.CHAPTER_SIZE + 1, -1.0))
			if cot >= 0.0:
				_draw_gate(ch, cot)
		vch = -1
		pos = s_pos
		enter = s_ent
		xshift = 0.0
		amul = 1.0

	## Cahaya warna chapter menyapu peta + angka chapter raksasa samar saat berpindah chapter.
	func _draw_swap_fx(ch: int) -> void:
		var acc: Color = chap_accent(ch)
		var u: float = clampf(swap_t, 0.0, 1.0)
		var env: float = sin(u * PI)
		var px: float = lerpf(-220.0, size.x + 220.0, smoothstep(0.0, 1.0, u)) if swap_dir > 0 else lerpf(size.x + 220.0, -220.0, smoothstep(0.0, 1.0, u))
		var band := PackedVector2Array([Vector2(px - 70.0, 0.0), Vector2(px + 70.0, 0.0), Vector2(px + 20.0, size.y), Vector2(px - 120.0, size.y)])
		draw_colored_polygon(band, Color(acc.r, acc.g, acc.b, 0.17 * env))
		var core := PackedVector2Array([Vector2(px - 8.0, 0.0), Vector2(px + 14.0, 0.0), Vector2(px - 36.0, size.y), Vector2(px - 58.0, size.y)])
		draw_colored_polygon(core, Color(1, 1, 1, 0.22 * env))
		UIKit.text_in(self, str(ch + 1), Rect2(0.0, 20.0, size.x, 340.0), 300, Color(acc.r, acc.g, acc.b, 0.11 * env), HORIZONTAL_ALIGNMENT_CENTER, 0)

	# ================================================================== SEGEL DUNIA TERKUNCI
	## Dunia yang belum terbuka tampil sebagai BRANKAS BAJA: isi dunia (gambar, nama level, node, bintang) tidak digambar sama sekali.
	## Hanya tampak: pola baja gelap, dua rantai bersilang, gembok besar, dan pelat syarat (dunia sebelumnya + kemajuannya).
	## Saat dunia terbuka: gembok bergetar -> pecah, rantai putus & jatuh, lalu lingkaran cahaya melebar menyingkap dunia berwarna.

	func _tri_ok(poly: PackedVector2Array) -> bool:
		if poly.size() < 3:
			return false
		var ar: float = 0.0
		for q in poly.size():
			var p0: Vector2 = poly[q]
			var p1: Vector2 = poly[(q + 1) % poly.size()]
			ar += p0.x * p1.y - p1.x * p0.y
		return absf(ar) > 4.0

	func _seal_col(y: float, acc: Color, a: float) -> Color:
		var k: float = clampf(y / PH, 0.0, 1.0)
		var c: Color = Color(0.075, 0.09, 0.16).lerp(Color(0.028, 0.034, 0.07), k).lerp(acc.darkened(0.6), 0.10)
		return Color(c.r, c.g, c.b, 0.955 * a)

	## Alas segel = panel dikurangi lingkaran (radius r) di tengah gembok. Dibagi 4 kuadran supaya tiap bagian tetap poligon sederhana.
	func _vault_fill_polys(pts: PackedVector2Array, r: float, ctr: Vector2 = VC, ext: Vector2 = Vector2(PW, PH)) -> Array:
		if r <= 0.5:
			return [pts]
		var circle := PackedVector2Array()
		for q in 72:
			var ang: float = float(q) * TAU / 72.0
			circle.append(ctr + Vector2(cos(ang), sin(ang)) * r)
		var quads: Array = [
			PackedVector2Array([Vector2(-80.0, -80.0), Vector2(ctr.x, -80.0), ctr, Vector2(-80.0, ctr.y)]),
			PackedVector2Array([Vector2(ctr.x, -80.0), Vector2(ext.x + 80.0, -80.0), Vector2(ext.x + 80.0, ctr.y), ctr]),
			PackedVector2Array([Vector2(-80.0, ctr.y), ctr, Vector2(ctr.x, ext.y + 80.0), Vector2(-80.0, ext.y + 80.0)]),
			PackedVector2Array([ctr, Vector2(ext.x + 80.0, ctr.y), Vector2(ext.x + 80.0, ext.y + 80.0), Vector2(ctr.x, ext.y + 80.0)]),
		]
		var out: Array = []
		for qd in quads:
			for piece in Geometry2D.intersect_polygons(pts, qd):
				for res in Geometry2D.clip_polygons(piece, circle):
					out.append(res)
		return out

	func _ensure_vault_cache() -> void:
		if not _lat.is_empty():
			return
		var pts: PackedVector2Array = _page_poly()
		# pola belah ketupat: dua keluarga garis diagonal
		for kk in range(-12, 28):
			var x0: float = float(kk) * 44.0
			for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(x0, -10.0), Vector2(x0 + PH + 20.0, PH + 10.0)]), pts):
				_lat.append(seg)
			for seg2 in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(x0 + PH + 20.0, -10.0), Vector2(x0, PH + 10.0)]), pts):
				_lat.append(seg2)
		# garis-garis peringatan di tepi bawah
		var band := PackedVector2Array([Vector2(8.0, PH - 17.0), Vector2(PW - 8.0, PH - 17.0), Vector2(PW - 8.0, PH - 7.0), Vector2(8.0, PH - 7.0)])
		for kk in range(0, 60):
			var sx: float = 8.0 + float(kk) * 30.0
			var stripe := PackedVector2Array([Vector2(sx + 10.0, PH - 17.0), Vector2(sx + 24.0, PH - 17.0), Vector2(sx + 14.0, PH - 7.0), Vector2(sx, PH - 7.0)])
			for piece in Geometry2D.intersect_polygons(stripe, band):
				for piece2 in Geometry2D.intersect_polygons(piece, pts):
					if _tri_ok(piece2):
						_stripes.append(piece2)
		for seg in _lat:
			var sp: PackedVector2Array = seg
			for q in range(sp.size() - 1):
				_lat_ml.append(sp[q])
				_lat_ml.append(sp[q + 1])
		_stripes_mesh = _mesh_from_polys(_stripes)

	## Gabungkan banyak poligon sederhana jadi satu ArrayMesh (warna putih; warna asli lewat modulate saat draw_mesh).
	func _mesh_from_polys(polys: Array) -> ArrayMesh:
		var verts := PackedVector2Array()
		for poly in polys:
			var pp: PackedVector2Array = poly
			var idx: PackedInt32Array = Geometry2D.triangulate_polygon(pp)
			for ii in idx:
				verts.append(pp[ii])
		if verts.is_empty():
			return null
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m

	var _idx_cache := PackedInt32Array()
	var _riv_cache: Dictionary = {}

	## Kirim banyak segitiga berwarna-per-titik sebagai SATU perintah gambar (menggantikan puluhan draw_colored_polygon).
	func _tri_batch(verts: PackedVector2Array, cols: PackedColorArray) -> void:
		var n: int = verts.size()
		if n < 3:
			return
		if _idx_cache.size() < n:
			var old: int = _idx_cache.size()
			_idx_cache.resize(n + 256)
			for q in range(old, _idx_cache.size()):
				_idx_cache[q] = q
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _idx_cache.slice(0, n), verts, cols)

	## Mesh kumpulan lingkaran kecil (paku keling) -- dibangun sekali per konfigurasi, digambar dengan satu draw_mesh.
	func _discs_mesh(centers: Array, r: float) -> ArrayMesh:
		var verts := PackedVector2Array()
		var segs: int = 12
		for ctr in centers:
			var cc: Vector2 = ctr
			for q in segs:
				var a0: float = float(q) * TAU / float(segs)
				var a1: float = float(q + 1) * TAU / float(segs)
				verts.append(cc)
				verts.append(cc + Vector2(cos(a0), sin(a0)) * r)
				verts.append(cc + Vector2(cos(a1), sin(a1)) * r)
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m

	func _draw_vault(i: int, first: int, pts: PackedVector2Array, acc: Color, a: float, ot: float, sealed_now: bool, ent: float) -> void:
		_ensure_vault_cache()
		var opening: bool = ot >= 0.0
		var charge: float = charge_of(first)
		var rt: float = float(rattle.get(first, 0.0))
		var focus_here: bool = int(hub.focus) == -5 and int(hub.gate_level) == first
		var ir: float = 0.0
		var iris_p: float = 0.0
		if opening and ot > IRIS_START:
			iris_p = clampf((ot - IRIS_START) / IRIS_DUR, 0.0, 1.0)
			ir = IRIS_R * (1.0 - pow(1.0 - iris_p, 3.0))
		var fade: float = (1.0 - clampf(ot / 0.22, 0.0, 1.0)) if opening else 1.0     # hiasan segel lenyap cepat saat pecah
		var gc: Color = Color(1.0, 0.5, 0.32).lerp(acc.lightened(0.35), 0.3)           # cahaya hangat dari celah segel

		# 1) alas baja gelap (menyisakan bayangan samar gambar dunia di bawahnya)
		for piece in _vault_fill_polys(pts, ir):
			var pp: PackedVector2Array = piece
			if not _tri_ok(pp):
				continue
			var cols := PackedColorArray()
			for p in pp:
				cols.append(_seal_col(p.y, acc, a))
			draw_polygon(pp, cols)
		if fade > 0.01:
			# 2) pola belah ketupat tipis + garis peringatan
			if _lat_ml.size() >= 2:
				draw_multiline(_lat_ml, Color(acc.r, acc.g, acc.b, 0.075 * a * fade), 1.0)
			if _stripes_mesh != null:
				draw_mesh(_stripes_mesh, null, Transform2D.IDENTITY, Color(1.0, 0.76, 0.2, 0.42 * a * fade))
			# 3) cahaya merembes dari celah gembok (makin kuat saat segel akan pecah)
			var pl: float = 0.5 + 0.5 * sin(t * 2.0 + float(i))
			var gk: float = (0.10 + 0.05 * pl + 0.5 * charge + 0.3 * rt + (0.08 if focus_here else 0.0)) * fade
			for g in 6:
				draw_circle(VC + Vector2(0.0, 22.0), 132.0 - 20.0 * float(g), Color(gc.r, gc.g, gc.b, gk * 0.075 * a))
			# 4) rantai bersilang + jangkarnya
			var hot: float = clampf(charge * 1.2 + rt * 0.5, 0.0, 1.0)
			_draw_chain(CH_A[0], CH_A[1], 3, a, ot, charge, rt, hot, gc)
			_draw_chain(CH_B[0], CH_B[1], 11, a, ot, charge, rt, hot, gc)
			for anc in [CH_A[0], CH_A[1], CH_B[0], CH_B[1]]:
				_draw_anchor(anc, a * clampf(1.0 - ot / 0.5, 0.0, 1.0) if opening else a, hot)

		# 5) gembok besar (utuh / pecah)
		_draw_vault_lock(first, a, acc, ot, charge, rt, focus_here, gc)

		# 6) pelat syarat + kursor
		if fade > 0.01:
			_draw_seal_plate(first, acc, a * fade, focus_here)
			if focus_here and not opening:
				_draw_reticle(a)

		# 7) judul dunia versi terkunci (tanpa membuka isi dunia)
		var th: float = (1.0 - clampf(ot / 0.3, 0.0, 1.0)) if opening else clampf(ent * 2.2, 0.0, 1.0)
		var thx: float = 0.0 if opening else -34.0 * (1.0 - _back(th))
		var tal: float = a * th
		if tal > 0.01:
			UIKit.text_in(self, (("WORLD %d" % (i + 1)) if view_ch() == 0 else ("CH%d  WORLD %d" % [view_ch() + 1, i + 1])), Rect2(34.0 + thx, 14.0, 240.0, 22.0), 18, Color(acc.r, acc.g, acc.b, 0.55 * tal), HORIZONTAL_ALIGNMENT_LEFT, 4, Color(0, 0, 0, tal))
			UIKit.text_in(self, String(CampaignData.WORLDS[i]["name"]), Rect2(34.0 + thx, 34.0, 560.0, 64.0), 54, Color(0.78, 0.83, 0.95, 0.5 * tal), HORIZONTAL_ALIGNMENT_LEFT, 8, Color(0, 0, 0, tal))
			_draw_lock_label(Rect2(PW - 270.0, 30.0, 240.0, 44.0), "LOCKED", 34, 30.0, Color(1, 1, 1, 0.55 * tal), 6, Color(0, 0, 0, tal), 0.0, true, 12.0)

		# 8) tepi lingkaran cahaya yang melebar (hanya di dalam panel)
		if opening and ir > 1.0:
			var ring := PackedVector2Array()
			for q in 73:
				var ang: float = float(q) * TAU / 72.0
				ring.append(VC + Vector2(cos(ang), sin(ang)) * ir)
			var ra: float = a * (1.0 - smoothstep(0.5, 1.0, iris_p))
			if ra > 0.01:
				for seg3 in Geometry2D.intersect_polyline_with_polygon(ring, pts):
					draw_polyline(seg3, Color(acc.r, acc.g, acc.b, 0.32 * ra), 20.0, true)
					draw_polyline(seg3, Color(acc.lightened(0.5).r, acc.lightened(0.5).g, acc.lightened(0.5).b, 0.9 * ra), 7.0, true)
					draw_polyline(seg3, Color(1, 1, 1, ra), 2.5, true)

	# ------------------------------------------------------------------ rantai
	func _steel(hot: float, gc: Color, lite: float = 0.0) -> Color:
		var c: Color = Color(0.58, 0.63, 0.75).lerp(Color(0.8, 0.84, 0.94), lite)
		return c.lerp(gc.lightened(0.25), hot * 0.65)

	func _draw_link(c: Vector2, ang: float, flat: bool, a: float, col: Color) -> void:
		if a <= 0.01:
			return
		if _atlas != null:
			draw_set_transform_matrix(_cur_xf * Transform2D(ang, c))
			if flat:
				var so: Vector2 = Vector2(2.5, 3.5).rotated(-ang) - FLAT_HALF
				var ho: Vector2 = Vector2(0.0, -0.6).rotated(-ang) - FLAT_HALF
				draw_texture_rect_region(_atlas, Rect2(so, FLAT_HALF * 2.0), _at_src(0), Color(0, 0, 0, 0.42 * a))
				draw_texture_rect_region(_atlas, Rect2(-FLAT_HALF, FLAT_HALF * 2.0), _at_src(1), Color(col.r, col.g, col.b, a))
				draw_texture_rect_region(_atlas, Rect2(-FLAT_HALF, FLAT_HALF * 2.0), _at_src(2), Color(0.02, 0.03, 0.07, 0.55 * a))
				draw_texture_rect_region(_atlas, Rect2(ho, FLAT_HALF * 2.0), _at_src(3), Color(1, 1, 1, 0.38 * a))
			else:
				var so2: Vector2 = Vector2(2.5, 3.5).rotated(-ang) - FLAT_HALF
				var ho2: Vector2 = Vector2(0.0, -1.8).rotated(-ang) - FLAT_HALF
				draw_texture_rect_region(_atlas, Rect2(so2, FLAT_HALF * 2.0), _at_src(4), Color(0, 0, 0, 0.42 * a))
				draw_texture_rect_region(_atlas, Rect2(-FLAT_HALF, FLAT_HALF * 2.0), _at_src(5), Color(col.r * 0.82, col.g * 0.82, col.b * 0.82, a))
				draw_texture_rect_region(_atlas, Rect2(ho2, FLAT_HALF * 2.0), _at_src(6), Color(1, 1, 1, 0.34 * a))
			return
		if flat:
			var ring := PackedVector2Array()
			var inner := PackedVector2Array()
			for q in 17:
				var th: float = float(q) * TAU / 16.0
				ring.append(c + Vector2(cos(th) * 15.5, sin(th) * 8.5).rotated(ang))
				inner.append(c + Vector2(cos(th) * 11.0, sin(th) * 4.2).rotated(ang))
			var sh := PackedVector2Array()
			for p in ring:
				sh.append(p + Vector2(2.5, 3.5))
			draw_polyline(sh, Color(0, 0, 0, 0.42 * a), 6.0, true)
			draw_polyline(ring, Color(col.r, col.g, col.b, a), 5.5, true)
			draw_polyline(inner, Color(0.02, 0.03, 0.07, 0.55 * a), 1.6, true)
			var hi := PackedVector2Array()
			for q in range(9, 16):
				hi.append(ring[q] + Vector2(0.0, -0.6))
			draw_polyline(hi, Color(1, 1, 1, 0.38 * a), 1.8, true)
		else:
			var d: Vector2 = Vector2(1.0, 0.0).rotated(ang)
			draw_line(c - d * 10.5 + Vector2(2.5, 3.5), c + d * 10.5 + Vector2(2.5, 3.5), Color(0, 0, 0, 0.42 * a), 9.0)
			draw_line(c - d * 10.5, c + d * 10.5, Color(col.r * 0.82, col.g * 0.82, col.b * 0.82, a), 8.0)
			draw_line(c - d * 9.0 - Vector2(0.0, 1.8), c + d * 9.0 - Vector2(0.0, 1.8), Color(1, 1, 1, 0.34 * a), 2.2)

	func _draw_chain(p0: Vector2, p1: Vector2, seed_i: int, a: float, ot: float, charge: float, rt: float, hot: float, gc: Color) -> void:
		var dir: Vector2 = (p1 - p0).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var cnt: int = int(p0.distance_to(p1) / LINK)
		var ang: float = dir.angle()
		var mid: float = float(cnt) * 0.5
		for k in cnt + 1:
			var base: Vector2 = p0 + dir * (float(k) * LINK)
			var off := Vector2.ZERO
			var rot_x: float = 0.0
			var al: float = a
			if ot < 0.0:
				var wob: float = sin(t * 1.4 + float(k) * 0.7 + float(seed_i)) * (0.9 + 2.0 * charge)
				var shk: float = 5.5 * rt + 2.6 * charge
				off = nrm * (wob + sin(t * 47.0 + float(k) * 1.9) * shk) + dir * sin(t * 39.0 + float(k)) * shk * 0.5
			else:
				var te: float = ot - absf(float(k) - mid) * 0.010
				if te > 0.0:
					var side: float = -1.0 if float(k) < mid else 1.0
					off = dir * side * (60.0 + 230.0 * _rnd(k, seed_i + 5)) * te + Vector2(0.0, 560.0 * te * te) + nrm * (_rnd(k, seed_i) - 0.5) * 140.0 * te
					rot_x = side * te * (3.0 + 6.0 * _rnd(k, seed_i + 2))
					al = a * clampf(1.0 - te / 0.85, 0.0, 1.0)
				if al <= 0.01:
					continue
			_draw_link(base + off, ang + rot_x, k % 2 == 0, al, _steel(hot, gc))
		if _atlas != null:
			draw_set_transform_matrix(_cur_xf)

	func _draw_anchor(c: Vector2, a: float, hot: float) -> void:
		if a <= 0.01:
			return
		if _atlas != null:
			draw_set_transform_matrix(_cur_xf * Transform2D(0.0, c))
			var arect := Rect2(-ANCH_HALF, ANCH_HALF * 2.0)
			draw_texture_rect_region(_atlas, Rect2(arect.position + Vector2(2.5, 3.5), arect.size), _anc_src(0), Color(0, 0, 0, 0.45 * a))
			draw_texture_rect_region(_atlas, arect, _anc_src(1), Color(0.2, 0.23, 0.32, a))
			draw_texture_rect_region(_atlas, arect, _anc_src(2), Color(0.62, 0.67, 0.8, a))
			draw_texture_rect_region(_atlas, arect, _anc_src(3), Color(0.1, 0.12, 0.19, a))
			draw_texture_rect_region(_atlas, arect, _anc_src(4), Color(0.7, 0.75, 0.88, 0.8 * a))
			draw_texture_rect_region(_atlas, arect, _anc_src(5), Color(0.8, 0.84, 0.95, 0.8 * a))
			draw_set_transform_matrix(_cur_xf)
			return
		draw_circle(c + Vector2(2.5, 3.5), 15.0, Color(0, 0, 0, 0.45 * a))
		draw_circle(c, 15.0, Color(0.2, 0.23, 0.32, a))
		draw_arc(c, 14.0, 0.0, TAU, 24, Color(0.62, 0.67, 0.8, a), 2.5, true)
		draw_circle(c, 8.0, Color(0.1, 0.12, 0.19, a))
		draw_circle(c + Vector2(-1.5, -1.5), 3.0, Color(0.7, 0.75, 0.88, 0.8 * a))
		for q in 4:
			var bp: Vector2 = c + Vector2(cos(float(q) * PI * 0.5 + 0.785), sin(float(q) * PI * 0.5 + 0.785)) * 11.0
			draw_circle(bp, 1.7, Color(0.8, 0.84, 0.95, 0.8 * a))

	# ------------------------------------------------------------------ gembok besar
	func _xf_pts(pts: PackedVector2Array, pivot: Vector2, rot: float, off: Vector2) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in pts:
			out.append((p - pivot).rotated(rot) + pivot + off)
		return out

	func _body_pts() -> PackedVector2Array:
		return PackedVector2Array([Vector2(-41.0, -10.0), Vector2(41.0, -10.0), Vector2(50.0, -1.0), Vector2(50.0, 55.0), Vector2(41.0, 64.0),
			Vector2(-41.0, 64.0), Vector2(-50.0, 55.0), Vector2(-50.0, -1.0)])

	func _grad_cols(pts: PackedVector2Array, y0: float, y1: float, c0: Color, c1: Color, a: float) -> PackedColorArray:
		var cols := PackedColorArray()
		for p in pts:
			var c: Color = c0.lerp(c1, clampf((p.y - y0) / maxf(y1 - y0, 1.0), 0.0, 1.0))
			cols.append(Color(c.r, c.g, c.b, c.a * a))
		return cols

	func _shackle_pts(half: int = 0) -> PackedVector2Array:
		# half: 0 = utuh, -1 = separuh kiri, 1 = separuh kanan (relatif terhadap pusat gembok, y negatif = ke atas)
		var out := PackedVector2Array()
		if half <= 0:
			out.append(Vector2(-31.0, 2.0))
			out.append(Vector2(-31.0, -12.0))
		var a0: int = 0
		var a1: int = 24
		if half < 0:
			a1 = 12
		elif half > 0:
			a0 = 12
		for q in range(a0, a1 + 1):
			var th: float = PI + float(q) * PI / 24.0
			out.append(Vector2(0.0, -12.0) + Vector2(cos(th), sin(th)) * 31.0)
		if half >= 0:
			out.append(Vector2(31.0, -12.0))
			out.append(Vector2(31.0, 2.0))
		return out

	func _draw_shackle(c: Vector2, half: int, rot: float, off: Vector2, a: float, hot: float, gc: Color, gold: float) -> void:
		var base: PackedVector2Array = _shackle_pts(half)
		var pv := Vector2(0.0, -12.0)
		var pp := PackedVector2Array()
		var sh := PackedVector2Array()
		for p in _xf_pts(base, pv, rot, off):
			pp.append(c + p)
			sh.append(c + p + Vector2(3.0, 5.0))
		if pp.size() < 2:
			return
		var col: Color = _steel(hot, gc, 0.05).lerp(Color(1.0, 0.9, 0.55), gold * 0.35)
		draw_polyline(sh, Color(0, 0, 0, 0.4 * a), 15.0, true)
		draw_polyline(pp, Color(0.05, 0.06, 0.1, a), 14.5, true)
		draw_polyline(pp, Color(col.r * 0.72, col.g * 0.72, col.b * 0.72, a), 11.5, true)
		draw_polyline(pp, Color(col.r, col.g, col.b, a), 8.0, true)
		var hi := PackedVector2Array()
		for q in pp.size():
			if pp[q].y <= c.y - 8.0:
				hi.append(pp[q] + Vector2(-1.5, -1.5))
		if hi.size() >= 2:
			draw_polyline(hi, Color(1, 1, 1, 0.45 * a), 2.2, true)

	func _draw_body(c: Vector2, pts: PackedVector2Array, a: float, hot: float, gold: float, gc: Color, keyhole: bool, glow: float) -> void:
		var top: Color = Color(0.72, 0.77, 0.88).lerp(Color(1.0, 0.82, 0.62), hot * 0.55).lerp(Color(1.0, 0.92, 0.62), gold * 0.3)
		var bot: Color = Color(0.24, 0.27, 0.37).lerp(Color(0.55, 0.2, 0.14), hot * 0.5)
		var wp := PackedVector2Array()
		for p in pts:
			wp.append(c + p)
		draw_polygon(wp, _grad_cols(wp, c.y - 10.0, c.y + 64.0, top, bot, a))
		draw_polyline(UIKit.closed(wp), Color(0.04, 0.05, 0.09, a), 3.5, true)
		draw_line(c + Vector2(-40.0, -8.5), c + Vector2(40.0, -8.5), Color(1, 1, 1, 0.45 * a), 2.0)
		if keyhole:
			# pelat tengah yang lebih gelap + paku keling
			var inset := PackedVector2Array([Vector2(-40.0, -1.0), Vector2(40.0, -1.0), Vector2(40.0, 55.0), Vector2(-40.0, 55.0)])
			var ip := PackedVector2Array()
			for p in inset:
				ip.append(c + p)
			draw_polygon(ip, _grad_cols(ip, c.y - 1.0, c.y + 55.0, Color(0.15, 0.17, 0.26), Color(0.07, 0.08, 0.14), a))
			draw_polyline(UIKit.closed(ip), Color(1, 1, 1, 0.16 * a), 1.5, true)
			for rv in [Vector2(-34.0, 5.0), Vector2(34.0, 5.0), Vector2(-34.0, 49.0), Vector2(34.0, 49.0)]:
				draw_circle(c + rv, 3.2, Color(0.74, 0.79, 0.9, a))
				draw_circle(c + rv + Vector2(-0.8, -0.8), 1.2, Color(1, 1, 1, 0.8 * a))
			# lubang kunci yang menyala
			var kc: Vector2 = c + Vector2(0.0, 21.0)
			draw_circle(kc, 15.0 + 4.0 * glow, Color(gc.r, gc.g, gc.b, (0.12 + 0.3 * glow) * a))
			draw_circle(kc, 9.5, Color(0.03, 0.03, 0.06, a))
			draw_colored_polygon(PackedVector2Array([kc + Vector2(-4.2, 3.0), kc + Vector2(4.2, 3.0), kc + Vector2(6.8, 25.0), kc + Vector2(-6.8, 25.0)]), Color(0.03, 0.03, 0.06, a))
			draw_circle(kc, 4.2 + 1.5 * glow, Color(gc.r, gc.g, gc.b, (0.35 + 0.6 * glow) * a))

	func _draw_lock_intact(c: Vector2, a: float, charge: float, rt: float, focus_here: bool, gc: Color) -> void:
		var hot: float = clampf(charge + rt * 0.6, 0.0, 1.0)
		var gold: float = 1.0 if focus_here else 0.0
		var bp: PackedVector2Array = _body_pts()
		var shadow := PackedVector2Array()
		for p in bp:
			shadow.append(c + p + Vector2(5.0, 9.0))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.4 * a))
		_draw_shackle(c, 0, 0.0, Vector2.ZERO, a, hot, gc, gold)
		_draw_body(c, bp, a, hot, gold, gc, true, hot + (0.35 if focus_here else 0.0) + 0.12 * sin(t * 3.0))
		# retakan bercahaya saat segel hampir pecah
		if charge > 0.35:
			var ck: float = clampf((charge - 0.35) / 0.65, 0.0, 1.0)
			var crack := PackedVector2Array([Vector2(0.0, -10.0), Vector2(5.0, 6.0), Vector2(-4.0, 18.0), Vector2(6.0, 32.0), Vector2(-3.0, 46.0), Vector2(2.0, 64.0)])
			var cp := PackedVector2Array()
			var cn: int = maxi(2, int(float(crack.size()) * ck) + 1)
			for q in mini(cn, crack.size()):
				cp.append(c + crack[q])
			if cp.size() >= 2:
				draw_polyline(cp, Color(gc.r, gc.g, gc.b, 0.4 * a), 8.0, true)
				draw_polyline(cp, Color(1.0, 0.92, 0.7, a), 2.5, true)

	func _draw_lock_broken(c: Vector2, a: float, acc: Color, te: float, first: int) -> void:
		var gc: Color = Color(1.0, 0.5, 0.32).lerp(acc.lightened(0.35), 0.3)
		# kilatan putih saat pecah
		var fl: float = clampf(1.0 - te / 0.34, 0.0, 1.0)
		if fl > 0.0:
			draw_circle(c + Vector2(0.0, 20.0), 60.0 + 150.0 * (1.0 - fl), Color(acc.r, acc.g, acc.b, 0.35 * fl * a))
			draw_circle(c + Vector2(0.0, 20.0), 40.0 + 90.0 * (1.0 - fl), Color(1, 1, 1, 0.85 * fl * a))
		# dua separuh badan gembok jatuh berputar
		var al: float = a * clampf(1.0 - (te - 0.12) / 0.8, 0.0, 1.0)
		if al > 0.01:
			var left := PackedVector2Array([Vector2(-41.0, -10.0), Vector2(0.0, -10.0), Vector2(5.0, 6.0), Vector2(-4.0, 18.0), Vector2(6.0, 32.0), Vector2(-3.0, 46.0), Vector2(2.0, 64.0), Vector2(-41.0, 64.0), Vector2(-50.0, 55.0), Vector2(-50.0, -1.0)])
			var right := PackedVector2Array([Vector2(0.0, -10.0), Vector2(41.0, -10.0), Vector2(50.0, -1.0), Vector2(50.0, 55.0), Vector2(41.0, 64.0), Vector2(2.0, 64.0), Vector2(-3.0, 46.0), Vector2(6.0, 32.0), Vector2(-4.0, 18.0), Vector2(5.0, 6.0)])
			var pv := Vector2(0.0, 27.0)
			var offl := Vector2(-70.0 * te - 60.0 * te * te, 420.0 * te * te - 30.0 * te)
			var offr := Vector2(70.0 * te + 60.0 * te * te, 460.0 * te * te - 20.0 * te)
			for half in 2:
				var src: PackedVector2Array = left if half == 0 else right
				var xp: PackedVector2Array = _xf_pts(src, pv, (-1.6 if half == 0 else 1.4) * te, offl if half == 0 else offr)
				var wp := PackedVector2Array()
				for p in xp:
					wp.append(c + p)
				if _tri_ok(wp):
					draw_polygon(wp, _grad_cols(wp, c.y - 10.0 + 400.0 * te * te, c.y + 64.0 + 400.0 * te * te, Color(0.72, 0.77, 0.88), Color(0.24, 0.27, 0.37), al))
					draw_polyline(UIKit.closed(wp), Color(0.04, 0.05, 0.09, al), 3.0, true)
		# dua separuh gagang meloncat ke atas
		var al2: float = a * clampf(1.0 - (te - 0.1) / 0.85, 0.0, 1.0)
		if al2 > 0.01:
			_draw_shackle(c, -1, -2.2 * te, Vector2(-120.0 * te, -210.0 * te + 640.0 * te * te), al2, 0.4, gc, 0.0)
			_draw_shackle(c, 1, 2.0 * te, Vector2(120.0 * te, -240.0 * te + 640.0 * te * te), al2, 0.4, gc, 0.0)
		# pecahan logam
		var fx: Dictionary = vault_fx.get(first, {})
		var lf: float = clampf(1.0 - te / 1.1, 0.0, 1.0)
		if lf > 0.0 and fx.has("shards"):
			for sd in fx["shards"]:
				var dir := Vector2(cos(float(sd["a"])), sin(float(sd["a"])))
				var p: Vector2 = c + Vector2(0.0, 20.0) + dir * float(sd["s"]) * (1.0 - pow(1.0 - clampf(te / 1.1, 0.0, 1.0), 2.0)) + Vector2(0.0, 380.0 * te * te)
				var z: float = float(sd["z"]) * (0.5 + 0.5 * lf)
				var kk: int = int(sd["k"])
				var scol: Color = Color(0.7, 0.75, 0.88) if kk == 0 else (Color(0.3, 0.33, 0.44) if kk == 1 else gc.lightened(0.3))
				var tri := PackedVector2Array([Vector2(0.0, -z), Vector2(z * 0.8, z * 0.7), Vector2(-z * 0.8, z * 0.7)])
				var op := PackedVector2Array()
				for tp in tri:
					op.append(p + tp.rotated(float(sd["r"]) + float(sd["rv"]) * te))
				draw_colored_polygon(op, Color(scol.r, scol.g, scol.b, lf * a))

	func _draw_vault_lock(first: int, a: float, acc: Color, ot: float, charge: float, rt: float, focus_here: bool, gc: Color, ctr: Vector2 = VC) -> void:
		if ot >= 0.0:
			_draw_lock_broken(ctr, a, acc, ot, first)
			return
		var amp: float = 2.4 * charge + 6.0 * rt
		var jig := Vector2.ZERO
		if amp > 0.0:
			jig = Vector2(sin(t * 61.0), cos(t * 53.0)) * amp
		_draw_lock_intact(ctr + jig + Vector2(0.0, sin(t * 1.6) * 2.0), a, charge, rt, focus_here, gc)

	# ------------------------------------------------------------------ pelat syarat & kursor
	func _draw_seal_plate(first: int, acc: Color, a: float, focus_here: bool) -> void:
		var info: Dictionary = hub.seal_info(first)
		var nm: String = String(info["name"])
		if int(info["ch"]) != view_ch():
			nm += "  (CH%d)" % (int(info["ch"]) + 1)
		var fs: int = 19
		var t1: String = "COMPLETE "
		var t3: String = " TO UNLOCK"
		var w1: float = UIKit.text_w(t1, fs)
		var w2: float = UIKit.text_w(nm, fs)
		var w3: float = UIKit.text_w(t3, fs)
		var pw: float = maxf(w1 + w2 + w3 + 78.0, 380.0)
		var pr := Rect2((PW - pw) * 0.5, 266.0, pw, 50.0)
		var edge: Color = Color(0.56, 0.62, 0.78, 0.8)
		if focus_here:
			edge = Color(1.0, 0.86, 0.36, 0.7 + 0.3 * sin(t * 6.0))
		draw_colored_polygon(UIKit.slanted(pr.size.x, pr.size.y, 12.0, pr.position.x + 3.0, pr.position.y + 4.0), Color(0, 0, 0, 0.5 * a))
		var ppts: PackedVector2Array = UIKit.slanted(pr.size.x, pr.size.y, 12.0, pr.position.x, pr.position.y)
		draw_colored_polygon(ppts, Color(0.025, 0.03, 0.07, 0.93 * a))
		draw_polyline(UIKit.closed(ppts), Color(edge.r, edge.g, edge.b, edge.a * a), 2.0, true)
		draw_rect(Rect2(pr.position.x + 18.0, pr.position.y + 6.0, 4.0, pr.size.y - 12.0), Color(acc.r, acc.g, acc.b, 0.9 * a))
		var tx: float = pr.position.x + 34.0 + (pr.size.x - 78.0 - (w1 + w2 + w3)) * 0.5
		var ty: float = pr.position.y + 4.0
		UIKit.text_in(self, t1, Rect2(tx, ty, w1 + 6.0, 24.0), fs, Color(1, 1, 1, 0.62 * a), HORIZONTAL_ALIGNMENT_LEFT, 3, Color(0, 0, 0, a))
		UIKit.text_in(self, nm, Rect2(tx + w1, ty, w2 + 6.0, 24.0), fs, Color(acc.lightened(0.35).r, acc.lightened(0.35).g, acc.lightened(0.35).b, a), HORIZONTAL_ALIGNMENT_LEFT, 3, Color(0, 0, 0, a))
		UIKit.text_in(self, t3, Rect2(tx + w1 + w2, ty, w3 + 6.0, 24.0), fs, Color(1, 1, 1, 0.62 * a), HORIZONTAL_ALIGNMENT_LEFT, 3, Color(0, 0, 0, a))
		# kemajuan dunia sebelumnya: 5 segmen + "n / 5"
		var done: int = int(info["done"])
		var cap: String = "%d / 5" % done
		var cw: float = UIKit.text_w(cap, 16)
		var gw: float = 5.0 * 30.0 + 4.0 * 6.0 + 12.0 + cw
		var gx: float = pr.position.x + 34.0 + (pr.size.x - 78.0 - gw) * 0.5
		var gy: float = pr.position.y + 33.0
		for k in 5:
			var seg := Rect2(gx + float(k) * 36.0, gy, 30.0, 8.0)
			var sc: Color = Color(1, 1, 1, 0.16)
			if k < done:
				sc = Color(0.29, 0.89, 0.63, 1.0)
			elif k == done and bool(info["active"]):
				sc = Color(acc.r, acc.g, acc.b, 0.5 + 0.5 * sin(t * 5.0))
			draw_rect(Rect2(seg.position + Vector2(1.5, 2.0), seg.size), Color(0, 0, 0, 0.5 * a))
			draw_rect(seg, Color(sc.r, sc.g, sc.b, sc.a * a))
		UIKit.text_in(self, cap, Rect2(gx + 5.0 * 36.0 + 6.0, gy - 8.0, cw + 8.0, 24.0), 16, Color(1, 1, 1, 0.78 * a), HORIZONTAL_ALIGNMENT_LEFT, 3, Color(0, 0, 0, a))

	## Kurung sudut emas berdenyut di sekeliling gembok saat kursor (keyboard / controller / mouse) ada di dunia terkunci ini.
	func _draw_reticle(a: float, ctr: Vector2 = VC) -> void:
		var pl: float = 0.5 + 0.5 * sin(t * 6.0)
		var r := Rect2(ctr.x - 84.0 - 4.0 * pl, ctr.y - 74.0 - 4.0 * pl, 168.0 + 8.0 * pl, 148.0 + 8.0 * pl)
		var col: Color = Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, (0.75 + 0.25 * pl) * a)
		var ln: float = 26.0
		for sx in [0, 1]:
			for sy in [0, 1]:
				var cx: float = r.position.x if sx == 0 else r.end.x
				var cy: float = r.position.y if sy == 0 else r.end.y
				var dx: float = ln if sx == 0 else -ln
				var dy: float = ln if sy == 0 else -ln
				draw_polyline(PackedVector2Array([Vector2(cx, cy + dy), Vector2(cx, cy), Vector2(cx + dx, cy)]), Color(0, 0, 0, 0.5 * a), 8.0, true)
				draw_polyline(PackedVector2Array([Vector2(cx, cy + dy), Vector2(cx, cy), Vector2(cx + dx, cy)]), col, 4.0, true)

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

	## Baris "gembok + teks" yang selalu simetris dan tidak pernah bertabrakan: lebar gembok, jarak, dan teks
	## dihitung sebagai SATU grup lalu dipusatkan (atau rata kanan) di dalam `rect`. Font mengecil otomatis
	## kalau grup lebih lebar dari `max_w` (0 = tanpa batas). Mengembalikan lebar grup yang tergambar.
	func _draw_lock_label(rect: Rect2, text: String, fs: int, lock_s: float, col: Color, outline: int, outline_col: Color, max_w: float = 0.0, right_align: bool = false, gap: float = 8.0) -> float:
		var lock_w: float = lock_s * 0.72
		var size_fs: int = fs
		var tw: float = UIKit.text_w(text, size_fs)
		while max_w > 0.0 and size_fs > 9 and lock_w + gap + tw > max_w:
			size_fs -= 1
			tw = UIKit.text_w(text, size_fs)
		var gw: float = lock_w + gap + tw
		var x0: float = rect.end.x - gw if right_align else rect.position.x + (rect.size.x - gw) * 0.5
		var cy: float = rect.position.y + rect.size.y * 0.5
		# gembok digambar dengan pusat bentuk (bukan pusat kotak) tepat di tengah garis teks
		UIKit.draw_lock(self, Vector2(x0 + lock_w * 0.5, cy + lock_s * 0.13), lock_s, col)
		UIKit.text_in(self, text, Rect2(x0 + lock_w + gap, rect.position.y, tw + 8.0, rect.size.y), size_fs, col, HORIZONTAL_ALIGNMENT_LEFT, outline, outline_col)
		return gw

	func _draw_tabs() -> void:
		if chap_sealed():
			_draw_tabs_sealed()
			return
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
			var locked: bool = int(wd["levels"][0]) + coff() > unlocked or held.has(int(wd["levels"][0]) + coff())
			var tc: Color = Color(0.04, 0.04, 0.1).lerp(Color(1, 1, 1, 0.78), 1.0 - an)
			if locked:
				# gembok + nama dipusatkan sebagai satu grup di area aman tab (di luar sisi miring), font mengecil otomatis
				_draw_lock_label(Rect2(r.position.x + 14.0, r.position.y, r.size.x - 28.0, r.size.y), String(wd["name"]), tab_fs[j], 14.0, Color(1, 1, 1, 0.4), 0, Color.BLACK, r.size.x - 28.0, false, 7.0)
			else:
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
	var _chip_meshes: Dictionary = {}   # ukuran chip -> mesh garis serong (di-cache, dulu dipotong ulang tiap frame)

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
				# garis serong warna chapter di dalam chip + gembok bercahaya warna chapter
				var skey := Vector2(snappedf(r.size.x, 0.01), snappedf(r.size.y, 0.01))
				var smesh: Variant = _chip_meshes.get(skey)
				if smesh == null and not _chip_meshes.has(skey):
					var chip_poly := PackedVector2Array([Vector2.ZERO, Vector2(r.size.x, 0.0), r.size, Vector2(0.0, r.size.y)])
					var pieces: Array = []
					for sk in range(-1, 5):
						var sx0: float = float(sk) * 9.0
						var stripe := PackedVector2Array([Vector2(sx0, r.size.y), Vector2(sx0 + 4.5, r.size.y), Vector2(sx0 + 4.5 + r.size.y, 0.0), Vector2(sx0 + r.size.y, 0.0)])
						for piece in Geometry2D.intersect_polygons(stripe, chip_poly):
							pieces.append(piece)
					var cv := PackedVector2Array()
					for pc in pieces:
						var pp: PackedVector2Array = pc
						for ii in Geometry2D.triangulate_polygon(pp):
							cv.append(pp[ii])
					if not cv.is_empty():
						var arr: Array = []
						arr.resize(Mesh.ARRAY_MAX)
						arr[Mesh.ARRAY_VERTEX] = cv
						var am := ArrayMesh.new()
						am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
						smesh = am
					_chip_meshes[skey] = smesh
				if smesh != null:
					draw_mesh(smesh, null, Transform2D(0.0, r.position), Color(ca.r, ca.g, ca.b, 0.30 if hv_c else 0.20))
				var lkc: Color = ca.lightened(0.4)
				_draw_lock(cc + Vector2(0, 0.5), Color(lkc.r, lkc.g, lkc.b, 0.95 if hv_c else 0.72))
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
		# tampilan SAMA dengan yang dipakai di dalam level: skin karakter + aksesoris terpasang (P1) + skin senjata
		var skin: String = String(fighter.get("skin", Cosmetics.last_cskin(ch)))
		if not Cosmetics.owns_skin(ch, skin):
			skin = ""
		var lo: Dictionary = Cosmetics.loadout(ch, skin, 0)
		var ctex: Texture2D = Cosmetics.char_tex(ch, skin)
		# aksesoris menjulur keluar kotak karakter: kalau ada, karakter dikecilkan sedikit supaya semuanya muat di potret
		var cr: Rect2 = _fit(ctex, pr.grow(-14.0 if not lo.is_empty() else -8.0))
		cr.position.y += sin(t * 2.6) * 2.5
		if ctex != null:
			Cosmetics.draw_preview(self, ch, skin, lo, cr)
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
		var wsk: String = String(fighter.get("wskin", ""))
		if not Cosmetics.owns_wskin(wid, wsk):
			wsk = ""
		var gtex: Texture2D = Cosmetics.weapon_tex(wid, wsk)
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
		if f == -5:
			var gl: int = int(hub.gate_level)
			if hub.chapter_locked(CampaignData.chapter_of(gl)):
				s = "CHAPTER %d  -  SEALED      COMPLETE CHAPTER %d TO UNLOCK" % [CampaignData.chapter_of(gl) + 1, CampaignData.chapter_of(gl)]
			else:
				var gi: Dictionary = hub.seal_info(gl)
				s = "%s  -  SEALED      COMPLETE %s TO UNLOCK" % [String(CampaignData.WORLDS[CampaignData.world_of(gl)]["name"]), String(gi["name"])]
		elif f >= 1 and hub.pager != null and hub.pager.sealed(CampaignData.world_of(f)):
			s = "%s  -  SEALED" % String(CampaignData.WORLDS[CampaignData.world_of(f)]["name"])
		elif f >= 1:
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
			else:
				var amp_m: float = 5.0 * pow(clampf(1.0 - tt / 0.4, 0.0, 1.0), 2.0)     # hentakan singkat saat segel pecah
				shake += Vector2(sin(tt * 83.0), cos(tt * 67.0)) * amp_m
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
		var c: Vector2 = pager.vault_screen(w)            # pusat gembok dunia yang baru terbuka
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
		# 3) inti cahaya dari gembok yang pecah + sinar berputar (dipotong di dalam panel dunia saja)
		var gl: float = clampf(1.0 - t / 0.55, 0.0, 1.0)
		if gl > 0.0:
			draw_circle(c, 46.0 + 120.0 * (1.0 - gl), Color(1, 1, 1, 0.55 * gl))
			draw_circle(c, 90.0 + 140.0 * (1.0 - gl), Color(acc.r, acc.g, acc.b, 0.22 * gl))
		var ru: float = clampf(t / 0.5, 0.0, 1.0)
		var rf: float = ru * (1.0 - clampf((t - 0.9) / 1.0, 0.0, 1.0))
		if rf > 0.0:
			var ln: float = 520.0 * _eo(ru)
			for q in 12:
				var a0: float = t * 0.45 + float(q) * TAU / 12.0
				var hw: float = 0.09
				var ray := PackedVector2Array([c, c + Vector2(cos(a0 - hw), sin(a0 - hw)) * ln, c + Vector2(cos(a0 + hw), sin(a0 + hw)) * ln])
				var rc: Color = acc.lightened(0.55) if q % 2 == 0 else GOLD
				for piece3 in Geometry2D.intersect_polygons(ray, poly):
					if piece3.size() >= 3:
						draw_colored_polygon(piece3, Color(rc.r, rc.g, rc.b, 0.24 * rf))
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
			var rp := UIKit.slanted(372.0, 30.0, 12.0, 34.0 + rx, 102.0)
			draw_colored_polygon(UIKit.slanted(372.0, 30.0, 12.0, 38.0 + rx, 106.0), Color(0, 0, 0, 0.45 * ra))
			draw_colored_polygon(rp, Color(0.03, 0.04, 0.10, 0.94 * ra).lerp(acc.darkened(0.3), 0.35))
			draw_polyline(UIKit.closed(rp), Color(acc.lightened(0.4), ra), 2.5, true)
			draw_rect(Rect2(34.0 + rx + 4.0, 102.0, 8.0, 30.0), Color(acc.r, acc.g, acc.b, ra))
			draw_colored_polygon(CampaignData.star_points(Vector2(34.0 + rx + 34.0, 117.0), 10.0, t * 2.2), Color(GOLD.r, GOLD.g, GOLD.b, ra))
			UIKit.text_in(self, "NEW WORLD UNLOCKED", Rect2(34.0 + rx + 52.0, 102.0, 300.0, 30.0), 20, Color(1, 1, 1, ra), HORIZONTAL_ALIGNMENT_LEFT, 4, Color(0, 0, 0, ra))
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
		var c: Vector2 = pager.gate_screen()     # pusat gembok gerbang chapter yang baru terbuka
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
	# Muat suara UI di thread latar supaya suara pertama (mis. ui_whoosh saat pindah chapter) tidak memuat file dari disk di tengah permainan.
	for sfx_n in ["ui_whoosh", "ui_error", "ui_hover", "click", "ui_back", "ui_start", "star", "ui_allready", "perk_open", "shield_break", "wall_impact"]:
		for ext in ["mp3", "wav", "ogg"]:
			var sp: String = "res://assets/sfx/%s.%s" % [sfx_n, ext]
			if ResourceLoader.exists(sp):
				ResourceLoader.load_threaded_request(sp)
				break
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
			fighter = (Global.selections[0] as Dictionary).duplicate()
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
	pager.vault_opened.connect(_on_vault_opened)
	pager.sealed_clicked.connect(_vault_denied)
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
			dur = 1.7          # lama gembok "mengisi daya" (bergetar, rantai menegang) sebelum segel dunia pecah
		elif kind == "chapter":
			dur = 2.0
		pager.walk_to(n, dur, kind == "")
		if kind != "":
			_vault_charge_sfx(dur)
		elif n == b:
			Global.play_sfx("ui_whoosh", -10.0, 0.75)
		var hold: float = 0.05
		if kind == "map":
			hold = 0.4 if n == b else 2.4          # beri waktu segel pecah & dunia tersingkap sebelum lanjut berjalan ke level berikutnya
		elif kind == "chapter":
			hold = 0.4 if n == b else 3.4
		await get_tree().create_timer(dur + hold).timeout
		if leaving or not is_inside_tree():
			return
	if not leaving:
		_set_focus(tgt, false)



## Suara "mengisi daya" sebelum segel dunia pecah: dengung rendah + dentang rantai yang makin cepat & tinggi.
func _vault_charge_sfx(dur: float) -> void:
	Global.play_sfx("ui_whoosh", -8.0, 0.5)
	var t0: int = Time.get_ticks_msec()
	while true:
		var el: float = float(Time.get_ticks_msec() - t0) / 1000.0
		if el >= dur or leaving or not is_inside_tree():
			return
		var u: float = el / dur
		Global.play_sfx("click", -10.0 + 5.0 * u, 0.5 + 0.7 * u)
		await get_tree().create_timer(lerpf(0.22, 0.05, u)).timeout


## Segel dunia pecah (dikirim WorldPager tepat saat lingkaran pembuka mulai): perayaan MAP baru atau CHAPTER baru + suara.
func _on_vault_opened(n: int) -> void:
	if leaving or fx_layer == null:
		return
	var new_chapter: bool = n > 1 and CampaignData.chapter_of(n) != CampaignData.chapter_of(n - 1)
	Global.play_sfx("shield_break", -2.0, 0.7)
	Global.play_sfx("wall_impact", -3.0, 0.65)
	if new_chapter:
		fx_layer.play_chapter(n)
		if chapter_nav != null:
			chapter_nav.celebrate(CampaignData.chapter_of(n))
		Global.play_sfx("match_fanfare", -3.0)
		Global.play_sfx("ui_allready", -6.0, 0.9)
	else:
		fx_layer.play_map(n)
		Global.play_sfx("perk_open", -4.0, 1.1)
		Global.play_sfx("star", -6.0, 1.25)
		Global.play_synth("shimmer", -6.0)
	if CampaignData.world_of(n) == _world and CampaignData.chapter_of(n) == chapter:
		_set_world_bg(n, 0.9)       # latar layar ikut berubah dari gelap menjadi warna dunia


func _set_world_bg(level: int, dur: float = 0.45) -> void:
	var w: int = CampaignData.world_of(level)
	var id: String = String(CampaignData.WORLDS[w]["id"])
	var pal: Array = Global.MAP_PALETTES[id]
	if world_sealed_visual(level):
		# dunia terkunci: latar layar juga gelap & polos, tidak membocorkan gambar / warna dunia
		bg.set_palette(Color("06070e"), Color("10142a"), Color(pal[2]).lerp(Color("5a6482"), 0.7), dur)
		bg.set_image(null, 0.0, dur)
		return
	bg.set_palette(pal[0], pal[1], pal[2], dur)
	bg.set_image(Global.map_background(id), 0.78, dur)


# ------------------------------------------------------------------ navigasi
func _set_focus(f: int, sound: bool = true) -> void:
	if leaving:
		return
	var old: int = focus
	var old_gate: int = gate_level
	var lvl: int = f                     # level yang menentukan dunia / chapter yang tampil
	if f >= 1 and world_locked(f):
		# dunia terkunci: kursor TIDAK masuk ke levelnya, hanya berhenti di gembok dunia itu
		lvl = CampaignData.checkpoint_of(f)
		if chapter_locked(CampaignData.chapter_of(f)):
			lvl = CampaignData.chapter_first(CampaignData.chapter_of(f))     # chapter terkunci: satu gerbang untuk seluruh chapter
		gate_level = lvl
		f = GATE
	focus = f
	btn_continue.set_selected(f == -2)
	if fighter_card != null:
		fighter_card.selected = (f == -4)
	if chapter_nav != null:
		chapter_nav.selected = (f == -3)
	if lvl >= 1:
		if f >= 1:
			last_tile = f
		var w: int = CampaignData.world_of(lvl)
		var c: int = CampaignData.chapter_of(lvl)
		var track: bool = f != GATE          # dunia terkunci yang hanya diintip tidak diingat untuk animasi geser berikutnya
		if c != chapter:
			var old_ch: int = chapter
			chapter = c
			_world = w
			if track:
				_prev_world = w
			pager.swap_chapter(w, old_ch, 1 if c > old_ch else -1)   # transisi mulus: peta lama keluar, peta baru masuk
			_set_world_bg(lvl, 0.7)
		elif w != _world:
			_world = w
			if track:
				_prev_world = w
			pager.target = w          # panel dunia meluncur ke tab yang baru
			_set_world_bg(lvl)
	if sound and (f != old or (f == GATE and gate_level != old_gate)):
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
	if chapter_locked(chapter):
		return          # chapter terkunci: tidak ada dunia yang bisa dibuka satu per satu
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
	if focus == GATE:
		# dunia terkunci: kiri / kanan = pindah dunia, atas = tombol lanjut, bawah = (tidak ada apa-apa di dalam segel)
		if dx != 0:
			var gn: int = gate_level + 5 if dx > 0 else gate_level - 1
			if chapter_locked(CampaignData.chapter_of(gate_level)):
				gn = CampaignData.chapter_last(CampaignData.chapter_of(gate_level)) + 1 if dx > 0 else gate_level - 1     # gerbang chapter: lompat antar chapter
			if gn < 1 or gn > CampaignData.TOTAL_LEVELS:
				pager.nudge(dx)
				Global.play_sfx("ui_error", -14.0)
				return
			Global.play_sfx("ui_whoosh", -12.0, 1.2)
			_set_focus(gn)
		elif dy < 0:
			_set_focus(-2)
		elif dy > 0:
			_vault_denied(CampaignData.world_of(gate_level))
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


## Loncat langsung ke chapter c (klik chip nomor di pelat chapter).
func _goto_chapter(c: int) -> void:
	if leaving or c == chapter:
		return
	_change_chapter(c - chapter)


func _step_world(dir: int) -> void:
	var nw: int = _world + dir
	if chapter_locked(chapter) or nw < 0 or nw >= CampaignData.WORLDS.size():
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
	elif focus == GATE:
		_vault_denied(CampaignData.world_of(gate_level))
	else:
		_on_tile_clicked(focus)


# ------------------------------------------------------------------ aksi
## Dunia terkunci ditekan / diklik: gembok & rantai bergetar, bunyi logam, dan pemberitahuan syarat membukanya.
func _vault_denied(w: int) -> void:
	if leaving or pager == null:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_lock_msg < 400:
		return          # klik/tombol yang sama terbaca dua kali (accept + fire): cukup satu notifikasi
	_last_lock_msg = now
	pager.rattle_world(w)
	Global.play_sfx("ui_error", -6.0)
	_clank_sfx(3, 0.07)
	if chapter_locked(chapter):
		var ci: Dictionary = chapter_info(chapter)
		UIInput.toast("CHAPTER LOCKED", "Complete CHAPTER %d first  (%d / 50)" % [int(ci["pch"]) + 1, int(ci["done"])], Color("ff7a7a"))
		return
	var info: Dictionary = seal_info(pager.first_of(w))
	var nm: String = String(info["name"])
	UIInput.toast("WORLD LOCKED", "Complete %s first  (%d / 5)" % [nm, int(info["done"])], Color("ff7a7a"))


## Beberapa dentang logam berurutan (rantai berderak). Memakai suara yang sudah ada, tanpa file audio baru.
func _clank_sfx(count: int, gap: float, vol: float = -9.0, pitch: float = 0.55) -> void:
	for k in count:
		Global.play_sfx("click", vol, pitch + 0.09 * float(k))
		await get_tree().create_timer(gap).timeout
		if leaving or not is_inside_tree():
			return


func _on_tile_clicked(n: int) -> void:
	if leaving:
		return
	if world_locked(n):
		_vault_denied(CampaignData.world_of(n))
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
