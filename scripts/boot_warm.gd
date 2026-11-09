class_name BootWarm
extends RefCounted
## ======================================================================================
##  PEMANASAN CAMPAIGN (dipakai oleh loading screen: scripts/loading.gd)
## ======================================================================================
## Tujuan: semua pekerjaan "pertama kali" milik CAMPAIGN dibayar di LOADING SCREEN, bukan saat pemain masuk campaign
## atau saat level pertama dimulai. Penyebab lag pertama kali yang masih tersisa sebelum file ini ada:
##   1) HURUF   font game bersifat dinamis (FreeType): tiap kombinasi (ukuran, kontur) dirender per huruf saat pertama
##              digambar. Pemanasan lama hanya mencakup Menu / Shop / About. Peta CAMPAIGN, layar pilih fighter, HUD level,
##              banner "LEVEL 1" dan layar "YOU DIED" memakai puluhan kombinasi lain -> FontWarm di bawah.
##   2) SHADER  DEFEAT_SHADER (membaca layar, dipakai saat hero kalah) dan shader skin / scarf / finisher baru dikompilasi saat
##              pertama dipakai; begitu juga mesh, multiline, Line2D, Polygon2D, StyleBoxFlat -> PrimWarm di bawah.
##   3) PETA    scene peta CAMPAIGN dijalankan SEKALI di luar layar (SubViewport tersembunyi) sehingga seluruh isinya
##              sempat digambar & dikompilasi -> warm_hub().
## Semua dikerjakan bertahap (ada batas waktu per frame) supaya animasi loading tetap mulus.

# karakter yang dipanaskan (sama dengan CosmeticUI.GlyphWarm + sedikit tanda baca tambahan)
const CH_UP := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -/,.!%+:'&?()"
const CH_LOW := "abcdefghijklmnopqrstuvwxyz"
const CH_BANNER := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 !/-"   # banner "LEVEL 1", "WAVE 2 / 5", nama boss, "WARNING!"
const CH_TITLE := "YOUDIEGAMVRCPNLT!"                            # "YOU DIED", "GAME OVER", "CAMPAIGN COMPLETE!"

const BANNER_SIZES := [110, 96, 90, 84, 80]                       # ukuran banner level (kontur 18)
const TITLE_SIZE := 132                                           # judul layar kalah (kontur 34 / 16 / 0)


# ------------------------------------------------------------------ daftar huruf
static func _add(out: Array, seen: Dictionary, s: int, o: int) -> void:
	var k: int = s * 100 + o
	if seen.has(k):
		return
	seen[k] = true
	out.append([s, o])


## Semua kombinasi [ukuran, kontur] yang dipakai peta CAMPAIGN, layar pilih fighter, HUD level, tombol & banner.
static func combos() -> Array:
	var out: Array = []
	var seen := {}
	# ---- peta CAMPAIGN (campaign_hub.gd)
	for c in [[13, 3], [14, 0], [14, 3], [15, 0], [15, 5], [16, 0], [16, 3], [16, 4], [16, 5], [17, 3], [18, 4], [20, 4],
			[22, 5], [24, 5], [24, 6], [26, 5], [28, 6], [30, 5], [30, 6], [32, 6], [36, 7], [44, 7], [52, 7], [54, 8],
			[58, 8], [82, 10]]:
		_add(out, seen, int(c[0]), int(c[1]))
	for fs in range(10, 17):                    # nama level, tab dunia, label gembok (mengecil otomatis 16 -> 10)
		for o in [0, 3, 4]:
			_add(out, seen, fs, o)
	for fs in range(16, 31, 2):                 # nama fighter di kartu (mengecil otomatis)
		_add(out, seen, fs, 6)
	# ---- level CAMPAIGN (campaign.gd)
	for c in [[14, 4], [16, 5], [17, 4], [18, 5], [19, 5], [20, 5], [24, 5], [28, 7], [30, 7], [44, 8], [46, 6], [54, 10],
			[58, 7], [68, 12], [92, 12]]:
		_add(out, seen, int(c[0]), int(c[1]))
	for fs in range(18, 22):                    # petunjuk berdenyut
		_add(out, seen, fs, 5)
	for fs in range(16, 31):                    # nama perk (fit)
		_add(out, seen, fs, 7)
	for fs in range(12, 21):                    # deskripsi perk (fit)
		_add(out, seen, fs, 5)
	# ---- HUD pertandingan / level (game.gd, player.gd)
	for c in [[14, 4], [17, 4], [18, 5], [19, 4], [20, 0], [20, 5], [22, 5], [24, 6], [26, 5], [28, 6], [34, 8], [64, 8],
			[16, 5], [20, 7]]:
		_add(out, seen, int(c[0]), int(c[1]))
	for fs in range(14, 25):                    # nama karakter di HUD
		_add(out, seen, fs, 6)
	for fs in range(9, 18):                     # jumlah kill
		_add(out, seen, fs, 3)
	for fs in range(9, 15):                     # nama power up aktif
		_add(out, seen, fs, 5)
	# ---- komponen UIKit (tombol, banner, prompt tombol)
	for c in [[20, 4], [20, 5], [24, 0], [28, 0], [28, 6], [30, 0], [34, 0], [52, 0], [64, 0], [70, 0]]:
		_add(out, seen, int(c[0]), int(c[1]))
	for fs in [26, 28, 30, 32, 34, 36, 38]:     # FancyButton
		_add(out, seen, fs, 5)
	for fs in range(12, 27):                    # prompt tombol / label kecil tanpa kontur
		_add(out, seen, fs, 0)
	# ---- layar pilih fighter (select.gd) - jalur pertama kali masuk campaign
	for c in [[11, 2], [13, 0], [13, 3], [14, 3], [14, 4], [15, 0], [15, 3], [15, 4], [18, 0], [20, 4], [20, 5], [22, 5],
			[26, 5], [26, 6], [30, 6], [32, 6], [40, 6], [96, 12], [42, 8], [22, 6]]:
		_add(out, seen, int(c[0]), int(c[1]))
	for fs in range(22, 43, 2):                 # "READY!" (fit)
		_add(out, seen, fs, 8)
	for fs in range(14, 25):                    # nama fighter / senjata (fit)
		_add(out, seen, fs, 5)
	return out


## Pekerjaan menggambar: [font, ukuran, kontur, teks]. Teks dipotong supaya satu gambar tidak terlalu lama (huruf besar = mahal).
static func _push(jobs: Array, f: Font, s: int, o: int, txt: String) -> void:
	var chunk: int = 4 if s >= 80 else (14 if s >= 40 else 60)
	var i: int = 0
	while i < txt.length():
		jobs.append([f, s, o, txt.substr(i, chunk)])
		i += chunk


static func font_jobs() -> Array:
	var f: Font = UIKit.font()
	var jobs: Array = []
	for c in combos():
		var s: int = int(c[0])
		var o: int = int(c[1])
		_push(jobs, f, s, o, CH_UP + (CH_LOW if s <= 20 else ""))
	for s in BANNER_SIZES:
		_push(jobs, f, int(s), 18, CH_BANNER)
	for o in [34, 16, 0]:
		_push(jobs, f, TITLE_SIZE, int(o), CH_TITLE)
	return jobs


# ------------------------------------------------------------------ pemanas huruf
## Menggambar huruf di luar layar sedikit demi sedikit (batas waktu per frame). Berjalan sejak awal loading, bersamaan
## dengan pemuatan aset. `done` menjadi true setelah semua selesai; pemilik node yang membuangnya (queue_free).
class FontWarm extends Control:
	const BUDGET_USEC := 5000
	var jobs: Array = []
	var done: bool = false
	var _i: int = 0

	func _init(job_list: Array = []) -> void:
		jobs = job_list
		position = Vector2(-6000.0, -6000.0)
		size = Vector2(64.0, 64.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE

	func progress() -> float:
		if done:
			return 1.0
		return clampf(float(_i) / float(maxi(jobs.size(), 1)), 0.0, 1.0)

	func _process(_d: float) -> void:
		if done:
			return
		if _i >= jobs.size():
			done = true
			set_process(false)
			return
		queue_redraw()

	func _draw() -> void:
		if done:
			return
		var t0: int = Time.get_ticks_usec()
		while _i < jobs.size():
			var j: Array = jobs[_i]
			var f: Font = j[0]
			var fs: int = int(j[1])
			var ol: int = int(j[2])
			var txt: String = String(j[3])
			if ol > 0:
				draw_string_outline(f, Vector2(0.0, 80.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, Color.BLACK)
			draw_string(f, Vector2(0.0, 80.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
			_i += 1
			if Time.get_ticks_usec() - t0 >= BUDGET_USEC:
				break


# ------------------------------------------------------------------ pemanas shader & primitif
## Memakai (sekali) semua shader kustom yang baru dikompilasi saat pertama dipakai + jenis gambar yang dipakai hazards / peta.
## Ditaruh di dalam layar dengan alpha sangat kecil (tidak terlihat) supaya benar-benar dirender; sama seperti Global.GpuWarm.
class PrimWarm extends Control:
	var done: bool = false
	var _step: int = 0
	var _mesh: ArrayMesh = null
	var _box: StyleBoxFlat = null

	func _init() -> void:
		position = Vector2(2.0, 2.0)
		size = Vector2(16.0, 16.0)
		clip_contents = true
		modulate = Color(1.0, 1.0, 1.0, 0.02)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE

	func _ready() -> void:
		# ---- shader kustom
		var mats: Array = []
		var cscript = load("res://scripts/campaign.gd")          # sengaja tanpa tipe: kita hanya butuh konstanta shader
		if cscript != null:
			var cmap: Dictionary = cscript.get_script_constant_map()
			if cmap.has("DEFEAT_SHADER"):
				var dsh := Shader.new()
				dsh.code = String(cmap["DEFEAT_SHADER"])
				var dm := ShaderMaterial.new()
				dm.shader = dsh
				mats.append(dm)
		for key in FxShaders.SKIN_CODE:
			mats.append(FxShaders.skin_material(String(key)))
		mats.append(FxShaders.wave_material())
		mats.append(FxShaders.victim_material())
		mats.append(FxShaders.add_material())
		for m in mats:
			var r := ColorRect.new()
			r.position = Vector2(1.0, 1.0)
			r.size = Vector2(12.0, 12.0)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.material = m
			add_child(r)

		# ---- Line2D / Polygon2D (hazards, peta)
		var ln := Line2D.new()
		ln.points = PackedVector2Array([Vector2(1, 1), Vector2(8, 4), Vector2(14, 12)])
		ln.width = 3.0
		ln.default_color = Color.WHITE
		ln.antialiased = true
		add_child(ln)
		var ln2 := Line2D.new()
		ln2.points = PackedVector2Array([Vector2(1, 12), Vector2(7, 6), Vector2(14, 2)])
		ln2.width = 4.0
		ln2.default_color = Color(1.0, 0.8, 0.4)
		ln2.joint_mode = Line2D.LINE_JOINT_ROUND
		ln2.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln2.end_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(ln2)
		var pg := Polygon2D.new()
		pg.polygon = PackedVector2Array([Vector2(2, 2), Vector2(12, 3), Vector2(8, 13)])
		pg.color = Color(0.4, 0.8, 1.0)
		add_child(pg)
		var pg2 := Polygon2D.new()
		pg2.polygon = PackedVector2Array([Vector2(3, 8), Vector2(13, 8), Vector2(8, 14)])
		pg2.vertex_colors = PackedColorArray([Color.RED, Color.GREEN, Color.BLUE])
		add_child(pg2)

		# ---- mesh + StyleBoxFlat (peta CAMPAIGN, prompt tombol)
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(0, 0), Vector2(12, 0), Vector2(12, 6), Vector2(0, 0), Vector2(12, 6), Vector2(0, 6)])
		_mesh = ArrayMesh.new()
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		_box = StyleBoxFlat.new()
		_box.bg_color = Color(0.9, 0.9, 0.95)
		_box.set_corner_radius_all(4)
		_box.border_color = Color(0.5, 0.5, 0.7)
		_box.set_border_width_all(2)

	func _process(_d: float) -> void:
		_step += 1
		queue_redraw()
		if _step >= 10:
			done = true
			set_process(false)

	func _draw() -> void:
		draw_multiline(PackedVector2Array([Vector2(0, 0), Vector2(14, 0), Vector2(0, 4), Vector2(14, 4)]), Color.WHITE, 1.0)
		if _mesh != null:
			draw_mesh(_mesh, null, Transform2D.IDENTITY, Color(1.0, 0.8, 0.2, 0.5))
		if _box != null:
			draw_style_box(_box, Rect2(0.0, 6.0, 14.0, 8.0))
		draw_set_transform(Vector2(4.0, 4.0), 0.4, Vector2.ONE)
		draw_rect(Rect2(0.0, 0.0, 6.0, 6.0), Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ peta CAMPAIGN dijalankan sekali (tersembunyi)
## Menjalankan scene peta CAMPAIGN yang SUNGGUHAN di dalam SubViewport yang tidak ditampilkan, beberapa frame saja, lalu
## membuangnya. Seluruh isi peta (teks, panel, shader latar, mesh, gembok, tombol, prompt) sempat digambar & dikompilasi,
## jadi saat pemain membukanya beneran, tidak ada lagi yang "pertama kali".
## Efek samping scene itu dinetralkan: suara & musik di-mute lalu dikembalikan, sambungan input diputus, dan
## Global.campaign_mode / status musik dikembalikan seperti semula. Tidak ada yang disimpan ke disk oleh peta.
static func warm_hub(host: Node) -> void:
	var tree: SceneTree = host.get_tree()
	var path: String = Global.HUB_SCENE
	var packed = Global._pre_keep.get(path, null)
	if packed == null:
		packed = ResourceLoader.load(path)         # seharusnya sudah di cache; ini hanya pengaman
	if not (packed is PackedScene):
		return

	# ---- simpan keadaan yang akan disentuh scene peta
	var was_mode: bool = Global.campaign_mode
	var music: AudioStreamPlayer = Global._music
	var was_playing: bool = music.playing
	var was_cur: String = Global._current_music
	var was_stream: AudioStream = music.stream
	var buses: Array = []
	for bn in ["SFX", "Music", "Celebrate"]:
		var bi: int = AudioServer.get_bus_index(bn)
		if bi >= 0:
			buses.append([bi, AudioServer.is_bus_mute(bi)])
			AudioServer.set_bus_mute(bi, true)

	# ---- jalankan peta di layar tersembunyi
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.disable_3d = true
	vp.gui_disable_input = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	var hub = (packed as PackedScene).instantiate()       # tanpa tipe: skrip peta punya anggota sendiri (_on_input)
	vp.add_child(hub)
	for c in UIInput.pressed.get_connections():           # peta tersembunyi tidak boleh bereaksi pada input pemain
		var cb: Callable = c["callable"]
		if cb.get_object() == hub:
			UIInput.pressed.disconnect(cb)

	var t0: int = Time.get_ticks_msec()
	var frames: int = 0
	while frames < 90 and (frames < 24 or Time.get_ticks_msec() - t0 < 700):
		await tree.process_frame
		frames += 1

	if is_instance_valid(hub):
		hub.queue_free()
	vp.queue_free()
	await tree.process_frame
	await tree.process_frame

	# ---- kembalikan keadaan semula
	Global.campaign_mode = was_mode
	music.stop()
	Global._current_music = was_cur
	music.stream = was_stream
	if was_playing:
		music.play()
	for b in buses:
		AudioServer.set_bus_mute(int(b[0]), bool(b[1]))
