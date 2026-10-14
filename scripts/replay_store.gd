class_name ReplayStore
extends RefCounted
## Penyimpanan & pengaturan REPLAY.
##   - Pengaturan replay disimpan di user://replay_settings.cfg (langsung tersimpan saat diubah, tanpa tombol SAVE).
##   - Setiap replay = 2 file di user://replays/:  <id>.meta (ringkasan kecil, dipakai daftar)  +  <id>.rpl (data rekaman, terkompresi).
## Semua fungsi static supaya bisa dipanggil dari mana saja (game.gd, menu.gd, replay.gd) tanpa autoload baru.

const DIR := "user://replays"
const SETTINGS_PATH := "user://replay_settings.cfg"
const FORMAT_VERSION := 1
const MAGIC := 0x42535250           # "BSRP"

# ---- pilihan pengaturan (indeks disimpan, bukan nilainya)
const QUALITY_NAMES: Array = ["ECO 20 FPS", "STANDARD 30 FPS", "SMOOTH 60 FPS"]
const QUALITY_HZ: Array = [20, 30, 60]
const LIMIT_NAMES: Array = ["5", "10", "20", "50", "100", "UNLIMITED"]
const LIMIT_VALUES: Array = [5, 10, 20, 50, 100, 0]
const SPEED_VALUES: Array = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0]
const SPEED_NAMES: Array = ["0.25x", "0.5x", "0.75x", "1x", "1.25x", "1.5x", "2x", "3x", "4x"]
const SKIP_NAMES: Array = ["5 SEC", "10 SEC", "15 SEC", "30 SEC"]
const SKIP_VALUES: Array = [5.0, 10.0, 15.0, 30.0]
const LEAD_NAMES: Array = ["OFF", "1 SEC", "2 SEC", "3 SEC", "5 SEC"]
const LEAD_VALUES: Array = [0.0, 1.0, 2.0, 3.0, 5.0]
const SORT_NAMES: Array = ["NEWEST", "OLDEST", "LONGEST"]

# ---- nilai pengaturan sekarang
static var enabled: bool = true               # REPLAY ON / OFF (hanya versus)
static var quality: int = 1                   # indeks QUALITY_*
static var keep_unfinished: bool = false      # simpan match yang ditinggalkan di tengah jalan
static var limit_idx: int = 2                 # indeks LIMIT_*
static var auto_delete: bool = true           # hapus replay terlama (yang tidak dikunci) kalau penuh
static var speed_idx: int = 3                 # kecepatan awal pemutar
static var skip_idx: int = 1                  # lompat maju / mundur
static var lead_idx: int = 2                  # lompat ke kill: mulai beberapa detik sebelum kill
static var show_markers: bool = true          # tanda kill di progress bar
static var show_hud: bool = true              # kartu pemain (darah, skor) saat menonton
static var autoplay: bool = false             # false = replay dibuka dalam keadaan JEDA (pemain menekan play sendiri); true = langsung putar
static var autohide_ui: bool = true           # kontrol menghilang kalau diam
static var play_sfx: bool = true              # suara efek di replay
static var play_music: bool = true            # musik di replay
static var sort_idx: int = 0                  # urutan daftar

static var _loaded: bool = false


# ================================================================== pengaturan
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	enabled = bool(cfg.get_value("rec", "enabled", enabled))
	quality = clampi(int(cfg.get_value("rec", "quality", quality)), 0, QUALITY_HZ.size() - 1)
	keep_unfinished = bool(cfg.get_value("rec", "keep_unfinished", keep_unfinished))
	limit_idx = clampi(int(cfg.get_value("rec", "limit_idx", limit_idx)), 0, LIMIT_VALUES.size() - 1)
	auto_delete = bool(cfg.get_value("rec", "auto_delete", auto_delete))
	speed_idx = clampi(int(cfg.get_value("play", "speed_idx", speed_idx)), 0, SPEED_VALUES.size() - 1)
	skip_idx = clampi(int(cfg.get_value("play", "skip_idx", skip_idx)), 0, SKIP_VALUES.size() - 1)
	lead_idx = clampi(int(cfg.get_value("play", "lead_idx", lead_idx)), 0, LEAD_VALUES.size() - 1)
	show_markers = bool(cfg.get_value("play", "show_markers", show_markers))
	show_hud = bool(cfg.get_value("play", "show_hud", show_hud))
	autoplay = bool(cfg.get_value("play", "autoplay2", autoplay))
	autohide_ui = bool(cfg.get_value("play", "autohide_ui", autohide_ui))
	play_sfx = bool(cfg.get_value("audio", "play_sfx", play_sfx))
	play_music = bool(cfg.get_value("audio", "play_music", play_music))
	sort_idx = clampi(int(cfg.get_value("list", "sort_idx", sort_idx)), 0, SORT_NAMES.size() - 1)


static func save_settings() -> void:
	ensure_loaded()                      # jangan pernah menimpa file dengan nilai default sebelum file dibaca
	var cfg := ConfigFile.new()
	cfg.set_value("rec", "enabled", enabled)
	cfg.set_value("rec", "quality", quality)
	cfg.set_value("rec", "keep_unfinished", keep_unfinished)
	cfg.set_value("rec", "limit_idx", limit_idx)
	cfg.set_value("rec", "auto_delete", auto_delete)
	cfg.set_value("play", "speed_idx", speed_idx)
	cfg.set_value("play", "skip_idx", skip_idx)
	cfg.set_value("play", "lead_idx", lead_idx)
	cfg.set_value("play", "show_markers", show_markers)
	cfg.set_value("play", "show_hud", show_hud)
	cfg.set_value("play", "autoplay2", autoplay)
	cfg.set_value("play", "autohide_ui", autohide_ui)
	cfg.set_value("audio", "play_sfx", play_sfx)
	cfg.set_value("audio", "play_music", play_music)
	cfg.set_value("list", "sort_idx", sort_idx)
	cfg.save(SETTINGS_PATH)


static func reset_settings() -> void:
	ensure_loaded()
	enabled = true
	quality = 1
	keep_unfinished = false
	limit_idx = 2
	auto_delete = true
	speed_idx = 3
	skip_idx = 1
	lead_idx = 2
	show_markers = true
	show_hud = true
	autoplay = false
	autohide_ui = true
	play_sfx = true
	play_music = true
	save_settings()


static func record_hz() -> int:
	return int(QUALITY_HZ[clampi(quality, 0, QUALITY_HZ.size() - 1)])


static func max_replays() -> int:
	ensure_loaded()
	return int(LIMIT_VALUES[clampi(limit_idx, 0, LIMIT_VALUES.size() - 1)])


static func skip_seconds() -> float:
	return float(SKIP_VALUES[clampi(skip_idx, 0, SKIP_VALUES.size() - 1)])


static func lead_seconds() -> float:
	return float(LEAD_VALUES[clampi(lead_idx, 0, LEAD_VALUES.size() - 1)])


static func default_speed() -> float:
	return float(SPEED_VALUES[clampi(speed_idx, 0, SPEED_VALUES.size() - 1)])


# ================================================================== file
static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)


static func _write_blob(path: String, d: Dictionary) -> bool:
	var raw: PackedByteArray = var_to_bytes(d)
	var comp: PackedByteArray = raw.compress(FileAccess.COMPRESSION_ZSTD)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_32(MAGIC)
	f.store_32(raw.size())
	f.store_buffer(comp)
	f.close()
	return true


static func _read_blob(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	if f.get_length() < 9 or f.get_32() != MAGIC:
		f.close()
		return {}
	var raw_size: int = f.get_32()
	var comp: PackedByteArray = f.get_buffer(f.get_length() - 8)
	f.close()
	var raw: PackedByteArray = comp.decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != raw_size:
		return {}
	var v: Variant = bytes_to_var(raw)
	if v is Dictionary:
		return v
	return {}


static func _new_id() -> String:
	return "%d_%03d" % [int(Time.get_unix_time_from_system()), randi() % 1000]


# ================================================================== simpan / muat
## Simpan satu replay. meta = ringkasan untuk daftar, data = isi rekaman. Mengembalikan id ("" kalau gagal).
static func save_replay(meta: Dictionary, data: Dictionary) -> String:
	_ensure_dir()
	var id: String = _new_id()
	meta["id"] = id
	meta["version"] = FORMAT_VERSION
	meta["created"] = int(Time.get_unix_time_from_system())
	meta["locked"] = false
	data["meta"] = meta
	if not _write_blob("%s/%s.rpl" % [DIR, id], data):
		return ""
	var f := FileAccess.open("%s/%s.rpl" % [DIR, id], FileAccess.READ)
	if f != null:
		meta["bytes"] = int(f.get_length())
		f.close()
	if not _write_blob("%s/%s.meta" % [DIR, id], meta):
		DirAccess.remove_absolute("%s/%s.rpl" % [DIR, id])
		return ""
	enforce_limit()
	return id


static func load_replay(id: String) -> Dictionary:
	return _read_blob("%s/%s.rpl" % [DIR, id])


static func list_replays() -> Array:
	ensure_loaded()
	_ensure_dir()
	var res: Array = []
	var d := DirAccess.open(DIR)
	if d == null:
		return res
	d.list_dir_begin()
	var fn: String = d.get_next()
	while fn != "":
		if not d.current_is_dir() and fn.ends_with(".meta"):
			var m: Dictionary = _read_blob("%s/%s" % [DIR, fn])
			if not m.is_empty() and FileAccess.file_exists("%s/%s.rpl" % [DIR, String(m.get("id", ""))]):
				res.append(m)
		fn = d.get_next()
	d.list_dir_end()
	match sort_idx:
		1:
			res.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["created"]) < int(b["created"]))
		2:
			res.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("duration", 0.0)) > float(b.get("duration", 0.0)))
		_:
			res.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["created"]) > int(b["created"]))
	return res


static func delete_replay(id: String) -> void:
	DirAccess.remove_absolute("%s/%s.rpl" % [DIR, id])
	DirAccess.remove_absolute("%s/%s.meta" % [DIR, id])


static func delete_all() -> void:
	for m in list_replays():
		delete_replay(String(m["id"]))


## Kunci / buka kunci replay (yang dikunci tidak ikut terhapus otomatis). Mengembalikan status baru.
static func toggle_lock(id: String) -> bool:
	var path: String = "%s/%s.meta" % [DIR, id]
	var m: Dictionary = _read_blob(path)
	if m.is_empty():
		return false
	m["locked"] = not bool(m.get("locked", false))
	_write_blob(path, m)
	return bool(m["locked"])


static func count() -> int:
	return list_replays().size()


static func total_bytes() -> int:
	var total: int = 0
	var d := DirAccess.open(DIR)
	if d == null:
		return 0
	d.list_dir_begin()
	var fn: String = d.get_next()
	while fn != "":
		if not d.current_is_dir():
			var f := FileAccess.open("%s/%s" % [DIR, fn], FileAccess.READ)
			if f != null:
				total += int(f.get_length())
				f.close()
		fn = d.get_next()
	d.list_dir_end()
	return total


static func format_bytes(b: int) -> String:
	if b < 1024:
		return "%d B" % b
	if b < 1024 * 1024:
		return "%.0f KB" % (float(b) / 1024.0)
	return "%.1f MB" % (float(b) / 1048576.0)


## True kalau sudah penuh DAN auto-delete mati (rekaman baru tidak boleh dimulai).
static func is_full_blocked() -> bool:
	var lim: int = max_replays()
	if lim <= 0 or auto_delete:
		return false
	return count() >= lim


## Hapus replay terlama yang tidak dikunci sampai jumlahnya <= batas.
static func enforce_limit() -> void:
	var lim: int = max_replays()
	if lim <= 0 or not auto_delete:
		return
	var all: Array = list_replays()
	if all.size() <= lim:
		return
	var old_first: Array = all.duplicate()
	old_first.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["created"]) < int(b["created"]))
	var over: int = all.size() - lim
	for m in old_first:
		if over <= 0:
			break
		if bool(m.get("locked", false)):
			continue
		delete_replay(String(m["id"]))
		over -= 1


# ================================================================== format tanggal & durasi
static func format_clock(sec: float) -> String:
	var s: int = int(maxf(sec, 0.0))
	return "%02d:%02d" % [s / 60, s % 60]


static func format_date(unix: int) -> String:
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60     # waktu lokal, bukan UTC
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unix + bias)
	return "%04d-%02d-%02d  %02d:%02d" % [int(dt["year"]), int(dt["month"]), int(dt["day"]), int(dt["hour"]), int(dt["minute"])]
