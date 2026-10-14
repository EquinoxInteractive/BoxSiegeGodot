extends Control
## ======================================================================================
##  LOADING SCREEN  (scene kedua, setelah splash/kredit - sebelum menu utama)
## ======================================================================================
## Ini BUKAN loading palsu. Semua pekerjaan berat yang dulu dikerjakan diam-diam di belakang menu
## (dan membuat awal permainan patah-patah) sekarang dikerjakan DI SINI, dengan progress bar sungguhan:
##   1) Aset: semua sprite, sfx, scene, musik dimuat & dipegang di memori      (Global.boot_begin)
##   2) Peta CAMPAIGN: scene, data 250 level, ukuran huruf, atlas rantai       (Global.boot_begin)
##   3) Suara sintetis (fanfare, applause, dll.)                               (Global.boot_begin)
##   4) SHOP & INVENTORY: tekstur skin / aksesori + scene                      (Cosmetics.warm_*)
##   5) Huruf berkontur (menu, shop, About) dimasukkan ke atlas font          (CosmeticUI.GlyphWarm, AboutUI.GlyphWarmer)
##   6) Shader GPU (additive, garis halus, poligon, partikel, latar menu)      (Global.boot_gpu_warm)
## Begitu semuanya selesai, game masuk ke menu dan seluruh game berjalan mulus (tanpa memuat apa pun lagi).
##
## Tampilan: latar prosedural (matahari terbit di atas benteng kotak + grid neon), kubus 3D melayang, bara api,
## cincin berputar + persen, progress bar, dan 4 karakter box yang berlari mengikuti bar.
## Latar sepenuhnya digambar lewat shader / kode, jadi tidak butuh file gambar baru.
##
## Setelah 100%: ANIMASI KELUAR (OUTRO) yang menyambung ke menu utama tanpa putus (lihat PortalFx di paling bawah):
##   1) angka persen + teks "READY!" membesar sebentar lalu mengecil & hilang; bar, logo, tips, footer keluar layar,
##      keempat karakter berlari keluar ke kanan, cincin menyusut & berputar kencang (charge)
##   2) bulatan di tengah jadi PORTAL: zoom eksponensial (kecepatan terasa konstan) yang SAMA PERSIS dengan zoom kamera,
##      sehingga tepi portal menempel di cincin; di ujung zoom layar menyala jadi cahaya hangat (flash)
##   3) di balik flash, menu dimuat; flash lalu mencair & terbuka dari tengah (iris lembut) menampakkan menu yang
##      mengendap dari zoom, bersamaan dengan intro logo + poster milik menu
## Semua ada di file ini saja (global.gd & menu.gd tidak perlu diubah).
##
## Pengaturan cepat ada di bagian konstanta di bawah.

const MENU_SCENE := "menu"           # scene tujuan (Global.goto)
const MIN_SHOW := 3.6                # loading minimal tampil (detik) supaya animasinya sempat terlihat, walau semua aset sudah di cache
const HARD_TIMEOUT := 70.0           # kalau ada langkah macet, setelah ini game tetap lanjut ke menu
const STEP_TIMEOUT := 25.0           # batas tunggu tiap langkah

# ---- animasi keluar (outro) setelah loading 100% - semua dalam detik sejak loading selesai
const OUT_POP := 0.30                # angka 100% "membal" sebentar
const OUT_TEXT0 := 0.45              # mulai: teks persen mengecil & hilang, cincin charge, bar/logo/tips keluar
const OUT_TEXT_DUR := 0.36           # lama teks menghilang
const OUT_CHARGE_DUR := 0.33         # lama cincin menyusut + berputar kencang
const OUT_UI_DUR := 0.50             # lama bar / logo / tips / karakter keluar layar
const OUT_PORTAL := 0.78             # portal mulai membesar (zoom). Durasi zoom & buka ada di PortalFx.COVER_DUR / REVEAL_DUR

# bobot kemajuan tiap langkah (jumlah = 1.0)
const W_PRE := 0.44                  # aset
const W_SYN := 0.08                  # suara sintetis
const W_CAM := 0.18                  # peta CAMPAIGN
const W_COS := 0.10                  # SHOP & INVENTORY
const W_GLY := 0.07                  # huruf
const W_GPU := 0.13                  # shader GPU

const TIP_TIME := 4.2                # lama tiap tips tampil (detik)
const TIPS := [
	"Shield blocks 2 hits of anything: bullets, knives, arrows, lava and spikes.",
	"Heal restores 1 HP instantly. Grab it when you are running low!",
	"Swap Position shuffles everyone's location. Perfect for escaping a bad spot.",
	"Ammo Refill fully reloads your main weapon.",
	"Invisible makes you vanish for 3 seconds. Sneak up and strike!",
	"Scream switches to the pistol when its ammo runs out.",
	"Every fighter carries a knife. Press the KNIFE button to swap to it.",
	"Time is up? The player with the most HP wins. A draw means SUDDEN DEATH!",
	"Each map has its own hazards: lava, slippery ice, crumbling platforms, spikes and more.",
	"Plug in up to 4 controllers. Each one becomes the next player automatically.",
	"Speed Boost and Jump Boost last for 10 seconds.",
	"Visit the SHOP to unlock fighter skins, accessories and weapon skins.",
	"Try the CAMPAIGN: %d levels, bosses and perks to collect." % CampaignData.TOTAL_LEVELS,
	"Change your controls anytime in SETTINGS > CONTROLS SETUP.",
]

# ------------------------------------------------------------------ shader latar
## Langit senja berlapis: nebula, bintang, matahari terbit (naik sesuai kemajuan loading), sinar, siluet benteng kotak
## dengan jendela menyala, dan lantai grid neon yang bergerak maju.
const SKY_SHADER := """
shader_type canvas_item;

uniform float prog = 0.0;
uniform float flash = 0.0;
uniform vec4 c_top : source_color = vec4(0.012, 0.010, 0.055, 1.0);
uniform vec4 c_mid : source_color = vec4(0.20, 0.05, 0.30, 1.0);
uniform vec4 c_hor : source_color = vec4(1.0, 0.40, 0.13, 1.0);
uniform vec4 c_acc : source_color = vec4(0.25, 0.80, 1.0, 1.0);
uniform vec4 c_sun_a : source_color = vec4(1.0, 0.90, 0.32, 1.0);
uniform vec4 c_sun_b : source_color = vec4(1.0, 0.24, 0.38, 1.0);

const float HORIZON = 0.64;
const float ASP = 1.7778;

float hash21(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float e = prog * prog * (3.0 - 2.0 * prog);

	// turunan dihitung DI LUAR percabangan (aman untuk fwidth)
	float fy = max((uv.y - HORIZON) / (1.0 - HORIZON), 0.0);
	float fz = 1.0 / (fy + 0.02);
	float fx = (uv.x - 0.5) * ASP * fz * 3.2;
	float fzz = fz * 2.2 + t * (0.8 + 1.6 * e);
	float wx = 0.03 + fwidth(fx) * 0.9;
	float wz = 0.03 + fwidth(fzz) * 0.9;

	vec3 col;
	if (uv.y < HORIZON) {
		float h = uv.y / HORIZON;
		col = mix(c_top.rgb, c_mid.rgb, pow(h, 0.9));
		col = mix(col, c_hor.rgb, pow(h, 4.0) * 0.8);

		// nebula
		vec2 p = vec2(uv.x * ASP, uv.y) * 2.0;
		float n1 = fbm(p + vec2(t * 0.025, t * 0.012));
		float n2 = fbm(p * 1.6 + vec2(-t * 0.03, t * 0.015) + n1 * 1.8);
		col += c_acc.rgb * smoothstep(0.50, 0.92, n2) * 0.20 * (1.0 - h * 0.6);
		col += vec3(0.85, 0.25, 0.75) * smoothstep(0.55, 0.95, n1) * 0.16 * (1.0 - h);

		// bintang berkelip
		vec2 sp = vec2(uv.x * ASP, uv.y) * 80.0;
		float rr = hash21(floor(sp));
		if (rr > 0.975) {
			vec2 f = fract(sp) - vec2(0.5);
			float tw = 0.55 + 0.45 * sin(t * (1.2 + rr * 3.0) + rr * 50.0);
			col += vec3(1.0, 0.95, 0.9) * smoothstep(0.22, 0.0, length(f)) * tw * (1.0 - h) * 0.9;
		}

		// matahari terbit (naik sesuai kemajuan loading)
		float R = 0.19;
		vec2 sc = vec2(0.5, HORIZON + 0.17 * (1.0 - e) - 0.05 * e);
		vec2 dv = vec2((uv.x - sc.x) * ASP, uv.y - sc.y);
		float dist = length(dv);
		col += c_hor.rgb * exp(-dist * 4.5) * (0.40 + 0.40 * e);
		float ang = atan(dv.y, dv.x);
		float rays = pow(abs(sin(ang * 9.0 + t * 0.15)), 14.0) * exp(-dist * 2.6);
		col += c_sun_a.rgb * rays * 0.20 * (0.4 + 0.6 * e);
		float disc = smoothstep(R, R - 0.004, dist);
		float below = clamp((uv.y - (sc.y - R)) / (2.0 * R), 0.0, 1.0);
		float k = smoothstep(0.35, 1.0, below);
		float bars = smoothstep(0.0, 0.02, fract(uv.y * 55.0) - k * 0.65);
		vec3 sun = mix(c_sun_a.rgb, c_sun_b.rgb, below);
		col = mix(col, sun, disc * bars);

		// garis cahaya di horizon
		col += c_hor.rgb * smoothstep(0.05, 0.0, HORIZON - uv.y) * 0.55;

		// siluet benteng / kota kotak
		float colx = uv.x * ASP * 26.0;
		float id = floor(colx);
		float fxx = fract(colx);
		float bh = 0.020 + 0.075 * pow(hash21(vec2(id, 7.0)), 1.5);
		float tower = step(0.9, hash21(vec2(id, 3.0)));
		bh += tower * 0.05;
		float cren = step(0.5, fract(colx * 3.0)) * 0.006 * (1.0 - tower);
		float top = HORIZON - bh - cren;
		float wmask = step(0.05, fxx) * step(fxx, 0.88);
		float inb = step(top, uv.y) * wmask;
		vec3 bcol = mix(c_top.rgb * 0.7, c_mid.rgb * 0.35, 0.5);
		vec2 wc = vec2(fxx * 5.0, (uv.y - top) * 75.0);
		vec2 wid = floor(wc);
		vec2 wf = fract(wc);
		float win = step(0.2, wf.x) * step(wf.x, 0.72) * step(0.25, wf.y) * step(wf.y, 0.72);
		win *= step(1.0, wc.y) * step(uv.y, HORIZON - 0.006);
		float rnd = hash21(wid + vec2(id * 1.7, 2.0));
		float on = step(0.80, rnd) * (0.65 + 0.35 * sin(t * (0.6 + rnd * 2.0) + rnd * 30.0));
		col = mix(col, bcol, inb);
		col += mix(c_sun_a.rgb, c_acc.rgb, step(0.9, rnd)) * win * on * inb * 0.9;
		col += c_hor.rgb * inb * smoothstep(0.012, 0.0, uv.y - top) * 0.55;
	} else {
		// lantai grid neon
		float dx = abs(fract(fx + 0.5) - 0.5);
		float dz = abs(fract(fzz + 0.5) - 0.5);
		float lx = 1.0 - smoothstep(0.0, wx, dx);
		float lz = 1.0 - smoothstep(0.0, wz, dz);
		float fade = smoothstep(0.0, 0.22, fy);
		vec3 gcol = mix(c_acc.rgb, c_hor.rgb, exp(-fy * 3.0));
		vec3 fcol = mix(c_hor.rgb * 0.28, c_top.rgb * 1.4, smoothstep(0.0, 0.55, fy));
		fcol += c_hor.rgb * exp(-fy * 10.0) * 0.55;
		fcol += gcol * max(lx, lz) * fade * 0.95;
		fcol += c_sun_a.rgb * exp(-abs(uv.x - 0.5) * ASP * 7.0) * exp(-fy * 4.0) * 0.30 * e;
		col = fcol;
	}

	col = mix(col, vec3(1.0, 0.92, 0.70), flash * 0.5);
	col += (hash21(FRAGCOORD.xy) - 0.5) / 255.0;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
"""

## Kilau yang menyapu logo BOXSIEGE secara berkala.
const LOGO_SHADER := """
shader_type canvas_item;
uniform float sweep = -1.0;
uniform float alpha = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = (UV.x - UV.y * 0.35) - sweep;
	float band = smoothstep(0.10, 0.0, abs(d));
	c.rgb += vec3(1.0, 0.95, 0.8) * band * 0.75 * c.a;
	COLOR = vec4(c.rgb, c.a * alpha);
}
"""

const LOGO_PATH := "res://assets/sprites/ui/title.png"
const LOGO_SIZE := Vector2(540.0, 106.5)        # rasio sama dengan title.png (1024 x 202)
const LOGO_POS := Vector2(370.0, 30.0)

var st: LState
var _t: float = 0.0
var _target: float = 0.0
var _all_done: bool = false
var _finishing: bool = false

# kemajuan langkah (0..1) yang dikerjakan di sini
var _cos_p: float = 0.0
var _cos_total: int = 1
var _gly_p: float = 0.0
var _gpu_p: float = 0.0
var _gpu_frames: int = 0
var _gpu_done: bool = false
var _phase: int = 0                  # 0 aset, 1 kosmetik, 2 huruf, 3 shader, 4 suara, 5 siap
var _cos_gw: Node = null
var _about_gw: Node = null
var _about_done: bool = false

var _tip_i: int = 0
var _tip_cycle: int = 0

var _portal: PortalFx = null         # transisi portal (hidup di root, selamat dari pergantian scene)
var _portal_sent: bool = false

var sky_mat: ShaderMaterial
var logo_mat: ShaderMaterial
var logo: TextureRect
var logo_shadow: TextureRect
var hud: Hud
var fade: ColorRect


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	Global.boot_managed = true
	pivot_offset = Vector2(640.0, 332.0)      # pusat cincin = titik zoom kamera saat outro
	st = LState.new()
	st.status = "STARTING"
	_tip_i = randi() % TIPS.size()
	st.tip = String(TIPS[_tip_i])

	_build_sky()
	var cubes := Cubes.new(st)
	add_child(cubes)
	add_child(_make_embers(80, 7.0, 40.0, 120.0, 0.10, 0.34, true))
	add_child(_make_embers(14, 10.0, 14.0, 40.0, 0.7, 1.5, false))
	_build_vignette()
	_build_logo()

	hud = Hud.new(st)
	add_child(hud)
	add_child(Runners.new(st))
	add_child(GlowLayer.new(hud))

	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

	_boot()


# ================================================================== pekerjaan loading (SUNGGUHAN)
func _boot() -> void:
	# beri 2 frame supaya animasi masuk sudah tampil sebelum pekerjaan berat dimulai
	await get_tree().process_frame
	await get_tree().process_frame

	Global.boot_begin()                       # aset + CAMPAIGN + suara sintetis (berjalan di latar / thread)
	AboutUI.preload_assets()                  # logo + font halaman About
	CosmeticUI.menu_warm_begin(self)          # susun antrean SHOP / INVENTORY (+ penanda pemanasan huruf)
	_cos_total = maxi(Cosmetics._warm_q.size(), 1)
	for c in get_children():
		if c is CosmeticUI.GlyphWarm:
			_cos_gw = c

	# ---- 1) aset + CAMPAIGN + antrean kosmetik (berjalan bersamaan)
	_phase = 0
	var waited: float = 0.0
	while waited < STEP_TIMEOUT and not (Global.boot_preload_done() and Global.boot_campaign_done):
		Cosmetics.warm_step(4)
		_cos_p = 1.0 - float(Cosmetics._warm_q.size()) / float(_cos_total)
		await get_tree().process_frame
		waited += get_process_delta_time()

	# ---- 2) SHOP & INVENTORY
	_phase = 1
	while not Cosmetics._warm_q.is_empty():
		Cosmetics.warm_step(8)
		_cos_p = 1.0 - float(Cosmetics._warm_q.size()) / float(_cos_total)
		await get_tree().process_frame
	await _wait_until(func() -> bool: return _threaded_ready(["res://scenes/shop.tscn", "res://scenes/inventory.tscn"]), 6.0)
	for sfx in CosmeticUI.WARM_SFX:
		Global.get_sfx(String(sfx))
	_cos_p = 1.0

	# ---- 3) huruf berkontur (menu / shop / about)
	_phase = 2
	CosmeticUI._mw_glyph_go = true            # izinkan GlyphWarm milik SHOP / INVENTORY mulai bekerja
	var gw := AboutUI.GlyphWarmer.new()
	_about_gw = gw
	gw.finished.connect(func() -> void: _about_done = true)
	add_child(gw)
	await _wait_until(func() -> bool:
		_gly_p = 0.5 * _glyph_frac_cos() + 0.5 * _glyph_frac_about()
		return CosmeticUI._mw_state == 2 and _about_done, 12.0)
	_gly_p = 1.0

	# ---- 4) shader GPU
	_phase = 3
	_run_gpu()
	await _wait_until(func() -> bool: return _gpu_done, 8.0)
	_gpu_p = 1.0

	# ---- 5) suara sintetis (biasanya sudah selesai sejak tadi)
	_phase = 4
	await _wait_until(func() -> bool: return Global.synth_ready(), STEP_TIMEOUT)

	_phase = 5
	_all_done = true


func _wait_until(cond: Callable, timeout: float) -> void:
	var w: float = 0.0
	while w < timeout and not cond.call():
		await get_tree().process_frame
		w += get_process_delta_time()


func _threaded_ready(paths: Array) -> bool:
	for p in paths:
		var s: int = ResourceLoader.load_threaded_get_status(String(p))
		if s == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return false
	return true


func _glyph_frac_cos() -> float:
	if CosmeticUI._mw_state == 2:
		return 1.0
	if _cos_gw != null and is_instance_valid(_cos_gw):
		var gw: CosmeticUI.GlyphWarm = _cos_gw
		return clampf(float(gw._i) / float(maxi(CosmeticUI.GlyphWarm.COMBOS.size(), 1)), 0.0, 1.0)
	return 0.0


func _glyph_frac_about() -> float:
	if _about_done:
		return 1.0
	if _about_gw != null and is_instance_valid(_about_gw):
		var gw: AboutUI.GlyphWarmer = _about_gw
		return clampf(float(gw._i) / float(maxi(gw._jobs.size(), 1)), 0.0, 1.0)
	return 0.0


## Memanaskan shader latar menu (FxBackground) + semua jenis gambar yang dipakai efek game (GpuWarm).
func _run_gpu() -> void:
	var host := Control.new()
	host.size = Vector2(16.0, 16.0)
	host.clip_contents = true
	host.modulate.a = 0.02
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)
	var fx := UIKit.FxBackground.new()
	host.add_child(fx)
	for i in 3:
		await get_tree().process_frame
		_gpu_frames += 1
	host.queue_free()
	await Global.boot_gpu_warm()
	_gpu_done = true


## Menghitung kemajuan, memperbarui teks status.
func _poll() -> void:
	var pre: float = Global.boot_preload_progress()
	var syn: float = Global.boot_synth_progress()
	var cam: float = Global.boot_campaign_p
	var gpu: float = _gpu_p
	if _phase == 3 and not _gpu_done:
		gpu = minf(float(_gpu_frames) / 22.0, 0.95)
	var tot: float = W_PRE * pre + W_SYN * syn + W_CAM * cam + W_COS * _cos_p + W_GLY * _gly_p + W_GPU * gpu
	if _all_done:
		tot = 1.0
	_target = maxf(_target, minf(tot, 1.0))

	var txt: String = "STARTING"
	var cnt: String = ""
	if _phase == 0:
		if not Global.boot_preload_done():
			txt = "LOADING ASSETS"
			var total: int = maxi(Global._pre_total, 1)
			cnt = "%d / %d" % [int(round(pre * float(total))), total]
		else:
			txt = "BUILDING CAMPAIGN WORLD"
			cnt = "%d%%" % int(cam * 100.0)
	elif _phase == 1:
		txt = "PREPARING SHOP & INVENTORY"
		cnt = "%d%%" % int(_cos_p * 100.0)
	elif _phase == 2:
		txt = "LOADING FONTS & TEXT"
		cnt = "%d%%" % int(_gly_p * 100.0)
	elif _phase == 3:
		txt = "COMPILING VISUAL EFFECTS"
	elif _phase == 4:
		txt = "SYNTHESIZING SOUNDS"
		cnt = "%d%%" % int(syn * 100.0)
	else:
		txt = "ALMOST READY"
	if _finishing:
		txt = "READY!"
		cnt = ""
	st.status = txt
	st.counter = cnt


func _process(d: float) -> void:
	_t += d
	st.t = _t
	_poll()
	if _t > HARD_TIMEOUT and not _all_done:
		_all_done = true                  # pengaman: jangan pernah menggantung di loading screen

	# kemajuan yang ditampilkan: halus, dan tidak lebih cepat dari batas minimal waktu tampil
	var cap: float = clampf((_t - 0.25) / MIN_SHOW, 0.0, 1.0)
	var goal: float = minf(_target, cap)
	st.shown = lerpf(st.shown, goal, 1.0 - exp(-d * 4.5))
	if goal - st.shown < 0.0006:
		st.shown = goal
	st.shown = clampf(st.shown, 0.0, 1.0)

	st.flash = maxf(st.flash - d * 1.6, 0.0)
	if _finishing:
		st.celebrate = minf(st.celebrate + d * 3.0, 1.0)
		st.out_t += minf(d, 0.05)                 # delta dibatasi: hitch sesaat tidak membuat animasi melompat
		_update_outro()
	st.spin += d * (1.0 + 7.0 * st.charge * st.charge)     # cincin berputar makin kencang saat charge
	sky_mat.set_shader_parameter("prog", st.shown)
	sky_mat.set_shader_parameter("flash", st.flash)

	# masuk dari hitam
	fade.color.a = maxf(fade.color.a - d * 1.5, 0.0)

	# tips bergantian dengan fade
	var cyc: int = int(_t / TIP_TIME)
	if cyc != _tip_cycle:
		_tip_cycle = cyc
		_tip_i = (_tip_i + 1) % TIPS.size()
		st.tip = String(TIPS[_tip_i])
	var ph: float = fposmod(_t, TIP_TIME)
	st.tip_a = clampf(ph / 0.4, 0.0, 1.0) * clampf((TIP_TIME - ph) / 0.4, 0.0, 1.0)

	# logo melayang pelan + kilau (saat outro: naik keluar layar sambil memudar)
	var bob: float = sin(_t * 1.4) * 3.0
	var lo := Vector2(0.0, -190.0 * st.ui_out)
	logo.position = LOGO_POS + Vector2(0.0, bob) + lo
	logo_shadow.position = LOGO_POS + Vector2(7.0, 10.0 + bob) + lo
	logo_shadow.modulate = Color(0.0, 0.0, 0.0, 0.55 * (1.0 - st.ui_out))
	logo_mat.set_shader_parameter("alpha", 1.0 - st.ui_out)
	var cyc2: float = fposmod(_t / 3.4, 1.0)
	logo_mat.set_shader_parameter("sweep", -0.4 + 1.9 * clampf(cyc2 * 1.5, 0.0, 1.0))

	if _all_done and not _finishing and st.shown >= 0.9995:
		_finish()


## Loading selesai: ledakan kecil + "READY!". Sisanya (teks hilang, charge, portal zoom, masuk menu) dijalankan
## per-frame oleh _update_outro() berdasarkan st.out_t, lalu PortalFx yang memindahkan scene ke menu.
func _finish() -> void:
	_finishing = true
	Global.boot_end()
	st.shown = 1.0
	st.flash = 1.0
	Global.play_sfx("ui_launch", -3.0)
	UIKit.burst(self, Hud.C, UIKit.GOLD, 48, 460.0, 9.0, 1.1, 520.0)
	UIKit.burst(self, Hud.C, UIKit.CYAN, 28, 340.0, 7.0, 0.9, 420.0)
	UIKit.ring(self, Hud.C, UIKit.GOLD, 260.0, 0.7)


## Mengatur semua nilai animasi keluar (0..1) dari waktu st.out_t. Nilai-nilai ini hanya DIBACA oleh Hud / Runners / logo.
func _update_outro() -> void:
	var o: float = st.out_t

	# angka 100% membal sedikit
	var pop: float = 0.0
	if o < OUT_POP:
		pop = sin(PI * o / OUT_POP)

	# persen + READY! mengecil lalu hilang
	var tv: float = clampf((o - OUT_TEXT0) / OUT_TEXT_DUR, 0.0, 1.0)
	st.txt_a = 1.0 - tv * tv * (3.0 - 2.0 * tv)
	st.txt_k = (1.0 + 0.16 * pop) * (1.0 - 0.55 * tv * tv * tv)

	# cincin menyusut + berputar kencang
	var cv: float = clampf((o - OUT_TEXT0) / OUT_CHARGE_DUR, 0.0, 1.0)
	st.charge = cv * cv * (3.0 - 2.0 * cv)

	# bar, logo, tips, footer, karakter: keluar layar (makin lama makin cepat)
	var ui: float = clampf((o - OUT_TEXT0 - 0.05) / OUT_UI_DUR, 0.0, 1.0)
	st.ui_out = ui * ui * ui

	# portal: zoom kamera & portal dihitung dari nilai u yang SAMA di frame yang sama -> tepi portal selalu menempel di cincin
	if o >= OUT_PORTAL:
		if _portal == null:
			_spawn_portal()
		var u: float = clampf((o - OUT_PORTAL) / PortalFx.COVER_DUR, 0.0, 1.0)
		scale = Vector2.ONE * PortalFx.zoom_at(u)
		_portal.set_cover(u)
		if u >= 1.0 and not _portal_sent:
			_portal_sent = true
			_portal.begin_switch()                     # layar sudah tertutup penuh -> pindah ke menu


func _spawn_portal() -> void:
	_portal = PortalFx.new("res://scenes/%s.tscn" % MENU_SCENE)
	get_tree().root.add_child(_portal)                   # di root: tidak ikut terhapus saat scene berganti
	Global.play_sfx("ui_whoosh", -3.0)


# ================================================================== pembangun tampilan
func _build_sky() -> void:
	var sh := Shader.new()
	sh.code = SKY_SHADER
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = sh
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = sky_mat
	add_child(r)


func _build_vignette() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.06), Color(0, 0, 0, 0.82)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 144
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 0.5)
	var v := TextureRect.new()
	v.texture = gt
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)


func _build_logo() -> void:
	var tex: Texture2D = null
	if ResourceLoader.exists(LOGO_PATH):
		tex = load(LOGO_PATH) as Texture2D
	logo_shadow = TextureRect.new()
	logo_shadow.texture = tex
	logo_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_shadow.stretch_mode = TextureRect.STRETCH_SCALE
	logo_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	logo_shadow.modulate = Color(0, 0, 0, 0.55)
	logo_shadow.size = LOGO_SIZE
	logo_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo_shadow)

	logo = TextureRect.new()
	logo.texture = tex
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_SCALE
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	logo.size = LOGO_SIZE
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = LOGO_SHADER
	logo_mat = ShaderMaterial.new()
	logo_mat.shader = sh
	logo.material = logo_mat
	add_child(logo)


## Bara api yang naik dari bawah (additive). fire = false -> bokeh besar yang redup di latar.
func _make_embers(amount: int, life: float, vmin: float, vmax: float, smin: float, smax: float, fire: bool) -> CPUParticles2D:
	var gt := GradientTexture2D.new()
	var rg := Gradient.new()
	rg.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	rg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	gt.gradient = rg
	gt.width = 32
	gt.height = 32
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var p := CPUParticles2D.new()
	p.texture = gt
	p.material = mat
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.position = Vector2(640.0, 760.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(700.0, 6.0)
	p.direction = Vector2(0.12, -1.0)
	p.spread = 16.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector2(0.0, -6.0)
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	var cr := Gradient.new()
	if fire:
		cr.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
		cr.colors = PackedColorArray([Color(1.0, 0.85, 0.35, 0.0), Color(1.0, 0.62, 0.20, 0.95), Color(1.0, 0.30, 0.12, 0.6), Color(0.8, 0.1, 0.1, 0.0)])
	else:
		cr.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		cr.colors = PackedColorArray([Color(0.5, 0.6, 1.0, 0.0), Color(0.55, 0.5, 1.0, 0.16), Color(0.9, 0.4, 0.9, 0.0)])
	p.color_ramp = cr
	return p


# ================================================================== keadaan bersama
class LState extends RefCounted:
	var t: float = 0.0
	var shown: float = 0.0           # kemajuan yang ditampilkan (0..1)
	var flash: float = 0.0
	var celebrate: float = 0.0       # 0..1 saat loading selesai
	# ---- animasi keluar (diisi _update_outro)
	var out_t: float = 0.0           # detik sejak loading selesai
	var spin: float = 0.0            # sudut putar cincin luar (dipercepat saat charge)
	var charge: float = 0.0          # 0..1 cincin menyusut + berputar kencang
	var txt_a: float = 1.0           # keterlihatan persen + caption di tengah
	var txt_k: float = 1.0           # skala persen
	var ui_out: float = 0.0          # 0..1 bar / logo / tips / footer / karakter keluar layar
	var status: String = ""
	var counter: String = ""
	var tip: String = ""
	var tip_a: float = 0.0


# ================================================================== kubus 3D melayang
class Cubes extends Control:
	const COUNT := 16
	const PAL := [Color("ff4a5a"), Color("4fd8ff"), Color("a6ff2e"), Color("ffd23f"), Color("ff7a2a"), Color("b07bff"), Color("ff3d9a")]
	const VERTS := [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1),
			Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]
	const FACES := [[0, 1, 2, 3], [4, 5, 6, 7], [0, 3, 7, 4], [1, 2, 6, 5], [0, 1, 5, 4], [3, 2, 6, 7]]
	const NORMALS := [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 1, 0)]

	var s: LState
	var items: Array = []

	func _init(state: LState) -> void:
		s = state
		size = Vector2(1280.0, 720.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in COUNT:
			var depth: float = rng.randf()
			var x: float
			if rng.randf() < 0.8:
				x = rng.randf_range(30.0, 400.0) if rng.randf() < 0.5 else rng.randf_range(880.0, 1250.0)
			else:
				x = rng.randf_range(400.0, 880.0)
				depth = minf(depth, 0.3)                 # yang di tengah: kecil & redup supaya tidak mengganggu HUD
			items.append({
				"pos": Vector2(x, rng.randf_range(-40.0, 760.0)),
				"size": lerpf(13.0, 44.0, depth),
				"yaw": rng.randf() * TAU,
				"spin": rng.randf_range(0.35, 1.1) * (1.0 if rng.randf() < 0.5 else -1.0),
				"pitch": rng.randf_range(-0.75, -0.40),
				"wob": rng.randf() * TAU,
				"col": PAL[rng.randi() % PAL.size()],
				"depth": depth,
				"speed": rng.randf_range(8.0, 20.0) * (0.4 + depth),
			})
		items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["depth"]) < float(b["depth"]))

	func _process(d: float) -> void:
		for it in items:
			var pos: Vector2 = it["pos"]
			pos.y -= float(it["speed"]) * d
			pos.x += sin(s.t * 0.5 + float(it["wob"])) * 6.0 * d
			var sz: float = float(it["size"])
			if pos.y < -sz * 2.0:
				pos.y = 720.0 + sz * 2.0
			it["pos"] = pos
			it["yaw"] = float(it["yaw"]) + float(it["spin"]) * d
		queue_redraw()

	func _draw() -> void:
		for it in items:
			_draw_cube(it)

	func _draw_cube(it: Dictionary) -> void:
		var pos: Vector2 = it["pos"]
		var sz: float = float(it["size"])
		var depth: float = float(it["depth"])
		var col: Color = it["col"]
		var yaw: float = float(it["yaw"])
		var pitch: float = float(it["pitch"]) + 0.12 * sin(s.t * 0.8 + float(it["wob"]))
		var cy: float = cos(yaw)
		var sy: float = sin(yaw)
		var cp: float = cos(pitch)
		var sp: float = sin(pitch)
		var pts: Array = []
		for v in VERTS:
			var vv: Vector3 = v
			var x1: float = vv.x * cy + vv.z * sy
			var z1: float = -vv.x * sy + vv.z * cy
			var y2: float = vv.y * cp - z1 * sp
			pts.append(Vector2(x1, y2) * sz + pos)
		var alpha: float = lerpf(0.28, 0.80, depth)
		for f in 6:
			var n: Vector3 = NORMALS[f]
			var nx: float = n.x * cy + n.z * sy
			var nz1: float = -n.x * sy + n.z * cy
			var ny: float = n.y * cp - nz1 * sp
			var nz: float = n.y * sp + nz1 * cp
			if nz <= 0.08:
				continue                                  # sisi membelakangi kamera
			var lit: float = clampf(-0.35 * nx - 0.75 * ny + 0.55 * nz, 0.0, 1.0)
			var shade: float = 0.28 + 0.72 * lit
			var idx: Array = FACES[f]
			var poly := PackedVector2Array([pts[idx[0]], pts[idx[1]], pts[idx[2]], pts[idx[3]]])
			draw_colored_polygon(poly, Color(col.r * shade, col.g * shade, col.b * shade, alpha))
			var edge: Color = col.lerp(Color.WHITE, 0.55)
			edge.a = alpha * 0.9
			draw_polyline(UIKit.closed(poly), edge, 1.5, true)


# ================================================================== HUD: cincin + persen + bar + teks
class Hud extends Control:
	const C := Vector2(640.0, 332.0)       # pusat cincin
	const BX := 250.0                      # progress bar
	const BW := 780.0
	const BY := 574.0
	const BH := 22.0
	const SK := 14.0
	const GOLD := Color("ffd23f")
	const ORANGE := Color("ff7a2a")
	const PINK := Color("ff3d7a")
	const CYAN := Color("4fd8ff")
	const R_RING := 104.0

	var s: LState

	func _init(state: LState) -> void:
		s = state
		size = Vector2(1280.0, 720.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	static func grad(x: float) -> Color:
		x = clampf(x, 0.0, 1.0)
		if x < 0.5:
			return GOLD.lerp(ORANGE, x * 2.0)
		return ORANGE.lerp(PINK, (x - 0.5) * 2.0)

	static func par(x: float, y: float, w: float, h: float, sk: float) -> PackedVector2Array:
		return PackedVector2Array([Vector2(x + sk, y), Vector2(x + sk + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])

	func _arc_pts(p: float) -> PackedVector2Array:
		var n: int = maxi(int(110.0 * p), 3)
		var pts := PackedVector2Array()
		for i in n + 1:
			var a: float = -PI * 0.5 + TAU * p * float(i) / float(n)
			pts.append(C + Vector2(cos(a), sin(a)) * R_RING)
		return pts

	func _arc_cols(p: float, count: int, alpha: float) -> PackedColorArray:
		var cols := PackedColorArray()
		for i in count:
			var c: Color = grad(p * float(i) / float(maxi(count - 1, 1)))
			c.a = alpha
			cols.append(c)
		return cols

	func _draw() -> void:
		var off := Vector2(0.0, s.ui_out * 200.0)        # bar + teks bawah meluncur turun keluar layar saat outro
		draw_set_transform(off, 0.0, Vector2.ONE)
		_draw_dim()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_ring()
		draw_set_transform(off, 0.0, Vector2.ONE)
		_draw_bar()
		_draw_texts()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# gradasi gelap di bawah supaya teks selalu terbaca
	func _draw_dim() -> void:
		draw_polygon(PackedVector2Array([Vector2(0, 556), Vector2(1280, 556), Vector2(1280, 720), Vector2(0, 720)]),
				PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.62), Color(0, 0, 0, 0.62)]))

	func _draw_ring() -> void:
		var t: float = s.t
		var rot: float = s.spin                            # = t, tapi dipercepat saat charge
		var p: float = s.shown
		var kk: float = 1.0 - 0.10 * s.charge              # cincin menyusut sedikit saat charge (skala dari pusat)
		draw_set_transform(C * (1.0 - kk), 0.0, Vector2(kk, kk))
		# piringan
		draw_circle(C + Vector2(0, 8), 120.0, Color(0, 0, 0, 0.30))
		draw_circle(C, 114.0, Color(0.03, 0.02, 0.09, 0.80))
		draw_circle(C, 98.0, Color(0.07, 0.05, 0.18, 0.55))
		# jalur cincin
		draw_arc(C, R_RING, 0.0, TAU, 96, Color(1, 1, 1, 0.10), 12.0, true)
		# garis skala (menyala saat dilewati kemajuan)
		var sweep: float = fposmod(t * 0.55, 1.0)
		for i in 60:
			var a: float = -PI * 0.5 + TAU * float(i) / 60.0
			var d := Vector2(cos(a), sin(a))
			var frac: float = float(i) / 60.0
			var major: bool = i % 5 == 0
			var col := Color(1, 1, 1, 0.14)
			if frac < p:
				col = grad(frac).lerp(Color.WHITE, clampf(1.0 - absf(frac - sweep) * 14.0, 0.0, 1.0) * 0.8)
			draw_line(C + d * 120.0, C + d * (126.0 + (4.0 if major else 0.0)), col, 3.0 if major else 2.0, true)
		# busur kemajuan
		if p > 0.003:
			var pts: PackedVector2Array = _arc_pts(p)
			var cols: PackedColorArray = _arc_cols(p, pts.size(), 1.0)
			draw_polyline_colors(pts, cols, 12.0, true)
			draw_circle(pts[0], 6.0, cols[0])
			draw_circle(pts[pts.size() - 1], 6.5, cols[cols.size() - 1].lerp(Color.WHITE, 0.4))
		# cincin pemutar luar
		for k in 3:
			var base: float = rot * 1.7 + float(k) * TAU / 3.0
			var ln: float = deg_to_rad(52.0 + 22.0 * sin(rot * 2.0 + float(k)))
			draw_arc(C, 142.0, base, base + ln, 20, Color(CYAN.r, CYAN.g, CYAN.b, 0.95), 5.0, true)
		var dn: int = 28
		for k in dn:
			var a0: float = -rot * 0.7 + TAU * float(k) / float(dn)
			draw_arc(C, 153.0, a0, a0 + TAU / float(dn) * 0.45, 4, Color(1, 1, 1, 0.28), 2.5, true)
		# titik mengorbit dengan ekor (warna 4 pemain)
		for k in 4:
			var base2: float = rot * 2.3 + float(k) * TAU / 4.0
			var pc: Color = Global.PLAYER_COLORS[k]
			for j in 9:
				var a2: float = base2 - float(j) * 0.085
				var fr: float = 1.0 - float(j) / 9.0
				draw_circle(C + Vector2(cos(a2), sin(a2)) * 164.0, 5.0 * fr + 1.0, Color(pc.r, pc.g, pc.b, 0.9 * fr))
		# riak
		var rp: float = fposmod(t / 2.4, 1.0)
		draw_arc(C, 114.0 + 40.0 * (1.0 - pow(1.0 - rp, 3.0)), 0.0, TAU, 96, Color(GOLD.r, GOLD.g, GOLD.b, 0.35 * (1.0 - rp)), 3.0, true)

		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# persen di tengah (saat outro: membal -> mengecil -> hilang)
		var ta: float = s.txt_a
		if ta <= 0.003:
			return
		var tk: float = s.txt_k
		draw_set_transform(C * (1.0 - tk), 0.0, Vector2(tk, tk))
		var pct: int = int(floor(p * 100.0 + 0.001))
		if p >= 0.9995:
			pct = 100
		var f: Font = UIKit.font()
		var fs: int = 76
		var num: String = str(pct)
		var nw: float = f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pw: float = f.get_string_size("%", HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		var x0: float = C.x - (nw + pw + 4.0) * 0.5
		var by: float = C.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5 - 6.0
		var fill: Color = Color.WHITE.lerp(GOLD, s.celebrate)
		fill.a = ta
		var ol := Color(0.0, 0.0, 0.0, ta)
		draw_string_outline(f, Vector2(x0 + 3.0, by + 4.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0, 0, 0, 0.55 * ta))
		draw_string_outline(f, Vector2(x0, by), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, ol)
		draw_string(f, Vector2(x0, by), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fill)
		var px: float = x0 + nw + 4.0
		var pcol: Color = grad(0.15 + p * 0.6)
		pcol.a = ta
		draw_string_outline(f, Vector2(px, by - 30.0), "%", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 7, ol)
		draw_string(f, Vector2(px, by - 30.0), "%", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, pcol)
		var cap: String = "READY!" if s.celebrate > 0.0 else "LOADING"
		UIKit.text_in(self, cap, Rect2(C.x - 80.0, C.y + 44.0, 160.0, 24.0), 18, Color(1, 1, 1, 0.7 * ta), HORIZONTAL_ALIGNMENT_CENTER, 4, ol)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_bar() -> void:
		var t: float = s.t
		var p: float = s.shown
		var fw: float = BW * p
		# bayangan + bingkai
		draw_colored_polygon(par(BX - 6.0 + 4.0, BY - 6.0 + 7.0, BW + 12.0, BH + 12.0, SK), Color(0, 0, 0, 0.45))
		var frame: PackedVector2Array = par(BX - 6.0, BY - 6.0, BW + 12.0, BH + 12.0, SK)
		draw_colored_polygon(frame, Color(0.02, 0.02, 0.07, 0.92))
		draw_polyline(UIKit.closed(frame), Color(GOLD.r, GOLD.g, GOLD.b, 0.85), 2.5, true)
		# jalur
		var tc: Color = Color(0.15, 0.13, 0.28)
		var tb: Color = Color(0.07, 0.06, 0.14)
		draw_polygon(par(BX, BY, BW, BH, SK), PackedColorArray([tc, tc, tb, tb]))
		# isi
		if fw > 1.0:
			var cl: Color = grad(0.0)
			var cr: Color = grad(p)
			var dk: float = 0.72
			draw_polygon(par(BX, BY, fw, BH, SK), PackedColorArray([cl, cr, Color(cr.r * dk, cr.g * dk, cr.b * dk), Color(cl.r * dk, cl.g * dk, cl.b * dk)]))
			# garis-garis miring yang bergerak
			var off: float = fposmod(t * 38.0, 36.0)
			var xs: float = -36.0 + off
			while xs < fw:
				var xl: float = clampf(xs, 0.0, fw)
				var xr: float = clampf(xs + 14.0, 0.0, fw)
				if xr - xl > 0.5:
					draw_colored_polygon(par(BX + xl, BY, xr - xl, BH, SK), Color(1, 1, 1, 0.13))
				xs += 36.0
			# kilap bagian atas
			draw_colored_polygon(PackedVector2Array([
					Vector2(BX + SK, BY), Vector2(BX + SK + fw, BY),
					Vector2(BX + SK * 0.5 + fw, BY + BH * 0.5), Vector2(BX + SK * 0.5, BY + BH * 0.5)]), Color(1, 1, 1, 0.16))
			# kilau yang menyapu isi bar
			var sh: float = fposmod(t * 0.7, 1.7)
			var cx: float = sh * (fw + 120.0) - 60.0
			var sl: float = clampf(cx - 22.0, 0.0, fw)
			var sr: float = clampf(cx + 22.0, 0.0, fw)
			if sr - sl > 0.5:
				draw_colored_polygon(par(BX + sl, BY, sr - sl, BH, SK), Color(1, 1, 1, 0.33))
			# garis terang di ujung isi
			draw_line(Vector2(BX + SK + fw, BY), Vector2(BX + fw, BY + BH), Color(1, 1, 1, 0.95), 3.0, true)

	func _draw_texts() -> void:
		var dots: String = ".".repeat(int(s.t * 2.6) % 4)
		var stat: String = s.status
		if s.celebrate <= 0.0:
			stat += dots
		UIKit.text_in(self, stat, Rect2(BX, BY + BH + 12.0, BW * 0.7, 30.0), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 5)
		if s.counter != "":
			UIKit.text_in(self, s.counter, Rect2(BX + BW * 0.5, BY + BH + 12.0, BW * 0.5 + SK, 30.0), 22, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_RIGHT, 4)

		# tips
		var bf: Font = AboutUI.body_font()
		var fs: int = 21
		var a: float = s.tip_a
		var tag_w: float = UIKit.text_w("TIP", fs, bf) + 22.0
		var tw: float = UIKit.text_w(s.tip, fs, bf)
		var total: float = tag_w + 12.0 + tw
		var x: float = 640.0 - total * 0.5
		var ty: float = 668.0
		var chip := Rect2(x, ty - 2.0, tag_w, 30.0)
		draw_rect(chip, Color(GOLD.r, GOLD.g, GOLD.b, 0.92 * a))
		UIKit.text_in(self, "TIP", chip, fs, Color(0.1, 0.06, 0.02, a), HORIZONTAL_ALIGNMENT_CENTER, 0, Color.BLACK, bf)
		UIKit.text_in(self, s.tip, Rect2(x + tag_w + 12.0, ty - 2.0, tw + 8.0, 30.0), fs, Color(1, 1, 1, 0.95 * a), HORIZONTAL_ALIGNMENT_LEFT, 4, Color(0, 0, 0, a), bf)

		# footer
		var ff: Font = UIKit.font()
		var left: String = "© %s %s %s" % [AboutData.COPYRIGHT_YEAR, AboutData.STUDIO_NAME_TOP, AboutData.STUDIO_NAME_BOTTOM]
		UIKit.text_in(self, left, Rect2(24.0, 694.0, 500.0, 20.0), 14, Color(1, 1, 1, 0.38), HORIZONTAL_ALIGNMENT_LEFT, 0, Color.BLACK, ff)
		UIKit.text_in(self, "MADE WITH %s" % AboutData.ENGINE_NAME.to_upper(), Rect2(1280.0 - 524.0, 694.0, 500.0, 20.0), 14, Color(1, 1, 1, 0.38), HORIZONTAL_ALIGNMENT_RIGHT, 0, Color.BLACK, ff)

	## Cahaya tambahan: dipanggil oleh GlowLayer (blend ADDITIVE).
	func draw_glow(ci: CanvasItem) -> void:
		var t: float = s.t
		var p: float = s.shown
		var kk: float = 1.0 - 0.10 * s.charge              # ikut menyusut bersama cincin
		ci.draw_set_transform(C * (1.0 - kk), 0.0, Vector2(kk, kk))
		ci.draw_circle(C, 100.0, Color(1.0, 0.55, 0.2, 0.04 + 0.02 * sin(t * 2.0)))
		if p > 0.003:
			var pts: PackedVector2Array = _arc_pts(p)
			ci.draw_polyline_colors(pts, _arc_cols(p, pts.size(), 0.16), 28.0, true)
			ci.draw_polyline_colors(pts, _arc_cols(p, pts.size(), 0.22), 18.0, true)
			var hp: Vector2 = pts[pts.size() - 1]
			for k in 5:
				ci.draw_circle(hp, 9.0 + float(k) * 7.0, Color(1.0, 0.72, 0.3, 0.13 * float(5 - k) / 5.0))
		# kilat saat selesai
		if s.flash > 0.01:
			ci.draw_circle(C, 120.0 + 320.0 * (1.0 - s.flash), Color(1.0, 0.9, 0.6, 0.33 * s.flash))
		# bar (ikut meluncur keluar layar saat outro)
		ci.draw_set_transform(Vector2(0.0, s.ui_out * 200.0), 0.0, Vector2.ONE)
		var fw: float = BW * p
		var head := Vector2(BX + fw + SK * 0.5, BY + BH * 0.5)
		if fw > 2.0:
			ci.draw_colored_polygon(par(BX - 2.0, BY - 5.0, fw + 4.0, BH + 10.0, SK), Color(1.0, 0.6, 0.2, 0.10))
		for k in 5:
			ci.draw_circle(head, 8.0 + float(k) * 6.0, Color(1.0, 0.8, 0.4, 0.15 * float(5 - k) / 5.0))
		# percikan dari ujung bar
		for k in 8:
			var ph: float = fposmod(t * 1.3 + float(k) * 0.37, 1.0)
			var sx: float = head.x - ph * 14.0 + sin(float(k) * 5.1) * 8.0
			var sy: float = head.y - 4.0 - ph * 48.0
			ci.draw_circle(Vector2(sx, sy), 2.4 * (1.0 - ph) + 0.6, Color(1.0, 0.86, 0.45, 0.9 * (1.0 - ph)))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Lapisan cahaya (additive) di atas HUD.
class GlowLayer extends Control:
	var hud: Hud

	func _init(h: Hud) -> void:
		hud = h
		size = Vector2(1280.0, 720.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		hud.draw_glow(self)


# ================================================================== 4 karakter box berlari mengikuti bar
class Runners extends Control:
	const SP := 50.0
	const SZ := 56.0
	var s: LState
	var tex: Array = []

	func _init(state: LState) -> void:
		s = state
		size = Vector2(1280.0, 720.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR       # sprite diperkecil -> pakai filter halus
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for folder in ["p1", "p2", "p3", "p4"]:                  # satu karakter acak dari tiap warna pemain
			var pool: Array[int] = []
			for i in Global.CHARACTERS.size():
				if String(Global.CHARACTERS[i][0]) == folder:
					pool.append(i)
			if not pool.is_empty():
				var idx: int = pool[rng.randi() % pool.size()]
				var tx: Texture2D = Global.character_texture(0, idx)
				if tx != null:
					tex.append(tx)

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var head: float = Hud.BX + 22.0 + s.shown * (Hud.BW - 44.0)
		var ue: float = s.ui_out                                 # outro: keempat karakter berlari keluar ke kanan
		for i in range(tex.size() - 1, -1, -1):                  # yang paling depan digambar terakhir
			var x: float = head - float(i) * SP + ue * 950.0
			var ph: float = s.t * 7.5 + float(i) * 0.9
			var hop: float = absf(sin(ph))
			var lift: float = hop * (12.0 + 34.0 * s.celebrate)
			var sx: float = lerpf(1.10, 0.94, hop)
			var sy: float = lerpf(0.90, 1.07, hop)
			# bayangan di atas bar
			if x > Hud.BX - 6.0 and x < Hud.BX + Hud.BW + 6.0:
				var sw: float = 24.0 * (1.0 - 0.45 * hop)
				var sp := PackedVector2Array()
				for j in 14:
					var a: float = TAU * float(j) / 14.0
					sp.append(Vector2(x + cos(a) * sw, Hud.BY + 1.0 + sin(a) * 3.5))
				draw_colored_polygon(sp, Color(0, 0, 0, 0.45 * (1.0 - 0.6 * hop) * (1.0 - clampf(ue * 8.0, 0.0, 1.0))))
			draw_set_transform(Vector2(x, Hud.BY - 3.0 - lift), 0.08 + 0.06 * sin(ph * 0.5), Vector2(sx, sy))
			var r := Rect2(-SZ * 0.5, -SZ, SZ, SZ)
			draw_rect(r.grow(3.0), Color(0, 0, 0, 0.92))
			draw_texture_rect(tex[i], r, false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ================================================================== PORTAL: bulatan tengah -> zoom -> menu utama
## Transisi yang menyambung loading screen ke menu utama. Node ini dipasang di ROOT (bukan di scene loading), jadi tetap
## hidup setelah scene loading dihapus dan scene menu dimuat. Urutannya:
##   1) COVER  : (dikendalikan Loading lewat set_cover(u)) disc di tengah cincin membesar dengan zoom EKSPONENSIAL,
##               dan Loading di-scale dengan faktor yang sama -> tepi portal selalu persis di cincin. Menjelang akhir
##               warna isi berubah dari gelap menjadi cahaya hangat (flash) sehingga tidak ada layar datar gelap.
##   2) SWITCH : saat layar penuh cahaya -> pindah ke scene menu (hitch pemuatan tertutup flash)
##   3) REVEAL : warna sama dengan akhir cover (tanpa lompatan). Cahaya mencair, lubang lembut membuka dari titik tengah
##               dengan cincin + sinar, menu mengendap dari ENTER_ZOOM ke 1.0. Waktu memakai delta yang dibatasi.
## Semua digambar dengan satu shader pada satu ColorRect.
class PortalFx extends CanvasLayer:
	const C := Vector2(640.0, 332.0)       # pusat cincin (sama dengan Hud.C)
	const R0 := 102.6                      # radius disc cincin setelah menyusut (114 x 0.9) = radius awal portal
	const R_FAR := 830.0                   # cukup besar untuk menutup pojok layar (jarak terjauh dari pusat = 748)
	const COVER_DUR := 0.62                # lama zoom sampai layar penuh cahaya
	const REVEAL_DUR := 0.95               # lama flash mencair + lubang membuka
	const ENTER_ZOOM := 1.20               # menu mulai sedikit membesar lalu mengendap ke 1.0
	const WARM := Color(1.0, 0.86, 0.55)   # warna cahaya di puncak zoom
	const DARK := Color(0.03, 0.02, 0.09)  # warna isi disc (sama dengan disc di Hud)
	const DEEP := Color(0.14, 0.05, 0.03)  # warna isi saat mencair (senada latar menu)

	const SHADER := """
shader_type canvas_item;

uniform vec2 center = vec2(640.0, 332.0);
uniform vec2 area = vec2(1280.0, 720.0);
uniform float radius = 103.0;
uniform float band = 12.0;
uniform float soft = 1.0;         // kelembutan tepi isi (px)
uniform float fill_a = 0.0;
uniform float invert = 0.0;       // 0 = isi di DALAM lingkaran (cover), 1 = isi di LUAR lingkaran (reveal / lubang)
uniform float ring_a = 0.0;
uniform float glow_a = 0.0;
uniform float warp = 0.0;
uniform float flash = 0.0;
uniform float spin = 0.0;
uniform vec4 fill = vec4(0.03, 0.02, 0.09, 1.0);

const float TWO_PI = 6.2831853;

vec4 over(vec4 t, vec4 b) {
	float a = t.a + b.a * (1.0 - t.a);
	vec3 c = (t.rgb * t.a + b.rgb * b.a * (1.0 - t.a)) / max(a, 0.0001);
	return vec4(c, a);
}

float hash11(float x) {
	return fract(sin(x * 91.7 + 3.1) * 43758.5453);
}

// gradasi emas -> oranye -> pink (sama dengan progress cincin) + garis cyan yang berputar
vec3 ring_col(float ang, float sp) {
	float x = fract(ang / TWO_PI + sp);
	float k = abs(x * 2.0 - 1.0);
	vec3 gold = vec3(1.0, 0.82, 0.25);
	vec3 orange = vec3(1.0, 0.48, 0.16);
	vec3 pink = vec3(1.0, 0.24, 0.48);
	vec3 c = mix(gold, orange, clamp(k * 2.0, 0.0, 1.0));
	c = mix(c, pink, clamp(k * 2.0 - 1.0, 0.0, 1.0));
	float cy = smoothstep(0.55, 1.0, sin(ang * 3.0 - sp * TWO_PI * 2.0) * 0.5 + 0.5);
	return mix(c, vec3(0.31, 0.85, 1.0), cy * 0.85);
}

void fragment() {
	vec2 p = UV * area;
	vec2 v = p - center;
	float dist = length(v);
	float ang = atan(v.y, v.x);
	float d = dist - radius;
	float sf = max(soft, 0.5);
	float inside = 1.0 - smoothstep(-sf, sf, d);
	float body = mix(inside, 1.0 - inside, invert);
	float side = mix(d, -d, invert);          // > 0 = sisi yang transparan

	vec3 rc = ring_col(ang, spin);
	vec4 res = vec4(fill.rgb, body * fill.a * fill_a);

	// sinar warp memancar dari tepi cincin ke sisi yang transparan
	float n = (ang / TWO_PI + 0.5) * 72.0;
	float id = floor(n);
	float f = fract(n);
	float h = hash11(id);
	float ray = 1.0 - smoothstep(0.0, 0.30, abs(f - 0.5));
	ray *= step(0.45, h);
	float reach = 50.0 + 330.0 * h;
	float ra = ray * exp(-max(side, 0.0) / reach) * smoothstep(0.0, 3.0, side) * warp * (0.45 + 0.55 * h);
	vec3 raycol = mix(vec3(1.0, 0.9, 0.6), vec3(0.45, 0.9, 1.0), step(0.7, h));
	res = over(vec4(raycol, clamp(ra, 0.0, 1.0)), res);

	// cahaya lembut di sekitar tepi
	float halo = exp(-abs(d) / (band * 1.6 + 6.0)) * glow_a;
	res = over(vec4(rc, halo * 0.55), res);

	// pita cincin bertanda garis skala
	float hb = band * 0.5;
	float rb = 1.0 - smoothstep(hb - 1.0, hb + 1.0, abs(d));
	float tick = 0.80 + 0.20 * step(0.5, fract(ang / TWO_PI * 60.0 - spin * 3.0));
	res = over(vec4(rc * tick, rb * ring_a), res);

	// garis inti putih tipis di tengah pita
	float core = 1.0 - smoothstep(0.5, 2.5, abs(d));
	res = over(vec4(1.0, 0.97, 0.85, core * 0.85 * ring_a), res);

	// kilat di pusat
	float fl = flash * exp(-dist / 300.0);
	res = over(vec4(1.0, 0.92, 0.65, fl * 0.55), res);

	COLOR = res;
}
"""

	var target_path: String = ""
	var rect: ColorRect
	var mat: ShaderMaterial
	var _spin: float = 0.0
	var _menu: Control = null
	var _revealing: bool = false
	var _rt: float = 0.0

	func _init(path: String) -> void:
		target_path = path
		name = "BoxPortalFx"
		layer = 100
		process_mode = Node.PROCESS_MODE_ALWAYS
		var sh := Shader.new()
		sh.code = SHADER
		mat = ShaderMaterial.new()
		mat.shader = sh
		rect = ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.material = mat
		add_child(rect)
		set_cover(0.0)

	## Faktor zoom pada kemajuan cover u (0..1). Eksponensial: kecepatan zoom yang dirasakan mata terasa konstan lalu
	## makin menghentak di akhir. Dipakai Loading untuk scale kamera DAN di sini untuk radius portal -> selalu sinkron.
	static func zoom_at(u: float) -> float:
		return pow(R_FAR / R0, pow(clampf(u, 0.0, 1.0), 1.6))

	func _process(d: float) -> void:
		_spin += d * 0.9
		mat.set_shader_parameter("spin", _spin)
		if rect.size.x > 1.0 and rect.size.y > 1.0:
			mat.set_shader_parameter("area", rect.size)
		if _revealing:
			_rt += minf(d, 1.0 / 30.0)          # delta dibatasi supaya hitch tidak memotong animasi buka
			var u: float = clampf(_rt / REVEAL_DUR, 0.0, 1.0)
			_apply_reveal(u)
			if u >= 1.0:
				_revealing = false
				if _menu != null and is_instance_valid(_menu):
					_menu.scale = Vector2.ONE
				queue_free()

	## Dipanggil Loading tiap frame selama cover.
	func set_cover(u: float) -> void:
		if _revealing:
			return
		var z: float = zoom_at(u)
		var lt: float = smoothstep(0.50, 1.0, u)                       # 0 = gelap, 1 = cahaya hangat
		var fade_out: float = 1.0 - smoothstep(0.80, 1.0, u)
		var ra: float = smoothstep(0.0, 0.20, u) * fade_out
		mat.set_shader_parameter("invert", 0.0)
		mat.set_shader_parameter("radius", R0 * z)
		mat.set_shader_parameter("band", 10.0 * z)                       # cincin ikut membesar bersama zoom
		mat.set_shader_parameter("soft", 1.0 + 5.0 * lt)
		mat.set_shader_parameter("fill", DARK.lerp(WARM, lt))
		mat.set_shader_parameter("fill_a", smoothstep(0.0, 0.60, u))
		mat.set_shader_parameter("ring_a", ra)
		mat.set_shader_parameter("glow_a", ra)
		mat.set_shader_parameter("warp", smoothstep(0.10, 0.50, u) * fade_out)
		mat.set_shader_parameter("flash", 0.8 * lt)

	## Dipanggil Loading satu kali saat cover selesai.
	func begin_switch() -> void:
		set_cover(1.0)
		_switch()

	func _switch() -> void:
		var tree: SceneTree = get_tree()
		tree.paused = false
		var err: Error = tree.change_scene_to_file(target_path)
		if err != OK:
			push_warning("PortalFx: gagal pindah ke %s (error %d)" % [target_path, err])
		# tunggu scene menu benar-benar terpasang (pergantian scene dikerjakan di akhir frame)
		for i in 15:
			await tree.process_frame
			var cs: Node = tree.current_scene
			if i >= 1 and cs != null and cs.scene_file_path == target_path:
				break
		# beberapa frame ekstra: frame berat (membangun menu + upload shader) habis selagi layar masih penuh cahaya
		await tree.process_frame
		await tree.process_frame
		_menu = tree.current_scene as Control
		if _menu != null:
			_menu.pivot_offset = C
			_menu.scale = Vector2.ONE * ENTER_ZOOM
		_rt = 0.0
		_apply_reveal(0.0)
		_revealing = true

	func _apply_reveal(u: float) -> void:
		var inv: float = maxf(1.0 - u, 0.0)
		var e: float = 1.0 - pow(inv, 3.2)                            # lubang meledak cepat lalu melambat
		var sf: float = lerpf(46.0, 1.5, e)
		mat.set_shader_parameter("invert", 1.0)
		mat.set_shader_parameter("soft", sf)
		mat.set_shader_parameter("radius", lerpf(-sf, R_FAR + 60.0, e))   # mulai tertutup rapat (tanpa lompatan dari cover)
		mat.set_shader_parameter("band", lerpf(60.0, 8.0, e))
		mat.set_shader_parameter("fill", WARM.lerp(DEEP, smoothstep(0.0, 0.55, u)))
		mat.set_shader_parameter("fill_a", 1.0 - smoothstep(0.45, 0.95, u))   # sisa isi mencair halus (crossfade)
		var ra: float = 1.0 - smoothstep(0.50, 0.95, u)
		mat.set_shader_parameter("ring_a", ra)
		mat.set_shader_parameter("glow_a", ra)
		mat.set_shader_parameter("warp", pow(inv, 1.6) * smoothstep(0.0, 0.08, u))
		mat.set_shader_parameter("flash", 0.8 * pow(inv, 2.0))
		if _menu != null and is_instance_valid(_menu):
			_menu.scale = Vector2.ONE * lerpf(ENTER_ZOOM, 1.0, 1.0 - pow(inv, 4.0))
