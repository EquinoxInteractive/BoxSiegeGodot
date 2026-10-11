extends Node
## Autoload "Global": data game (karakter, senjata, map), pengaturan, audio, dan helper UI.

const GAME_TITLE := "BoxSiege"          # Nama game
const SETTINGS_PATH := "user://settings.cfg"

const MAX_HP := 3
const MIN_TIME := 30
const MAX_TIME := 300
const TIME_STEP := 30
const TIME_INFINITE := 0               # match_time = 0 -> waktu tidak terbatas
const MATCH_PATH := "user://match.cfg"
const MIN_WINS := 1
const MAX_WINS := 5                    # maksimal round yang harus dimenangkan (1-5)
const MAX_ROUND_SFX := 16              # suara intro round tersedia sampai round_16 (lihat assets/sfx/)

const PLAYER_NAMES := ["PLAYER 1", "PLAYER 2", "PLAYER 3", "PLAYER 4"]

## Roster: SEMUA karakter bisa dipakai pemain mana saja (hanya tidak boleh kembar).
## Format: [folder sprite, nama file sprite]. Urutan = urutan di grid layar pilih fighter.
## Indeks 0-15 = blok 4x4 di kiri grid, indeks 16-23 (karakter baru) = blok 2x4 di kanan grid.
## Kalau jumlah karakter berubah, ubah juga CHAR_COUNT / RANDOM_CELL / CELLS di select.gd.
const CHARACTERS := [
	["p1", "angry"], ["p1", "melow"], ["p1", "bandel"], ["p1", "ninja"],
	["p2", "calm"], ["p2", "baik"], ["p2", "silat"], ["p2", "mime"],
	["p3", "spiderweaver"], ["p3", "blind"], ["p3", "joker"], ["p3", "drunk"],
	["p4", "bald-man"], ["p4", "savior"], ["p4", "spiderblack"], ["p4", "deadswim"],
	# ---- karakter baru (16-23)
	["p1", "robot"], ["p1", "zombie"],
	["p2", "pirate"], ["p2", "pocong"],
	["p3", "vampire"], ["p3", "cyclops"],
	["p4", "pumpkin"], ["p4", "alien"],
]
const ROSTER_COLS := 4

## Senjata.
##   4 senjata utama (selectable) dipilih di layar SELECT: smith, kurval, flamer, scream.
##   pistol = senjata cadangan (hanya muncul otomatis setelah peluru Scream habis), knife = pisau (semua pemain punya).
## Kolom:
##   damage        darah yang berkurang per kena (MAX_HP = 3, jadi damage 3 = langsung mati)
##   ammo          jumlah peluru per ronde (-1 = tak terbatas)
##   cooldown      jeda antar tembakan (detik) -> makin kecil makin cepat
##   bullet_speed  kecepatan lesat peluru (px/detik)
##   auto          true = tombol tembak boleh ditahan; false = harus tap-tap
##   fallback      senjata pengganti otomatis saat peluru habis ("" = tidak ada, hanya bisa pakai pisau)
##   recoil        dorongan badan ke belakang saat menembak
##   spread        acak posisi vertikal peluru (px), dipakai Flamer
##   range         jarak maksimal peluru (px), 0 = sampai keluar layar / kena sesuatu
##   hold_len      panjang sprite senjata saat dipegang di tangan (px); ubah ini kalau senjata terlihat terlalu besar / kecil
##   sfx_gap       jeda minimal antar suara tembakan (supaya senjata super cepat tidak berisik menumpuk)
const WEAPONS := {
	"smith": {"hold_len": 56.0, "name": "SMITH", "enabled": true, "selectable": true, "kind": "gun",
		"damage": 1.0, "ammo": 25, "cooldown": 0.30, "bullet_speed": 900.0, "auto": false,
		"sfx": "gun_smith", "sfx_vol": -4.0, "sfx_gap": 0.0, "recoil": 45.0, "spread": 0.0, "range": 0.0, "fallback": "",
		"color": Color("ffd23f"), "glow": Color("ff8a1f")},
	"kurval": {"hold_len": 60.0, "name": "KURVAL", "enabled": true, "selectable": true, "kind": "gun",
		"damage": 1.5, "ammo": 10, "cooldown": 0.55, "bullet_speed": 720.0, "auto": false,
		"sfx": "gun_kurval", "sfx_vol": -3.0, "sfx_gap": 0.0, "recoil": 110.0, "spread": 0.0, "range": 0.0, "fallback": "",
		"color": Color("ff9d2e"), "glow": Color("ff4a1f")},
	"flamer": {"hold_len": 66.0, "name": "FLAMER", "enabled": true, "selectable": true, "kind": "gun",
		"damage": 0.5, "ammo": 30, "cooldown": 0.07, "bullet_speed": 1150.0, "auto": true,
		"sfx": "gun_flamer", "sfx_vol": -9.0, "sfx_gap": 0.13, "recoil": 14.0, "spread": 5.0, "range": 0.0, "fallback": "",
		"color": Color("ffb43a"), "glow": Color("ff4a14")},
	"scream": {"hold_len": 76.0, "name": "SCREAM", "enabled": true, "selectable": true, "kind": "gun",
		"damage": 3.0, "ammo": 3, "cooldown": 1.30, "bullet_speed": 1750.0, "auto": false,
		"sfx": "gun_scream", "sfx_vol": -1.0, "sfx_gap": 0.0, "recoil": 380.0, "spread": 0.0, "range": 0.0, "fallback": "pistol",
		"color": Color("ff5cf2"), "glow": Color("7a2bff")},
	"pistol": {"hold_len": 30.0, "name": "PISTOL", "enabled": true, "selectable": false, "kind": "gun",
		"damage": 0.25, "ammo": -1, "cooldown": 0.30, "bullet_speed": 900.0, "auto": false,
		"sfx": "gun_secondary", "sfx_vol": -5.0, "sfx_gap": 0.0, "recoil": 35.0, "spread": 0.0, "range": 0.0, "fallback": "",
		"color": Color("fff0b0"), "glow": Color("ffb43a")},
	"knife": {"hold_len": 52.0, "name": "KNIFE", "enabled": true, "selectable": false, "kind": "melee",
		"damage": 3.0, "ammo": -1, "cooldown": 0.45, "bullet_speed": 0.0, "auto": false,
		"reach": 83.0, "reach_y": 52.0, "hit_delay": 0.07, "fallback": "",
		"color": Color("dfe8ff"), "glow": Color("8fc8ff")},
}
## Urutan senjata di layar pilih senjata (hanya 4 senjata utama).
const WEAPON_ORDER := ["smith", "kurval", "flamer", "scream"]
const MELEE_WEAPON := "knife"

## Map. Layout tiap map ada di map_data.gd.
const MAPS := {
	"earth": {"name": "EARTH", "enabled": true},
	"hell": {"name": "HELL", "enabled": true},
	"snow": {"name": "SNOW", "enabled": true},
	"desert": {"name": "DESERT", "enabled": true},
	"jungle": {"name": "JUNGLE", "enabled": true},
	"safari": {"name": "SAFARI", "enabled": true},
	"temple": {"name": "TEMPLE", "enabled": true},
	"ocean": {"name": "OCEAN", "enabled": true},
	"space": {"name": "SPACE", "enabled": true},
	"factory": {"name": "FACTORY", "enabled": true},
	"random": {"name": "RANDOM", "enabled": true},      # pilihan khusus: map diacak tiap pertandingan dimulai
}
const MAP_ORDER := ["earth", "hell", "snow", "desert", "jungle", "safari", "temple", "ocean", "space", "factory", "random"]
const RANDOM_MAP := "random"

var PLAYER_COLORS: Array[Color] = [
	Color("ff3b3b"), Color("3b9bff"), Color("a855f7"), Color("ff8a1f"),
]

## Palet background per map (atas, bawah, aksen) untuk efek UI.
const MAP_PALETTES := {
	"earth": [Color("0b2a4a"), Color("0f5a7a"), Color("7dff6a")],
	"hell": [Color("1c0505"), Color("5a0d0d"), Color("ff6a1a")],
	"snow": [Color("0d1f3d"), Color("2b5c92"), Color("bfe6ff")],
	"desert": [Color("3a1d08"), Color("a8581a"), Color("ffc46b")],
	"jungle": [Color("06210f"), Color("1d5a2a"), Color("9cff7a")],
	"safari": [Color("33200a"), Color("8a5a1a"), Color("ffd27a")],
	"temple": [Color("1b2108"), Color("56602a"), Color("e8dc8a")],
	"ocean": [Color("062a40"), Color("0d6b8a"), Color("7ff0e6")],
	"space": [Color("0d0626"), Color("2f1b6b"), Color("8ae8ff")],
	"factory": [Color("161a22"), Color("4a4f5c"), Color("ffc933")],
	"random": [Color("1a1233"), Color("4a2a7a"), Color("ffd23f")],
}

## ---- Power up ----
## Semua power up bisa diizinkan / dilarang muncul lewat layar BATTLE SETTINGS (bawaan: semua muncul).
## id = nama file ikon di assets/sprites/powerups/<id>.png (nama & warna HUD ada di Player.PU_INFO).
const POWERUP_ORDER := ["heal", "jump", "speed", "shield", "invisible", "ammo_refill", "swap_position"]
const POWERUPS := {
	"heal": {"name": "HEAL", "desc": "+1 HEART", "color": Color("4be3a0")},
	"jump": {"name": "JUMP", "desc": "HIGHER JUMP", "color": Color("3d8bff")},
	"speed": {"name": "SPEED", "desc": "RUN FASTER", "color": Color("ff5d4d")},
	"shield": {"name": "SHIELD", "desc": "BLOCKS HITS", "color": Color("73d9ff")},
	"invisible": {"name": "INVISIBLE", "desc": "FADE AWAY", "color": Color("b36bff")},
	"ammo_refill": {"name": "AMMO", "desc": "REFILL AMMO", "color": Color("ff9d2e")},
	"swap_position": {"name": "SWAP", "desc": "SHUFFLE SPOTS", "color": Color("8ed457")},
}
## Seberapa sering power up muncul: jeda antar kemunculan (detik) dan batas jumlah di arena.
const POWERUP_AMOUNTS := [
	{"name": "FEW", "min": 13.0, "max": 19.0, "cap": 1},
	{"name": "NORMAL", "min": 6.0, "max": 10.0, "cap": 2},
	{"name": "MANY", "min": 3.5, "max": 6.0, "cap": 3},
	{"name": "CHAOS", "min": 1.5, "max": 3.0, "cap": 5},
]

## Kepadatan objek / rintangan arena (setting OBJECTS di BATTLE SETTINGS, hanya mode versus).
## Indeks 1 (NORMAL) = map apa adanya. Logika ada di MapData.apply_density().
const OBJECT_DENSITIES := [
	{"name": "FEWER", "desc": "LIGHTER HAZARDS"},
	{"name": "NORMAL", "desc": "DEFAULT MAP"},
	{"name": "MORE", "desc": "EXTRA OBJECTS"},
	{"name": "EXTREME", "desc": "PACKED ARENA"},
]

## ---- Kontrol ----
## Aksi yang bisa diubah (urutan = urutan baris di layar CONTROLS SETUP). "up" = lompat.
const ACTIONS := ["left", "right", "up", "down", "shoot", "swap"]
const ACTION_LABELS := {"left": "LEFT", "right": "RIGHT", "up": "JUMP", "down": "DROP", "shoot": "SHOOT", "swap": "KNIFE"}
const PAD_AXIS_BASE := 1000          # kode binding >= 1000 = trigger analog (axis = kode - 1000)

## Pilihan perangkat tiap pemain (Global.input_pref):
##   PREF_AUTO     = otomatis (pakai controller yang masih kosong, kalau habis -> keyboard)
##   PREF_KEYBOARD = keyboard
##   angka >= 0    = controller urutan ke-N (0 = controller pertama yang terhubung)
const PREF_AUTO := -2
const PREF_KEYBOARD := -1

## Keybind keyboard bawaan tiap pemain.
const DEFAULT_KEYS := [
	{"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S, "shoot": KEY_F, "swap": KEY_G},
	{"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN, "shoot": KEY_SLASH, "swap": KEY_PERIOD},
	{"left": KEY_J, "right": KEY_L, "up": KEY_I, "down": KEY_K, "shoot": KEY_H, "swap": KEY_U},
	{"left": KEY_KP_4, "right": KEY_KP_6, "up": KEY_KP_8, "down": KEY_KP_5, "shoot": KEY_KP_0, "swap": KEY_KP_PERIOD},
]
## Tombol controller bawaan (stick kiri selalu aktif juga untuk gerak / lompat / turun).
const DEFAULT_PADS := [
	{"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT, "up": JOY_BUTTON_A, "down": JOY_BUTTON_DPAD_DOWN, "shoot": JOY_BUTTON_X, "swap": JOY_BUTTON_Y},
	{"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT, "up": JOY_BUTTON_A, "down": JOY_BUTTON_DPAD_DOWN, "shoot": JOY_BUTTON_X, "swap": JOY_BUTTON_Y},
	{"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT, "up": JOY_BUTTON_A, "down": JOY_BUTTON_DPAD_DOWN, "shoot": JOY_BUTTON_X, "swap": JOY_BUTTON_Y},
	{"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT, "up": JOY_BUTTON_A, "down": JOY_BUTTON_DPAD_DOWN, "shoot": JOY_BUTTON_X, "swap": JOY_BUTTON_Y},
]

## Pilihan batas FPS di SETTINGS (0 = Unlimited / tanpa batas).
const FPS_OPTIONS := [30, 60, 90, 120, 240, 0]

# ---- Pengaturan (tersimpan) ----
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var vibration: bool = true
var fullscreen: bool = false
var screen_shake: bool = true
var show_fps: bool = false          # tampilkan counter FPS di pojok kiri bawah layar
var fps_limit: int = 60             # salah satu dari FPS_OPTIONS (0 = Unlimited)

var key_bindings: Array = []        # 4 Dictionary {aksi: kode keyboard}
var pad_bindings: Array = []        # 4 Dictionary {aksi: kode tombol controller}
var input_pref: Array[int] = [PREF_AUTO, PREF_AUTO, PREF_AUTO, PREF_AUTO]   # pilihan perangkat tiap pemain

# ---- State yang dibawa antar scene ----
var player_devices: Array[int] = [-1, -1, -1, -1]   # device joypad tiap pemain (-1 = keyboard)
var player_count: int = 2
var selections: Array = []          # [{ "character": int, "weapon": String }, ...]
var team_of: Array[int] = [0, 1, 2, 3]   # versus 3-4 pemain: nomor TIM (0-3) tiap pemain. Bawaan: semua sendiri-sendiri (FFA)
var map_id: String = "earth"
var match_time: int = 90               # detik; TIME_INFINITE (0) = tidak terbatas
var WINS_TO_MATCH: int = 3             # jumlah round yang harus dimenangkan
var powerups_on: bool = true
var powerup_amount: int = 1            # indeks POWERUP_AMOUNTS
var powerup_allowed := {}              # id power up -> boleh muncul?
var object_density: int = 1            # indeks OBJECT_DENSITIES (1 = NORMAL)

# ---- Mode CAMPAIGN (single player)
var campaign_mode: bool = false        # true = layar pilih fighter melanjutkan ke CAMPAIGN (bukan ke BATTLE SETTINGS)
var campaign_run: Dictionary = {}      # state permainan campaign yang sedang berjalan (lihat CampaignData.new_run)

# ---- Draf pengaturan (SETTINGS): perubahan baru disimpan ke file setelah tombol SAVE ditekan ----
var _edit_snapshot: Dictionary = {}   # kosong = tidak sedang mengedit

var font_ui: Font
var font_digital: Font
var ui_theme: Theme

var _music: AudioStreamPlayer
var _current_music := ""
var _sfx_cache := {}
var _slash_stream: AudioStreamWAV
var _tex_cache := {}
var _transition: UIKit.ScreenTransition
var _fps_layer: CanvasLayer
var _fps_label: Label
var _changing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # musik tetap jalan saat game di-pause
	reset_bindings()
	_load_settings()
	_load_match_settings()
	if OS.is_debug_build():
		MapData.verify_levels()   # pastikan FEWER / NORMAL / MORE / EXTREME selalu beda jumlah objek di semua map
	_setup_buses()
	font_ui = load("res://assets/fonts/badaboom.ttf")
	font_digital = load("res://assets/fonts/digital7.ttf")
	ui_theme = _build_theme()

	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_music.finished.connect(_on_music_finished)
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)
	apply_fullscreen()
	apply_fps_limit()
	_build_fps_overlay()

	var layer := CanvasLayer.new()
	layer.layer = 110
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_transition = UIKit.ScreenTransition.new()
	layer.add_child(_transition)

	Input.joy_connection_changed.connect(_on_joy_changed)
	assign_devices()

	# ANTI-LAG: siapkan suara sintetis & aset berat di latar belakang selagi pemain masih di menu
	prewarm_synth()
	_start_asset_preload()
	_start_gpu_warmup()


func _exit_tree() -> void:
	_synth_abort = true
	if _synth_thread != null and _synth_thread.is_started():
		_synth_thread.wait_to_finish()


# ------------------------------------------------------------------ PRELOAD ASET (anti-lag)
## Tekstur / suara / musik dimuat di latar belakang sejak game dibuka, lalu DIPEGANG di memori.
## Sebelumnya aset baru dibaca dari disk saat pertama dipakai (mis. saat match mulai / peluru pertama), dan
## bisa terhapus lagi dari cache begitu tidak ada yang memakainya -> baca disk ulang -> patah-patah.
const PRELOAD_PER_FRAME := 3                 # maksimal aset yang diambil per frame (supaya tidak ada lonjakan)
const _PRE_TEX_DIRS := ["res://assets/sprites/characters/p1", "res://assets/sprites/characters/p2",
		"res://assets/sprites/characters/p3", "res://assets/sprites/characters/p4",
		"res://assets/sprites/guns", "res://assets/sprites/guns/p1", "res://assets/sprites/guns/p2",
		"res://assets/sprites/guns/p3", "res://assets/sprites/guns/p4", "res://assets/sprites/powerups",
		"res://assets/sprites/stages", "res://assets/sprites/campaign", "res://assets/sprites/ui"]
var _pre_pending: Array[String] = []         # path yang sudah diminta, belum diambil
var _pre_sfx_of := {}                        # path -> nama sfx (untuk mengisi _sfx_cache)
var _pre_keep := {}                          # path -> resource yang dipegang terus (musik)


func _start_asset_preload() -> void:
	# 1) musik
	for m in ["menu", "game", "campaign", "boss"]:
		_pre_request("res://assets/music/music_%s.ogg" % m)
	# 2) sprite
	for d in _PRE_TEX_DIRS:
		for f in _list_res_files(String(d)):
			var ext: String = f.get_extension().to_lower()
			if ext == "png" or ext == "jpg" or ext == "webp":
				_pre_request("%s/%s" % [d, f])
	# 3) sfx (urutan ekstensi sama seperti get_sfx: mp3, wav, ogg)
	var found := {}   # nama -> {ext: true}
	for f in _list_res_files("res://assets/sfx"):
		var ext2: String = f.get_extension().to_lower()
		if ext2 == "mp3" or ext2 == "wav" or ext2 == "ogg":
			var nm: String = f.get_basename()
			if not found.has(nm):
				found[nm] = {}
			found[nm][ext2] = true
	for nm2 in found:
		for ext3 in ["mp3", "wav", "ogg"]:
			if found[nm2].has(ext3):
				var path: String = "res://assets/sfx/%s.%s" % [nm2, ext3]
				_pre_sfx_of[path] = String(nm2)
				_pre_request(path)
				break
	set_process(not _pre_pending.is_empty())


## Daftar file di folder res:// (juga benar di game hasil export: akhiran .import / .remap dibuang).
func _list_res_files(dir_path: String) -> Array[String]:
	var res: Array[String] = []
	for f in DirAccess.get_files_at(dir_path):
		var n: String = String(f)
		if n.ends_with(".import"):
			n = n.trim_suffix(".import")
		elif n.ends_with(".remap"):
			n = n.trim_suffix(".remap")
		if not res.has(n):
			res.append(n)
	return res


func _pre_request(path: String) -> void:
	if ResourceLoader.has_cached(path):
		_pre_adopt(path, load(path))
		return
	if ResourceLoader.load_threaded_request(path) == OK:
		_pre_pending.append(path)


## Simpan resource yang sudah termuat ke cache yang dipakai game.
func _pre_adopt(path: String, res: Resource) -> void:
	if res == null:
		return
	if _pre_sfx_of.has(path):
		var nm: String = String(_pre_sfx_of[path])
		if not _sfx_cache.has(nm):
			_sfx_cache[nm] = res
	elif res is Texture2D:
		if not _tex_cache.has(path):
			_tex_cache[path] = res
	else:
		_pre_keep[path] = res


func _process(_delta: float) -> void:
	var taken: int = 0
	var i: int = 0
	while i < _pre_pending.size() and taken < PRELOAD_PER_FRAME:
		var path: String = _pre_pending[i]
		var status: int = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_pre_adopt(path, ResourceLoader.load_threaded_get(path))
			_pre_pending.remove_at(i)
			taken += 1
		elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			i += 1
		else:
			_pre_pending.remove_at(i)   # gagal / tidak valid -> dilewati (nanti dimuat biasa saat dibutuhkan)
	if _pre_pending.is_empty():
		set_process(false)


# ------------------------------------------------------------------ PEMANASAN GPU (anti-lag)
## Driver GPU mengompilasi shader tampilan (blend additive, garis halus, poligon, partikel) saat PERTAMA kali dipakai.
## Di PC lawas itu terasa sebagai patah-patah tepat saat efek kemenangan / level clear pertama muncul.
## Di sini semua jenis gambar itu digambar sekali di menu (nyaris transparan, ukuran ~1 piksel, +-0.5 detik),
## jadi kompilasinya selesai sebelum pertandingan. Tampilan game tidak berubah.
func _start_gpu_warmup() -> void:
	await get_tree().create_timer(1.2).timeout
	var layer := CanvasLayer.new()
	layer.layer = 109
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var w := GpuWarm.new()
	w.font = font_ui
	layer.add_child(w)
	await get_tree().create_timer(0.6).timeout
	layer.queue_free()


class GpuWarm extends Node2D:
	var font: Font = null
	var additive: bool = false
	var _tex: GradientTexture2D = null

	func _ready() -> void:
		modulate = Color(1, 1, 1, 0.02)     # tetap digambar (shader dikompilasi) tapi tak terlihat
		scale = Vector2(0.03, 0.03)
		position = Vector2(2, 2)
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0.0)])
		_tex = GradientTexture2D.new()
		_tex.gradient = gr
		_tex.width = 16
		_tex.height = 16
		_tex.fill = GradientTexture2D.FILL_RADIAL
		_tex.fill_from = Vector2(0.5, 0.5)
		_tex.fill_to = Vector2(1.0, 0.5)
		var add_mat := CanvasItemMaterial.new()
		add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		if additive:
			material = add_mat
		else:
			var kid := GpuWarm.new()
			kid.additive = true
			kid.font = font
			add_child(kid)
			# partikel: gaya konfeti (tanpa tekstur) dan gaya percikan cahaya (tekstur + additive)
			var cr := Gradient.new()
			cr.set_color(0, Color("ffd23f"))
			cr.set_color(1, Color.WHITE)
			var conf := CPUParticles2D.new()
			conf.amount = 6
			conf.lifetime = 0.4
			conf.one_shot = true
			conf.explosiveness = 1.0
			conf.spread = 180.0
			conf.initial_velocity_min = 20.0
			conf.initial_velocity_max = 60.0
			conf.angular_velocity_min = -200.0
			conf.angular_velocity_max = 200.0
			conf.scale_amount_min = 5.0
			conf.scale_amount_max = 9.0
			conf.color_initial_ramp = cr
			add_child(conf)
			conf.emitting = true
			var glo := CPUParticles2D.new()
			glo.amount = 6
			glo.lifetime = 0.4
			glo.one_shot = true
			glo.explosiveness = 1.0
			glo.spread = 180.0
			glo.initial_velocity_min = 20.0
			glo.initial_velocity_max = 60.0
			glo.scale_amount_min = 5.0
			glo.scale_amount_max = 9.0
			glo.texture = _tex
			glo.material = add_mat
			glo.color_ramp = cr
			add_child(glo)
			glo.emitting = true
		queue_redraw()

	func _process(_d: float) -> void:
		queue_redraw()    # beberapa frame berturut-turut supaya semua varian benar-benar terpakai

	func _draw() -> void:
		var tri := PackedVector2Array([Vector2(0, 0), Vector2(40, 8), Vector2(12, 40)])
		draw_rect(Rect2(0, 0, 40, 40), Color.WHITE)
		draw_texture_rect(_tex, Rect2(0, 0, 40, 40), false, Color.WHITE)
		draw_line(Vector2(0, 0), Vector2(40, 40), Color.WHITE, 3.0, true)
		draw_line(Vector2(0, 40), Vector2(40, 0), Color.WHITE, 1.0, false)
		draw_polyline(tri, Color.WHITE, 3.0, true)
		draw_colored_polygon(tri, Color.WHITE)
		draw_polygon(tri, PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
		draw_arc(Vector2(20, 20), 18.0, 0.0, TAU, 32, Color.WHITE, 3.0, true)
		draw_circle(Vector2(20, 20), 10.0, Color.WHITE)
		if font != null:
			draw_string(font, Vector2(0, 30), "A1", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
			draw_string_outline(font, Vector2(0, 30), "A1", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)


# ------------------------------------------------------------------ data helpers
func enabled_weapons() -> Array[String]:
	var res: Array[String] = []
	for id in WEAPON_ORDER:
		var data: Dictionary = WEAPONS[id]
		if data["enabled"]:
			res.append(id)
	return res


func enabled_maps() -> Array[String]:
	var res: Array[String] = []
	for id in MAP_ORDER:
		var data: Dictionary = MAPS[id]
		if data["enabled"] and id != RANDOM_MAP:
			res.append(id)
	return res


## Peta nyata untuk pilihan RANDOM: acak dari semua map aktif, dan tidak sama dengan map acak sebelumnya.
var _last_random_map: String = ""
func pick_random_map() -> String:
	var pool: Array[String] = enabled_maps()
	if pool.size() > 1 and pool.has(_last_random_map):
		pool.erase(_last_random_map)
	var pick: String = pool[randi() % pool.size()]
	_last_random_map = pick
	return pick


## Peta yang benar-benar dimainkan untuk pengaturan map saat ini (RANDOM -> diacak).
func resolve_map_id(id: String) -> String:
	if id == RANDOM_MAP:
		return pick_random_map()
	return id


## Cache tekstur: tekstur yang hanya dipegang sementara bisa terhapus sebelum selesai digambar (jadi kotak putih).
func cached_tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


func character_count() -> int:
	return CHARACTERS.size()


## Parameter pertama (slot pemain) dipertahankan agar pemanggil lama tetap jalan; karakter ditentukan oleh char_idx saja.
func character_name(_slot: int, char_idx: int) -> String:
	var n: String = CHARACTERS[char_idx][1]
	return n.replace("_", " ").replace("-", " ").to_upper()


func character_texture(_slot: int, char_idx: int, dead: bool = false) -> Texture2D:
	var info: Array = CHARACTERS[char_idx]
	var suffix: String = "_die" if dead else ""
	var path: String = "res://assets/sprites/characters/%s/%s%s.png" % [info[0], info[1], suffix]
	return cached_tex(path)


func weapon_texture(player_idx: int, weapon_id: String) -> Texture2D:
	var path: String = "res://assets/sprites/guns/p%d/%s.png" % [player_idx + 1, weapon_id]
	return cached_tex(path)


## Gambar kolase semua map (dipakai sebagai pratinjau pilihan RANDOM), dibuat sekali lalu disimpan.
func _random_map_texture() -> Texture2D:
	if _tex_cache.has("random_collage"):
		return _tex_cache["random_collage"]
	var ids: Array[String] = enabled_maps()
	var cols := 4
	var rows: int = int(ceil(float(ids.size()) / float(cols)))
	var cw: int = 320 / cols
	var ch: int = 180 / maxi(rows, 1)
	var img := Image.create(320, 180, false, Image.FORMAT_RGBA8)
	img.fill(Color("1a1233"))
	for i in ids.size():
		var tex: Texture2D = cached_tex("res://assets/sprites/stages/%s.png" % ids[i])
		if tex == null:
			continue
		var im: Image = tex.get_image()
		if im == null:
			continue
		if im.is_compressed():
			im.decompress()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
		img.blit_rect(im, Rect2i(0, 0, cw, ch), Vector2i((i % cols) * cw, (i / cols) * ch))
	var t := ImageTexture.create_from_image(img)
	_tex_cache["random_collage"] = t
	return t


func map_background(id: String) -> Texture2D:
	if id == RANDOM_MAP:
		return _random_map_texture()
	var path: String = "res://assets/sprites/stages/%s.png" % id
	return cached_tex(path)


func format_time(seconds: int) -> String:
	if seconds <= TIME_INFINITE:
		return "INF"
	return "%d:%02d" % [seconds / 60, seconds % 60]


## Urutan pilihan waktu: 0:30 ... 5:00 lalu INFINITE (di ujung).
func time_options() -> Array[int]:
	var res: Array[int] = []
	var t: int = MIN_TIME
	while t <= MAX_TIME:
		res.append(t)
		t += TIME_STEP
	res.append(TIME_INFINITE)
	return res


## Geser pilihan waktu satu langkah (tanpa wrap). Mengembalikan nilai baru (sama kalau sudah di ujung).
func step_time(cur: int, dir: int) -> int:
	var opts: Array[int] = time_options()
	var pos: int = opts.find(cur)
	if pos == -1:
		pos = 0
	return opts[clampi(pos + dir, 0, opts.size() - 1)]


func allowed_powerups() -> Array[String]:
	var res: Array[String] = []
	if not powerups_on:
		return res
	for id in POWERUP_ORDER:
		if bool(powerup_allowed.get(id, true)):
			res.append(id)
	return res


func reset_powerup_rules() -> void:
	powerups_on = true
	powerup_amount = 1
	for id in POWERUP_ORDER:
		powerup_allowed[id] = true


# ------------------------------------------------------------------ TEAM (versus 3-4 pemain)
## Layar TEAM (scripts/team.gd) mengisi `team_of`. Tiap pemain punya nomor tim 0-3 ("TEAM 01" - "TEAM 04").
## Pemain yang sendirian di timnya = bermain solo. Kalau tidak ada tim berisi >= 2 pemain, game berjalan
## persis seperti FFA biasa (teams_active() = false).
const MAX_TEAMS := 4
const TEAM_COLORS := [Color("a6ff2e"), Color("5b6bff"), Color("ff3d9a"), Color("1fe3c8")]

## Nerf tim yang lebih banyak dari tim terkecil (level = selisih jumlah anggota, maks 2).
## Sengaja ringan: tidak mengubah darah / pisau / senjata sekali-mati, hanya melambatkan sedikit.
##   dmg   = pengali damage peluru (senjata dengan damage >= darah maksimal tetap sekali-mati)
##   rate  = pengali jeda tembak (> 1 = lebih lambat)
##   speed = pengali kecepatan lari, jump = pengali tinggi lompat
const TEAM_NERF := [
	{"dmg": 1.0, "rate": 1.0, "speed": 1.0, "jump": 1.0},
	{"dmg": 0.85, "rate": 1.10, "speed": 0.96, "jump": 1.0},
	{"dmg": 0.70, "rate": 1.22, "speed": 0.92, "jump": 0.97},
]


## Maksimal anggota satu tim: 4 pemain -> 3, 3 pemain -> 2.
func team_cap(n: int = -1) -> int:
	var c: int = player_count if n < 0 else n
	if c >= 4:
		return 3
	if c == 3:
		return 2
	return 1


func team_members(team: int) -> Array[int]:
	var res: Array[int] = []
	for i in mini(player_count, team_of.size()):
		if team_of[i] == team:
			res.append(i)
	return res


func team_size(team: int) -> int:
	return team_members(team).size()


func team_color(team: int) -> Color:
	return TEAM_COLORS[clampi(team, 0, MAX_TEAMS - 1)]


func team_name(team: int) -> String:
	return "TEAM %02d" % (clampi(team, 0, MAX_TEAMS - 1) + 1)


func reset_teams() -> void:
	team_of = [0, 1, 2, 3]


## Pastikan pembagian tim masih sah untuk jumlah pemain sekarang (kalau tidak -> semua sendiri-sendiri).
func sanitize_teams() -> void:
	if team_of.size() != 4:
		reset_teams()
		return
	var cap: int = team_cap()
	for t in MAX_TEAMS:
		if team_size(t) > cap:
			reset_teams()
			return
	for i in 4:
		if team_of[i] < 0 or team_of[i] >= MAX_TEAMS:
			reset_teams()
			return


## True kalau pertandingan versus ini memakai tim (3-4 pemain dan ada tim berisi >= 2 pemain).
func teams_active() -> bool:
	if campaign_mode or player_count < 3:
		return false
	for t in MAX_TEAMS:
		if team_size(t) >= 2:
			return true
	return false


## Level nerf sebuah tim: selisih jumlah anggota dengan tim terkecil yang ada (0 = seimbang, maks 2).
func team_nerf_level(team: int) -> int:
	if not teams_active():
		return 0
	var sz: int = team_size(team)
	if sz <= 0:
		return 0
	var smallest: int = 99
	for t in MAX_TEAMS:
		var s: int = team_size(t)
		if s > 0:
			smallest = mini(smallest, s)
	return clampi(sz - smallest, 0, TEAM_NERF.size() - 1)


func team_nerf(team: int) -> Dictionary:
	return TEAM_NERF[team_nerf_level(team)]


# ------------------------------------------------------------------ scene
func goto(scene_name: String) -> void:
	if _changing:
		return
	_changing = true
	play_sfx("ui_whoosh", -6.0)
	await _transition.cover()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % scene_name)
	await get_tree().process_frame
	await get_tree().process_frame
	await _transition.reveal()
	_changing = false


# ------------------------------------------------------------------ controller
## Tentukan perangkat tiap pemain dari pilihan di CONTROLS SETUP (input_pref):
##   KEYBOARD     -> keyboard
##   CONTROLLER n -> controller urutan ke-n (kalau belum tercolok, sementara pakai keyboard)
##   AUTO         -> controller yang belum dipakai pemain lain, berurutan; kalau habis -> keyboard
func assign_devices() -> void:
	var pads: Array[int] = UIInput.pads()
	var used := {}
	for i in 4:
		player_devices[i] = -1
		var p: int = input_pref[i]
		if p >= 0 and p < pads.size():
			player_devices[i] = pads[p]
			used[pads[p]] = true
	var next := 0
	for i in 4:
		if input_pref[i] != PREF_AUTO:
			continue
		while next < pads.size() and used.has(pads[next]):
			next += 1
		if next < pads.size():
			player_devices[i] = pads[next]
			used[pads[next]] = true


func device_of(player_idx: int) -> int:
	return player_devices[player_idx] if player_idx >= 0 and player_idx < 4 else -1


## True kalau pemain ini sedang memakai controller (bukan keyboard).
func uses_pad(player_idx: int) -> bool:
	var d: int = device_of(player_idx)
	return d >= 0 and UIInput.pads().has(d)


## Slot pemain yang dikuasai device ini (-1 kalau tidak ada).
func slot_of_device(device: int) -> int:
	if device < 0:
		return -1
	var idx: int = player_devices.find(device)
	return idx if idx < player_count else -1


func _on_joy_changed(_device: int, _connected: bool) -> void:
	assign_devices()   # controller dicabut / dicolok: pembagian perangkat dihitung ulang


# ------------------------------------------------------------------ pilihan perangkat
func input_options() -> Array[int]:
	var res: Array[int] = [PREF_AUTO, PREF_KEYBOARD]
	for i in UIInput.pads().size():
		res.append(i)
	return res


func pref_label(pref: int) -> String:
	if pref == PREF_AUTO:
		return "AUTO"
	if pref == PREF_KEYBOARD:
		return "KEYBOARD"
	return "CONTROLLER %d" % (pref + 1)


## Ganti pilihan perangkat. Kalau controller itu sudah dipakai pemain lain, keduanya bertukar.
func set_input_pref(player_idx: int, pref: int) -> void:
	var old: int = input_pref[player_idx]
	if pref >= 0:
		for p in 4:
			if p != player_idx and input_pref[p] == pref:
				input_pref[p] = old if old != pref else PREF_AUTO
	input_pref[player_idx] = pref
	assign_devices()


func cycle_input_pref(player_idx: int, dir: int) -> void:
	var opts: Array[int] = input_options()
	var pos: int = opts.find(input_pref[player_idx])
	if pos == -1:
		pos = 0
	set_input_pref(player_idx, opts[posmod(pos + dir, opts.size())])


# ------------------------------------------------------------------ keybind
func reset_bindings(player_idx: int = -1) -> void:
	for i in 4:
		if player_idx >= 0 and i != player_idx:
			continue
		if key_bindings.size() < 4:
			key_bindings.append({})
			pad_bindings.append({})
		key_bindings[i] = (DEFAULT_KEYS[i] as Dictionary).duplicate()
		pad_bindings[i] = (DEFAULT_PADS[i] as Dictionary).duplicate()


func reset_input_prefs() -> void:
	for i in 4:
		input_pref[i] = PREF_AUTO
	assign_devices()


## ESC dipakai untuk pause / membatalkan, jadi tidak boleh dijadikan keybind.
func is_key_reserved(code: int) -> bool:
	return code == KEY_ESCAPE or code == KEY_NONE


## Tombol START / HOME dipakai untuk pause.
func is_pad_reserved(code: int) -> bool:
	return code == JOY_BUTTON_START or code == JOY_BUTTON_GUIDE


## Set keybind keyboard. Kalau tombol itu sudah dipakai aksi lain (pemain mana pun), keduanya bertukar.
## Mengembalikan [pemain, aksi] yang ditukar (kosong kalau tidak ada).
func set_key_binding(player_idx: int, action: String, code: int) -> Array:
	var old: int = int(key_bindings[player_idx][action])
	if old == code:
		return []
	var swapped := []
	for p in 4:
		for a in ACTIONS:
			if (p != player_idx or a != action) and int(key_bindings[p][a]) == code:
				key_bindings[p][a] = old
				swapped = [p, a]
	key_bindings[player_idx][action] = code
	return swapped


## Set tombol controller. Bentrok hanya dicek dalam pemain yang sama (controller tiap pemain terpisah).
func set_pad_binding(player_idx: int, action: String, code: int) -> Array:
	var old: int = int(pad_bindings[player_idx][action])
	if old == code:
		return []
	var swapped := []
	for a in ACTIONS:
		if a != action and int(pad_bindings[player_idx][a]) == code:
			pad_bindings[player_idx][a] = old
			swapped = [player_idx, a]
	pad_bindings[player_idx][action] = code
	return swapped


func reset_key_action(player_idx: int, action: String) -> void:
	set_key_binding(player_idx, action, int(DEFAULT_KEYS[player_idx][action]))


func reset_pad_action(player_idx: int, action: String) -> void:
	set_pad_binding(player_idx, action, int(DEFAULT_PADS[player_idx][action]))


func key_name(code: int) -> String:
	return UIKit.key_label(code)


## Nama tombol controller. style: "ps" (default) atau "xbox".
func pad_button_name(code: int, style: String = "ps") -> String:
	var xb: bool = style == "xbox"
	if code >= PAD_AXIS_BASE:
		match code - PAD_AXIS_BASE:
			JOY_AXIS_TRIGGER_LEFT:
				return "LT" if xb else "L2"
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT" if xb else "R2"
		return "AXIS"
	match code:
		JOY_BUTTON_A: return "A" if xb else "CROSS"
		JOY_BUTTON_B: return "B" if xb else "CIRCLE"
		JOY_BUTTON_X: return "X" if xb else "SQUARE"
		JOY_BUTTON_Y: return "Y" if xb else "TRIANGLE"
		JOY_BUTTON_LEFT_SHOULDER: return "LB" if xb else "L1"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB" if xb else "R1"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_DPAD_UP: return "D-UP"
		JOY_BUTTON_DPAD_DOWN: return "D-DOWN"
		JOY_BUTTON_DPAD_LEFT: return "D-LEFT"
		JOY_BUTTON_DPAD_RIGHT: return "D-RIGHT"
		JOY_BUTTON_BACK: return "VIEW" if xb else "SHARE"
		JOY_BUTTON_START: return "MENU" if xb else "OPTIONS"
		JOY_BUTTON_GUIDE: return "HOME"
	return "BTN %d" % code


## Getar controller milik pemain tertentu.
func rumble(player_idx: int, weak: float, strong: float, duration: float) -> void:
	UIInput.rumble(device_of(player_idx), weak, strong, duration)


## Statistik senjata 0..1 untuk bar di layar pilih senjata.
##   DMG  = damage, RATE = tembakan per detik (1 / cooldown), SPD = kecepatan peluru.
func weapon_stats(id: String) -> Dictionary:
	var w: Dictionary = WEAPONS[id]
	if not w.get("enabled", false):
		return {}
	return {
		"damage": clampf(float(w["damage"]) / 3.0, 0.05, 1.0),
		"rate": clampf((1.0 / maxf(float(w["cooldown"]), 0.01)) / 5.0, 0.05, 1.0),
		"speed": clampf(float(w.get("bullet_speed", 0.0)) / 1800.0, 0.05, 1.0),
	}


# ------------------------------------------------------------------ audio
func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	# pengaman: banyak suara bertumpuk (perayaan level clear) tidak membuat suara pecah
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx_idx) == 0:
		var lim := AudioEffectLimiter.new()
		lim.ceiling_db = -0.5
		lim.threshold_db = -3.0
		AudioServer.add_bus_effect(sfx_idx, lim)
	# bus "Celebrate": SFX + gema (reverb) supaya fanfare / kembang api terasa megah. Volume tetap ikut SFX.
	if AudioServer.get_bus_index("Celebrate") == -1:
		AudioServer.add_bus()
		var cidx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(cidx, "Celebrate")
		AudioServer.set_bus_send(cidx, "SFX")
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.72
		rv.damping = 0.45
		rv.spread = 1.0
		rv.dry = 0.85
		rv.wet = 0.28
		AudioServer.add_bus_effect(cidx, rv)


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	var idx: int = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_mute(idx, music_volume <= 0.001)


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	var idx: int = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(sfx_volume, 0.0001)))
	AudioServer.set_bus_mute(idx, sfx_volume <= 0.001)


func apply_fullscreen() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


# ------------------------------------------------------------------ FPS (batas & counter)
## Nama pilihan untuk baris FPS LIMIT di SETTINGS: "30", "60", ..., "UNLIMITED".
func fps_option_names() -> Array:
	var out: Array = []
	for f in FPS_OPTIONS:
		out.append("UNLIMITED" if int(f) == 0 else str(int(f)))
	return out


## Indeks fps_limit di dalam FPS_OPTIONS (dipakai baris pengaturan).
func fps_index() -> int:
	var i: int = FPS_OPTIONS.find(fps_limit)
	return i if i >= 0 else FPS_OPTIONS.find(60)


## Terapkan batas FPS:
##  - Engine.max_fps = batas (0 = tanpa batas)
##  - VSync hanya aktif untuk 30 / 60 FPS. Di atas itu VSync dimatikan, kalau tidak FPS tertahan di refresh rate monitor.
##  - Fisika (pemain, peluru, hazard) ikut dinaikkan ke >= batas FPS (maks 240 Hz) supaya gerakan benar-benar
##    terlihat lebih halus di 90 / 120 / 240 FPS. Semua gerakan di game ini sudah berbasis delta, jadi kecepatannya tetap sama.
func apply_fps_limit() -> void:
	if not FPS_OPTIONS.has(fps_limit):
		fps_limit = 60
	Engine.max_fps = fps_limit
	var use_vsync: bool = fps_limit == 30 or fps_limit == 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if use_vsync else DisplayServer.VSYNC_DISABLED)
	var ticks: int = 240 if fps_limit == 0 else clampi(fps_limit, 60, 240)
	Engine.physics_ticks_per_second = ticks
	Engine.max_physics_steps_per_frame = maxi(8, int(float(ticks) / 15.0))


func set_show_fps(v: bool) -> void:
	show_fps = v
	_refresh_fps_visibility()


func _refresh_fps_visibility() -> void:
	if _fps_layer != null:
		_fps_layer.visible = show_fps
	_update_fps_label()


## Counter FPS di pojok kiri bawah (di atas semua layar, termasuk saat game di-pause).
func _build_fps_overlay() -> void:
	_fps_layer = CanvasLayer.new()
	_fps_layer.layer = 125
	_fps_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_fps_layer)
	_fps_label = make_label("", 26, Color("9dff7a"), 6)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_fps_label.offset_left = 14.0
	_fps_label.offset_top = -44.0
	_fps_label.offset_right = 260.0
	_fps_label.offset_bottom = -8.0
	_fps_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_fps_layer.add_child(_fps_label)
	var t := Timer.new()
	t.wait_time = 0.25
	t.autostart = true
	t.ignore_time_scale = true            # tetap berdetak normal saat slow motion
	t.process_mode = Node.PROCESS_MODE_ALWAYS
	t.timeout.connect(_update_fps_label)
	add_child(t)
	_refresh_fps_visibility()


func _update_fps_label() -> void:
	if _fps_label == null or not show_fps:
		return
	_fps_label.text = "FPS %d" % int(Engine.get_frames_per_second())


func play_music(which: String) -> void:
	if which == _current_music and _music.playing:
		return
	_current_music = which
	var path: String = "res://assets/music/music_%s.ogg" % which
	_music.stream = load(path)
	_music.play()


func _on_music_finished() -> void:
	_music.play()   # loop


func get_sfx(sfx_name: String) -> AudioStream:
	if _sfx_cache.has(sfx_name):
		return _sfx_cache[sfx_name]
	for ext in ["mp3", "wav", "ogg", "MP3", "WAV", "OGG"]:
		var path: String = "res://assets/sfx/%s.%s" % [sfx_name, ext]
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path)
			_sfx_cache[sfx_name] = s
			return s
	push_warning("SFX tidak ditemukan: " + sfx_name)
	return null


## Cek apakah file sfx ada (tanpa memunculkan warning).
func has_sfx(sfx_name: String) -> bool:
	if _sfx_cache.has(sfx_name):
		return true
	for ext in ["mp3", "wav", "ogg", "MP3", "WAV", "OGG"]:
		if ResourceLoader.exists("res://assets/sfx/%s.%s" % [sfx_name, ext]):
			return true
	return false


# ------------------------------------------------------------------ suara pengisi (voice)
## Letak file: assets/sfx/voice/  (format .mp3 / .wav / .ogg, boleh campur). Kalau file belum ada, tidak ada suara & tidak ada error.
##   char_<id>.*        dibacakan saat karakter DIPILIH (dikunci) di layar Choose Your Fighter, mis. char_bandel.wav
##                      -> JUGA dipakai lagi saat karakter itu menang match (digabung dengan wins)
##   team_<n>.*         nama tim, n = 1..4, mis. team_1.wav ("Team One") -> dipakai saat tim menang (digabung dengan wins)
##   wins.*             kata "Wins" (SATU file untuk semua) -> disambung setelah suara karakter / suara tim
##   weapon_<id>.*      nama senjata, dibacakan saat senjata DIPILIH (tombol accept / enter) di layar Choose Your Fighter,
##                      mis. weapon_smith.wav, weapon_kurval.wav, weapon_flamer.wav, weapon_scream.wav
##                      (<id> = kunci senjata di Global.WEAPONS; senjata baru otomatis ikut: tinggal taruh weapon_<idbaru>.*)
## Saat menang:  pemain sendiri = char_<id> + wins   ("Bandel" + "Wins")
##               tim (>1 anggota) = team_<n> + wins   ("Team One" + "Wins")
##   flawless_victory.* kata "Flawless Victory" (SATU file untuk semua) -> disambung SETELAH "Wins", HANYA kalau pemenang
##                      menang dengan darah masih penuh (tidak berkurang sama sekali, mis. 3 dari 3)
## Opsional (override): kalau file win_<id>.* / team_<n>_win.* ada, file itu yang dipakai sendirian (tanpa digabung).
## <id> = nama sprite karakter huruf kecil, tanda "-" diganti "_" (lihat Global.CHARACTERS), mis. bald-man -> bald_man.
const VOICE_WIN_DELAY := 1.0            # jeda (detik) suara menang setelah animasi kemenangan mulai, supaya tidak tertimpa fanfare
const VOICE_WINS_NAME := "wins"         # nama file kata "Wins" di assets/sfx/voice/ (tanpa ekstensi)
const VOICE_FLAWLESS_NAME := "flawless_victory"   # nama file "Flawless Victory" di assets/sfx/voice/ (tanpa ekstensi)
const VOICE_CHAIN_GAP := 0.05           # jeda (detik) antara suara karakter/tim dan "Wins"


func character_voice_id(char_idx: int) -> String:
	var info: Array = CHARACTERS[clampi(char_idx, 0, CHARACTERS.size() - 1)]
	return String(info[1]).to_lower().replace("-", "_")


func play_voice(voice_name: String, delay: float = 0.0, volume_db: float = 0.0) -> void:
	var key: String = "voice/" + voice_name
	if not has_sfx(key):
		return
	if delay > 0.0:
		await get_tree().create_timer(delay, true).timeout
	play_sfx(key, volume_db)


## "Bandel" saat karakter dipilih.
func play_character_voice(char_idx: int) -> void:
	play_voice("char_" + character_voice_id(char_idx))


## Suara nama senjata saat senjata dipilih (file: assets/sfx/voice/weapon_<id>.*).
## Kalau file-nya belum ada -> diam saja, tanpa error.
func play_weapon_voice(weapon_id: String) -> void:
	play_voice("weapon_" + weapon_id.to_lower())


## Memutar beberapa suara voice berurutan (tiap suara menunggu yang sebelumnya selesai).
## Nama yang filenya tidak ada dilewati begitu saja (tanpa error).
func play_voice_chain(voice_names: Array, delay: float = 0.0, volume_db: float = 0.0) -> void:
	var streams: Array[AudioStream] = []
	for vn in voice_names:
		var key: String = "voice/" + String(vn)
		if has_sfx(key):
			var st: AudioStream = get_sfx(key)
			if st != null:
				streams.append(st)
	if streams.is_empty():
		return
	if delay > 0.0:
		await get_tree().create_timer(delay, true).timeout
	for i in streams.size():
		var p := AudioStreamPlayer.new()
		p.stream = streams[i]
		p.bus = "SFX"
		p.volume_db = volume_db
		add_child(p)
		p.play()
		await p.finished
		p.queue_free()
		if i < streams.size() - 1 and VOICE_CHAIN_GAP > 0.0:
			await get_tree().create_timer(VOICE_CHAIN_GAP, true).timeout


## "Bandel Wins" saat pemain sendiri menang = suara karakter (char_<id>) + "wins".
## Kalau ada file khusus win_<id>, file itu dipakai sendirian.
## flawless = true -> setelah "Wins" disambung suara "Flawless Victory" (menang tanpa darah berkurang).
func play_win_voice(char_idx: int, delay: float = VOICE_WIN_DELAY, flawless: bool = false) -> void:
	var id: String = character_voice_id(char_idx)
	var names: Array = []
	if has_sfx("voice/win_" + id):
		names = ["win_" + id]
	else:
		names = ["char_" + id, VOICE_WINS_NAME]
	if flawless:
		names.append(VOICE_FLAWLESS_NAME)
	play_voice_chain(names, delay)


## "Team One Wins" saat tim menang = suara tim (team_<n>) + "wins" (team = 0..3 -> team_1 .. team_4).
## Kalau ada file khusus team_<n>_win, file itu dipakai sendirian.
## flawless = true -> setelah "Wins" disambung suara "Flawless Victory" (menang tanpa darah berkurang).
func play_team_win_voice(team: int, delay: float = VOICE_WIN_DELAY, flawless: bool = false) -> void:
	var n: int = clampi(team, 0, MAX_TEAMS - 1) + 1
	var names: Array = []
	if has_sfx("voice/team_%d_win" % n):
		names = ["team_%d_win" % n]
	else:
		names = ["team_%d" % n, VOICE_WINS_NAME]
	if flawless:
		names.append(VOICE_FLAWLESS_NAME)
	play_voice_chain(names, delay)


## Suara intro "ROUND N". File: assets/sfx/round_1 ... round_16 (.mp3/.wav/.ogg).
## Kalau file round_N belum dibuat, otomatis memakai round tertinggi yang sudah ada (mis. round_8).
func play_round_sfx(round_num: int) -> void:
	var n: int = clampi(round_num, 1, MAX_ROUND_SFX)
	while n > 1 and not has_sfx("round_%d" % n):
		n -= 1
	play_sfx("round_%d" % n)


func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch: float = 1.0, bus: String = "SFX") -> void:
	var stream: AudioStream = get_sfx(sfx_name)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = volume_db
	p.pitch_scale = maxf(pitch, 0.1)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Suara tebasan pisau ("swish"). Dibuat lewat kode (tanpa file audio baru), cukup sekali lalu disimpan.
func play_slash(volume_db: float = -2.0) -> void:
	if _slash_stream == null:
		_slash_stream = _make_slash_stream()
	var p := AudioStreamPlayer.new()
	p.stream = _slash_stream
	p.bus = "SFX"
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.92, 1.1)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _make_slash_stream() -> AudioStreamWAV:
	var rate: int = 22050
	var n: int = int(float(rate) * 0.22)
	var data := PackedByteArray()
	data.resize(n * 2)
	var r := RandomNumberGenerator.new()
	r.seed = 1337
	var lp1: float = 0.0
	var lp2: float = 0.0
	for i in n:
		var u: float = float(i) / float(n)
		var noise: float = r.randf_range(-1.0, 1.0)
		var a: float = lerpf(0.10, 0.62, u)        # cutoff naik pelan -> bunyi "swish"
		lp1 += (noise - lp1) * a
		lp2 += (noise - lp2) * 0.04                 # buang nada rendah
		var s: float = lp1 - lp2
		var env: float = minf(u / 0.12, 1.0) * pow(1.0 - u, 1.6)
		var v: int = int(clampf(s * env * 1.9, -1.0, 1.0) * 30000.0)
		data.encode_s16(i * 2, v)
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.stereo = false
	st.data = data
	return st


# ------------------------------------------------------------------ SUARA SINTETIS (dibuat lewat kode)
## Dipakai animasi LEVEL CLEAR (campaign.gd) dan animasi kemenangan VERSUS (game.gd). Tidak butuh file audio baru:
## gelombang dihitung lewat kode di THREAD LATAR BELAKANG sejak game dibuka, disimpan di memori + cache disk (user://synth_cache).
## Pakai:  Global.prewarm_synth()  -> mulai membangun (aman dipanggil berkali-kali; sudah otomatis dipanggil di _ready)
##         Global.play_synth("clear_fanfare", -4.0)  -> true kalau sudah siap dan terdengar
const SYNTH_IDS := ["clear_boom", "coin", "whistle", "pop", "applause", "vic_riser", "vic_crash", "chime",
		"stab", "shimmer", "clear_fanfare", "vic_anthem"]   # urutan = dari yang ringan ke yang berat; vic_*: animasi kemenangan VERSUS (game.gd)
const SYNTH_CHUNK := 2600           # sampel per potongan kerja (dipakai thread latar belakang)
const SYNTH_CACHE_VER := 1          # NAIK-kan angka ini kalau Anda mengubah rumus suara _syn_* (supaya cache disk dibuat ulang)
const SYNTH_CACHE_DIR := "user://synth_cache"
const _FT_SAW := 0
const _FT_BELL := 1
const _FT_SQUARE := 2
var _synth_cache := {}
var _synth_state: int = 0           # 0 = belum, 1 = sedang membangun, 2 = selesai
var _synth_thread: Thread = null
var _synth_abort: bool = false      # true saat game ditutup -> thread berhenti cepat


## Mulai menyiapkan semua suara sintetis. AMAN dipanggil berkali-kali (hanya jalan sekali).
## Perbaikan lag: dulu suara dihitung di thread utama tiap game dimulai (ribuan sampel per frame -> patah-patah).
## Sekarang: (1) dibaca dari cache disk kalau sudah pernah dibuat, (2) sisanya dihitung di THREAD LATAR BELAKANG
## prioritas rendah, dimulai sejak game dibuka (di menu), jadi saat pertandingan dimulai sudah siap / tidak mengganggu.
func prewarm_synth() -> void:
	if _synth_state != 0:
		return
	_synth_state = 1
	var missing: Array = []
	for id in SYNTH_IDS:
		var st: AudioStreamWAV = _synth_load_disk(String(id))
		if st != null:
			_synth_cache[String(id)] = st
		else:
			missing.append(String(id))
	if missing.is_empty():
		_synth_state = 2
		return
	_synth_thread = Thread.new()
	_synth_thread.start(_synth_thread_main.bind(missing), Thread.PRIORITY_LOW)


func synth_ready() -> bool:
	return _synth_state == 2


func has_synth(id: String) -> bool:
	return _synth_cache.has(id)


func play_synth(id: String, volume_db: float = 0.0, pitch: float = 1.0, bus: String = "SFX") -> bool:
	if not _synth_cache.has(id):
		return false
	var p := AudioStreamPlayer.new()
	p.stream = _synth_cache[id]
	p.bus = bus
	p.volume_db = volume_db
	p.pitch_scale = maxf(pitch, 0.1)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return true


## Berjalan di thread terpisah. Tidak menyentuh scene tree / node; hasil dikirim balik lewat call_deferred.
func _synth_thread_main(ids: Array) -> void:
	for id in ids:
		if _synth_abort:
			return
		var st: AudioStreamWAV = _synth_build_sync(String(id))
		if st == null:
			return
		_synth_save_disk(String(id), st)
		call_deferred("_synth_built", String(id), st)
	call_deferred("_synth_all_built")


func _synth_built(id: String, st: AudioStreamWAV) -> void:
	_synth_cache[id] = st


func _synth_all_built() -> void:
	_synth_state = 2
	if _synth_thread != null and _synth_thread.is_started():
		_synth_thread.wait_to_finish()
	_synth_thread = null


func _synth_cache_path(id: String) -> String:
	return "%s/v%d_%s.bin" % [SYNTH_CACHE_DIR, SYNTH_CACHE_VER, id]


func _synth_save_disk(id: String, st: AudioStreamWAV) -> void:
	DirAccess.make_dir_recursive_absolute(SYNTH_CACHE_DIR)
	var f := FileAccess.open(_synth_cache_path(id), FileAccess.WRITE)
	if f == null:
		return
	f.store_32(st.mix_rate)
	f.store_32(st.data.size())
	f.store_buffer(st.data)
	f.close()


## Baca suara dari cache disk. Kalau file tidak ada / ukurannya tidak cocok dengan spesifikasi -> null (dibuat ulang).
func _synth_load_disk(id: String) -> AudioStreamWAV:
	var path: String = _synth_cache_path(id)
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var spec: Dictionary = _synth_spec(id)
	var rate: int = int(spec["rate"])
	var want: int = int(float(rate) * float(spec["dur"])) * 2
	var got_rate: int = int(f.get_32())
	var got_len: int = int(f.get_32())
	if got_rate != rate or got_len != want:
		f.close()
		return null
	var data: PackedByteArray = f.get_buffer(got_len)
	f.close()
	if data.size() != want:
		return null
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.stereo = false
	st.data = data
	return st


func _synth_spec(id: String) -> Dictionary:
	match id:
		"clear_boom": return {"rate": 22050, "dur": 1.9}
		"clear_fanfare": return {"rate": 32000, "dur": 3.6}
		"shimmer": return {"rate": 32000, "dur": 2.2}
		"chime": return {"rate": 32000, "dur": 1.5}
		"coin": return {"rate": 32000, "dur": 0.5}
		"stab": return {"rate": 32000, "dur": 1.5}
		"whistle": return {"rate": 22050, "dur": 0.8}
		"pop": return {"rate": 22050, "dur": 1.1}
		"vic_riser": return {"rate": 32000, "dur": 1.7}
		"vic_crash": return {"rate": 32000, "dur": 3.4}
		"vic_anthem": return {"rate": 32000, "dur": 6.2}
	return {"rate": 22050, "dur": 4.2}   # applause


## Versi tanpa await dari pembangun suara (dijalankan di thread latar belakang). Hasil sampel IDENTIK dengan versi lama.
func _synth_build_sync(id: String) -> AudioStreamWAV:
	var spec: Dictionary = _synth_spec(id)
	var rate: int = int(spec["rate"])
	var n: int = int(float(rate) * float(spec["dur"]))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ctx: Dictionary = {"rng": RandomNumberGenerator.new()}
	(ctx["rng"] as RandomNumberGenerator).seed = hash(id)
	var i: int = 0
	while i < n:
		if _synth_abort:
			return null
		var e: int = mini(i + SYNTH_CHUNK, n)
		_synth_fill(id, buf, i, e, rate, ctx)
		i = e
	# normalisasi + ubah ke 16-bit
	var peak: float = 0.0001
	for k in n:
		peak = maxf(peak, absf(buf[k]))
	var g: float = 0.92 / peak
	var data := PackedByteArray()
	data.resize(n * 2)
	for k in n:
		data.encode_s16(k * 2, int(clampf(buf[k] * g, -1.0, 1.0) * 32000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.stereo = false
	st.data = data
	return st


func _synth_fill(id: String, buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	match id:
		"clear_boom": _syn_boom(buf, i0, i1, rate, ctx)
		"clear_fanfare": _syn_fanfare(buf, i0, i1, rate, ctx)
		"shimmer": _syn_shimmer(buf, i0, i1, rate, ctx)
		"chime": _syn_chime(buf, i0, i1, rate, ctx)
		"coin": _syn_coin(buf, i0, i1, rate, ctx)
		"stab": _syn_stab(buf, i0, i1, rate, ctx)
		"whistle": _syn_whistle(buf, i0, i1, rate, ctx)
		"pop": _syn_pop(buf, i0, i1, rate, ctx)
		"vic_riser": _syn_vic_riser(buf, i0, i1, rate, ctx)
		"vic_crash": _syn_vic_crash(buf, i0, i1, rate, ctx)
		"vic_anthem": _syn_vic_anthem(buf, i0, i1, rate, ctx)
		_: _syn_applause(buf, i0, i1, rate, ctx)


static func _midi_hz(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## Satu suara: [mulai, durasi, frekuensi, amplitudo, fase1, fase2, lp1, lp2, jenis, lepas]
static func _voice(start: float, dur: float, midi: float, amp: float, kind: int = 0, rel: float = 0.25) -> Array:
	return [start, dur, _midi_hz(midi), amp, 0.0, 0.0, 0.0, 0.0, kind, rel]


## Mesin pemutar suara: menjumlahkan semua voice yang aktif di rentang sampel [i0, i1).
static func _voices_chunk(buf: PackedFloat32Array, i0: int, i1: int, rate: int, voices: Array) -> void:
	var r: float = float(rate)
	var t0: float = float(i0) / r
	var t1: float = float(i1) / r
	var act: Array = []
	for v in voices:
		if t1 >= float(v[0]) and t0 <= float(v[0]) + float(v[1]) + float(v[9]) * 6.0:
			act.append(v)
	for i in range(i0, i1):
		var t: float = float(i) / r
		var x: float = 0.0
		for v in act:
			var tt: float = t - float(v[0])
			if tt < 0.0:
				continue
			var dur: float = float(v[1])
			var rel: float = float(v[9])
			var env: float = 1.0
			if tt > dur:
				env = exp(-(tt - dur) / maxf(rel * 0.35, 0.001))
				if env < 0.002:
					continue
			var f: float = float(v[2])
			var amp: float = float(v[3])
			var kind: int = int(v[8])
			if kind == _FT_SAW:
				# "brass": dua saw sedikit sumbang + pulsa, disaring lowpass yang membuka di awal
				env *= minf(tt / 0.022, 1.0) * (0.82 + 0.18 * minf(tt / 0.25, 1.0))
				var vib: float = 0.0055 * minf(maxf(tt - 0.22, 0.0) / 0.3, 1.0) * sin(TAU * 5.6 * tt)
				var ff: float = f * (1.0 + vib)
				v[4] = float(v[4]) + ff * 1.0035 / r
				v[5] = float(v[5]) + ff * 0.9965 / r
				var ph1: float = float(v[4]) - floorf(float(v[4]))
				var ph2: float = float(v[5]) - floorf(float(v[5]))
				var s: float = (ph1 + ph2) - 1.0
				s += 0.35 * ((1.0 if ph1 < 0.3 else -1.0) + 0.4)   # pulsa 30% (dibuat tanpa DC offset)
				var fc: float = 800.0 + 4200.0 * (1.0 - exp(-tt * 26.0)) - 900.0 * minf(maxf(tt - 0.4, 0.0), 1.0)
				var a: float = minf(TAU * fc / r, 0.9)
				v[6] = float(v[6]) + (s - float(v[6])) * a
				v[7] = float(v[7]) + (float(v[6]) - float(v[7])) * a
				x += float(v[7]) * env * amp * 1.6
			elif kind == _FT_BELL:
				# lonceng kaca: partikel tak harmonis, meluruh cepat
				var d: float = exp(-tt * 3.6)
				var w: float = TAU * f * tt
				var b: float = sin(w) + 0.45 * sin(w * 2.756) * exp(-tt * 3.0) + 0.22 * sin(w * 5.404) * exp(-tt * 6.0)
				b *= minf(tt / 0.002, 1.0)
				x += b * d * env * amp
			else:
				# square ala 8-bit
				v[4] = float(v[4]) + f / r
				var ph: float = float(v[4]) - floorf(float(v[4]))
				x += (1.0 if ph < 0.5 else -1.0) * exp(-tt * 7.0) * env * amp
		buf[i] = x


func _syn_boom(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	var ph: float = float(ctx.get("ph", 0.0))
	var lp: float = float(ctx.get("lp", 0.0))
	var lp2: float = float(ctx.get("lp2", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		ph += TAU * (36.0 + 130.0 * exp(-t * 9.0)) / r
		var body: float = sin(ph) * exp(-t * 2.4)
		var n: float = rng.randf() * 2.0 - 1.0
		lp += (n - lp) * (0.03 + 0.55 * exp(-t * 16.0))
		lp2 += (n - lp2) * 0.014
		var x: float = body * 1.1 + lp * exp(-t * 7.0) * 1.3 + lp2 * exp(-t * 1.5) * 5.0
		buf[i] = tanh(x * 1.5)
	ctx["ph"] = ph
	ctx["lp"] = lp
	ctx["lp2"] = lp2


func _syn_fanfare(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	if not ctx.has("v"):
		var v: Array = []
		# tiga ketukan pembuka (power chord) -> naik -> not tinggi panjang dengan akor C mayor
		for k in 3:
			var st: float = 0.14 * float(k)
			v.append(_voice(st, 0.1, 72.0, 0.42, _FT_SAW, 0.12))
			v.append(_voice(st, 0.1, 60.0, 0.30, _FT_SAW, 0.12))
			v.append(_voice(st, 0.1, 79.0, 0.22, _FT_SAW, 0.12))
		v.append(_voice(0.44, 0.2, 76.0, 0.46, _FT_SAW, 0.14))
		v.append(_voice(0.44, 0.2, 64.0, 0.30, _FT_SAW, 0.14))
		v.append(_voice(0.68, 0.2, 79.0, 0.46, _FT_SAW, 0.14))
		v.append(_voice(0.68, 0.2, 67.0, 0.30, _FT_SAW, 0.14))
		# akor penutup panjang
		v.append(_voice(0.94, 1.9, 84.0, 0.50, _FT_SAW, 0.6))
		v.append(_voice(0.94, 1.9, 76.0, 0.32, _FT_SAW, 0.6))
		v.append(_voice(0.94, 1.9, 67.0, 0.34, _FT_SAW, 0.6))
		v.append(_voice(0.94, 1.9, 60.0, 0.34, _FT_SAW, 0.6))
		v.append(_voice(0.94, 1.9, 48.0, 0.50, _FT_SAW, 0.6))
		# lari lonceng tinggi (gemerlap)
		var bells: Array = [88.0, 91.0, 96.0, 100.0, 103.0, 108.0]
		for k in bells.size():
			v.append(_voice(1.5 + 0.075 * float(k), 0.1, float(bells[k]), 0.28, _FT_BELL, 0.3))
		v.append(_voice(0.94, 0.1, 96.0, 0.3, _FT_BELL, 0.3))
		ctx["v"] = v
	_voices_chunk(buf, i0, i1, rate, ctx["v"])


func _syn_shimmer(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	if not ctx.has("v"):
		var v: Array = []
		var scale: Array = [84, 86, 88, 91, 93, 96, 98, 100, 103, 105, 108]
		for k in 30:
			var st: float = rng.randf_range(0.0, 1.4)
			var m: float = float(scale[rng.randi() % scale.size()])
			v.append(_voice(st, 0.05, m, rng.randf_range(0.18, 0.42), _FT_BELL, 0.2))
		ctx["v"] = v
	_voices_chunk(buf, i0, i1, rate, ctx["v"])
	# sapuan noise naik (swoosh)
	var r: float = float(rate)
	var low: float = float(ctx.get("low", 0.0))
	var band: float = float(ctx.get("band", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		if t > 1.2:
			break
		var fc: float = 500.0 * pow(14.0, t / 1.1)
		var f: float = minf(2.0 * sin(PI * minf(fc, 9000.0) / r), 1.0)
		var n: float = rng.randf() * 2.0 - 1.0
		var high: float = n - low - 0.35 * band
		band += f * high
		low += f * band
		var env: float = sin(clampf(t / 1.2, 0.0, 1.0) * PI) * 0.9
		buf[i] += band * env * 0.7
	ctx["low"] = low
	ctx["band"] = band


func _syn_chime(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	if not ctx.has("v"):
		ctx["v"] = [_voice(0.0, 0.05, 84.0, 0.6, _FT_BELL), _voice(0.05, 0.05, 88.0, 0.5, _FT_BELL),
			_voice(0.10, 0.05, 91.0, 0.5, _FT_BELL), _voice(0.15, 0.05, 96.0, 0.35, _FT_BELL)]
	_voices_chunk(buf, i0, i1, rate, ctx["v"])


func _syn_coin(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var r: float = float(rate)
	var ph: float = float(ctx.get("ph", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var f: float = _midi_hz(83.0) if t < 0.07 else _midi_hz(88.0)
		ph += f / r
		var p: float = ph - floorf(ph)
		var env: float = minf(t / 0.003, 1.0) * exp(-maxf(t - 0.07, 0.0) * 9.0)
		buf[i] = (1.0 if p < 0.5 else -1.0) * env * 0.5
	ctx["ph"] = ph


func _syn_stab(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	if not ctx.has("v"):
		var v: Array = []
		for m in [36.0, 48.0, 60.0, 64.0, 67.0, 72.0, 76.0, 79.0]:
			v.append(_voice(0.0, 0.3, float(m), 0.34, _FT_SAW, 0.5))
		v.append(_voice(0.0, 0.1, 96.0, 0.3, _FT_BELL, 0.3))
		v.append(_voice(0.0, 0.1, 100.0, 0.2, _FT_BELL, 0.3))
		ctx["v"] = v
	_voices_chunk(buf, i0, i1, rate, ctx["v"])


func _syn_whistle(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	var ph: float = float(ctx.get("ph", 0.0))
	var lp: float = float(ctx.get("lp", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		ph += TAU * 450.0 * pow(4.9, minf(t / 0.7, 1.0)) / r
		var env: float = minf(t / 0.03, 1.0) * (1.0 - smoothstep(0.58, 0.78, t))
		var trem: float = 1.0 - 0.15 * sin(TAU * 18.0 * t)
		var n: float = rng.randf() * 2.0 - 1.0
		lp += (n - lp) * 0.4
		var hiss: float = (n - lp) * 0.18 * (t / 0.7)
		buf[i] = (sin(ph) + 0.25 * sin(ph * 2.0) + hiss) * env * trem * 0.6
	ctx["ph"] = ph
	ctx["lp"] = lp


## Penanjak ketegangan sebelum ledakan kemenangan: desis noise naik + nada sapuan naik + tremolo makin cepat.
func _syn_vic_riser(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	var dur: float = 1.7
	var low: float = float(ctx.get("low", 0.0))
	var band: float = float(ctx.get("band", 0.0))
	var ph: float = float(ctx.get("ph", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var u: float = clampf(t / dur, 0.0, 1.0)
		# noise band-pass: frekuensi tengah naik dari 300 Hz ke 6 kHz
		var fc: float = 300.0 * pow(20.0, u)
		var f: float = minf(2.0 * sin(PI * minf(fc, 9000.0) / r), 1.0)
		var n: float = rng.randf() * 2.0 - 1.0
		var high: float = n - low - 0.22 * band
		band += f * high
		low += f * band
		var env_n: float = pow(u, 1.7) * (1.0 - smoothstep(0.97, 1.0, u))
		# nada sapuan naik 110 Hz -> 1.7 kHz dengan tremolo yang makin cepat
		ph += TAU * (110.0 * pow(15.5, u)) / r
		var tone: float = sin(ph) + 0.5 * sin(ph * 2.0) + 0.25 * sin(ph * 3.0)
		var trem: float = 1.0 - 0.32 * sin(TAU * (7.0 + 34.0 * u) * t)
		var env_t: float = u * u * (1.0 - smoothstep(0.97, 1.0, u))
		buf[i] = band * env_n * 0.95 + tone * env_t * trem * 0.42
	ctx["low"] = low
	ctx["band"] = band
	ctx["ph"] = ph


## Cymbal crash raksasa: desis terang yang meluruh lama + denting logam tak harmonis + dentuman bawah.
func _syn_vic_crash(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	var lp: float = float(ctx.get("lp", 0.0))
	var ph: float = float(ctx.get("ph", 0.0))
	var metal: Array = [3520.0, 4870.0, 6120.0, 7340.0, 8810.0]
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		lp += (n - lp) * 0.3
		var hp: float = n - lp                      # high-pass sederhana
		var sizzle: float = hp * (exp(-t * 1.25) * 0.85 + exp(-t * 7.0) * 0.9)
		var ring: float = 0.0
		for k in metal.size():
			ring += sin(TAU * float(metal[k]) * t + sin(t * 41.0 + float(k)) * 1.6) * exp(-t * (2.0 + 0.5 * float(k)))
		ring *= 0.11
		ph += TAU * (46.0 + 70.0 * exp(-t * 10.0)) / r
		var thump: float = sin(ph) * exp(-t * 3.2) * 0.9
		var atk: float = minf(t / 0.002, 1.0)
		buf[i] = tanh((sizzle + ring) * atk * 1.25 + thump)
	ctx["lp"] = lp
	ctx["ph"] = ph


## Fanfare kemenangan besar: 3 hentakan -> lari bel -> akor penuh dengan melodi heroik -> akor puncak + gemerlap.
## Ditambah drum (kick) dan crash noise pada ketukan penting supaya terasa heboh.
func _syn_vic_anthem(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	if not ctx.has("v"):
		var v: Array = []
		# tiga hentakan pembuka: C -> F -> G
		var hits: Array = [[0.0, [48.0, 60.0, 72.0, 76.0, 79.0]], [0.43, [53.0, 65.0, 77.0, 81.0, 84.0]], [0.86, [55.0, 67.0, 79.0, 83.0, 86.0]]]
		for h in hits:
			for m in (h[1] as Array):
				v.append(_voice(float(h[0]), 0.26, float(m), 0.34, _FT_SAW, 0.16))
		# akor C penuh + lari bel naik
		for m in [36.0, 48.0, 60.0, 67.0, 72.0, 76.0, 79.0, 84.0]:
			v.append(_voice(1.29, 0.85, float(m), 0.36, _FT_SAW, 0.5))
		var run: Array = [96.0, 100.0, 103.0, 108.0, 112.0]
		for k in run.size():
			v.append(_voice(1.29 + 0.07 * float(k), 0.1, float(run[k]), 0.26, _FT_BELL, 0.3))
		# melodi heroik di atas akor F lalu G
		for m in [41.0, 53.0, 65.0, 69.0, 72.0]:
			v.append(_voice(2.25, 0.82, float(m), 0.3, _FT_SAW, 0.25))
		v.append(_voice(2.25, 0.2, 79.0, 0.5, _FT_SAW, 0.15))
		v.append(_voice(2.5, 0.2, 81.0, 0.5, _FT_SAW, 0.15))
		v.append(_voice(2.75, 0.34, 84.0, 0.54, _FT_SAW, 0.2))
		for m in [43.0, 55.0, 67.0, 71.0, 74.0]:
			v.append(_voice(3.15, 0.5, float(m), 0.32, _FT_SAW, 0.25))
		v.append(_voice(3.15, 0.2, 83.0, 0.5, _FT_SAW, 0.15))
		v.append(_voice(3.4, 0.24, 86.0, 0.52, _FT_SAW, 0.15))
		# akor puncak panjang
		for m in [36.0, 48.0, 60.0, 67.0, 72.0, 76.0, 79.0, 84.0, 88.0]:
			v.append(_voice(3.7, 1.7, float(m), 0.36, _FT_SAW, 0.9))
		v.append(_voice(3.7, 1.7, 91.0, 0.5, _FT_SAW, 0.9))
		var glit: Array = [84.0, 88.0, 91.0, 96.0, 100.0, 103.0, 108.0, 112.0, 115.0]
		for k in glit.size():
			v.append(_voice(3.7 + 0.065 * float(k), 0.1, float(glit[k]), 0.26, _FT_BELL, 0.35))
		for k in 10:
			v.append(_voice(4.5 + rng.randf_range(0.0, 1.2), 0.05, float([96, 100, 103, 108, 112][rng.randi() % 5]), rng.randf_range(0.12, 0.26), _FT_BELL, 0.3))
		ctx["v"] = v
	_voices_chunk(buf, i0, i1, rate, ctx["v"])
	# drum: kick pada hentakan dan akor puncak, crash noise pada akor puncak
	var r: float = float(rate)
	var kicks: Array = [0.0, 0.43, 0.86, 1.29, 2.25, 3.15, 3.7]
	var prev: float = float(ctx.get("prev", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var x: float = 0.0
		for kt in kicks:
			var tt: float = t - float(kt)
			if tt < 0.0 or tt > 0.5:
				continue
			var kph: float = TAU * (42.0 * tt + (150.0 - 42.0) / 22.0 * (1.0 - exp(-tt * 22.0)))
			x += sin(kph) * exp(-tt * 7.5) * 0.9
		var n: float = rng.randf() * 2.0 - 1.0
		var hp: float = n - prev
		prev = n
		var tc: float = t - 3.7
		if tc > 0.0:
			x += hp * exp(-tc * 2.4) * 0.5
		var tc2: float = t - 1.29
		if tc2 > 0.0 and tc2 < 1.0:
			x += hp * exp(-tc2 * 6.0) * 0.28
		buf[i] += x
	ctx["prev"] = prev


func _syn_pop(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	var ph: float = float(ctx.get("ph", 0.0))
	var cl: float = float(ctx.get("cl", 0.0))
	var lp: float = float(ctx.get("lp", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		lp += (n - lp) * (0.08 + 0.7 * exp(-t * 40.0))
		var crack: float = lp * exp(-t * 38.0) * 1.6
		ph += TAU * (55.0 + 160.0 * exp(-t * 14.0)) / r
		var thump: float = sin(ph) * exp(-t * 9.0) * 0.9
		var imp: float = 0.0
		if t > 0.05 and rng.randf() < 0.05 * exp(-(t - 0.05) * 3.0):
			imp = rng.randf_range(0.3, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		cl += (imp - cl) * 0.45
		buf[i] = tanh(crack + thump + cl * 1.4)
	ctx["ph"] = ph
	ctx["cl"] = cl
	ctx["lp"] = lp


func _syn_applause(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	var s1: Array = ctx.get("s1", [0.0, 0.0])
	var s2: Array = ctx.get("s2", [0.0, 0.0])
	var s3: Array = ctx.get("s3", [0.0, 0.0])
	var f1: float = 2.0 * sin(PI * 1150.0 / r)
	var f2: float = 2.0 * sin(PI * 2300.0 / r)
	var f3: float = 2.0 * sin(PI * 900.0 / r)
	for i in range(i0, i1):
		var t: float = float(i) / r
		var d: float = smoothstep(0.0, 0.45, t) * (1.0 - smoothstep(2.6, 4.1, t))
		var imp: float = 0.0
		if rng.randf() < 0.014 * d:
			imp = rng.randf_range(0.4, 1.0)
		var n: float = rng.randf() * 2.0 - 1.0
		# dua resonator "tepukan" + deru penonton
		var h1: float = imp - float(s1[0]) - 0.18 * float(s1[1])
		s1[1] = float(s1[1]) + f1 * h1
		s1[0] = float(s1[0]) + f1 * float(s1[1])
		var h2: float = imp - float(s2[0]) - 0.22 * float(s2[1])
		s2[1] = float(s2[1]) + f2 * h2
		s2[0] = float(s2[0]) + f2 * float(s2[1])
		var h3: float = n * 0.5 - float(s3[0]) - 0.8 * float(s3[1])
		s3[1] = float(s3[1]) + f3 * h3
		s3[0] = float(s3[0]) + f3 * float(s3[1])
		buf[i] = (float(s1[1]) + float(s2[1]) * 0.8) * 1.5 + float(s3[1]) * d * 0.5
	ctx["s1"] = s1
	ctx["s2"] = s2
	ctx["s3"] = s3


# ------------------------------------------------------------------ draf pengaturan (SAVE / DISCARD)
func _capture_settings() -> Dictionary:
	return {
		"music": snappedf(music_volume, 0.01),
		"sfx": snappedf(sfx_volume, 0.01),
		"vibration": vibration,
		"fullscreen": fullscreen,
		"shake": screen_shake,
		"show_fps": show_fps,
		"fps_limit": fps_limit,
		"prefs": input_pref.duplicate(),
		"keys": key_bindings.duplicate(true),
		"pads": pad_bindings.duplicate(true),
	}


## Mulai mengedit: simpan salinan pengaturan yang sekarang (sebagai titik kembali).
func begin_edit() -> void:
	_edit_snapshot = _capture_settings()


func is_editing() -> bool:
	return not _edit_snapshot.is_empty()


## True kalau ada perubahan yang belum di-SAVE.
func has_unsaved() -> bool:
	if _edit_snapshot.is_empty():
		return false
	return var_to_str(_capture_settings()) != var_to_str(_edit_snapshot)


## Tombol SAVE: tulis ke file, lalu jadikan kondisi sekarang sebagai titik kembali yang baru.
func commit_edit() -> void:
	save_settings()
	if is_editing():
		_edit_snapshot = _capture_settings()


## Buang semua perubahan yang belum di-SAVE (kembali ke kondisi saat begin_edit / SAVE terakhir).
func revert_edit() -> void:
	if _edit_snapshot.is_empty():
		return
	var snap: Dictionary = _edit_snapshot
	vibration = bool(snap["vibration"])
	screen_shake = bool(snap["shake"])
	fullscreen = bool(snap["fullscreen"])
	show_fps = bool(snap["show_fps"])
	fps_limit = int(snap["fps_limit"])
	set_music_volume(float(snap["music"]))
	set_sfx_volume(float(snap["sfx"]))
	for i in 4:
		input_pref[i] = int(snap["prefs"][i])
		key_bindings[i] = (snap["keys"][i] as Dictionary).duplicate()
		pad_bindings[i] = (snap["pads"][i] as Dictionary).duplicate()
	apply_fullscreen()
	apply_fps_limit()
	_refresh_fps_visibility()
	assign_devices()
	_edit_snapshot = {}


## Selesai mengedit tanpa mengubah apa pun (dipakai saat tidak ada perubahan).
func end_edit() -> void:
	_edit_snapshot = {}


# ------------------------------------------------------------------ pengaturan pertandingan (BATTLE SETTINGS)
func _load_match_settings() -> void:
	reset_powerup_rules()
	var cfg := ConfigFile.new()
	if cfg.load(MATCH_PATH) != OK:
		return
	var mt: int = int(cfg.get_value("match", "time", match_time))
	match_time = mt if time_options().has(mt) else 90
	WINS_TO_MATCH = clampi(int(cfg.get_value("match", "wins", WINS_TO_MATCH)), MIN_WINS, MAX_WINS)
	var mid: String = str(cfg.get_value("match", "map", map_id))
	if MAPS.has(mid):
		map_id = mid
	powerups_on = bool(cfg.get_value("powerups", "on", true))
	powerup_amount = clampi(int(cfg.get_value("powerups", "amount", 1)), 0, POWERUP_AMOUNTS.size() - 1)
	for id in POWERUP_ORDER:
		powerup_allowed[id] = bool(cfg.get_value("allowed", id, true))
	object_density = clampi(int(cfg.get_value("objects", "density", 1)), 0, OBJECT_DENSITIES.size() - 1)


func save_match_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("match", "time", match_time)
	cfg.set_value("match", "wins", WINS_TO_MATCH)
	cfg.set_value("match", "map", map_id)
	cfg.set_value("powerups", "on", powerups_on)
	cfg.set_value("powerups", "amount", powerup_amount)
	cfg.set_value("objects", "density", object_density)
	for id in POWERUP_ORDER:
		cfg.set_value("allowed", id, bool(powerup_allowed.get(id, true)))
	cfg.save(MATCH_PATH)


# ------------------------------------------------------------------ settings
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_volume = float(cfg.get_value("audio", "music_volume", music_volume))
		sfx_volume = float(cfg.get_value("audio", "sfx_volume", sfx_volume))
		vibration = bool(cfg.get_value("controls", "vibration", vibration))
		fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
		screen_shake = bool(cfg.get_value("display", "screen_shake", screen_shake))
		show_fps = bool(cfg.get_value("display", "show_fps", show_fps))
		var fl: int = int(cfg.get_value("display", "fps_limit", fps_limit))
		fps_limit = fl if FPS_OPTIONS.has(fl) else 60
		for i in 4:
			var pref: Variant = cfg.get_value("input", "device_p%d" % (i + 1), PREF_AUTO)
			input_pref[i] = int(pref) if pref is int and int(pref) >= PREF_AUTO else PREF_AUTO
			for a in ACTIONS:
				var kv: Variant = cfg.get_value("keys", "p%d_%s" % [i + 1, a], key_bindings[i][a])
				if kv is int and int(kv) > 0:
					key_bindings[i][a] = int(kv)
				var pv: Variant = cfg.get_value("pads", "p%d_%s" % [i + 1, a], pad_bindings[i][a])
				if pv is int and int(pv) >= 0:
					pad_bindings[i][a] = int(pv)
		_sanitize_bindings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("controls", "vibration", vibration)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "screen_shake", screen_shake)
	cfg.set_value("display", "show_fps", show_fps)
	cfg.set_value("display", "fps_limit", fps_limit)
	for i in 4:
		cfg.set_value("input", "device_p%d" % (i + 1), input_pref[i])
		for a in ACTIONS:
			cfg.set_value("keys", "p%d_%s" % [i + 1, a], int(key_bindings[i][a]))
			cfg.set_value("pads", "p%d_%s" % [i + 1, a], int(pad_bindings[i][a]))
	cfg.save(SETTINGS_PATH)


## Kalau file setting rusak / ada tombol ganda, kembalikan ke bawaan supaya kontrol tidak kacau.
func _sanitize_bindings() -> void:
	var seen := {}
	var dup := false
	for p in 4:
		for a in ACTIONS:
			var c: int = int(key_bindings[p][a])
			if seen.has(c) or is_key_reserved(c):
				dup = true
			seen[c] = true
	if dup:
		for i in 4:
			key_bindings[i] = (DEFAULT_KEYS[i] as Dictionary).duplicate()
	for p in 4:
		var used := {}
		var bad := false
		for a in ACTIONS:
			var c: int = int(pad_bindings[p][a])
			if used.has(c) or is_pad_reserved(c):
				bad = true
			used[c] = true
		if bad:
			pad_bindings[p] = (DEFAULT_PADS[p] as Dictionary).duplicate()


# ------------------------------------------------------------------ UI helpers
func make_box(bg: Color, border: Color, border_w: int = 3, radius: int = 10, margin: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin * 0.6
	sb.content_margin_bottom = margin * 0.6
	return sb


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_ui
	t.default_font_size = 28

	t.set_stylebox("normal", "Button", make_box(Color("23233a"), Color("6c6f9c")))
	t.set_stylebox("hover", "Button", make_box(Color("34345a"), Color("ffd23f")))
	t.set_stylebox("pressed", "Button", make_box(Color("ffd23f"), Color("ffffff")))
	t.set_stylebox("focus", "Button", make_box(Color("34345a"), Color("ffffff"), 4))
	t.set_stylebox("disabled", "Button", make_box(Color("1a1a28"), Color("3a3a50")))
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color("ffd23f"))
	t.set_color("font_pressed_color", "Button", Color("1a1a28"))
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))
	t.set_font_size("font_size", "Button", 30)

	t.set_stylebox("panel", "PanelContainer", make_box(Color(0.1, 0.1, 0.18, 0.88), Color("6c6f9c"), 3, 14, 12))
	return t


func make_label(text: String, size: int = 28, color: Color = Color.WHITE, outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_ui)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
	return l


func make_button(text: String, callback: Callable, min_size: Vector2 = Vector2(320, 64), font_size: int = 32) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(play_sfx.bind("ui_confirm", -6.0))
	b.pressed.connect(callback)
	return b
