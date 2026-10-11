class_name CosmeticUI
extends Control
## Layar SHOP dan INVENTORY (satu basis kode, dua scene: shop.tscn & inventory.tscn).
##
## SHOP      : beli skin karakter / skin senjata / aksesoris dengan koin.
## INVENTORY : lihat koleksi (yang dimiliki & yang masih terkunci), pasang aksesoris per karakter + per skin,
##             lihat skin senjata, dan ganti skin PISTOL / PISAU (dua senjata ini tidak ada di layar pilih karakter).
##
## Navigasi (keyboard / controller / mouse):
##   atas/bawah = pindah baris (TAB -> pemilih -> kotak item)     kiri/kanan = ganti nilai / pindah kartu
##   prev / next (bahu) = ganti TAB     accept = beli / pasang     back = kembali ke menu

const W := 1280.0
const H := 720.0
const PANEL_X := 852.0
const GRID_X := 28.0
const GRID_W := 800.0
## Ruang kosong di sekeliling area grid. Kartu terpilih punya bingkai tebal, bayangan, dan efek "terangkat"
## yang keluar dari kotaknya; tanpa ruang ini bagian atas & kanan kartu terpotong oleh clip_contents.
const GRID_PAD := 12.0
const BOTTOM := 646.0
const SLOT_FILTERS := ["ALL", "HEAD", "FACE", "NECK", "BACK"]

var shop_mode: bool = true
var kinds: Array = []                 # urutan tab: "cskin" | "wskin" | "acc"
var tab: int = 0
var row: int = 0                      # 0 = tab, 1..n = pemilih, n+1 = grid
var cur: int = 0                      # kursor grid
var scroll: float = 0.0
var scroll_to: float = 0.0
var sel_char: int = 0
var sel_skin: int = 0                 # indeks di [""] + skin yang dimiliki (inventory > aksesoris)
var sel_weapon: int = 0
var stage: int = 0                   # 0 = pilih KARAKTER / SENJATA, 1 = daftar SKIN-nya (hanya tab cskin & wskin)
var sel_slot: int = 0                 # shop: 0 = ALL, 1..4 slot ; inventory: 0..3 slot
var t: float = 0.0
var coins_shown: float = 0.0
var coin_shake: float = 0.0
var stamp_t: float = 0.0
var stamp_text: String = ""
var leaving: bool = false

# --- animasi
var grid_t: float = -0.15             # waktu animasi kartu grid (negatif = tertunda)
var fly_mode: int = 0                 # 0 = naik dari bawah | 1 = meledak dari kartu terpilih | 2 = dibagikan dari atas
var fly_from: Vector2 = Vector2.ZERO  # titik asal animasi (koordinat layar)
var stage_t: float = 0.0              # waktu sejak masuk / keluar tahap
var panel_t: float = 1.0              # waktu animasi panel kanan (reset tiap item berganti)
var panel_key: String = ""
var tab_f: float = 0.0                # posisi sorotan tab (halus)
var tab_focus_f: float = 0.0          # 0..1 seberapa kuat sorotan tab (1 = kursor sedang di baris TAB)
var pill_f: float = 0.0               # posisi sorotan slot (halus)
var dlg_t: float = 0.0                # 0..1 progres animasi MASUK modal konfirmasi
var flash_t: float = 0.0
var flash_col: Color = Color.WHITE
var trans_active: bool = false        # sedang transisi masuk / keluar karakter-senjata (input dikunci)
var trans_t: float = 0.0
var trans_kind: String = ""           # "enter" | "exit"
var trans_pick: int = -1
var trans_origin: Vector2 = Vector2.ZERO
var trans_it: Dictionary = {}
var dlg_layer: Control

# --- modal konfirmasi beli
const DLG_W := 640.0
const DLG_H := 372.0
var dlg_open: bool = false            # true selama modal tampil (termasuk animasi keluar)
var dlg_yes: bool = true              # pilihan yang sedang disorot: true = BELI, false = BATAL
var dlg_item: Dictionary = {}
var dlg_closing: bool = false         # animasi keluar sedang jalan (input dikunci)
var dlg_result: bool = false          # jawaban terakhir (true = jadi beli)
var dlg_out: float = 0.0              # 0..1 progres animasi keluar
var dlg_close_dur: float = 0.24
var dlg_age: float = 0.0              # detik sejak modal dibuka (untuk animasi bertahap & jeda anti salah tekan)
var dlg_sel_f: float = 0.0            # sorotan tombol yang meluncur halus (0 = BELI, 1 = BATAL)
var dlg_bal: int = 0                  # saldo koin saat modal dibuka (tidak ikut berubah saat animasi keluar)
var dlg_prompt: UIKit.PromptBar

var bg: UIKit.FxBackground
var grid: GridView
var action_btn: UIKit.FancyButton
var back_btn: UIKit.FancyButton
var prompt: UIKit.PromptBar
var _hits: Array = []
var _items_cache: Array = []
var _intro: float = 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	theme = Global.ui_theme
	Global.play_music("menu")
	kinds = ["cskin", "wskin", "acc"] if shop_mode else ["char", "wskin"]
	var sf: Dictionary = CampaignData.saved_fighter()
	if not sf.is_empty():
		sel_char = int(sf["character"])
	coins_shown = float(Cosmetics.coins())

	bg = UIKit.FxBackground.new()
	bg.show_behind_parent = true      # latar digambar DI BELAKANG gambar layar ini (header, tab, panel)
	add_child(bg)
	if shop_mode:
		bg.set_palette(Color("1a1004"), Color("3a1a08"), Color("ffcd3c"), 0.0)
	else:
		bg.set_palette(Color("060a20"), Color("1a0a38"), Color("8a6cff"), 0.0)

	grid = GridView.new()
	grid.ui = self
	grid.position = Vector2(GRID_X - GRID_PAD, 200.0 - GRID_PAD)
	add_child(grid)

	action_btn = UIKit.FancyButton.new("", Vector2(366, 54), 28)
	action_btn.position = Vector2(PANEL_X + 22.0, 574.0)
	action_btn.activated.connect(_on_action)
	add_child(action_btn)

	back_btn = UIKit.FancyButton.new("BACK", Vector2(190, 46), 28)
	back_btn.position = Vector2(10, 662)
	back_btn.accent = Color("ff7a7a")
	back_btn.activated.connect(_go_back)
	back_btn.modulate.a = 0.85
	add_child(back_btn)

	prompt = UIKit.make_prompt(self)

	dlg_layer = DlgLayer.new()
	dlg_layer.ui = self
	dlg_layer.visible = false
	add_child(dlg_layer)
	dlg_prompt = UIKit.make_prompt(dlg_layer)
	dlg_prompt.set_prompts([[&"dpad", "CHOOSE"], [&"none", "ACCEPT = CONFIRM"], [&"back", "CANCEL"]])

	UIInput.pressed.connect(_on_input)
	cur = 0                           # daftar karakter / senjata selalu mulai dari paling atas
	_update_prompt()
	_relayout()
	set_process(true)


func _exit_tree() -> void:
	if UIInput.pressed.is_connected(_on_input):
		UIInput.pressed.disconnect(_on_input)


# ------------------------------------------------------------------ data tab
func kind() -> String:
	return String(kinds[tab])


## True kalau tab aktif punya dua tahap (pilih karakter/senjata dulu, baru skin-nya).
func is_two_stage() -> bool:
	return kind() == "cskin" or kind() == "wskin" or kind() == "char"


## Grid berisi aksesoris (tab ACCESSORIES di shop, atau di dalam karakter pada INVENTORY).
func is_acc_grid() -> bool:
	return kind() == "acc" or (kind() == "char" and stage == 2)


## True kalau sekarang sedang di tahap memilih karakter / senjata (belum masuk ke skin).
func picking() -> bool:
	return is_two_stage() and stage == 0


## Indeks kursor di daftar pilihan karakter/senjata (supaya kursor kembali ke yang tadi dipilih).
func _pick_cursor() -> int:
	match kind():
		"cskin", "char": return sel_char
		"wskin": return sel_weapon
	return 0


func _update_prompt() -> void:
	if prompt == null:
		return
	var acc_txt: String = "BUY" if shop_mode else "EQUIP"
	if picking():
		acc_txt = "OPEN"
	elif kind() == "char" and stage == 1:
		acc_txt = "CUSTOMIZE"
	prompt.set_prompts([[&"dpad", "MOVE"], [&"none", "ACCEPT = %s" % acc_txt],
		[&"none", "L / R = TAB"], [&"back", "BACK TO LIST" if (is_two_stage() and stage >= 1) else "BACK"]])


func tab_title(k: String) -> String:
	match k:
		"cskin": return "CHARACTER SKINS"
		"char": return "CHARACTERS"
		"wskin": return "WEAPON SKINS"
	return "ACCESSORIES"


## Nama baris pemilih untuk tab aktif.
func sel_names() -> Array:
	match kind():
		"cskin", "wskin": return []        # tidak ada pemilih geser kiri/kanan: pilih lewat kotak karakter / senjata
		"char": return ["SLOT"] if stage == 2 else []   # INVENTORY: tahap 1 = daftar skin, tahap 2 = kustomisasi aksesoris
	if shop_mode:
		return ["TYPE"]
	return ["CHARACTER", "SKIN", "SLOT"]


func grid_row() -> int:
	return 1 + sel_names().size()


func cur_weapon() -> String:
	return String(Cosmetics.WEAPON_IDS[sel_weapon])


## Semua id skin karakter (urutan: DEFAULT, lalu semua skin; yang belum dimiliki tampil terkunci).
func skin_ids() -> Array:
	var out: Array = [""]
	for sk in CosmeticsData.CHAR_SKINS:
		out.append(String(sk[0]))
	return out


func cur_skin_id() -> String:
	var opts: Array = skin_ids()
	return String(opts[clampi(sel_skin, 0, opts.size() - 1)])


func skin_locked() -> bool:
	var sid: String = cur_skin_id()
	return sid != "" and not Cosmetics.owns_skin(sel_char, sid)


## Item yang ditampilkan di panel kanan (di baris daftar skin = skin yang disorot).
func panel_item() -> Dictionary:
	return cur_item()


func _repop() -> void:
	grid_t = 0.0
	fly_mode = 0


func sel_text(i: int) -> String:
	if i < 0:
		var sid0: String = cur_skin_id()
		return "DEFAULT" if sid0 == "" else String(Cosmetics.char_skin_info(sid0)[1])
	var nm: String = String(sel_names()[i])
	match nm:
		"CHARACTER": return Global.character_name(0, sel_char)
		"WEAPON": return String(Global.WEAPONS[cur_weapon()]["name"])
		"TYPE": return String(SLOT_FILTERS[sel_slot])
		"SKIN":
			var sid: String = cur_skin_id()
			return "DEFAULT" if sid == "" else String(Cosmetics.char_skin_info(sid)[1])
		"SLOT": return String(Cosmetics.SLOT_NAMES[Cosmetics.SLOTS[sel_slot]])
	return ""


func sel_step(i: int, dir: int) -> void:
	var nm: String = String(sel_names()[i])
	match nm:
		"CHARACTER":
			sel_char = posmod(sel_char + dir, Global.character_count())
			sel_skin = 0
		"WEAPON":
			sel_weapon = posmod(sel_weapon + dir, Cosmetics.WEAPON_IDS.size())
		"TYPE":
			sel_slot = posmod(sel_slot + dir, SLOT_FILTERS.size())
		"SKIN":
			sel_skin = posmod(sel_skin + dir, skin_ids().size())
		"SLOT":
			sel_slot = posmod(sel_slot + dir, Cosmetics.SLOTS.size())
	if nm != "SKIN":
		cur = 0
		scroll_to = 0.0
		_repop()
	Global.play_sfx("ui_move", -10.0)
	_refresh()


## Daftar item untuk grid saat ini.
func items() -> Array:
	return _items_cache


func _build_items() -> Array:
	var out: Array = []
	if picking():
		if kind() == "cskin" or kind() == "char":
			for i in Global.character_count():
				out.append({"kind": "pchar", "id": "", "ch": i, "name": Global.character_name(0, i), "rarity": "common", "price": 0,
					"owned": true, "have": Cosmetics.owned_skin_ids(i).size(), "total": Cosmetics.char_skin_count()})
		else:
			for w in Cosmetics.WEAPON_IDS:
				var wid: String = String(w)
				out.append({"kind": "pweapon", "id": "", "w": wid, "name": String(Global.WEAPONS[wid]["name"]), "rarity": "common", "price": 0,
					"owned": true, "have": Cosmetics.owned_wskin_ids(wid).size(), "total": Cosmetics.weapon_skin_list(wid).size()})
		return out
	if kind() == "char" and stage == 1:
		# INVENTORY, di dalam karakter: semua skin (yang belum dimiliki tampil terkunci)
		for sid0 in skin_ids():
			var sid1: String = String(sid0)
			var inf: Array = [] if sid1 == "" else Cosmetics.char_skin_info(sid1)
			out.append({"kind": "cskin", "id": sid1, "name": "DEFAULT" if sid1 == "" else String(inf[1]),
				"rarity": "common" if sid1 == "" else String(inf[2]), "price": 0 if sid1 == "" else int(inf[3]),
				"owned": sid1 == "" or Cosmetics.owns_skin(sel_char, sid1), "ch": sel_char})
		return out
	match kind():
		"cskin":
			for s in CosmeticsData.CHAR_SKINS:
				var sid: String = String(s[0])
				out.append({"kind": "cskin", "id": sid, "name": String(s[1]), "rarity": String(s[2]), "price": int(s[3]),
					"owned": Cosmetics.owns_skin(sel_char, sid), "ch": sel_char})
		"wskin":
			var w: String = cur_weapon()
			if not shop_mode and (w == "pistol" or w == "knife"):
				out.append({"kind": "wskin", "id": "", "name": "DEFAULT", "rarity": "common", "price": 0, "owned": true, "w": w,
					"equipped": Cosmetics.equipped_extra(w) == ""})
			for s in Cosmetics.weapon_skin_list(w):
				var sid2: String = String(s[0])
				out.append({"kind": "wskin", "id": sid2, "name": String(s[1]), "rarity": String(s[2]), "price": int(s[3]),
					"owned": Cosmetics.owns_wskin(w, sid2), "w": w,
					"equipped": (w == "pistol" or w == "knife") and Cosmetics.equipped_extra(w) == sid2})
		"acc", "char":
			var lo: Dictionary = {}
			if not shop_mode:
				lo = Cosmetics.loadout(sel_char, cur_skin_id())
				out.append({"kind": "acc", "id": "", "name": "NONE", "rarity": "common", "price": 0, "owned": true,
					"slot": String(Cosmetics.SLOTS[sel_slot]), "equipped": not lo.has(String(Cosmetics.SLOTS[sel_slot])), "none": true})
			for a in CosmeticsData.ACCESSORIES:
				var slot: String = String(a[2])
				if shop_mode and sel_slot > 0 and slot != String(Cosmetics.SLOTS[sel_slot - 1]):
					continue
				if not shop_mode and slot != String(Cosmetics.SLOTS[sel_slot]):
					continue
				var aid: String = String(a[0])
				out.append({"kind": "acc", "id": aid, "name": String(a[1]), "rarity": String(a[4]), "price": int(a[3]),
					"owned": Cosmetics.owns_acc(aid), "slot": slot, "equipped": lo.get(slot, "") == aid})
	return out


func _refresh() -> void:
	_items_cache = _build_items()
	cur = clampi(cur, 0, maxi(_items_cache.size() - 1, 0))
	_relayout()
	queue_redraw()


func cols() -> int:
	return 6 if is_acc_grid() else 5


func card_size() -> Vector2:
	return Vector2(124, 150) if is_acc_grid() else Vector2(150, 196)


## Jumlah baris di atas grid: pemilih (tab aksesoris) atau satu bar "BACK + nama" saat di dalam karakter/senjata.
func bar_count() -> int:
	if is_two_stage():
		return 1 if stage >= 1 else 0
	return sel_names().size()


func grid_top() -> float:
	if kind() == "char" and stage == 2:
		return 226.0
	return 138.0 + float(bar_count()) * 40.0 + 6.0


func _relayout() -> void:
	_items_cache = _build_items()
	if grid != null:
		grid.position = Vector2(GRID_X - GRID_PAD, grid_top() - GRID_PAD)
		grid.size = Vector2(GRID_W + GRID_PAD * 2.0, BOTTOM - grid_top() + GRID_PAD * 2.0)
		grid.queue_redraw()
	_update_action_btn()


func cur_item() -> Dictionary:
	if _items_cache.is_empty():
		return {}
	return _items_cache[clampi(cur, 0, _items_cache.size() - 1)]


func _update_action_btn() -> void:
	if action_btn == null:
		return
	var it: Dictionary = cur_item()
	if it.is_empty():
		action_btn.visible = false
		return
	action_btn.visible = true
	action_btn.disabled = false
	action_btn.accent = UIKit.GOLD
	if picking():
		action_btn.text = "VIEW SKINS"
		action_btn.accent = UIKit.CYAN
		action_btn.queue_redraw()
		return
	if kind() == "char" and stage == 1 and not shop_mode:
		if bool(it["owned"]):
			action_btn.text = "CUSTOMIZE"
			action_btn.accent = UIKit.CYAN
		else:
			action_btn.text = "LOCKED"
			action_btn.disabled = true
		action_btn.queue_redraw()
		return
	var owned: bool = bool(it["owned"])
	if shop_mode:
		if owned:
			action_btn.text = "OWNED"
			action_btn.disabled = true
			action_btn.accent = UIKit.GREEN
		else:
			var pr: int = int(it["price"])
			action_btn.text = "BUY   %s" % _fmt(pr)
			if not Cosmetics.can_afford(pr):
				action_btn.accent = Color("ff7a7a")
	else:
		var k: String = kind()
		if not owned:
			action_btn.text = "LOCKED"
			action_btn.disabled = true
		elif k == "acc" or k == "char":
			action_btn.text = "UNEQUIP" if bool(it.get("equipped", false)) and not bool(it.get("none", false)) else ("EQUIPPED" if bool(it.get("none", false)) and bool(it["equipped"]) else "EQUIP")
			if bool(it.get("none", false)) and bool(it["equipped"]):
				action_btn.disabled = true
			action_btn.accent = UIKit.GREEN if bool(it.get("equipped", false)) else UIKit.GOLD
		elif k == "wskin":
			var w: String = String(it.get("w", ""))
			if w == "pistol" or w == "knife":
				action_btn.text = "EQUIPPED" if bool(it.get("equipped", false)) else "EQUIP"
				action_btn.disabled = bool(it.get("equipped", false))
				action_btn.accent = UIKit.GREEN if bool(it.get("equipped", false)) else UIKit.GOLD
			else:
				action_btn.text = "OWNED"
				action_btn.disabled = true
				action_btn.accent = UIKit.GREEN
		else:
			action_btn.text = "CUSTOMIZE"
			action_btn.accent = UIKit.CYAN
	action_btn.queue_redraw()


func _fmt(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	var c: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


# ------------------------------------------------------------------ input
func _on_input(_source: int, action: StringName) -> void:
	if leaving or trans_active:
		return
	if dlg_open:
		if dlg_closing:
			return
		match action:
			&"left":
				_dlg_select(true)
			&"right":
				_dlg_select(false)
			&"up", &"down":
				_dlg_select(not dlg_yes)
			&"accept", &"fire":
				if dlg_age >= 0.3:        # jeda singkat: tekan accept 2x cepat tidak langsung membeli
					_dialog_answer(dlg_yes)
			&"back":
				_dialog_answer(false)
		return
	match action:
		&"up":
			_move_row(-1)
		&"down":
			_move_row(1)
		&"left":
			_move_h(-1)
		&"right":
			_move_h(1)
		&"prev":
			_set_tab(posmod(tab - 1, kinds.size()))
		&"next":
			_set_tab(posmod(tab + 1, kinds.size()))
		&"accept":
			if row == grid_row():
				_activate()
			elif kind() == "char" and stage == 2 and row > 0:
				row = grid_row()
				Global.play_sfx("ui_hover", -9.0)
				_update_action_btn()
				queue_redraw()
			else:
				_move_row(1)
		&"back":
			_go_back()


func _move_row(dir: int) -> void:
	var gr: int = grid_row()
	if row == gr:
		var c: int = cols()
		var nc: int = cur + dir * c
		if dir < 0 and cur < c:
			row = gr - 1
			Global.play_sfx("ui_hover", -9.0)
		elif dir > 0:
			if nc >= _items_cache.size():
				# baris terakhir tidak penuh: tetap bisa turun ke item terakhir kalau barisnya berbeda
				if cur / c < (_items_cache.size() - 1) / c:
					nc = _items_cache.size() - 1
				else:
					return
			cur = nc
			Global.play_sfx("ui_move", -12.0)
		else:
			cur = nc
			Global.play_sfx("ui_move", -12.0)
	else:
		var nr: int = clampi(row + dir, 0, gr)
		if nr != row:
			row = nr
			Global.play_sfx("ui_hover", -9.0)
	_follow_cursor()
	_update_action_btn()
	queue_redraw()


func _move_h(dir: int) -> void:
	if row == 0:
		_set_tab(posmod(tab + dir, kinds.size()))
	elif row < grid_row():
		sel_step(row - 1, dir)
	else:
		if _items_cache.is_empty():
			return
		var nc: int = clampi(cur + dir, 0, _items_cache.size() - 1)
		if nc != cur:
			cur = nc
			Global.play_sfx("ui_move", -12.0)
			_follow_cursor()
			_update_action_btn()
	queue_redraw()


func _set_tab(i: int) -> void:
	if trans_active:
		return
	if i == tab:
		if stage >= 1:
			_exit_stage()
		return
	tab = i
	stage = 0
	cur = 0                           # pindah tab: kursor selalu mulai dari item paling atas
	scroll = 0.0
	scroll_to = 0.0
	row = clampi(row, 0, grid_row())
	Global.play_sfx("ui_hover", -7.0)
	_refresh()
	_follow_cursor()
	scroll = scroll_to
	_repop()
	grid_t = -0.05
	stage_t = 0.0
	panel_t = 0.0
	_update_prompt()


func _card_rect_local(i: int) -> Rect2:
	var cs: Vector2 = card_size()
	var c: int = cols()
	return Rect2(Vector2(float(i % c) * (cs.x + 12.0), float(i / c) * (cs.y + 12.0) - scroll), cs)


## Mulai transisi masuk: semua kartu tersedot ke kartu yang dipilih, lalu skin-nya meledak keluar dari situ.
func _enter_stage(it: Dictionary) -> void:
	if trans_active:
		return
	trans_active = true
	trans_t = 0.0
	trans_kind = "enter"
	trans_pick = cur
	trans_it = it
	trans_origin = grid.position + Vector2(GRID_PAD, GRID_PAD) + _card_rect_local(cur).get_center()
	Global.play_sfx("ui_confirm", -8.0)
	Global.play_sfx("ui_whoosh", -9.0, 0.9)


func _finish_enter() -> void:
	var it: Dictionary = trans_it
	var k: String = String(it["kind"])
	if k == "pchar":
		sel_char = int(it["ch"])
		sel_skin = 0
		if not shop_mode:
			sel_skin = maxi(skin_ids().find(Cosmetics.last_cskin(sel_char)), 0)
		stage = 1
	elif k == "pweapon":
		sel_weapon = maxi(Cosmetics.WEAPON_IDS.find(String(it["w"])), 0)
		stage = 1
	else:
		# "cskin" (INVENTORY): masuk ke mode kustomisasi aksesoris untuk skin ini
		sel_skin = maxi(skin_ids().find(String(it["id"])), 0)
		sel_slot = 0
		pill_f = 0.0
		stage = 2
	cur = sel_skin if (kind() == "char" and stage == 1) else 0
	scroll = 0.0
	scroll_to = 0.0
	row = grid_row()
	grid_t = -0.1 if stage == 2 else 0.0
	fly_mode = 1
	fly_from = trans_origin
	stage_t = 0.0
	panel_t = 0.0
	flash_t = 1.0
	flash_col = UIKit.CYAN
	_refresh()
	if kind() == "char" and stage == 1:
		_follow_cursor()
		scroll = scroll_to
	_update_prompt()
	UIKit.ring(self, trans_origin, UIKit.CYAN, 210.0, 0.55)
	UIKit.ring(self, trans_origin, UIKit.GOLD, 120.0, 0.4)
	UIKit.burst(self, trans_origin, UIKit.GOLD, 26, 340.0)


## Mulai transisi keluar: skin menyusut ke tombol BACK, lalu daftar karakter / senjata "dibagikan" dari atas.
func _exit_stage() -> void:
	if trans_active:
		return
	trans_active = true
	trans_t = 0.0
	trans_kind = "exit"
	trans_pick = -1
	trans_origin = Vector2(GRID_X + 40.0, 155.0)
	Global.play_sfx("ui_back", -8.0)
	Global.play_sfx("ui_whoosh", -11.0, 1.3)


func _finish_exit() -> void:
	if kind() == "char" and stage == 2:
		stage = 1                     # dari kustomisasi balik ke daftar skin
		cur = sel_skin
	else:
		stage = 0
		cur = _pick_cursor()
	scroll = 0.0
	scroll_to = 0.0
	row = grid_row()
	grid_t = 0.0
	fly_mode = 2
	fly_from = trans_origin
	stage_t = 0.0
	panel_t = 0.0
	flash_t = 0.8
	flash_col = Color("ffffff")
	_refresh()
	_follow_cursor()
	scroll = scroll_to
	_update_prompt()
	UIKit.ring(self, trans_origin, Color(1, 1, 1, 0.9), 150.0, 0.45)


func _follow_cursor() -> void:
	var cs: Vector2 = card_size()
	var r: int = cur / cols()
	var top: float = float(r) * (cs.y + 12.0)
	var view_h: float = BOTTOM - grid_top()
	if top < scroll_to:
		scroll_to = top
	elif top + cs.y > scroll_to + view_h:
		scroll_to = top + cs.y - view_h + 6.0
	scroll_to = maxf(scroll_to, 0.0)


func _activate() -> void:
	var it: Dictionary = cur_item()
	if it.is_empty():
		return
	if picking():
		_enter_stage(it)
		return
	if kind() == "char" and stage == 1:
		if bool(it["owned"]):
			_enter_stage(it)              # tombol CUSTOMIZE -> panel aksesoris
		else:
			_deny("SKIN LOCKED", "Buy this skin in the SHOP")
		return
	if shop_mode:
		if bool(it["owned"]):
			Global.play_sfx("ui_error", -12.0)
			return
		var pr: int = int(it["price"])
		if not Cosmetics.can_afford(pr):
			_deny("NOT ENOUGH COINS", "You need %s more" % _fmt(pr - Cosmetics.coins()))
			return
		_open_dialog(it)
		return
	# ---- inventory
	if kind() == "char" and skin_locked():
		_deny("SKIN LOCKED", "Buy this skin in the SHOP")
		return
	if not bool(it["owned"]):
		_deny("LOCKED", "Buy it in the SHOP")
		return
	var k: String = kind()
	if k == "acc" or k == "char":
		var sid: String = cur_skin_id()
		var slot: String = String(it["slot"])
		if bool(it.get("none", false)):
			Cosmetics.set_acc(sel_char, sid, slot, "")
		elif bool(it.get("equipped", false)):
			Cosmetics.set_acc(sel_char, sid, slot, "")
		else:
			Cosmetics.set_acc(sel_char, sid, slot, String(it["id"]))
			stamp("EQUIPPED")
		Global.play_sfx("ui_confirm", -6.0)
		_burst_preview(Color("4fd8ff"))
		_refresh()
	elif k == "wskin":
		var w: String = String(it.get("w", ""))
		if w == "pistol" or w == "knife":
			Cosmetics.set_equipped_extra(w, String(it["id"]))
			Global.play_sfx("ui_confirm", -6.0)
			stamp("EQUIPPED")
			_burst_preview(Color("ffcd3c"))
			_refresh()
		else:
			UIInput.toast("PICK IT IN FIGHTER SELECT", "%s skins are chosen after you pick the weapon" % String(Global.WEAPONS[w]["name"]), UIKit.GOLD)


func _deny(title: String, sub: String) -> void:
	Global.play_sfx("ui_error", -6.0)
	coin_shake = 1.0
	UIInput.toast(title, sub, Color("ff7a7a"))


## Buka modal "yakin beli?" untuk item `it`. Belum ada koin yang dipotong sampai pemain menekan YES.
func _open_dialog(it: Dictionary) -> void:
	dlg_item = it
	dlg_yes = true
	dlg_sel_f = 0.0
	dlg_age = 0.0
	dlg_t = 0.0
	dlg_out = 0.0
	dlg_closing = false
	dlg_result = false
	dlg_bal = Cosmetics.coins()
	dlg_open = true
	dlg_layer.visible = true
	dlg_layer.modulate.a = 0.0
	if prompt != null and prompt.get_parent() != null:
		prompt.get_parent().visible = false
	Global.play_sfx("ui_panel", -6.0)
	Global.play_sfx("ui_whoosh", -14.0, 1.25)


## Posisi tetap kartu & tombol modal (dipakai untuk menggambar DAN untuk klik mouse).
func _dlg_geom() -> Dictionary:
	var box := Rect2((W - DLG_W) * 0.5, (H - DLG_H) * 0.5, DLG_W, DLG_H)
	var by: float = box.position.y + 296.0
	return {"box": box, "yes": Rect2(box.position.x + 35.0, by, 265.0, 54.0), "no": Rect2(box.position.x + 324.0, by, 265.0, 54.0)}


## Mouse saat modal tampil: kursor menyorot tombol, klik = pilih, klik di luar kartu = batal.
func _dlg_mouse(event: InputEvent) -> void:
	if dlg_closing:
		return
	var g: Dictionary = _dlg_geom()
	if event is InputEventMouseMotion:
		var mp: Vector2 = (event as InputEventMouseMotion).position
		if (g["yes"] as Rect2).has_point(mp):
			_dlg_select(true)
		elif (g["no"] as Rect2).has_point(mp):
			_dlg_select(false)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (event as InputEventMouseButton).position
		if (g["yes"] as Rect2).has_point(p):
			if dlg_age >= 0.3:
				dlg_yes = true
				_dialog_answer(true)
		elif (g["no"] as Rect2).has_point(p) or not (g["box"] as Rect2).has_point(p):
			dlg_yes = false
			_dialog_answer(false)


func _dlg_select(yes: bool) -> void:
	if dlg_yes == yes:
		return
	dlg_yes = yes
	Global.play_sfx("ui_move", -10.0, 1.15 if yes else 0.9)


## Dipanggil setelah animasi keluar selesai.
func _finish_dialog() -> void:
	dlg_open = false
	dlg_closing = false
	dlg_out = 0.0
	dlg_t = 0.0
	if dlg_layer != null:
		dlg_layer.visible = false
		dlg_layer.modulate.a = 1.0
	if prompt != null and prompt.get_parent() != null:
		prompt.get_parent().visible = true
	_update_action_btn()
	queue_redraw()


func _dialog_answer(yes: bool) -> void:
	if dlg_closing or not dlg_open:
		return
	dlg_closing = true
	dlg_out = 0.0
	dlg_result = yes
	dlg_close_dur = 0.34 if yes else 0.22
	if not yes:
		Global.play_sfx("ui_back", -8.0)
		return
	var it: Dictionary = dlg_item
	var ok: bool = false
	match String(it["kind"]):
		"cskin":
			ok = Cosmetics.buy_skin(int(it["ch"]), String(it["id"]))
		"wskin":
			ok = Cosmetics.buy_wskin(String(it["w"]), String(it["id"]))
		"acc":
			ok = Cosmetics.buy_acc(String(it["id"]))
	if ok:
		Global.play_synth("coin", -4.0, 1.0)
		Global.play_sfx("ui_marimba", -6.0, 1.2)
		stamp("PURCHASED!")
		var col: Color = Cosmetics.rarity_color(String(it["rarity"]))
		_burst_preview(col)
		UIKit.ring(self, Vector2(PANEL_X + 205.0, 300.0), col, 190.0, 0.6)
		# ledakan koin dari tengah modal
		var mc := Vector2(W * 0.5, H * 0.5)
		UIKit.burst(self, mc, UIKit.GOLD, 34, 480.0, 7.0, 0.9)
		UIKit.ring(self, mc, UIKit.GOLD, 260.0, 0.55)
		UIInput.rumble(-1, 0.3, 0.6, 0.25)
	else:
		_deny("PURCHASE FAILED", "Not enough coins")
	_refresh()


func stamp(text: String) -> void:
	stamp_text = text
	stamp_t = 1.0


func _burst_preview(col: Color) -> void:
	panel_t = 0.0
	UIKit.burst(self, Vector2(PANEL_X + 205.0, 300.0), col, 30, 380.0)


func _on_action() -> void:
	if dlg_open or leaving or trans_active:
		return
	if kind() == "char" and stage == 2 and row < grid_row():
		row = grid_row()
		Global.play_sfx("ui_hover", -9.0)
		_update_action_btn()
		return
	row = grid_row()
	_activate()


func _go_back() -> void:
	if leaving or trans_active:
		return
	if dlg_open:
		_dialog_answer(false)
		return
	if is_two_stage() and stage >= 1:
		_exit_stage()
		return
	leaving = true
	Global.play_sfx("ui_back", -5.0)
	Global.goto("menu")


# ------------------------------------------------------------------ mouse
func _gui_input(event: InputEvent) -> void:
	if leaving or trans_active:
		return
	if dlg_open:
		_dlg_mouse(event)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (event as InputEventMouseButton).position
		for h in _hits:
			if (h["rect"] as Rect2).has_point(p):
				_on_hit(String(h["type"]), int(h["a"]))
				return
	elif event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var d: float = -60.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 60.0
		var cs: Vector2 = card_size()
		var rows_n: int = (_items_cache.size() + cols() - 1) / cols()
		var max_s: float = maxf(float(rows_n) * (cs.y + 12.0) - (BOTTOM - grid_top()), 0.0)
		scroll_to = clampf(scroll_to + d, 0.0, max_s)


func _on_hit(type: String, a: int) -> void:
	if dlg_open:
		return
	match type:
		"tab":
			row = 0
			_set_tab(a)
		"crumb":
			_exit_stage()
		"slot":
			row = 1
			if a != sel_slot:
				sel_slot = a
				cur = 0
				scroll_to = 0.0
				_repop()
				Global.play_sfx("ui_move", -10.0)
				_refresh()
		"sel_l":
			row = a + 1
			sel_step(a, -1)
		"sel_r":
			row = a + 1
			sel_step(a, 1)
		"card":
			row = grid_row()
			if a == cur:
				_activate()
			else:
				cur = a
				Global.play_sfx("ui_move", -12.0)
				_update_action_btn()
	queue_redraw()


# ------------------------------------------------------------------ frame
func _process(d: float) -> void:
	t += d
	_intro = minf(_intro + d, 2.0)
	if trans_active:
		trans_t += d / (0.26 if trans_kind == "enter" else 0.2)
		if trans_t >= 1.0:
			trans_t = 1.0
			trans_active = false
			if trans_kind == "enter":
				_finish_enter()
			else:
				_finish_exit()
	else:
		grid_t += d
	stage_t += d
	panel_t += d
	flash_t = maxf(flash_t - d * 2.6, 0.0)
	_tick_dialog(d)
	tab_f = lerpf(tab_f, float(tab), minf(1.0, d * 14.0))
	tab_focus_f = lerpf(tab_focus_f, 1.0 if (row == 0 and not dlg_open) else 0.0, minf(1.0, d * 12.0))
	pill_f = lerpf(pill_f, float(sel_slot), minf(1.0, d * 14.0))
	_track_panel()
	if dlg_layer != null:
		dlg_layer.queue_redraw()
	var target: float = float(Cosmetics.coins())
	coins_shown = lerpf(coins_shown, target, minf(1.0, d * 7.0))
	if absf(coins_shown - target) < 0.6:
		coins_shown = target
	coin_shake = maxf(coin_shake - d * 2.5, 0.0)
	stamp_t = maxf(stamp_t - d * 0.8, 0.0)
	scroll = lerpf(scroll, scroll_to, minf(1.0, d * 14.0))
	if absf(scroll - scroll_to) < 0.4:
		scroll = scroll_to
	action_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE if dlg_open else Control.MOUSE_FILTER_STOP
	queue_redraw()
	if grid != null:
		grid.queue_redraw()


## Animasi modal konfirmasi: masuk (bertahap), sorotan tombol meluncur, lalu keluar.
func _tick_dialog(d: float) -> void:
	if not dlg_open:
		dlg_t = 0.0
		return
	dlg_age += d
	dlg_t = clampf(dlg_age / 0.45, 0.0, 1.0)
	dlg_sel_f = lerpf(dlg_sel_f, 0.0 if dlg_yes else 1.0, minf(1.0, d * 16.0))
	var fade: float = CosmeticUI.ease_out(clampf(dlg_age / 0.2, 0.0, 1.0))
	if dlg_closing:
		dlg_out += d / maxf(dlg_close_dur, 0.05)
		fade = 1.0 - CosmeticUI.ease_in(clampf(dlg_out, 0.0, 1.0))
		if dlg_out >= 1.0:
			_finish_dialog()
			return
	if dlg_layer != null:
		dlg_layer.modulate.a = fade


## Pantau item panel: tiap item berganti, animasi "pop" panel diulang.
func _track_panel() -> void:
	var it: Dictionary = panel_item()
	var key: String = "%s|%s|%s|%s|%s|%d|%d|%d" % [String(it.get("kind", "")), String(it.get("id", "")), str(it.get("ch", -1)),
		String(it.get("w", "")), String(it.get("slot", "")), sel_skin, sel_char, stage]
	if key != panel_key:
		panel_key = key
		panel_t = 0.0


static func ease_in(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	return c * c


static func ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


static func back(x: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	var u: float = clampf(x, 0.0, 1.0) - 1.0
	return 1.0 + c3 * u * u * u + c1 * u * u


static func draw_coin(ci: CanvasItem, c: Vector2, s: float, tm: float = 0.0, spin: bool = false, alpha: float = 1.0) -> void:
	var tex: Texture2D = Cosmetics.coin_tex()
	if tex == null:
		ci.draw_circle(c, s * 0.5, Color("ffcd3c", alpha))
		return
	var wv: float = s * (maxf(absf(cos(tm * 3.0)), 0.2) if spin else 1.0)
	ci.draw_texture_rect(tex, Rect2(c.x - wv * 0.5, c.y - s * 0.5, wv, s), false, Color(1, 1, 1, alpha))


func _sparkle(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.22, -r * 0.22), c + Vector2(r, 0), c + Vector2(r * 0.22, r * 0.22),
		c + Vector2(0, r), c + Vector2(-r * 0.22, r * 0.22), c + Vector2(-r, 0), c + Vector2(-r * 0.22, -r * 0.22)])
	draw_colored_polygon(pts, col)


func _draw() -> void:
	_hits.clear()
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.18))
	if flash_t > 0.0:
		var k0: float = 1.0 - flash_t
		for k in 4:
			draw_circle(fly_from, (50.0 + k0 * 340.0) * (1.0 - float(k) * 0.2), Color(flash_col, 0.08 * flash_t))
	_draw_header()
	_draw_tabs()
	_draw_selectors()
	_draw_panel()


func _draw_header() -> void:
	var e: float = CosmeticUI.ease_out(clampf(_intro / 0.5, 0.0, 1.0))
	var xo: float = (1.0 - e) * -360.0
	var title: String = "SHOP" if shop_mode else "INVENTORY"
	var col: Color = UIKit.GOLD if shop_mode else Color("a58cff")
	var pts := UIKit.slanted(330.0, 58.0, 22.0, 24.0 + xo, 14.0)
	draw_colored_polygon(UIKit.slanted(330.0, 58.0, 22.0, 30.0 + xo, 20.0), Color(0, 0, 0, 0.5))
	draw_polygon(pts, PackedColorArray([col.lightened(0.15), col.lightened(0.15), col.darkened(0.45), col.darkened(0.45)]))
	draw_polyline(UIKit.closed(pts), Color(1, 1, 1, 0.9), 3.0, true)
	UIKit.text_in(self, title, Rect2(44.0 + xo, 14.0, 300.0, 58.0), 44, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 8)
	# ikon kecil di banner
	if shop_mode:
		DockButton.draw_shop_icon(self, Vector2(300.0 + xo, 43.0), 40.0, t)
	else:
		DockButton.draw_chest_icon(self, Vector2(300.0 + xo, 43.0), 40.0, t, 0.5)
	var cnt: Dictionary = Cosmetics.owned_counts()
	var sub: String = "SPEND YOUR COINS ON STYLE" if shop_mode else "OWNED   SKINS %d/%d   WEAPON %d/%d   ACC %d/%d" % [
		int(cnt["skins"]), int(cnt["skins_total"]), int(cnt["wskins"]), int(cnt["wskins_total"]), int(cnt["acc"]), int(cnt["acc_total"])]
	UIKit.text_in(self, sub, Rect2(372.0, 24.0, 600.0, 36.0), 18, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT, 4)
	# saldo koin
	var sh: float = sin(t * 60.0) * 7.0 * coin_shake
	var cp := UIKit.slanted(250.0, 52.0, 16.0, 1004.0 + sh, 16.0)
	draw_colored_polygon(cp, Color(0.08, 0.06, 0.02, 0.92))
	var flash: Color = Color("ff7a7a") if coin_shake > 0.0 else UIKit.GOLD
	draw_polyline(UIKit.closed(cp), flash, 3.0, true)
	draw_coin(self, Vector2(1046.0 + sh, 42.0), 34.0, t, true)
	UIKit.text_in(self, _fmt(int(roundf(coins_shown))), Rect2(1070.0 + sh, 16.0, 168.0, 52.0), 32, UIKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 6)


func _draw_tabs() -> void:
	var cnt: Dictionary = Cosmetics.owned_counts()
	var gc: Color = UIKit.GOLD if shop_mode else Color("a58cff")
	for i in kinds.size():
		var r := Rect2(GRID_X + float(i) * 276.0, 84.0, 266.0, 44.0)
		var bp := UIKit.slanted(r.size.x, r.size.y, 14.0, r.position.x, r.position.y)
		draw_colored_polygon(bp, Color(0.05, 0.05, 0.12, 0.8))
		draw_polyline(UIKit.closed(bp), Color(1, 1, 1, 0.18), 2.0, true)
		_hits.append({"rect": r, "type": "tab", "a": i})
	# sorotan tab meluncur halus. Kursor di baris TAB = sangat terang: cahaya berdenyut, bingkai putih tebal,
	# tab terangkat, dan garis kilau di bawahnya. Kursor di baris lain = tab terpilih tampil lebih redup.
	var f: float = tab_focus_f
	var pul: float = 0.5 + 0.5 * sin(t * 6.0)
	var hx: float = GRID_X + tab_f * 276.0
	var lift: float = -3.0 * f
	if f > 0.01:
		for k in 4:
			var g: float = float(k) * 4.0 + 3.0
			draw_colored_polygon(UIKit.slanted(266.0 + g * 2.0, 44.0 + g * 2.0, 14.0, hx - g, 84.0 + lift - g), Color(gc, (0.07 + 0.08 * pul) * f))
	var hp := UIKit.slanted(266.0, 44.0, 14.0, hx, 84.0 + lift)
	var c_top: Color = gc.darkened(0.15).lerp(gc.lightened(0.3), f)
	var c_bot: Color = gc.darkened(0.55).lerp(gc.darkened(0.2), f)
	c_top.a = lerpf(0.75, 1.0, f)
	c_bot.a = lerpf(0.75, 1.0, f)
	draw_polygon(hp, PackedColorArray([c_top, c_top, c_bot, c_bot]))
	var bcol: Color = Color(gc.lightened(0.3), 0.7).lerp(Color(1, 1, 1, 0.7 + 0.3 * pul), f)
	draw_polyline(UIKit.closed(hp), bcol, lerpf(2.0, 4.0, f), true)
	if f > 0.01:
		draw_rect(Rect2(hx + 14.0, 133.0, 238.0, 4.0), Color(gc, 0.6 * f))
		var shx: float = hx + 14.0 + fposmod(t * 1.2, 1.0) * 178.0
		draw_rect(Rect2(shx, 133.0, 60.0, 4.0), Color(1, 1, 1, 0.9 * f))
	for i in kinds.size():
		var k: String = String(kinds[i])
		var r2 := Rect2(GRID_X + float(i) * 276.0, 84.0, 266.0, 44.0)
		var on: bool = absf(float(i) - tab_f) < 0.5
		var tlift: float = lift if on else 0.0
		var txt_col: Color = Color(0.1, 0.06, 0.0) if on else Color(1, 1, 1, 0.6)
		UIKit.text_in(self, tab_title(k), Rect2(r2.position.x + 12.0, r2.position.y - 4.0 + tlift, r2.size.x - 70.0, r2.size.y), 22, txt_col, HORIZONTAL_ALIGNMENT_LEFT, 0 if on else 3)
		var have: int = int(cnt["acc"])
		var all: int = int(cnt["acc_total"])
		match k:
			"cskin":
				have = int(cnt["skins"])
				all = int(cnt["skins_total"])
			"wskin":
				have = int(cnt["wskins"])
				all = int(cnt["wskins_total"])
			"char":
				have = int(cnt["skins"]) + int(cnt["acc"])
				all = int(cnt["skins_total"]) + int(cnt["acc_total"])
		UIKit.text_in(self, "%d/%d" % [have, all], Rect2(r2.end.x - 74.0, r2.position.y + tlift, 58.0, r2.size.y), 15, txt_col, HORIZONTAL_ALIGNMENT_RIGHT, 0)


## Kemunculan elemen tahap-2 (bar, daftar skin, slot): 0 -> ~1.1 -> 1 (efek membal), menyusut saat keluar.
func _stage_vis(delay: float) -> float:
	var v: float = CosmeticUI.back(clampf((stage_t - delay) / 0.45, 0.0, 1.0))
	if trans_active and trans_kind == "exit":
		v *= 1.0 - CosmeticUI.ease_in(clampf(trans_t, 0.0, 1.0))
	return v


func _draw_crumb() -> void:
	var v: float = _stage_vis(0.0)
	var xo: float = (1.0 - v) * -360.0
	var y: float = 138.0
	var r := Rect2(GRID_X + xo, y, 600.0, 34.0)
	var pts := UIKit.slanted(r.size.x, r.size.y, 10.0, r.position.x, r.position.y)
	draw_colored_polygon(pts, Color(0.05, 0.05, 0.12, 0.85))
	draw_polyline(UIKit.closed(pts), Color(UIKit.GOLD, 0.8), 2.0, true)
	var sw: float = fposmod(t * 0.7, 1.7)
	if sw < 1.0:
		draw_line(Vector2(r.position.x + 14.0 + sw * 520.0, y + 31.0), Vector2(r.position.x + 74.0 + sw * 520.0, y + 31.0), Color(UIKit.GOLD, 0.85 * sin(sw * PI)), 3.0)
	var pul: float = 1.0 + 0.2 * sin(t * 6.0)
	UIKit.draw_chevron(self, Vector2(r.position.x + 26.0 - 3.0 * sin(t * 6.0), y + 17.0), 9.0 * pul, -1, UIKit.GOLD)
	UIKit.text_in(self, "BACK", Rect2(r.position.x + 44.0, y, 100.0, 34.0), 15, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT, 3)
	var vx: float = r.position.x + 160.0
	var ft := Rect2(vx, y + 3.0, 28.0, 28.0)
	var custom: bool = kind() == "char" and stage == 2
	var tex: Texture2D = Cosmetics.char_tex(sel_char, cur_skin_id() if custom else "") if kind() != "wskin" else Cosmetics.weapon_tex(cur_weapon(), "", 0)
	if kind() != "wskin":
		draw_texture_rect(tex, ft, false)
	else:
		draw_texture_rect(tex, _fit_rect(tex, ft), false)
	draw_rect(ft, Color(0, 0, 0, 0.8), false, 2.0)
	vx += 38.0
	var nm: String = Global.character_name(0, sel_char) if kind() != "wskin" else String(Global.WEAPONS[cur_weapon()]["name"])
	if custom:
		nm += "  /  " + sel_text(-1)
		UIKit.text_in(self, "CUSTOMIZE", Rect2(r.end.x - 150.0, y, 130.0, 34.0), 15, UIKit.CYAN, HORIZONTAL_ALIGNMENT_RIGHT, 3)
	UIKit.text_in(self, nm, Rect2(vx, y, r.end.x - 160.0 - vx, 34.0), _fit(nm, r.end.x - 160.0 - vx, 24), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 5)
	_hits.append({"rect": r, "type": "crumb", "a": 0})


## Pilihan slot aksesoris (HEAD / FACE / NECK / BACK) dengan sorotan yang meluncur.
func _draw_pills() -> void:
	var y0: float = 182.0
	var pw: float = 146.0
	var gap: float = 8.0
	var on_row: bool = row == 1
	var lo: Dictionary = Cosmetics.loadout(sel_char, cur_skin_id())
	var gc := Color("a58cff")
	for i in Cosmetics.SLOTS.size():
		var v: float = _stage_vis(0.22 + float(i) * 0.05)
		var x: float = GRID_X + float(i) * (pw + gap)
		var y: float = y0 + (1.0 - v) * 44.0
		var pts := UIKit.slanted(pw, 34.0, 10.0, x, y)
		draw_colored_polygon(pts, Color(0.05, 0.05, 0.12, 0.85))
		draw_polyline(UIKit.closed(pts), Color(1, 1, 1, 0.16), 2.0, true)
		_hits.append({"rect": Rect2(x, y0, pw, 34.0), "type": "slot", "a": i})
	var vh: float = _stage_vis(0.3)
	var hx: float = GRID_X + pill_f * (pw + gap)
	var hp := UIKit.slanted(pw, 34.0, 10.0, hx, y0 + (1.0 - vh) * 44.0)
	draw_polygon(hp, PackedColorArray([gc.lightened(0.2), gc.lightened(0.2), gc.darkened(0.35), gc.darkened(0.35)]))
	draw_polyline(UIKit.closed(hp), Color(UIKit.GOLD if on_row else Color(1, 1, 1, 0.8)).lerp(Color.WHITE, 0.5 + 0.5 * sin(t * 6.0) if on_row else 0.0), 3.0, true)
	for i in Cosmetics.SLOTS.size():
		var v: float = _stage_vis(0.22 + float(i) * 0.05)
		var slot: String = String(Cosmetics.SLOTS[i])
		var x: float = GRID_X + float(i) * (pw + gap)
		var y: float = y0 + (1.0 - v) * 44.0
		var on: bool = absf(float(i) - pill_f) < 0.5
		UIKit.text_in(self, String(Cosmetics.SLOT_NAMES[slot]), Rect2(x + 14.0, y, pw - 40.0, 34.0), 20, Color(0.08, 0.04, 0.16) if on else Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT, 0 if on else 3)
		var dc := Vector2(x + pw - 22.0, y + 17.0)
		if lo.has(slot):
			draw_circle(dc, 6.0, UIKit.GREEN)
			draw_arc(dc, 6.0, 0.0, TAU, 16, Color(0, 0, 0, 0.7), 1.5, true)
		else:
			draw_arc(dc, 5.0, 0.0, TAU, 16, Color(0, 0, 0, 0.55) if on else Color(1, 1, 1, 0.25), 2.0, true)


func _draw_selectors() -> void:
	if is_two_stage():
		if stage >= 1:
			_draw_crumb()
			if kind() == "char" and stage == 2:
				_draw_pills()
		return
	var names: Array = sel_names()
	for i in names.size():
		var y: float = 138.0 + float(i) * 40.0
		var on: bool = row == i + 1
		var r := Rect2(GRID_X, y, 600.0, 34.0)
		var pts := UIKit.slanted(r.size.x, r.size.y, 10.0, r.position.x, r.position.y)
		draw_colored_polygon(pts, Color(0.05, 0.05, 0.12, 0.85))
		draw_polyline(UIKit.closed(pts), UIKit.GOLD if on else Color(1, 1, 1, 0.16), 3.0 if on else 2.0, true)
		UIKit.text_in(self, String(names[i]), Rect2(r.position.x + 22.0, y, 140.0, 34.0), 15, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT, 3)
		var pul: float = 1.0 + (0.25 * sin(t * 6.0) if on else 0.0)
		var cc: Color = Color(UIKit.GOLD, 1.0) if on else Color(1, 1, 1, 0.4)
		UIKit.draw_chevron(self, Vector2(r.position.x + 190.0, y + 17.0), 9.0 * pul, -1, cc)
		UIKit.draw_chevron(self, Vector2(r.end.x - 30.0, y + 17.0), 9.0 * pul, 1, cc)
		var txt: String = sel_text(i)
		var vx: float = r.position.x + 214.0
		if String(names[i]) == "CHARACTER":
			var ft := Rect2(vx, y + 3.0, 28.0, 28.0)
			draw_texture_rect(Cosmetics.char_tex(sel_char, ""), ft, false)
			draw_rect(ft, Color(0, 0, 0, 0.8), false, 2.0)
			vx += 38.0
		UIKit.text_in(self, txt, Rect2(vx, y, r.end.x - 60.0 - vx, 34.0), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 5)
		_hits.append({"rect": Rect2(r.position.x + 160.0, y, 70.0, 34.0), "type": "sel_l", "a": i})
		_hits.append({"rect": Rect2(r.end.x - 70.0, y, 70.0, 34.0), "type": "sel_r", "a": i})


func _preview_char() -> int:
	if shop_mode and kind() == "acc":
		return int(t / 2.4) % Global.character_count()
	return sel_char


func _draw_panel() -> void:
	var e: float = CosmeticUI.ease_out(clampf((_intro - 0.1) / 0.5, 0.0, 1.0))
	var px: float = PANEL_X + (1.0 - e) * 420.0
	var it: Dictionary = panel_item()
	var pe: float = CosmeticUI.back(clampf(panel_t / 0.5, 0.0, 1.0))
	var pf: float = CosmeticUI.ease_out(clampf(panel_t / 0.32, 0.0, 1.0))
	var ps: float = lerpf(0.5, 1.0, pe)
	var skin_dim: bool = not shop_mode and kind() == "char" and stage == 2 and skin_locked()
	var rc: Color = Cosmetics.rarity_color(String(it.get("rarity", "common"))) if not it.is_empty() else Color(1, 1, 1, 0.3)
	var panel := Rect2(px, 84.0, 410.0, 562.0)
	var pts := UIKit.slanted(panel.size.x, panel.size.y, 18.0, panel.position.x, panel.position.y)
	draw_colored_polygon(UIKit.slanted(panel.size.x, panel.size.y, 18.0, panel.position.x + 6.0, panel.position.y + 8.0), Color(0, 0, 0, 0.5))
	var t0: Color = Color(0.1, 0.1, 0.22, 0.94).lerp(rc.darkened(0.6), 0.35)
	draw_polygon(pts, PackedColorArray([t0, t0, Color(0.03, 0.03, 0.08, 0.95), Color(0.03, 0.03, 0.08, 0.95)]))
	draw_polyline(UIKit.closed(pts), rc, 4.0, true)
	if it.is_empty():
		UIKit.text_in(self, "NOTHING HERE", panel, 28, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_CENTER, 4)
		return
	var cx: float = px + 205.0
	# nama & rarity
	var nm: String = String(it["name"])
	UIKit.text_in(self, nm, Rect2(px + 24.0 + (1.0 - pf) * 60.0, 94.0, 366.0, 46.0), _fit(nm, 366.0, 38), Color(1, 1, 1, pf), HORIZONTAL_ALIGNMENT_CENTER, 7)
	var rn: String = String(Cosmetics.RARITY_NAMES[String(it["rarity"])])
	var sub: String = rn
	match String(it["kind"]):
		"pchar": sub = "CHARACTER"
		"pweapon": sub = "WEAPON"
		"cskin": sub = "%s  -  %s SKIN" % [rn, Global.character_name(0, int(it["ch"]))]
		"wskin": sub = "%s  -  %s SKIN" % [rn, String(Global.WEAPONS[String(it["w"])]["name"])]
		"acc": sub = "%s  -  %s ACCESSORY" % [rn, String(Cosmetics.SLOT_NAMES[String(it["slot"])])]
	UIKit.text_in(self, sub, Rect2(px + 24.0 - (1.0 - pf) * 60.0, 138.0, 366.0, 24.0), 17, Color(rc, pf), HORIZONTAL_ALIGNMENT_CENTER, 4)
	# area preview
	var area := Rect2(px + 24.0, 170.0, 362.0, 296.0)
	draw_rect(area, Color(0, 0, 0, 0.4))
	draw_rect(area, Color(rc, 0.35), false, 2.0)
	var glow_r: float = 120.0 + 12.0 * sin(t * 2.4)
	for k in 5:
		draw_circle(area.get_center(), glow_r * (1.0 - float(k) * 0.17), Color(rc, 0.05))
	var owned: bool = bool(it["owned"])
	var tint: Color = Color.WHITE if (owned or shop_mode) else Color(0.28, 0.28, 0.32, 1.0)
	var bob: float = sin(t * 2.0) * 6.0
	var ac: Vector2 = area.get_center() + Vector2(0, bob)
	match String(it["kind"]):
		"pchar":
			draw_set_transform(ac, -(1.0 - pf) * 0.22, Vector2.ONE)
			var facep := Rect2(-Vector2(100, 100) * ps, Vector2(200, 200) * ps)
			Cosmetics.draw_preview(self, int(it["ch"]), "", {}, facep, Color.WHITE)
			draw_rect(facep, Color(0, 0, 0, 0.9), false, 3.0)
			draw_set_transform(Vector2.ZERO)
		"pweapon":
			var texp: Texture2D = Cosmetics.weapon_tex(String(it["w"]), "", 0)
			var bxp2 := Rect2(area.position + Vector2(20, 60), Vector2(area.size.x - 40.0, area.size.y - 120.0))
			var fitp: Rect2 = _fit_rect(texp, bxp2)
			draw_set_transform(fitp.get_center() + Vector2(0, bob), deg_to_rad(sin(t * 1.6) * 3.0) - (1.0 - pf) * 0.25, Vector2.ONE)
			draw_texture_rect(texp, Rect2(-fitp.size * 0.5 * ps, fitp.size * ps), false, Color.WHITE)
			draw_set_transform(Vector2.ZERO)
		"cskin":
			draw_set_transform(ac, -(1.0 - pf) * 0.22, Vector2.ONE)
			var face := Rect2(-Vector2(100, 100) * ps, Vector2(200, 200) * ps)
			var lo0: Dictionary = {}
			if not shop_mode:
				lo0 = Cosmetics.loadout(int(it["ch"]), String(it["id"]))
			Cosmetics.draw_preview(self, int(it["ch"]), String(it["id"]), lo0, face, tint)
			draw_rect(face, Color(0, 0, 0, 0.9), false, 3.0)
			draw_set_transform(Vector2.ZERO)
		"wskin":
			var w: String = String(it["w"])
			var tex: Texture2D = Cosmetics.weapon_tex(w, String(it["id"]), 0)
			var bx := Rect2(area.position + Vector2(20, 60), Vector2(area.size.x - 40.0, area.size.y - 120.0))
			var fit: Rect2 = _fit_rect(tex, bx)
			draw_set_transform(fit.get_center() + Vector2(0, bob), deg_to_rad(sin(t * 1.6) * 3.0) - (1.0 - pf) * 0.25, Vector2.ONE)
			draw_texture_rect(tex, Rect2(-fit.size * 0.5 * ps, fit.size * ps), false, tint)
			draw_set_transform(Vector2.ZERO)
			# kilas peluru dengan warna skin
			var bc: Color = Cosmetics.bullet_color(w, String(it["id"]))
			if bc.a > 0.0 and (owned or shop_mode):
				var bxp: float = fposmod(t * 1.1, 1.0)
				var by: float = area.end.y - 34.0
				var bxx: float = area.position.x + 30.0 + bxp * (area.size.x - 60.0)
				draw_line(Vector2(bxx - 44.0, by), Vector2(bxx, by), Color(bc, 0.5), 6.0)
				draw_circle(Vector2(bxx, by), 6.0, bc.lightened(0.4))
				draw_circle(Vector2(bxx, by), 11.0, Color(bc, 0.3))
		"acc":
			var pc: int = _preview_char()
			var sid: String = ""
			var lo: Dictionary = {}
			if not shop_mode:
				pc = sel_char
				sid = cur_skin_id()
				lo = Cosmetics.loadout(pc, sid).duplicate()
				var slot: String = String(it["slot"])
				if bool(it.get("none", false)):
					lo.erase(slot)
				else:
					lo[slot] = String(it["id"])           # selalu tampilkan (coba pakai) walau belum dimiliki
			else:
				lo = {String(it["slot"]): String(it["id"])}
			draw_set_transform(ac, -(1.0 - pf) * 0.22, Vector2.ONE)
			var face2 := Rect2(Vector2(-78, -70) * ps, Vector2(156, 156) * ps)
			Cosmetics.draw_preview(self, pc, sid, lo, face2, Color.WHITE if not skin_dim else Color(0.4, 0.4, 0.45))
			draw_rect(face2, Color(0, 0, 0, 0.9), false, 3.0)
			draw_set_transform(Vector2.ZERO)
			if shop_mode:
				UIKit.text_in(self, Global.character_name(0, pc), Rect2(area.position.x, area.end.y - 28.0, area.size.x, 24.0), 16, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER, 3)
	# kilau untuk epic / legendary
	var rar: String = String(it["rarity"])
	if rar == "epic" or rar == "legendary":
		for k in 7:
			var a: float = t * 0.8 + float(k) * TAU / 7.0
			var rr: float = 128.0 + 18.0 * sin(t * 2.0 + float(k))
			var sp: Vector2 = area.get_center() + Vector2(cos(a) * rr * 1.2, sin(a) * rr * 0.85)
			_sparkle(sp, 5.0 + 3.0 * sin(t * 4.0 + float(k) * 1.7), Color(rc.lightened(0.5), 0.8))
	# gembok kalau terkunci (inventory)
	if (not owned and not shop_mode) or skin_dim:
		UIKit.draw_lock(self, area.position + Vector2(area.size.x - 36.0, 36.0), 30.0, Color(1, 1, 1, 0.9))
	# info bawah
	var iy: float = 474.0
	var picker: bool = String(it["kind"]) == "pchar" or String(it["kind"]) == "pweapon"
	if picker:
		UIKit.text_in(self, "SKINS  %d / %d" % [int(it["have"]), int(it["total"])], Rect2(px, iy, 410.0, 44.0), 34, UIKit.CYAN, HORIZONTAL_ALIGNMENT_CENTER, 7)
	elif skin_dim:
		UIKit.text_in(self, "SKIN LOCKED", Rect2(px, iy, 410.0, 44.0), 34, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER, 7)
	elif shop_mode and not owned:
		draw_coin(self, Vector2(cx - 62.0, iy + 22.0), 36.0, t, true)
		UIKit.text_in(self, _fmt(int(it["price"])), Rect2(cx - 38.0, iy, 200.0, 44.0), 38, UIKit.GOLD if Cosmetics.can_afford(int(it["price"])) else Color("ff7a7a"), HORIZONTAL_ALIGNMENT_LEFT, 7)
	elif owned:
		UIKit.text_in(self, "OWNED", Rect2(px, iy, 410.0, 44.0), 34, UIKit.GREEN, HORIZONTAL_ALIGNMENT_CENTER, 7)
	else:
		UIKit.text_in(self, "LOCKED", Rect2(px, iy, 410.0, 44.0), 34, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER, 7)
	var d1: String = ""
	var d2: String = ""
	match String(it["kind"]):
		"pchar":
			d1 = "Skins you own for this character"
			d2 = "Press ACCEPT to see all skins"
		"pweapon":
			d1 = "Skins you own for this weapon"
			d2 = "Press ACCEPT to see all skins"
		"cskin":
			d1 = "Skin for %s only" % Global.character_name(0, int(it["ch"]))
			d2 = "Pick it after locking your fighter"
		"wskin":
			d1 = "Bullets glow in this skin's color"
			var w2: String = String(it["w"])
			d2 = "Change it here in INVENTORY" if (w2 == "pistol" or w2 == "knife") else "Pick it after choosing the weapon"
		"acc":
			d1 = "Fits every character and skin"
			d2 = "Equip it per character in INVENTORY" if shop_mode else ("Each character + skin keeps its own set" if owned else "Preview only - buy it in the SHOP")
	UIKit.text_in(self, d1, Rect2(px + 20.0, 520.0, 370.0, 22.0), 15, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 3)
	UIKit.text_in(self, d2, Rect2(px + 20.0, 540.0, 370.0, 22.0), 15, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_CENTER, 3)
	# cap besar (PURCHASED / EQUIPPED)
	if stamp_t > 0.0:
		var sp2: float = 1.0 - stamp_t
		var sc: float = lerpf(2.4, 1.0, CosmeticUI.back(clampf(sp2 * 4.0, 0.0, 1.0)))
		draw_set_transform(area.get_center(), deg_to_rad(-9.0), Vector2.ONE * sc)
		var sr := Rect2(-150, -34, 300, 68)
		draw_rect(sr, Color(0.0, 0.1, 0.05, 0.9 * clampf(stamp_t * 3.0, 0.0, 1.0)))
		draw_rect(sr, Color(UIKit.GREEN, clampf(stamp_t * 3.0, 0.0, 1.0)), false, 5.0)
		UIKit.text_in(self, stamp_text, sr, 44, Color(UIKit.GREEN, clampf(stamp_t * 3.0, 0.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, 8)
		draw_set_transform(Vector2.ZERO)


func _fit(s: String, maxw: float, fs: int) -> int:
	while fs > 12 and UIKit.text_w(s, fs) > maxw:
		fs -= 2
	return fs


func _fit_rect(tex: Texture2D, box: Rect2) -> Rect2:
	if tex == null:
		return box
	var ts: Vector2 = tex.get_size()
	var k: float = minf(box.size.x / ts.x, box.size.y / ts.y)
	var sz: Vector2 = ts * k
	return Rect2(box.get_center() - sz * 0.5, sz)


# ------------------------------------------------------------------ modal konfirmasi beli
## Progres animasi bertahap (0..1, ease-out) untuk satu bagian modal.
func _dp(delay: float, dur: float) -> float:
	return CosmeticUI.ease_out(clampf((dlg_age - delay) / dur, 0.0, 1.0))


func _item_sub(it: Dictionary) -> String:
	match String(it["kind"]):
		"cskin": return "%s SKIN" % Global.character_name(0, int(it["ch"]))
		"wskin": return "%s SKIN" % String(Global.WEAPONS[String(it["w"])]["name"])
		"acc": return "%s ACCESSORY" % String(Cosmetics.SLOT_NAMES[String(it["slot"])])
	return ""


func _dlg_sparkle(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.22, -r * 0.22), c + Vector2(r, 0), c + Vector2(r * 0.22, r * 0.22),
		c + Vector2(0, r), c + Vector2(-r * 0.22, r * 0.22), c + Vector2(-r, 0), c + Vector2(-r * 0.22, -r * 0.22)])
	ci.draw_colored_polygon(pts, col)


## Potong poligon `poly` dengan persegi `r` (dipakai supaya header & kilap tetap mengikuti bentuk miring kartu).
func _dlg_clip(poly: PackedVector2Array, r: Rect2) -> Array:
	var rp := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	return Geometry2D.intersect_polygons(poly, rp)


## Gambar item yang mau dibeli di dalam kotak `area` (ikut transform modal `xf`).
func _dlg_art(ci: CanvasItem, xf: Transform2D, area: Rect2, a: float) -> void:
	var it: Dictionary = dlg_item
	var pop: float = lerpf(0.4, 1.0, CosmeticUI.back(a))
	var bob: float = sin(t * 2.0) * 5.0
	var ac: Vector2 = area.get_center() + Vector2(0, bob)
	match String(it["kind"]):
		"cskin":
			ci.draw_set_transform_matrix(xf * Transform2D(sin(t * 1.3) * 0.05 - (1.0 - a) * 0.3, Vector2.ONE, 0.0, ac))
			var face := Rect2(-Vector2(82, 82) * pop, Vector2(164, 164) * pop)
			Cosmetics.draw_preview(ci, int(it["ch"]), String(it["id"]), {}, face, Color(1, 1, 1, a))
			ci.draw_rect(face, Color(0, 0, 0, 0.9 * a), false, 3.0)
		"wskin":
			var w: String = String(it["w"])
			var tex: Texture2D = Cosmetics.weapon_tex(w, String(it["id"]), 0)
			var fit: Rect2 = _fit_rect(tex, Rect2(area.position + Vector2(14, 40), area.size - Vector2(28, 80)))
			ci.draw_set_transform_matrix(xf * Transform2D(deg_to_rad(sin(t * 1.6) * 4.0) - (1.0 - a) * 0.3, Vector2.ONE, 0.0, fit.get_center() + Vector2(0, bob)))
			if tex != null:
				ci.draw_texture_rect(tex, Rect2(-fit.size * 0.5 * pop, fit.size * pop), false, Color(1, 1, 1, a))
			ci.draw_set_transform_matrix(xf)
			# kilas peluru dengan warna skin
			var bc: Color = Cosmetics.bullet_color(w, String(it["id"]))
			if bc.a > 0.0:
				var bxp: float = fposmod(t * 1.1, 1.0)
				var by: float = area.end.y - 22.0
				var bxx: float = area.position.x + 20.0 + bxp * (area.size.x - 40.0)
				ci.draw_line(Vector2(bxx - 36.0, by), Vector2(bxx, by), Color(bc, 0.5 * a), 5.0)
				ci.draw_circle(Vector2(bxx, by), 5.0, Color(bc.lightened(0.4), a))
				ci.draw_circle(Vector2(bxx, by), 9.0, Color(bc, 0.3 * a))
		"acc":
			var pc: int = _preview_char()
			var lo: Dictionary = {String(it["slot"]): String(it["id"])}
			ci.draw_set_transform_matrix(xf * Transform2D(sin(t * 1.3) * 0.05 - (1.0 - a) * 0.3, Vector2.ONE, 0.0, ac))
			var face2 := Rect2(Vector2(-66, -58) * pop, Vector2(132, 132) * pop)
			Cosmetics.draw_preview(ci, pc, "", lo, face2, Color(1, 1, 1, a))
			ci.draw_rect(face2, Color(0, 0, 0, 0.9 * a), false, 3.0)
	ci.draw_set_transform_matrix(xf)


## Satu baris rincian harga: label di kiri, koin + angka rata kanan.
func _dlg_row(ci: CanvasItem, label: String, val: int, y: float, ix: float, iw: float, h: float, fs: int, col: Color, a: float, coin_s: float) -> void:
	var off: float = (1.0 - a) * 36.0
	UIKit.text_in(ci, label, Rect2(ix + off, y, 170.0, h), 17, Color(1, 1, 1, 0.62 * a), HORIZONTAL_ALIGNMENT_LEFT, 3)
	var s: String = _fmt(val)
	var tw: float = UIKit.text_w(s, fs)
	UIKit.text_in(ci, s, Rect2(ix + off, y, iw, h), fs, Color(col, col.a * a), HORIZONTAL_ALIGNMENT_RIGHT, 6)
	CosmeticUI.draw_coin(ci, Vector2(ix + off + iw - tw - coin_s * 0.7, y + h * 0.5), coin_s, t, true, a)


func _draw_dialog(ci: CanvasItem) -> void:
	var rarity: String = String(dlg_item["rarity"])
	var rc: Color = Cosmetics.rarity_color(rarity)
	var pr: int = int(dlg_item["price"])
	var geom: Dictionary = _dlg_geom()
	var box: Rect2 = geom["box"]
	var ctr: Vector2 = box.get_center()
	var pulse: float = 0.5 + 0.5 * sin(t * 2.2)
	var pts := UIKit.slanted(box.size.x, box.size.y, 22.0, box.position.x, box.position.y)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

	# ---- latar gelap + cahaya warna rarity di belakang kartu
	ci.draw_rect(Rect2(0, 0, W, H), Color(0.01, 0.0, 0.05, 0.76))
	for k in 7:
		ci.draw_circle(ctr, (440.0 - float(k) * 50.0) * (0.96 + 0.04 * pulse), Color(rc, 0.032))
	# partikel kotak-kotak yang melayang naik
	for k in 18:
		var life: float = fposmod(t * (0.16 + 0.05 * float(k % 4)) + float(k) * 0.137, 1.0)
		var px: float = box.position.x - 50.0 + fposmod(float(k) * 83.7, box.size.x + 100.0)
		var py: float = box.end.y + 50.0 - life * (box.size.y + 130.0)
		var sz: float = 3.0 + float(k % 3) * 2.0
		ci.draw_rect(Rect2(px, py, sz, sz), Color(rc.lightened(0.45), sin(life * PI) * 0.55))

	# ---- transform kartu: muncul membesar dengan efek membal; keluar: sukses = mengembang, batal = mengecil & turun
	var op: float = clampf(dlg_age / 0.5, 0.0, 1.0)
	var sc: float = lerpf(0.7, 1.0, CosmeticUI.back(op))
	var yo: float = (1.0 - CosmeticUI.ease_out(op)) * 50.0
	var ro: float = (1.0 - CosmeticUI.ease_out(op)) * -0.06
	if dlg_closing:
		var co: float = CosmeticUI.ease_in(clampf(dlg_out, 0.0, 1.0))
		if dlg_result:
			sc *= 1.0 + 0.1 * CosmeticUI.ease_out(clampf(dlg_out, 0.0, 1.0))
		else:
			sc *= 1.0 - 0.14 * co
			yo += 36.0 * co
	var xf := Transform2D(ro, Vector2(sc, sc), 0.0, ctr + Vector2(0, yo)) * Transform2D(0.0, Vector2.ONE, 0.0, -ctr)
	ci.draw_set_transform_matrix(xf)

	# ---- badan kartu
	ci.draw_colored_polygon(UIKit.slanted(box.size.x, box.size.y, 22.0, box.position.x + 8.0, box.position.y + 12.0), Color(0, 0, 0, 0.55))
	var top_c: Color = Color(0.13, 0.11, 0.26).lerp(rc.darkened(0.55), 0.35)
	var bot_c := Color(0.035, 0.035, 0.09)
	ci.draw_polygon(pts, PackedColorArray([top_c, top_c, bot_c, bot_c]))
	var bcol: Color = rc.lerp(UIKit.GOLD, 0.35 + 0.35 * pulse)
	ci.draw_polyline(UIKit.closed(pts), Color(bcol, 0.14 + 0.1 * pulse), 12.0, true)
	ci.draw_polyline(UIKit.closed(pts), bcol, 4.0, true)

	# ---- header
	var ha: float = _dp(0.05, 0.3)
	var head := Rect2(box.position.x, box.position.y, box.size.x, 46.0)
	for poly in _dlg_clip(pts, head):
		ci.draw_colored_polygon(poly, Color(rc.darkened(0.5), 0.95 * ha))
	ci.draw_line(Vector2(box.position.x + 17.0, head.end.y), Vector2(box.end.x - 3.0, head.end.y), Color(bcol, ha), 3.0)
	var title := "CONFIRM PURCHASE"
	var ttw: float = UIKit.text_w(title, 26)
	UIKit.text_in(ci, title, Rect2(box.position.x, head.position.y + (1.0 - ha) * -14.0, box.size.x, 46.0), 26, Color(1, 1, 1, ha), HORIZONTAL_ALIGNMENT_CENTER, 6)
	CosmeticUI.draw_coin(ci, Vector2(ctr.x - ttw * 0.5 - 30.0, head.position.y + 23.0), 28.0, t, true, ha)
	CosmeticUI.draw_coin(ci, Vector2(ctr.x + ttw * 0.5 + 30.0, head.position.y + 23.0), 28.0, t + 1.3, true, ha)

	# ---- kotak pratinjau item
	var aa: float = _dp(0.12, 0.45)
	var area := Rect2(box.position.x + 44.0, box.position.y + 66.0, 216.0, 206.0)
	ci.draw_rect(area, Color(0, 0, 0, 0.42 * aa))
	for k in 5:
		ci.draw_circle(area.get_center(), (110.0 + 10.0 * sin(t * 2.4)) * (1.0 - float(k) * 0.17), Color(rc, 0.06 * aa))
	ci.draw_rect(area, Color(rc, 0.4 * aa), false, 2.0)
	var bl: float = 16.0
	var bk: Color = Color(rc.lightened(0.35), aa)
	for cx2 in 2:
		for cy2 in 2:
			var cp := Vector2(area.position.x if cx2 == 0 else area.end.x, area.position.y if cy2 == 0 else area.end.y)
			var sx: float = 1.0 if cx2 == 0 else -1.0
			var sy: float = 1.0 if cy2 == 0 else -1.0
			ci.draw_line(cp, cp + Vector2(bl * sx, 0), bk, 3.0)
			ci.draw_line(cp, cp + Vector2(0, bl * sy), bk, 3.0)
	_dlg_art(ci, xf, area, aa)
	if rarity == "epic" or rarity == "legendary":
		for k in 7:
			var an: float = t * 0.8 + float(k) * TAU / 7.0
			var rr: float = 92.0 + 14.0 * sin(t * 2.0 + float(k))
			var sp: Vector2 = area.get_center() + Vector2(cos(an) * rr * 1.1, sin(an) * rr * 0.78)
			_dlg_sparkle(ci, sp, 4.0 + 3.0 * sin(t * 4.0 + float(k) * 1.7), Color(rc.lightened(0.5), 0.85 * aa))
	# lencana rarity
	var rn: String = String(Cosmetics.RARITY_NAMES[rarity])
	var rw: float = UIKit.text_w(rn, 15) + 26.0
	var rp := Rect2(area.position.x + 8.0, area.position.y + 8.0, rw, 24.0)
	var rpp := UIKit.slanted(rp.size.x, rp.size.y, 8.0, rp.position.x, rp.position.y)
	ci.draw_colored_polygon(rpp, Color(rc.darkened(0.35), 0.95 * aa))
	ci.draw_polyline(UIKit.closed(rpp), Color(rc.lightened(0.3), aa), 2.0, true)
	UIKit.text_in(ci, rn, rp, 15, Color(1, 1, 1, aa), HORIZONTAL_ALIGNMENT_CENTER, 3)

	# ---- info item
	var ix: float = box.position.x + 284.0
	var iw: float = 312.0            # kolom info berakhir di x+596: sisa ~30px dari tepi kanan kartu yang miring
	var na: float = _dp(0.2, 0.35)
	var nm: String = String(dlg_item["name"])
	UIKit.text_in(ci, _item_sub(dlg_item), Rect2(ix + (1.0 - na) * 50.0, box.position.y + 62.0, iw, 22.0), 16, Color(rc, na), HORIZONTAL_ALIGNMENT_LEFT, 4)
	UIKit.text_in(ci, nm, Rect2(ix + (1.0 - na) * 70.0, box.position.y + 84.0, iw, 50.0), _fit(nm, iw, 40), Color(rc.lerp(Color.WHITE, 0.4), na), HORIZONTAL_ALIGNMENT_LEFT, 8)
	ci.draw_line(Vector2(ix, box.position.y + 140.0), Vector2(ix + iw * na, box.position.y + 140.0), Color(rc, 0.9), 3.0)

	# ---- rincian koin: harga, saldo, saldo setelah beli (angka berhitung turun)
	var ra: float = _dp(0.3, 0.35)
	_dlg_row(ci, "PRICE", pr, box.position.y + 148.0, ix, iw, 36.0, 28, UIKit.GOLD, ra, 28.0)
	var ba: float = _dp(0.36, 0.35)
	_dlg_row(ci, "YOUR COINS", dlg_bal, box.position.y + 186.0, ix, iw, 36.0, 28, Color(1, 1, 1, 0.85), ba, 28.0)
	var da: float = _dp(0.42, 0.3)
	ci.draw_line(Vector2(ix, box.position.y + 230.0), Vector2(ix + iw * da, box.position.y + 230.0), Color(UIKit.GOLD, 0.8), 3.0)
	var aaf: float = _dp(0.46, 0.35)
	var cnt: float = CosmeticUI.ease_out(clampf((dlg_age - 0.6) / 0.8, 0.0, 1.0))
	var after_v: int = int(round(lerpf(float(dlg_bal), float(dlg_bal - pr), cnt)))
	var after_col: Color = Color(1, 1, 1, 1).lerp(UIKit.GREEN, cnt)
	_dlg_row(ci, "AFTER BUYING", after_v, box.position.y + 236.0, ix, iw, 44.0, 36, after_col, aaf, 34.0)

	# ---- tombol YES / CANCEL
	var bta: float = _dp(0.5, 0.4)
	var slide := Vector2(0.0, (1.0 - bta) * 40.0)
	var yes_r := Rect2((geom["yes"] as Rect2).position + slide, (geom["yes"] as Rect2).size)
	var no_r := Rect2((geom["no"] as Rect2).position + slide, (geom["no"] as Rect2).size)
	for i in 2:
		var yes: bool = i == 0
		var br: Rect2 = yes_r if yes else no_r
		var wgt: float = (1.0 - dlg_sel_f) if yes else dlg_sel_f
		var chosen: bool = dlg_closing and (yes == dlg_result)
		var alpha: float = bta
		var bs: float = 1.0 + 0.03 * wgt + 0.012 * wgt * sin(t * 7.0)
		if dlg_closing:
			if chosen:
				bs = 1.0 + 0.05 * (1.0 - clampf(dlg_out * 4.0, 0.0, 1.0)) - 0.03
			else:
				alpha *= 1.0 - 0.7 * clampf(dlg_out * 2.0, 0.0, 1.0)
		var bc: Color = UIKit.GREEN if yes else Color("ff7a7a")
		var bcn: Vector2 = br.get_center()
		ci.draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(bs, bs), 0.0, bcn * (1.0 - bs)))
		var bp := UIKit.slanted(br.size.x, br.size.y, 12.0, br.position.x, br.position.y)
		if wgt > 0.02:
			var gp := UIKit.slanted(br.size.x + 14.0, br.size.y + 14.0, 14.0, br.position.x - 7.0, br.position.y - 7.0)
			ci.draw_colored_polygon(gp, Color(bc, (0.16 + 0.1 * sin(t * 6.0)) * wgt * alpha))
		var t_on: Color = bc.lightened(0.1)
		var b_on: Color = bc.darkened(0.45)
		var t_off := Color(0.12, 0.12, 0.2)
		var b_off := Color(0.05, 0.05, 0.1)
		var tc: Color = t_off.lerp(t_on, wgt)
		var bcc: Color = b_off.lerp(b_on, wgt)
		tc.a = alpha
		bcc.a = alpha
		ci.draw_polygon(bp, PackedColorArray([tc, tc, bcc, bcc]))
		ci.draw_polyline(UIKit.closed(bp), Color(1, 1, 1, lerpf(0.22, 1.0, wgt) * alpha), lerpf(2.0, 4.0, wgt), true)
		var ic := Vector2(br.position.x + 46.0, bcn.y)
		var icol := Color(1, 1, 1, lerpf(0.55, 1.0, wgt) * alpha)
		if yes:
			ci.draw_polyline(PackedVector2Array([ic + Vector2(-10, 0), ic + Vector2(-3, 8), ic + Vector2(11, -9)]), icol, 5.0, true)
		else:
			ci.draw_line(ic + Vector2(-9, -9), ic + Vector2(9, 9), icol, 5.0, true)
			ci.draw_line(ic + Vector2(-9, 9), ic + Vector2(9, -9), icol, 5.0, true)
		var lbl: String = "BUY" if yes else "CANCEL"
		var lr := Rect2(br.position.x + 64.0, br.position.y, br.size.x - 84.0, br.size.y)
		UIKit.text_in(ci, lbl, lr, _fit(lbl, lr.size.x, 30), icol, HORIZONTAL_ALIGNMENT_CENTER, 6, Color(0, 0, 0, alpha))
	ci.draw_set_transform_matrix(xf)

	# ---- kilap yang menyapu kartu + kilatan putih saat beli
	var swp: float = fposmod(t * 0.45, 1.8)
	if swp < 1.0:
		var sx2: float = box.position.x - 120.0 + swp * (box.size.x + 240.0)
		var band := PackedVector2Array([Vector2(sx2, box.position.y), Vector2(sx2 + 70.0, box.position.y), Vector2(sx2 + 10.0, box.end.y), Vector2(sx2 - 60.0, box.end.y)])
		for poly2 in Geometry2D.intersect_polygons(pts, band):
			ci.draw_colored_polygon(poly2, Color(1, 1, 1, 0.07))
	if dlg_closing and dlg_result:
		ci.draw_colored_polygon(pts, Color(1.0, 0.95, 0.7, 0.45 * (1.0 - CosmeticUI.ease_out(clampf(dlg_out, 0.0, 1.0)))))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ================================================================== grid item (dipotong sendiri)
class GridView extends Control:
	var ui: CosmeticUI

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if ui == null:
			return
		var its: Array = ui.items()
		var cs: Vector2 = ui.card_size()
		var cn: int = ui.cols()
		var on_grid: bool = ui.row == ui.grid_row()
		var n: int = its.size()
		var stag: float = minf(0.04, 0.5 / maxf(float(n), 1.0))
		var late: int = -1
		var pad: float = CosmeticUI.GRID_PAD
		for i in n:
			var r: int = i / cn
			var c: int = i % cn
			var x: float = pad + float(c) * (cs.x + 12.0)
			var y: float = pad + float(r) * (cs.y + 12.0) - ui.scroll
			if y + cs.y < -4.0 or y > size.y + 4.0:
				continue
			var base := Vector2(x, y)
			var ctr: Vector2 = base + cs * 0.5
			var off := Vector2.ZERO
			var sc: float = 1.0
			var rot: float = 0.0
			var al: float = 1.0
			var sgn: float = 1.0 if (i % 2 == 0) else -1.0
			if ui.trans_active:
				if ui.trans_kind == "enter" and i == ui.trans_pick:
					late = i
					continue
				# semua kartu lain tersedot ke titik tujuan sambil mengecil & berputar
				var u: float = CosmeticUI.ease_in(ui.trans_t)
				off = ((ui.trans_origin - position) - ctr) * u
				sc = maxf(1.0 - 0.92 * u, 0.04)
				rot = u * 0.7 * sgn
				al = 1.0 - u
			else:
				var dd: float = clampf((ui.grid_t - float(i) * stag) / 0.38, 0.0, 1.0)
				if dd <= 0.0:
					continue
				var e: float = CosmeticUI.ease_out(dd)
				var b: float = CosmeticUI.back(dd)
				match ui.fly_mode:
					1:
						off = ((ui.fly_from - position) - ctr) * (1.0 - e)
						sc = lerpf(0.12, 1.0, b)
						rot = (1.0 - e) * 0.5 * sgn
					2:
						off = Vector2(0.0, -(1.0 - e) * 90.0)
						sc = lerpf(0.55, 1.0, b)
						rot = (1.0 - e) * -0.3 * sgn
					_:
						off = Vector2(0.0, (1.0 - e) * 40.0)
						sc = lerpf(0.78, 1.0, b)
				al = dd
			_draw_xf(its[i], base, cs, i == ui.cur, on_grid and i == ui.cur, al, off, sc, rot)
			if not ui.trans_active:
				# area klik hanya dipotong di batas atas/bawah grid yang sebenarnya (ruang pad kiri/kanan tetap bisa diklik)
				var gr := Rect2(position + base, cs).intersection(Rect2(position + Vector2(0.0, pad), Vector2(size.x, size.y - pad * 2.0)))
				if gr.size.x > 4.0 and gr.size.y > 4.0:
					ui._hits.append({"rect": gr, "type": "card", "a": i})
		if late >= 0:
			# kartu yang dipilih membesar dan berdenyut sebelum semuanya berganti
			var u2: float = CosmeticUI.ease_out(ui.trans_t)
			var bx: float = pad + float(late % cn) * (cs.x + 12.0)
			var by: float = pad + float(late / cn) * (cs.y + 12.0) - ui.scroll
			_draw_xf(its[late], Vector2(bx, by), cs, true, true, 1.0, Vector2.ZERO, 1.0 + 0.34 * u2, sin(ui.trans_t * PI * 2.0) * 0.08)

	func _draw_xf(it: Dictionary, base: Vector2, cs: Vector2, sel: bool, active: bool, al: float, off: Vector2, sc: float, rot: float) -> void:
		var c0: Vector2 = base + cs * 0.5
		var xf := Transform2D(rot, Vector2(sc, sc), 0.0, c0 + off) * Transform2D(0.0, Vector2.ONE, 0.0, -c0)
		draw_set_transform_matrix(xf)
		_draw_card(it, base, cs, sel, active, al)
		draw_set_transform_matrix(Transform2D.IDENTITY)

	func _draw_card(it: Dictionary, p: Vector2, cs: Vector2, sel: bool, active: bool, alpha: float) -> void:
		var rc: Color = Cosmetics.rarity_color(String(it["rarity"]))
		var owned: bool = bool(it["owned"])
		var lift: float = -4.0 - 2.0 * sin(ui.t * 5.0) if active else (-2.0 if sel else 0.0)
		var o: Vector2 = p + Vector2(0, lift)
		var w: float = cs.x
		var h: float = cs.y
		var ch: float = 12.0
		var pts := PackedVector2Array([o + Vector2(ch, 0), o + Vector2(w, 0), o + Vector2(w, h - ch), o + Vector2(w - ch, h), o + Vector2(0, h), o + Vector2(0, ch)])
		draw_colored_polygon(PackedVector2Array([pts[0] + Vector2(4, 6), pts[1] + Vector2(4, 6), pts[2] + Vector2(4, 6), pts[3] + Vector2(4, 6), pts[4] + Vector2(4, 6), pts[5] + Vector2(4, 6)]), Color(0, 0, 0, 0.4 * alpha))
		var top: Color = Color(0.12, 0.12, 0.24, 0.95).lerp(rc.darkened(0.55), 0.4)
		var bot: Color = Color(0.04, 0.04, 0.1, 0.96)
		draw_polygon(pts, PackedColorArray([top, top, bot, bot, bot, top]))
		var closed_pts := PackedVector2Array(pts)
		closed_pts.append(pts[0])
		var bc: Color = Color(UIKit.GOLD, 1.0) if active else (Color(rc, 0.9) if sel else Color(rc, 0.55))
		draw_polyline(closed_pts, bc, 4.0 if active else 2.0, true)
		# thumbnail
		var s: float = w - 20.0
		var th := Rect2(o + Vector2(10, 10), Vector2(s, s))
		draw_rect(th, Color(0, 0, 0, 0.38))
		for k in 3:
			draw_circle(th.get_center(), s * (0.5 - float(k) * 0.14), Color(rc, 0.06))
		var tint: Color = Color.WHITE if (owned or ui.shop_mode) else Color(0.25, 0.25, 0.3, 1.0)
		var is_pick: bool = String(it["kind"]) == "pchar" or String(it["kind"]) == "pweapon"
		if owned and ui.shop_mode and not is_pick:
			tint = Color(0.62, 0.62, 0.68, 1.0)
		match String(it["kind"]):
			"pchar":
				Cosmetics.draw_preview(self, int(it["ch"]), "", {}, th.grow(-2.0), Color.WHITE)
				draw_rect(th.grow(-2.0), Color(0, 0, 0, 0.85), false, 2.0)
			"pweapon":
				var texw: Texture2D = Cosmetics.weapon_tex(String(it["w"]), "", 0)
				draw_texture_rect(texw, ui._fit_rect(texw, th.grow(-6.0)), false, Color.WHITE)
			"cskin":
				var lo0: Dictionary = {}
				if not ui.shop_mode:
					lo0 = Cosmetics.loadout(int(it["ch"]), String(it["id"]))
				Cosmetics.draw_preview(self, int(it["ch"]), String(it["id"]), lo0, th.grow(-2.0), tint)
				draw_rect(th.grow(-2.0), Color(0, 0, 0, 0.85), false, 2.0)
			"wskin":
				var tex: Texture2D = Cosmetics.weapon_tex(String(it["w"]), String(it["id"]), 0)
				var fit: Rect2 = ui._fit_rect(tex, th.grow(-6.0))
				draw_texture_rect(tex, fit, false, tint)
			"acc":
				var pc: int = ui.sel_char if not ui.shop_mode else 4
				var fs: float = s * 0.5
				var face := Rect2(th.get_center() - Vector2(fs, fs) * 0.5 + Vector2(0, fs * 0.04), Vector2(fs, fs))
				if bool(it.get("none", false)):
					draw_line(th.position + Vector2(18, 18), th.end - Vector2(18, 18), Color(1, 1, 1, 0.5), 4.0)
					draw_line(th.position + Vector2(th.size.x - 18, 18), th.position + Vector2(18, th.size.y - 18), Color(1, 1, 1, 0.5), 4.0)
				else:
					var lo: Dictionary = {String(it["slot"]): String(it["id"])}
					Cosmetics.draw_preview(self, pc, "" if ui.shop_mode else ui.cur_skin_id(), lo, face, tint)
		if not owned and not ui.shop_mode:
			UIKit.draw_lock(self, th.get_center(), 30.0, Color(1, 1, 1, 0.85))
		# rarity pip
		draw_colored_polygon(PackedVector2Array([o + Vector2(w - 26, 0), o + Vector2(w, 0), o + Vector2(w, 26)]), Color(rc, 0.95))
		# nama + harga / status
		var nm: String = String(it["name"])
		UIKit.text_in(self, nm, Rect2(o.x + 4.0, o.y + s + 12.0, w - 8.0, 22.0), ui._fit(nm, w - 14.0, 17), Color(1, 1, 1, 0.95 if owned or ui.shop_mode else 0.5), HORIZONTAL_ALIGNMENT_CENTER, 4)
		var py: float = o.y + s + 34.0
		var equipped: bool = bool(it.get("equipped", false))
		if is_pick:
			UIKit.text_in(self, "SKINS %d/%d" % [int(it["have"]), int(it["total"])], Rect2(o.x, py, w, 22.0), 15, UIKit.CYAN, HORIZONTAL_ALIGNMENT_CENTER, 3)
		elif ui.shop_mode:
			if owned:
				UIKit.text_in(self, "OWNED", Rect2(o.x, py, w, 22.0), 16, UIKit.GREEN, HORIZONTAL_ALIGNMENT_CENTER, 4)
			else:
				var pr: int = int(it["price"])
				var txt: String = ui._fmt(pr)
				var tw: float = UIKit.text_w(txt, 18)
				var cc: Color = UIKit.GOLD if Cosmetics.can_afford(pr) else Color("ff7a7a")
				CosmeticUI.draw_coin(self, Vector2(o.x + w * 0.5 - tw * 0.5 - 8.0, py + 11.0), 18.0)
				UIKit.text_in(self, txt, Rect2(o.x + w * 0.5 - tw * 0.5 + 4.0, py, tw + 8.0, 22.0), 18, cc, HORIZONTAL_ALIGNMENT_LEFT, 4)
		else:
			if not owned:
				UIKit.text_in(self, "LOCKED", Rect2(o.x, py, w, 22.0), 15, Color(1, 1, 1, 0.4), HORIZONTAL_ALIGNMENT_CENTER, 3)
			elif equipped:
				UIKit.text_in(self, "EQUIPPED", Rect2(o.x, py, w, 22.0), 15, UIKit.GREEN, HORIZONTAL_ALIGNMENT_CENTER, 4)
			else:
				UIKit.text_in(self, "OWNED", Rect2(o.x, py, w, 22.0), 15, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 3)
		if owned and (equipped and not ui.shop_mode):
			draw_circle(o + Vector2(20, 20), 11.0, UIKit.GREEN)
			draw_polyline(PackedVector2Array([o + Vector2(14, 20), o + Vector2(19, 25), o + Vector2(27, 14)]), Color.BLACK, 3.0, true)


# ================================================================== lapisan dialog (di atas semua anak lain)
class DlgLayer extends Control:
	var ui: CosmeticUI

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		size = Vector2(CosmeticUI.W, CosmeticUI.H)

	func _draw() -> void:
		if ui != null and ui.dlg_open:
			ui._draw_dialog(self)


# ================================================================== tombol DOCK di menu utama (SHOP & INVENTORY)
class DockButton extends Control:
	signal activated
	signal hovered

	var kind_id: String = "shop"           # "shop" | "inventory"
	var selected: bool = false
	var sel: float = 0.0
	var flash: float = 0.0
	var t: float = 0.0
	var phase: float = 0.0
	var accent: Color = Color("ffcd3c")

	func _init(k: String = "shop") -> void:
		kind_id = k
		size = Vector2(262, 92)
		custom_minimum_size = size
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		accent = Color("ffcd3c") if k == "shop" else Color("a58cff")
		phase = 0.0 if k == "shop" else 1.7

	func _ready() -> void:
		mouse_entered.connect(func() -> void: hovered.emit())

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			press()

	func set_selected(v: bool) -> void:
		selected = v

	func press() -> void:
		Global.play_sfx("ui_confirm", -3.0)
		flash = 1.0
		activated.emit()

	func _process(d: float) -> void:
		t += d
		sel = lerpf(sel, 1.0 if selected else 0.0, minf(1.0, d * 12.0))
		flash = maxf(flash - d * 3.0, 0.0)
		scale = Vector2.ONE * (1.0 + 0.07 * sel + 0.05 * flash)
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var fy: float = sin(t * 1.7 + phase) * 2.5 * (1.0 - sel * 0.6)
		var o := Vector2(0, fy)
		var sk: float = 18.0
		var pts := UIKit.slanted(w - 8.0, h - 8.0, sk, 4.0 + o.x, 4.0 + o.y)
		draw_colored_polygon(UIKit.slanted(w - 8.0, h - 8.0, sk, 10.0, 12.0 + fy), Color(0, 0, 0, 0.5))
		var top: Color = Color(0.1, 0.09, 0.2, 0.94).lerp(accent.darkened(0.25), sel)
		var bot: Color = Color(0.03, 0.03, 0.08, 0.95).lerp(accent.darkened(0.7), sel)
		draw_polygon(pts, PackedColorArray([top, top, bot, bot]))
		# kilau berjalan
		var sh: float = fposmod(t * 0.55 + phase, 2.2)
		if sh < 1.0:
			var bx: float = -40.0 + sh * (w + 80.0)
			var a: float = (0.14 + 0.2 * sel) * sin(sh * PI)
			var band := PackedVector2Array([Vector2(bx, 4.0 + fy), Vector2(bx + 26.0, 4.0 + fy), Vector2(bx + 6.0, h - 4.0 + fy), Vector2(bx - 20.0, h - 4.0 + fy)])
			for k in band.size():
				band[k].x = clampf(band[k].x, 6.0 + sk * (1.0 - clampf((band[k].y - fy) / h, 0.0, 1.0)), w - 6.0)
			draw_colored_polygon(band, Color(1, 1, 1, a))
		var edge: Color = accent.lerp(Color.WHITE, 0.6 * sel + 0.4 * flash)
		draw_polyline(UIKit.closed(pts), edge, 3.0 + 2.0 * sel, true)
		# ikon di kotak kiri
		var ib := Rect2(22.0, 16.0 + fy, 60.0, 60.0)
		draw_rect(ib, Color(0, 0, 0, 0.45))
		draw_rect(ib, Color(accent, 0.5 + 0.5 * sel), false, 2.0)
		var ic: Vector2 = ib.get_center() + Vector2(0, 2.0)
		if kind_id == "shop":
			CosmeticUI.DockButton.draw_shop_icon(self, ic, 52.0, t + sel * 2.0)
		else:
			CosmeticUI.DockButton.draw_chest_icon(self, ic, 52.0, t, sel)
		# teks
		var title: String = "SHOP" if kind_id == "shop" else "INVENTORY"
		var fs: int = 34 if kind_id == "shop" else 28
		UIKit.text_in(self, title, Rect2(94.0, 8.0 + fy, w - 110.0, 44.0), fs, Color.WHITE.lerp(accent.lightened(0.5), 0.5 * sel), HORIZONTAL_ALIGNMENT_LEFT, 7)
		if kind_id == "shop":
			CosmeticUI.draw_coin(self, Vector2(106.0, 66.0 + fy), 20.0, t, true)
			UIKit.text_in(self, CosmeticUI._fmt_static(Cosmetics.coins()), Rect2(122.0, 54.0 + fy, w - 140.0, 24.0), 20, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, 4)
		else:
			var cnt: Dictionary = Cosmetics.owned_counts()
			var have: int = int(cnt["skins"]) + int(cnt["wskins"]) + int(cnt["acc"])
			UIKit.text_in(self, "%d ITEMS" % have, Rect2(94.0, 54.0 + fy, w - 110.0, 24.0), 18, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_LEFT, 4)
		if sel > 0.05:
			UIKit.draw_chevron(self, Vector2(w - 24.0 + sin(t * 8.0) * 3.0, h * 0.5 + fy), 10.0, 1, Color(accent.lightened(0.4), sel))

	static func draw_shop_icon(ci: CanvasItem, c: Vector2, s: float, tm: float) -> void:
		var k: float = s / 52.0
		var bob: float = sin(tm * 3.0) * 1.5 * k
		var ink := Color(0.05, 0.04, 0.08)
		# badan toko
		ci.draw_rect(Rect2(c + Vector2(-19, -2) * k, Vector2(38, 26) * k), Color("f2e2b8"))
		ci.draw_rect(Rect2(c + Vector2(-19, -2) * k, Vector2(38, 26) * k), ink, false, 2.0)
		ci.draw_rect(Rect2(c + Vector2(-5, 8) * k, Vector2(11, 16) * k), Color("7a4a22"))
		ci.draw_rect(Rect2(c + Vector2(-5, 8) * k, Vector2(11, 16) * k), ink, false, 2.0)
		ci.draw_rect(Rect2(c + Vector2(9, 5) * k, Vector2(8, 8) * k), Color("8fe0ff"))
		ci.draw_rect(Rect2(c + Vector2(9, 5) * k, Vector2(8, 8) * k), ink, false, 1.5)
		# tenda belang
		for i in 5:
			var x0: float = -22.0 + float(i) * 8.8
			var col: Color = Color("e0303c") if i % 2 == 0 else Color("fbfbff")
			var pts := PackedVector2Array([c + Vector2(x0 + 2, -16) * k, c + Vector2(x0 + 10.8, -16) * k, c + Vector2(x0 + 8.8, -2) * k + Vector2(2, 0) * k, c + Vector2(x0 - 1, -2) * k + Vector2(2, 0) * k])
			ci.draw_colored_polygon(pts, col)
			ci.draw_circle(c + Vector2(x0 + 5.4, -2) * k, 4.4 * k, col)
		ci.draw_rect(Rect2(c + Vector2(-19, -17) * k, Vector2(38, 3) * k), ink)
		# koin melayang
		CosmeticUI.draw_coin(ci, c + Vector2(0, -23.0 * k + bob), 13.0 * k, tm * 1.3, true)

	static func draw_chest_icon(ci: CanvasItem, c: Vector2, s: float, tm: float, open: float) -> void:
		var k: float = s / 52.0
		var ink := Color(0.05, 0.04, 0.08)
		var wood := Color("9a5a2a")
		var gold := Color("ffcd3c")
		var lift: float = open * 9.0 * k
		# cahaya dari dalam
		if open > 0.05:
			ci.draw_circle(c + Vector2(0, -2 * k), 22.0 * k, Color(1, 0.85, 0.3, 0.18 * open))
		# badan
		ci.draw_rect(Rect2(c + Vector2(-20, 2) * k, Vector2(40, 22) * k), wood)
		ci.draw_rect(Rect2(c + Vector2(-20, 2) * k, Vector2(40, 22) * k), ink, false, 2.0)
		ci.draw_rect(Rect2(c + Vector2(-20, 9) * k, Vector2(40, 4) * k), gold)
		ci.draw_rect(Rect2(c + Vector2(-20, 2) * k, Vector2(5, 22) * k), gold)
		ci.draw_rect(Rect2(c + Vector2(15, 2) * k, Vector2(5, 22) * k), gold)
		# tutup (naik sedikit saat dipilih)
		var lid := PackedVector2Array()
		for i in 13:
			var a: float = PI + float(i) / 12.0 * PI
			lid.append(c + Vector2(cos(a) * 20.0, -2.0 + sin(a) * 15.0) * k + Vector2(0, -lift))
		ci.draw_colored_polygon(lid, wood.lightened(0.1))
		var lid_c := PackedVector2Array(lid)
		lid_c.append(lid[0])
		ci.draw_polyline(lid_c, ink, 2.0, true)
		ci.draw_line(c + Vector2(-20, -2) * k + Vector2(0, -lift), c + Vector2(20, -2) * k + Vector2(0, -lift), gold, 3.0)
		# gembok
		ci.draw_rect(Rect2(c + Vector2(-4, 5) * k + Vector2(0, -lift * 0.5), Vector2(8, 10) * k), gold)
		ci.draw_rect(Rect2(c + Vector2(-4, 5) * k + Vector2(0, -lift * 0.5), Vector2(8, 10) * k), ink, false, 1.5)
		ci.draw_circle(c + Vector2(0, 10) * k + Vector2(0, -lift * 0.5), 1.6 * k, ink)
		# kilau
		var sp: float = 0.5 + 0.5 * sin(tm * 4.0)
		var sc: Vector2 = c + Vector2(15, -14) * k
		var r: float = (3.0 + 3.0 * sp) * k
		ci.draw_colored_polygon(PackedVector2Array([sc + Vector2(0, -r), sc + Vector2(r * 0.25, -r * 0.25), sc + Vector2(r, 0), sc + Vector2(r * 0.25, r * 0.25),
			sc + Vector2(0, r), sc + Vector2(-r * 0.25, r * 0.25), sc + Vector2(-r, 0), sc + Vector2(-r * 0.25, -r * 0.25)]), Color(1, 1, 0.85, 0.5 + 0.5 * sp))


static func _fmt_static(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	var c: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out
