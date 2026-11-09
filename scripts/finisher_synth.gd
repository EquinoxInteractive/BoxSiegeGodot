class_name FinisherSynth
extends RefCounted
## SUARA FINISHER (kill terakhir, skin senjata LV3).
##
## Satu suara untuk SETIAP jenis finisher (bukan per senjata / per skin), jadi finisher yang sama SELALU berbunyi sama.
## Semua suara dihitung lewat kode (tanpa file audio) oleh mesin suara sintetis di global.gd (thread latar belakang +
## cache disk), sudah selesai sebelum pertandingan dimulai (loading screen menunggunya).
## Panjang tiap suara = Finisher.D (3.6 dtk) dan disusun PERSIS mengikuti waktu animasi di finisher.gd:
##   t = 0      benturan kill (kilatan putih)           -> hantaman khas tiap finisher
##   sisanya    fase animasi masing-masing finisher      -> lihat komentar di tiap fungsi _<jenis>()
## Finisher memutar suaranya sendiri (finisher.gd -> _sync_audio), jadi otomatis ikut Game, Replay (jeda / geser / kecepatan)
## dan preview Shop / Inventory.
##
## Mengubah rumus suara? NAIK-kan Global.SYNTH_CACHE_VER supaya cache disk dibuat ulang.

const D := 3.6
const KINDS := ["blackhole", "lightning", "inferno", "glitch", "shatter", "ascend", "petals", "cosmic", "toxic", "jackpot", "slice",
	"meteor", "tsunami", "reaper", "portal", "sands", "firework", "orbital", "hex", "balloon", "ufo"]

## Bus pemutaran: "Celebrate" = SFX + gema (megah / luas), "SFX" = kering (tajam / dekat).
const BUS := {
	"blackhole": "Celebrate", "lightning": "Celebrate", "inferno": "SFX", "glitch": "SFX", "shatter": "Celebrate",
	"ascend": "Celebrate", "petals": "Celebrate", "cosmic": "Celebrate", "toxic": "SFX", "jackpot": "Celebrate", "slice": "SFX",
	"meteor": "SFX", "tsunami": "Celebrate", "reaper": "Celebrate", "portal": "Celebrate", "sands": "Celebrate",
	"firework": "Celebrate", "orbital": "SFX", "hex": "Celebrate", "balloon": "SFX", "ufo": "Celebrate",
}
## Volume (dB) per jenis, supaya semua finisher terdengar sama keras.
const GAIN := {
	"blackhole": -4.5, "lightning": -3.5, "inferno": -4.0, "glitch": -2.0, "shatter": -3.0,
	"ascend": -3.5, "petals": -3.0, "cosmic": -5.0, "toxic": -3.0, "jackpot": -2.5, "slice": -2.0,
	"meteor": -4.0, "tsunami": -4.0, "reaper": -3.5, "portal": -4.0, "sands": -3.0,
	"firework": -3.5, "orbital": -4.0, "hex": -3.5, "balloon": -3.0, "ufo": -3.5,
}
const SCALE := [0.0, 3.0, 7.0, 10.0, 12.0, 15.0]


static func ids() -> Array:
	var out: Array = []
	for k in KINDS:
		out.append("fin_" + String(k))
	return out


static func is_id(id: String) -> bool:
	return id.begins_with("fin_")


static func spec(id: String) -> Dictionary:
	match id:
		"fin_shatter", "fin_ascend", "fin_petals", "fin_cosmic", "fin_jackpot", "fin_slice", "fin_reaper", "fin_portal", "fin_sands", "fin_firework", "fin_orbital", "fin_hex", "fin_balloon", "fin_ufo":
			return {"rate": 32000, "dur": D}
	return {"rate": 22050, "dur": D}


static func bus_of(kind: String) -> String:
	return String(BUS.get(kind, "SFX"))


static func gain_of(kind: String) -> float:
	return float(GAIN.get(kind, -4.0))


static func fill(id: String, buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	match id:
		"fin_blackhole": _blackhole(buf, i0, i1, rate, ctx)
		"fin_lightning": _lightning(buf, i0, i1, rate, ctx)
		"fin_inferno": _inferno(buf, i0, i1, rate, ctx)
		"fin_glitch": _glitch(buf, i0, i1, rate, ctx)
		"fin_shatter": _shatter(buf, i0, i1, rate, ctx)
		"fin_ascend": _ascend(buf, i0, i1, rate, ctx)
		"fin_petals": _petals(buf, i0, i1, rate, ctx)
		"fin_cosmic": _cosmic(buf, i0, i1, rate, ctx)
		"fin_toxic": _toxic(buf, i0, i1, rate, ctx)
		"fin_jackpot": _jackpot(buf, i0, i1, rate, ctx)
		"fin_slice": _slice(buf, i0, i1, rate, ctx)
		"fin_meteor": _meteor(buf, i0, i1, rate, ctx)
		"fin_tsunami": _tsunami(buf, i0, i1, rate, ctx)
		"fin_reaper": _reaper(buf, i0, i1, rate, ctx)
		"fin_portal": _portal(buf, i0, i1, rate, ctx)
		"fin_sands": _sands(buf, i0, i1, rate, ctx)
		"fin_firework": _firework(buf, i0, i1, rate, ctx)
		"fin_orbital": _orbital(buf, i0, i1, rate, ctx)
		"fin_hex": _hex(buf, i0, i1, rate, ctx)
		"fin_balloon": _balloon(buf, i0, i1, rate, ctx)
		"fin_ufo": _ufo(buf, i0, i1, rate, ctx)


# ================================================================== alat bantu
static func _hz(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## Acak deterministik (sama dengan FxDraw.h) -> pola glitch selalu sama.
static func _hs(i: float, salt: float) -> float:
	return fposmod(sin(i * 12.9898 + salt * 78.233) * 43758.5453, 1.0)


## Lonceng kaca: [mulai, hz, amp, peluruhan, amp parsial-2, amp parsial-3]. Parsial di atas Nyquist dimatikan (anti-alias).
static func _be(start: float, hz: float, amp: float, dec: float, rate: int) -> Array:
	var nyq: float = float(rate) * 0.45
	var p2: float = 0.42 if hz * 2.756 < nyq else 0.0
	var p3: float = 0.2 if hz * 5.404 < nyq else 0.0
	return [start, hz, amp, dec, p2, p3]


## Sebar `count` lonceng acak: waktu = t_from + span * rand^curve (curve > 1 = rapat di awal), nada dari daftar midi.
static func _scatter(rng: RandomNumberGenerator, rate: int, count: int, t_from: float, span: float, curve: float, midis: Array, a_lo: float, a_hi: float, d_lo: float, d_hi: float) -> Array:
	var out: Array = []
	for k in range(count):
		var st: float = t_from + span * pow(rng.randf(), curve)
		var m: float = float(midis[rng.randi() % midis.size()])
		var am: float = rng.randf_range(a_lo, a_hi)
		var dc: float = rng.randf_range(d_lo, d_hi)
		out.append(_be(st, _hz(m), am, dc, rate))
	return out


## Menambahkan semua lonceng yang sedang aktif ke buf[i0, i1).
static func _bells(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ev: Array) -> void:
	var r: float = float(rate)
	var t0: float = float(i0) / r
	var t1: float = float(i1) / r
	var act: Array = []
	for e in ev:
		var st: float = float(e[0])
		if t1 >= st and t0 <= st + float(e[3]) * 6.0:
			act.append(e)
	if act.size() == 0:
		return
	for i in range(i0, i1):
		var t: float = float(i) / r
		var x: float = 0.0
		for b in act:
			var tt: float = t - float(b[0])
			if tt < 0.0:
				continue
			var d: float = exp(-tt / float(b[3])) * float(b[2])
			if d < 0.003:
				continue
			var w: float = TAU * float(b[1]) * tt
			var s: float = sin(w) + float(b[4]) * sin(w * 2.756) * exp(-tt * 9.0) + float(b[5]) * sin(w * 5.404) * exp(-tt * 18.0)
			x += s * d * minf(tt / 0.002, 1.0)
		buf[i] += x


## Pad paduan suara: jumlah nada (hz) dengan vibrato halus.
static func _pad(t: float, hzs: Array, vib: float) -> float:
	var x: float = 0.0
	for k in range(hzs.size()):
		var f: float = float(hzs[k])
		var w: float = TAU * f * t + vib * sin(TAU * (4.6 + 0.37 * float(k)) * t + float(k) * 1.7)
		x += sin(w) + 0.4 * sin(w * 2.0) + 0.12 * sin(w * 3.0)
	return x


## Penutup tiap suara: soft-clip (supaya puncak tidak menghancurkan bagian lain) + fade-out halus di akhir + fade-in 1 ms.
static func _finish(buf: PackedFloat32Array, i0: int, i1: int, rate: int, drive: float) -> void:
	var r: float = float(rate)
	for i in range(i0, i1):
		var t: float = float(i) / r
		var fade: float = (1.0 - smoothstep(D - 0.4, D - 0.02, t)) * minf(t / 0.001, 1.0)
		buf[i] = tanh(buf[i] * drive) * fade


# ================================================================== 1. EVENT HORIZON (blackhole)
## 0.00 hantaman berat | 0.1-0.9 lubang hitam membuka: dengung sub makin dalam + pusaran | 0.9-2.2 korban terhisap: nada
## berputar makin cepat & tinggi | 2.12-2.25 ruang HENING (vakum) | 2.25 runtuh: ledakan sub + gelombang kejut | sisa: gemuruh.
static func _blackhole(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	var ph: float = float(ctx.get("ph", 0.0))
	var ph2: float = float(ctx.get("ph2", 0.0))
	var ph3: float = float(ctx.get("ph3", 0.0))
	var ph4: float = float(ctx.get("ph4", 0.0))
	var low: float = float(ctx.get("low", 0.0))
	var band: float = float(ctx.get("band", 0.0))
	var lp1: float = float(ctx.get("lp1", 0.0))
	var lp2: float = float(ctx.get("lp2", 0.0))
	var lp3: float = float(ctx.get("lp3", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		var grow: float = smoothstep(0.1, 0.9, t)
		var col: float = 1.0 - smoothstep(2.07, 2.16, t)
		var e: float = pow(clampf((t - 0.9) / 1.3, 0.0, 1.0), 2.0)
		# hantaman awal
		ph4 += TAU * (42.0 + 60.0 * exp(-t * 24.0)) / r
		var x: float = sin(ph4) * exp(-t * 7.0) * 1.1
		lp3 += (n - lp3) * 0.35
		x += (n - lp3) * exp(-t * 55.0) * 0.9
		# dengung sub yang makin dalam lalu naik saat terhisap
		var f0: float = 38.0 + 22.0 * grow + 150.0 * e
		ph += TAU * f0 * (1.0 + 0.012 * sin(TAU * 6.0 * t) * grow) / r
		x += (sin(ph) + 0.5 * sin(ph * 2.0 + sin(ph * 0.5)) + 0.22 * sin(ph * 3.0)) * grow * col * 0.3
		# pusaran noise (band-pass naik)
		var fc: float = 160.0 + 2600.0 * e + 90.0 * sin(t * 7.0)
		var fq: float = minf(2.0 * sin(PI * minf(fc, 7000.0) / r), 1.0)
		var high: float = n - low - 0.35 * band
		band += fq * high
		low += fq * band
		x += band * (0.12 + 0.5 * e) * grow * col
		# nada berputar (spin-up)
		ph2 += TAU * (320.0 + 1700.0 * e) / r
		x += sin(ph2 + 2.0 * sin(ph2 * 0.37)) * e * col * 0.1
		# runtuh
		var tc: float = t - 2.25
		if tc >= 0.0:
			ph3 += TAU * (30.0 + 170.0 * exp(-tc * 11.0)) / r
			x += sin(ph3) * exp(-tc * 2.4) * minf(tc / 0.003, 1.0) * 2.0
			lp1 += (n - lp1) * (0.02 + 0.5 * exp(-tc * 30.0))
			x += lp1 * exp(-tc * 4.2) * 3.0
			lp2 += (n - lp2) * 0.3
			x += (n - lp2) * exp(-tc * 40.0) * 1.0
		buf[i] = x
	ctx["ph"] = ph
	ctx["ph2"] = ph2
	ctx["ph3"] = ph3
	ctx["ph4"] = ph4
	ctx["low"] = low
	ctx["band"] = band
	ctx["lp1"] = lp1
	ctx["lp2"] = lp2
	ctx["lp3"] = lp3
	_finish(buf, i0, i1, rate, 1.15)


# ================================================================== 2. WRATH OF STORM (lightning)
## 0.15-0.55 listrik mengisi: rengekan naik + letupan kecil | 0.55 SAMBARAN: retakan + dentum sub | 0.55-1.25 dengung listrik
## berkedip (28 Hz, sama dengan kedip layar) | 0.7-3.3 guruh bergulung | percikan api mereda.
static func _lightning(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	var ph: float = float(ctx.get("ph", 0.0))
	var ph2: float = float(ctx.get("ph2", 0.0))
	var ph3: float = float(ctx.get("ph3", 0.0))
	var ph4: float = float(ctx.get("ph4", 0.0))
	var ph5: float = float(ctx.get("ph5", 0.0))
	var lp1: float = float(ctx.get("lp1", 0.0))
	var lp2: float = float(ctx.get("lp2", 0.0))
	var lp3: float = float(ctx.get("lp3", 0.0))
	var pop: float = float(ctx.get("pop", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		# benturan awal
		ph4 += TAU * (50.0 + 70.0 * exp(-t * 30.0)) / r
		var x: float = sin(ph4) * exp(-t * 14.0) * 0.8
		lp2 += (n - lp2) * 0.4
		x += (n - lp2) * exp(-t * 70.0) * 0.7
		# dengung awan
		var cl: float = smoothstep(0.0, 0.5, t) * (1.0 - smoothstep(2.6, 3.3, t))
		ph5 += TAU * 52.0 / r
		x += (sin(ph5) + 0.5 * sin(ph5 * 2.0)) * 0.16 * cl
		# listrik mengisi
		var u: float = clampf((t - 0.15) / 0.4, 0.0, 1.0)
		var pd: float = 0.0
		if t > 0.15 and t < 0.56:
			ph2 += TAU * 380.0 * pow(9.0, u) / r
			x += sin(ph2) * pow(u, 1.5) * (0.55 + 0.45 * sin(TAU * 40.0 * t)) * 0.32
			pd = 0.0015 + 0.03 * u
		# sambaran
		var hit: float = t - 0.55
		if hit >= 0.0:
			pd = 0.014 * exp(-hit * 1.1)
			ph += TAU * (34.0 + 110.0 * exp(-hit * 14.0)) / r
			x += sin(ph) * exp(-hit * 3.0) * minf(hit / 0.002, 1.0) * 1.5
			x += n * exp(-hit * 90.0) * 1.8
			lp3 += (n - lp3) * 0.25
			x += lp3 * exp(-hit * 5.0) * 2.4
			ph3 += 118.0 / r
			var saw: float = fposmod(ph3, 1.0) * 2.0 - 1.0
			var gate: float = 1.0 if int(t * 28.0) % 2 == 0 else 0.12
			x += saw * gate * 0.55 * (1.0 - smoothstep(0.55, 1.3, hit)) * minf(hit / 0.01, 1.0)
			lp1 += (n - lp1) * 0.03
			var roll: float = 0.55 + 0.45 * sin(TAU * 1.3 * hit + 1.2 * sin(TAU * 0.45 * hit))
			x += lp1 * roll * exp(-maxf(hit - 0.15, 0.0) * 0.8) * smoothstep(0.0, 0.35, hit) * 5.5
		# letupan / percikan
		pop *= 0.93
		if rng.randf() < pd:
			pop += rng.randf_range(0.4, 1.0)
		x += pop * n * 0.7
		buf[i] = x
	ctx["ph"] = ph
	ctx["ph2"] = ph2
	ctx["ph3"] = ph3
	ctx["ph4"] = ph4
	ctx["ph5"] = ph5
	ctx["lp1"] = lp1
	ctx["lp2"] = lp2
	ctx["lp3"] = lp3
	ctx["pop"] = pop
	_finish(buf, i0, i1, rate, 1.2)


# ================================================================== 3. BURN TO ASH (inferno)
## 0.00 "WHOOMPH" api menyala | 0.1-2.4 raungan api + letupan bara | 2.4-3.2 api padam | 1.4-3.5 abu jatuh (desis halus).
static func _inferno(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	var ph: float = float(ctx.get("ph", 0.0))
	var ph2: float = float(ctx.get("ph2", 0.0))
	var lp1: float = float(ctx.get("lp1", 0.0))
	var lp2: float = float(ctx.get("lp2", 0.0))
	var lp3: float = float(ctx.get("lp3", 0.0))
	var lp4: float = float(ctx.get("lp4", 0.0))
	var pop: float = float(ctx.get("pop", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		var g: float = smoothstep(0.1, 0.9, t) * (1.0 - smoothstep(2.4, 3.2, t))
		# whoomph
		ph += TAU * (85.0 - 40.0 * minf(t / 0.5, 1.0)) / r
		var x: float = sin(ph) * exp(-t * 6.0) * 1.2
		lp3 += (n - lp3) * (0.04 + 0.2 * exp(-t * 6.0))
		x += lp3 * (1.0 - exp(-t * 40.0)) * exp(-t * 3.2) * 4.0
		# raungan
		var flick: float = 0.75 + 0.25 * sin(t * 11.0) * sin(t * 17.0 + 1.0) + 0.1 * sin(t * 29.0)
		lp1 += (n - lp1) * 0.05
		lp2 += (n - lp2) * 0.28
		x += (lp1 * 2.6 + (lp2 - lp1) * 1.0) * g * flick
		ph2 += TAU * 55.0 / r
		x += sin(ph2) * 0.1 * g
		# letupan bara
		pop *= 0.9
		if rng.randf() < 0.004 + 0.012 * g:
			pop += rng.randf_range(0.35, 1.0)
		x += pop * n * 1.3 * (0.6 + 0.4 * g)
		# abu jatuh
		var ash: float = smoothstep(1.4, 2.4, t) * (1.0 - smoothstep(3.0, 3.58, t))
		lp4 += (n - lp4) * 0.3
		x += (n - lp4) * 0.06 * ash
		buf[i] = x
	ctx["ph"] = ph
	ctx["ph2"] = ph2
	ctx["lp1"] = lp1
	ctx["lp2"] = lp2
	ctx["lp3"] = lp3
	ctx["lp4"] = lp4
	ctx["pop"] = pop
	_finish(buf, i0, i1, rate, 1.2)


# ================================================================== 4. SYSTEM CRASH (glitch)
## 0.00 zap digital | 0.1-2.35 data glitch (nada loncat tiap 1/12 dtk, bitcrush) + bip ERROR bergantian tiap 1/6 dtk (sama
## dengan teks SYSTEM ERROR / FATAL) | 2.0 sistem jatuh (nada meluncur turun) | 2.3-2.78 TV mati (rengek turun) | 2.78 "pop" lalu sunyi.
static func _glitch(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	var ph: float = float(ctx.get("ph", 0.0))
	var ph2: float = float(ctx.get("ph2", 0.0))
	var ph3: float = float(ctx.get("ph3", 0.0))
	var ph4: float = float(ctx.get("ph4", 0.0))
	var ph5: float = float(ctx.get("ph5", 0.0))
	var hold: float = float(ctx.get("hold", 0.0))
	var hc: int = int(ctx.get("hc", 0))
	var hn: float = float(ctx.get("hn", 0.0))
	var nc: int = int(ctx.get("nc", 0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		var x: float = 0.0
		# zap pembuka
		if t < 0.14:
			ph5 += TAU * (2400.0 * exp(-t * 22.0) + 180.0) / r
			x += (1.0 if sin(ph5) > 0.0 else -1.0) * exp(-t * 20.0) * 0.6
			x += n * exp(-t * 90.0) * 0.6
		# glitch data
		if t > 0.1 and t < 2.35:
			var k: float = floorf(t * 12.0)
			var sp: float = fposmod(t * 12.0, 1.0)
			if _hs(k, 3.0) > 0.35 and sp < 0.82:
				var deg: int = int(_hs(k, 1.0) * 6.0)
				var oct: float = 12.0 * floorf(_hs(k, 2.0) * 2.0)
				ph += _hz(57.0 + float(SCALE[deg]) + oct) / r
				var hl: int = 1 + int(_hs(k, 4.0) * 5.0)
				hc += 1
				if hc >= hl:
					hc = 0
					hold = fposmod(ph, 1.0) * 2.0 - 1.0
				var q: float = floorf(hold * 3.0) / 3.0
				x += q * 0.34 * (1.0 - 0.5 * sp) * (1.0 - smoothstep(2.0, 2.35, t))
			if _hs(k, 6.0) > 0.62 and sp < 0.5:
				nc += 1
				if nc >= 5:
					nc = 0
					hn = n
				x += hn * 0.26
		# bip error
		if t > 0.3 and t < 2.4:
			var m: float = fposmod(t * 6.0, 1.0) / 6.0
			if m < 0.085:
				var tog: int = int(t * 6.0)
				ph2 += (880.0 if tog % 2 == 0 else 622.0) / r
				x += (1.0 if fposmod(ph2, 1.0) < 0.5 else -1.0) * 0.24 * (1.0 - m / 0.085 * 0.4)
		# sistem jatuh
		if t > 2.0 and t < 2.78:
			var u: float = t - 2.0
			ph3 += (80.0 + 1400.0 * exp(-u * 9.0)) / r
			x += (fposmod(ph3, 1.0) * 2.0 - 1.0) * 0.36 * (1.0 - smoothstep(0.55, 0.78, u))
		# TV mati
		if t > 2.3 and t < 2.78:
			ph4 += TAU * (60.0 + 3140.0 * exp(-(t - 2.3) * 7.5)) / r
			x += sin(ph4) * 0.34 * (1.0 - smoothstep(2.58, 2.76, t)) * minf((t - 2.3) / 0.01, 1.0)
		var pt: float = t - 2.78
		if pt >= 0.0:
			x += sin(TAU * 68.0 * pt) * exp(-pt * 26.0) * 1.6
			x += n * exp(-pt * 180.0) * 1.0
		buf[i] = x
	ctx["ph"] = ph
	ctx["ph2"] = ph2
	ctx["ph3"] = ph3
	ctx["ph4"] = ph4
	ctx["ph5"] = ph5
	ctx["hold"] = hold
	ctx["hc"] = hc
	ctx["hn"] = hn
	ctx["nc"] = nc
	_finish(buf, i0, i1, rate, 1.15)


# ================================================================== 5. FLASH FREEZE (shatter)
## 0.00 "ting" es | 0.1-0.9 membeku: desis dingin + derit es + denting kristal | 0.86-1.28 sembilan RETAKAN | 1.3 PECAH:
## dentum + pecahan kaca | 1.3-2.8 pecahan berjatuhan (lonceng kaca rapat di awal) | sisa: kilau salju.
static func _shatter(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	if not ctx.has("bells"):
		var ev: Array = []
		ev.append(_be(0.0, _hz(100.0), 0.5, 0.35, rate))
		ev.append_array(_scatter(rng, rate, 11, 0.12, 1.1, 1.0, [96.0, 100.0, 103.0, 105.0, 108.0], 0.07, 0.16, 0.22, 0.4))
		ev.append_array(_scatter(rng, rate, 64, 1.3, 1.5, 1.7, [91.0, 93.0, 96.0, 98.0, 100.0, 103.0, 105.0, 108.0, 110.0], 0.1, 0.3, 0.08, 0.22))
		ev.append_array(_scatter(rng, rate, 14, 2.0, 1.2, 1.0, [100.0, 103.0, 105.0, 108.0], 0.06, 0.14, 0.2, 0.4))
		ctx["bells"] = ev
		var cr: Array = []
		for k in range(9):
			cr.append([0.86 + 0.42 * (float(k) / 8.0) + rng.randf_range(-0.02, 0.02), rng.randf_range(0.5, 1.0)])
		ctx["cracks"] = cr
	var t0: float = float(i0) / r
	var t1: float = float(i1) / r
	var act: Array = []
	for c in ctx["cracks"]:
		if t1 >= float(c[0]) and t0 <= float(c[0]) + 0.07:
			act.append(c)
	var ph: float = float(ctx.get("ph", 0.0))
	var ph2: float = float(ctx.get("ph2", 0.0))
	var ph3: float = float(ctx.get("ph3", 0.0))
	var lp1: float = float(ctx.get("lp1", 0.0))
	var lp2: float = float(ctx.get("lp2", 0.0))
	var lp3: float = float(ctx.get("lp3", 0.0))
	var lp4: float = float(ctx.get("lp4", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		# benturan awal
		ph += TAU * (70.0 + 80.0 * exp(-t * 30.0)) / r
		var x: float = sin(ph) * exp(-t * 12.0) * 0.8
		lp1 += (n - lp1) * 0.3
		x += (n - lp1) * exp(-t * 60.0) * 0.5
		# desis dingin
		var fr: float = smoothstep(0.1, 0.9, t) * (1.0 - smoothstep(0.9, 1.35, t))
		lp2 += (n - lp2) * 0.4
		x += (n - lp2) * 0.12 * fr * (0.7 + 0.3 * sin(t * 37.0))
		# derit es
		var ca: float = smoothstep(0.3, 0.85, t) * (1.0 - smoothstep(0.85, 1.2, t))
		ph2 += TAU * (190.0 + 60.0 * sin(t * 13.0) + 140.0 * smoothstep(0.3, 0.9, t)) / r
		x += (sin(ph2) * 0.5 + (fposmod(ph2 / TAU, 1.0) * 2.0 - 1.0) * 0.2) * ca * 0.22 * (0.6 + 0.4 * sin(t * 47.0))
		# retakan
		lp3 += (n - lp3) * 0.15
		for c in act:
			var tt: float = t - float(c[0])
			if tt >= 0.0 and tt < 0.07:
				var a: float = float(c[1])
				x += (n - lp3) * exp(-tt * 110.0) * a * 1.1
				x += sin(TAU * (260.0 + 90.0 * a) * tt) * exp(-tt * 70.0) * a * 0.5
		# pecah
		var ts: float = t - 1.3
		if ts >= 0.0:
			ph3 += TAU * (50.0 + 100.0 * exp(-ts * 14.0)) / r
			x += sin(ph3) * exp(-ts * 7.0)
			lp4 += (n - lp4) * 0.18
			x += (n - lp4) * exp(-ts * 9.0) * 1.7 * minf(ts / 0.001, 1.0)
			x += (n - lp4) * exp(-ts * 80.0) * 1.2
		buf[i] = x
	ctx["ph"] = ph
	ctx["ph2"] = ph2
	ctx["ph3"] = ph3
	ctx["lp1"] = lp1
	ctx["lp2"] = lp2
	ctx["lp3"] = lp3
	ctx["lp4"] = lp4
	_bells(buf, i0, i1, rate, ctx["bells"])
	_finish(buf, i0, i1, rate, 1.2)


# ================================================================== 6. ASCENSION (ascend)
## 0.00 "ting" suci | 0.15-1.4 pad paduan suara membesar (kolom cahaya) | 0.72 denting halo | 0.8-2.8 kepak sayap lembut |
## 0.92-2.3 harpa naik tangga nada (korban naik ke langit) | 1.9-2.4 penanjak cahaya | 2.4 LEDAKAN CAHAYA: akor lonceng + kilau.
static func _ascend(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	if not ctx.has("bells"):
		var ev: Array = []
		ev.append(_be(0.0, _hz(93.0), 0.25, 0.45, rate))
		ev.append(_be(0.72, _hz(98.0), 0.22, 0.45, rate))
		var harp: Array = [74.0, 76.0, 78.0, 81.0, 83.0, 86.0, 90.0, 93.0, 95.0, 98.0, 102.0]
		for k in range(harp.size()):
			ev.append(_be(0.92 + 0.13 * float(k), _hz(float(harp[k])), 0.2, 0.4, rate))
		var burst: Array = [81.0, 86.0, 90.0, 93.0, 98.0, 102.0]
		for k in range(burst.size()):
			ev.append(_be(2.4 + 0.03 * float(k), _hz(float(burst[k])), 0.34, 0.8, rate))
		ev.append_array(_scatter(rng, rate, 22, 2.45, 0.95, 1.0, [90.0, 93.0, 95.0, 98.0, 102.0, 105.0], 0.08, 0.2, 0.25, 0.5))
		ctx["bells"] = ev
		ctx["pad"] = [_hz(50.0), _hz(57.0), _hz(62.0), _hz(66.0), _hz(69.0), _hz(73.0)]
		ctx["pad2"] = [_hz(74.0), _hz(78.0), _hz(81.0), _hz(86.0)]
	var pad: Array = ctx["pad"]
	var pad2: Array = ctx["pad2"]
	var ph: float = float(ctx.get("ph", 0.0))
	var lp1: float = float(ctx.get("lp1", 0.0))
	var lp2: float = float(ctx.get("lp2", 0.0))
	var lp3: float = float(ctx.get("lp3", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		# benturan lembut
		ph += TAU * (95.0 - 35.0 * minf(t / 0.1, 1.0)) / r
		var x: float = sin(ph) * exp(-t * 14.0) * 0.6
		lp3 += (n - lp3) * 0.1
		x += lp3 * exp(-t * 30.0) * 1.2
		# pad paduan suara
		var pa: float = smoothstep(0.15, 1.4, t) * (1.0 - smoothstep(3.0, 3.55, t))
		var tc: float = t - 2.4
		if tc >= 0.0:
			pa *= 1.0 + 0.9 * exp(-tc * 2.0)
		if pa > 0.001:
			var trem: float = 0.92 + 0.08 * sin(TAU * 0.9 * t)
			x += _pad(t, pad, 0.5) * pa * trem * 0.1
			if tc >= 0.0:
				x += _pad(t, pad2, 0.4) * pa * smoothstep(0.0, 0.12, tc) * 0.08
		# kepak sayap
		var wg: float = smoothstep(0.8, 1.5, t) * (1.0 - smoothstep(2.2, 2.8, t))
		lp1 += (n - lp1) * 0.06
		x += lp1 * 1.6 * wg * (0.5 + 0.5 * sin(t * 7.0 - 1.5))
		# penanjak cahaya + kilau ledakan
		lp2 += (n - lp2) * 0.25
		var hp: float = n - lp2
		if t > 1.9 and t < 2.4:
			x += hp * 0.15 * smoothstep(1.9, 2.4, t)
		if tc >= 0.0:
			x += hp * minf(tc / 0.25, 1.0) * exp(-tc * 2.2) * 0.35
		buf[i] = x
	ctx["ph"] = ph
	ctx["lp1"] = lp1
	ctx["lp2"] = lp2
	ctx["lp3"] = lp3
	_bells(buf, i0, i1, rate, ctx["bells"])
	_finish(buf, i0, i1, rate, 1.1)


# ================================================================== 7. PETAL STORM (petals)
## 0.00 "puff" lembut | 0.1-3.3 angin pusaran yang berputar | 0.25-2.6 petik kelopak (tangga nada pentatonik sakura) |
## 1.5-2.4 mekar: pad lembut + sapuan lonceng naik | sisa: angin mereda.
static func _petals(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	if not ctx.has("bells"):
		var ev: Array = []
		ev.append(_be(0.02, _hz(88.0), 0.3, 0.5, rate))
		ev.append_array(_scatter(rng, rate, 26, 0.25, 2.4, 1.3, [76.0, 77.0, 81.0, 83.0, 84.0, 88.0, 89.0, 93.0, 95.0], 0.13, 0.26, 0.22, 0.4))
		var gl: Array = [88.0, 91.0, 93.0, 96.0, 100.0]
		for k in range(gl.size()):
			ev.append(_be(1.5 + 0.07 * float(k), _hz(float(gl[k])), 0.22, 0.6, rate))
		ctx["bells"] = ev
		ctx["pad"] = [_hz(57.0), _hz(64.0), _hz(69.0), _hz(72.0), _hz(76.0)]
	var pad: Array = ctx["pad"]
	var ph: float = float(ctx.get("ph", 0.0))
	var low: float = float(ctx.get("low", 0.0))
	var band: float = float(ctx.get("band", 0.0))
	var lp1: float = float(ctx.get("lp1", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		# puff
		ph += TAU * 110.0 / r
		lp1 += (n - lp1) * 0.1
		var x: float = lp1 * exp(-t * 14.0) * 2.0 + sin(ph) * exp(-t * 18.0) * 0.3
		# angin pusaran
		var g: float = smoothstep(0.1, 0.8, t) * (1.0 - smoothstep(2.6, 3.4, t))
		var sm: float = smoothstep(0.3, 1.6, t)
		var fc: float = 520.0 + 650.0 * sin(TAU * 0.5 * t) + 500.0 * sm
		var fq: float = minf(2.0 * sin(PI * minf(fc, 6000.0) / r), 1.0)
		var high: float = n - low - 0.4 * band
		band += fq * high
		low += fq * band
		x += band * g * (0.55 + 0.45 * sin(TAU * (0.9 + 0.6 * sm) * t)) * 0.75
		# mekar
		var bl: float = smoothstep(1.4, 2.1, t) * (1.0 - smoothstep(2.7, 3.45, t))
		if bl > 0.001:
			x += _pad(t, pad, 0.4) * bl * 0.07
		buf[i] = x
	ctx["ph"] = ph
	ctx["low"] = low
	ctx["band"] = band
	ctx["lp1"] = lp1
	_bells(buf, i0, i1, rate, ctx["bells"])
	_finish(buf, i0, i1, rate, 1.1)


# ================================================================== 8. SUPERNOVA (cosmic)
## 0.00 denyut dalam | 0.35-1.7 bintang bermunculan (kelip tinggi) | 0.55-1.7 rengekan pengisian naik (garis rasi) |
## 1.56-1.7 VAKUM sesaat | 1.7 SUPERNOVA: dentum sub + ledakan + gelombang kejut + lonceng | 1.95-3.2 bintang padam satu-satu.
static func _cosmic(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	if not ctx.has("bells"):
		var ev: Array = []
		ev.append(_be(0.0, _hz(100.0), 0.3, 0.5, rate))
		ev.append_array(_scatter(rng, rate, 26, 0.35, 1.3, 0.9, [96.0, 100.0, 103.0, 105.0, 108.0, 112.0], 0.1, 0.22, 0.35, 0.7))
		var ring: Array = [72.0, 79.0, 84.0, 91.0, 96.0]
		for k in range(ring.size()):
			ev.append(_be(1.7 + 0.04 * float(k), _hz(float(ring[k])), 0.35, 0.9, rate))
		ev.append_array(_scatter(rng, rate, 26, 1.95, 1.3, 1.0, [91.0, 96.0, 100.0, 103.0, 105.0, 108.0], 0.1, 0.3, 0.3, 0.7))
		ctx["bells"] = ev
	var ph: float = float(ctx.get("ph", 0.0))
	var ph2: float = float(ctx.get("ph2", 0.0))
	var ph3: float = float(ctx.get("ph3", 0.0))
	var ph4: float = float(ctx.get("ph4", 0.0))
	var lp1: float = float(ctx.get("lp1", 0.0))
	var lp2: float = float(ctx.get("lp2", 0.0))
	var lp3: float = float(ctx.get("lp3", 0.0))
	var low: float = float(ctx.get("low", 0.0))
	var band: float = float(ctx.get("band", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		# denyut awal
		ph4 += TAU * 60.0 / r
		var x: float = sin(ph4) * exp(-t * 10.0) * 0.7
		lp3 += (n - lp3) * 0.3
		x += (n - lp3) * exp(-t * 80.0) * 0.4
		# pengisian
		var u: float = clampf((t - 0.55) / 1.15, 0.0, 1.0)
		if t > 0.55 and t < 1.72:
			var hz: float = 110.0 * pow(9.0, u)
			ph += TAU * hz / r
			ph2 += TAU * hz * 1.007 / r
			var trem: float = 0.6 + 0.4 * sin(TAU * (6.0 + 16.0 * u) * t)
			var vac: float = 1.0 - smoothstep(1.56, 1.69, t)
			x += (sin(ph) + sin(ph2) + 0.3 * sin(ph * 3.0)) * 0.5 * pow(u, 1.4) * trem * vac * 0.38
			lp2 += (n - lp2) * 0.2
			x += (n - lp2) * u * vac * 0.12
		# supernova
		var tc: float = t - 1.7
		if tc >= 0.0:
			ph3 += TAU * (30.0 + 190.0 * exp(-tc * 8.0)) / r
			x += sin(ph3) * exp(-tc * 2.6) * minf(tc / 0.004, 1.0) * 1.6
			lp1 += (n - lp1) * (0.03 + 0.6 * exp(-tc * 5.0))
			x += lp1 * exp(-tc * 3.0) * 2.0
			var fc: float = 250.0 + 5000.0 * smoothstep(0.0, 1.2, tc)
			var fq: float = minf(2.0 * sin(PI * minf(fc, 9000.0) / r), 1.0)
			var high: float = n - low - 0.3 * band
			band += fq * high
			low += fq * band
			x += band * 0.6 * exp(-tc * 1.5) * minf(tc / 0.05, 1.0)
		buf[i] = x
	ctx["ph"] = ph
	ctx["ph2"] = ph2
	ctx["ph3"] = ph3
	ctx["ph4"] = ph4
	ctx["lp1"] = lp1
	ctx["lp2"] = lp2
	ctx["lp3"] = lp3
	ctx["low"] = low
	ctx["band"] = band
	_bells(buf, i0, i1, rate, ctx["bells"])
	_finish(buf, i0, i1, rate, 1.15)


# ================================================================== 9. MELTDOWN (toxic)
## 0.00 cipratan basah | 0.1-2.6 gelembung & tetesan | 0.5-2.1 korban meleleh: desis asam + kecipak rendah + "bleeehh" turun |
## 2.35 gelembung besar terakhir | 2.9-3.5 reda.
static func _toxic(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	if not ctx.has("bubs"):
		var bu: Array = []
		for k in range(24):
			var st: float = 0.12 + 2.5 * rng.randf()
			var f0: float = rng.randf_range(260.0, 800.0)
			var du: float = rng.randf_range(0.06, 0.13)
			var am: float = rng.randf_range(0.3, 0.55)
			bu.append([st, f0, du, am])
		bu.append([2.35, 130.0, 0.24, 0.7])
		ctx["bubs"] = bu
	var t0: float = float(i0) / r
	var t1: float = float(i1) / r
	var act: Array = []
	for b in ctx["bubs"]:
		if t1 >= float(b[0]) and t0 <= float(b[0]) + float(b[2]) * 2.2:
			act.append(b)
	var ph: float = float(ctx.get("ph", 0.0))
	var ph2: float = float(ctx.get("ph2", 0.0))
	var ph3: float = float(ctx.get("ph3", 0.0))
	var lp1: float = float(ctx.get("lp1", 0.0))
	var lp2: float = float(ctx.get("lp2", 0.0))
	var pop: float = float(ctx.get("pop", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		var m: float = smoothstep(0.5, 2.1, t)
		var fade: float = 1.0 - smoothstep(2.9, 3.5, t)
		# cipratan awal
		ph3 += TAU * (120.0 - 50.0 * minf(t / 0.15, 1.0)) / r
		lp2 += (n - lp2) * 0.1
		var x: float = lp2 * exp(-t * 18.0) * 3.0 + sin(ph3) * exp(-t * 14.0) * 0.5
		# desis asam
		pop *= 0.93
		if rng.randf() < 0.002 + 0.02 * m:
			pop += rng.randf_range(0.4, 1.0)
		lp1 += (n - lp1) * 0.25
		x += (pop * n * 0.8 + (n - lp1) * 0.07 * m) * fade
		# kecipak rendah
		ph += TAU * (80.0 + 28.0 * sin(TAU * 4.3 * t) + 70.0 * m) / r
		x += sin(ph) * (0.55 + 0.45 * sin(TAU * 6.5 * t)) * 0.3 * m * fade
		# "bleeehh" meleleh
		var u: float = clampf((t - 0.5) / 1.6, 0.0, 1.0)
		if t > 0.5 and t < 2.1:
			ph2 += TAU * 650.0 * pow(0.2, u) * (1.0 + 0.35 * sin(TAU * 23.0 * t)) / r
			x += (sin(ph2) + 0.4 * sin(ph2 * 2.0)) * sin(u * PI) * 0.2
		# gelembung
		for b in act:
			var tt: float = t - float(b[0])
			if tt >= 0.0 and tt < float(b[2]) * 2.2:
				var du2: float = float(b[2])
				var w: float = TAU * float(b[1]) * (tt + 1.1 * tt * tt / du2)
				x += sin(w) * exp(-tt * 5.0 / du2) * minf(tt / 0.002, 1.0) * float(b[3])
		buf[i] = x
	ctx["ph"] = ph
	ctx["ph2"] = ph2
	ctx["ph3"] = ph3
	ctx["lp1"] = lp1
	ctx["lp2"] = lp2
	ctx["pop"] = pop
	_finish(buf, i0, i1, rate, 1.6)


# ================================================================== 10. JACKPOT! (jackpot)
## 0.00 koin jatuh "ting" | 0.12-1.6 gulungan mesin slot berdetak makin cepat | 0.9-1.7 koin pertama berdenting + nada harap |
## 1.65 JACKPOT: fanfare terompet + "ka-ching" + hujan koin | 1.7-3.2 koin berdenting jatuh | sisa: kilau konfeti.
static func _jackpot(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	if not ctx.has("bells"):
		var ev: Array = []
		ev.append(_be(0.0, _hz(98.0), 0.4, 0.25, rate))
		ev.append_array(_scatter(rng, rate, 12, 0.92, 0.75, 1.0, [96.0, 100.0, 103.0, 105.0], 0.1, 0.2, 0.07, 0.14))
		ev.append(_be(1.65, _hz(103.0), 0.55, 0.5, rate))
		ev.append(_be(1.72, _hz(108.0), 0.5, 0.6, rate))
		ev.append_array(_scatter(rng, rate, 38, 1.7, 1.5, 1.4, [96.0, 98.0, 100.0, 103.0, 105.0, 108.0], 0.16, 0.36, 0.06, 0.13))
		ev.append_array(_scatter(rng, rate, 10, 1.7, 1.3, 1.2, [84.0, 88.0, 91.0, 96.0], 0.15, 0.3, 0.2, 0.35))
		ctx["bells"] = ev
		var tk: Array = []
		var tt0: float = 0.12
		var iv: float = 0.17
		var k: int = 0
		while tt0 < 1.6:
			tk.append([tt0, 1250.0 if k % 2 == 0 else 1700.0, 0.7 + 0.4 * (tt0 / 1.6)])
			tt0 += iv
			iv = maxf(iv * 0.92, 0.035)
			k += 1
		ctx["ticks"] = tk
		ctx["brass"] = [_hz(48.0), _hz(60.0), _hz(64.0), _hz(67.0), _hz(72.0), _hz(76.0)]
	var brass: Array = ctx["brass"]
	var t0: float = float(i0) / r
	var t1: float = float(i1) / r
	var act: Array = []
	for c in ctx["ticks"]:
		if t1 >= float(c[0]) and t0 <= float(c[0]) + 0.06:
			act.append(c)
	var ph: float = float(ctx.get("ph", 0.0))
	var ph2: float = float(ctx.get("ph2", 0.0))
	var lp1: float = float(ctx.get("lp1", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		# benturan
		ph += TAU * 80.0 / r
		var x: float = sin(ph) * exp(-t * 12.0) * 0.5
		# detak gulungan slot
		for c in act:
			var tt: float = t - float(c[0])
			if tt >= 0.0 and tt < 0.06:
				x += sin(TAU * float(c[1]) * tt) * exp(-tt * 110.0) * float(c[2])
		# nada harap
		if t > 0.9 and t < 1.66:
			var u: float = clampf((t - 0.9) / 0.75, 0.0, 1.0)
			ph2 += TAU * 500.0 * pow(2.6, u) / r
			x += sin(ph2) * 0.13 * u
		# fanfare jackpot
		var tb: float = t - 1.65
		if tb >= 0.0 and tb < 1.4:
			var env: float = minf(tb / 0.012, 1.0) * (0.35 + 0.65 * exp(-tb * 3.5)) * exp(-maxf(tb - 0.35, 0.0) * 3.0)
			var br: float = exp(-tb * 4.0)
			var s: float = 0.0
			for q in range(brass.size()):
				var w: float = TAU * float(brass[q]) * tb
				s += sin(w) + 0.5 * sin(w * 2.0) + br * (0.33 * sin(w * 3.0) + 0.25 * sin(w * 4.0) + 0.2 * sin(w * 5.0))
			x += s * env * 0.12
			# kilau konfeti
			lp1 += (n - lp1) * 0.3
			x += (n - lp1) * exp(-tb * 1.6) * 0.1
		buf[i] = x
	ctx["ph"] = ph
	ctx["ph2"] = ph2
	ctx["lp1"] = lp1
	_bells(buf, i0, i1, rate, ctx["bells"])
	_finish(buf, i0, i1, rate, 1.1)


# ================================================================== 11. PRISM CUT (slice)
## 0.00 "tak" kecil | 0.30 tebasan 1 + 0.55 tebasan 2: desing bilah + dentingan logam | 0.9 potongan terlepas |
## 0.95-2.3 denting pelangi naik tangga nada + kilau bintang | sisa: hening.
static func _slice(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	if not ctx.has("bells"):
		var ev: Array = []
		ev.append(_be(0.34, _hz(100.0), 0.3, 0.3, rate))
		ev.append(_be(0.34, _hz(100.0) * 1.505, 0.2, 0.22, rate))
		ev.append(_be(0.59, _hz(105.0), 0.3, 0.3, rate))
		ev.append(_be(0.59, _hz(105.0) * 1.505, 0.2, 0.22, rate))
		ev.append(_be(0.9, _hz(84.0), 0.25, 0.5, rate))
		var arp: Array = [84.0, 86.0, 88.0, 91.0, 93.0, 96.0, 98.0, 100.0, 103.0, 105.0, 108.0, 110.0]
		for k in range(arp.size()):
			ev.append(_be(0.95 + 0.07 * float(k), _hz(float(arp[k])), 0.22, 0.4, rate))
		ev.append_array(_scatter(rng, rate, 20, 1.0, 1.5, 1.0, [91.0, 96.0, 100.0, 103.0, 105.0, 108.0], 0.08, 0.2, 0.25, 0.5))
		ctx["bells"] = ev
	var ph: float = float(ctx.get("ph", 0.0))
	var ph2: float = float(ctx.get("ph2", 0.0))
	var low: float = float(ctx.get("low", 0.0))
	var band: float = float(ctx.get("band", 0.0))
	var lp1: float = float(ctx.get("lp1", 0.0))
	var lp2: float = float(ctx.get("lp2", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		# tak kecil
		ph += TAU * 120.0 / r
		lp1 += (n - lp1) * 0.3
		var x: float = (n - lp1) * exp(-t * 120.0) * 0.5 + sin(ph) * exp(-t * 20.0) * 0.4
		# desing bilah
		var s1: float = t - 0.3
		var s2: float = t - 0.55
		var e1: float = 0.0
		var e2: float = 0.0
		if s1 >= 0.0:
			e1 = minf(s1 / 0.008, 1.0) * exp(-s1 * 10.0)
		if s2 >= 0.0:
			e2 = minf(s2 / 0.008, 1.0) * exp(-s2 * 10.0)
		var fc: float = 1500.0 + 6000.0 * clampf(s1 / 0.12, 0.0, 1.0)
		if e2 > e1:
			fc = 7500.0 - 6000.0 * clampf(s2 / 0.12, 0.0, 1.0)
		var fq: float = minf(2.0 * sin(PI * minf(fc, 9000.0) / r), 1.0)
		var high: float = n - low - 0.3 * band
		band += fq * high
		low += fq * band
		x += band * maxf(e1, e2) * 1.3
		# potongan terlepas
		var tp: float = t - 0.9
		if tp >= 0.0:
			ph2 += TAU * 90.0 / r
			lp2 += (n - lp2) * 0.3
			x += sin(ph2) * exp(-tp * 18.0) * 0.5 + (n - lp2) * exp(-tp * 100.0) * 0.4
		buf[i] = x
	ctx["ph"] = ph
	ctx["ph2"] = ph2
	ctx["low"] = low
	ctx["band"] = band
	ctx["lp1"] = lp1
	ctx["lp2"] = lp2
	_bells(buf, i0, i1, rate, ctx["bells"])
	_finish(buf, i0, i1, rate, 1.15)


# ================================================================== GELOMBANG 2: suara 10 finisher baru
## Pola sama dengan di atas: filter / fase disimpan di ctx antar potongan; waktu mengikuti animasi di finisher.gd.

## Noise berfilter (state-variable band-pass): kembalikan band; state disimpan di ctx[key_low], ctx[key_band].
static func _svf(ctx: Dictionary, key: String, n: float, fc: float, rate: int, q: float = 0.35) -> float:
	var low: float = float(ctx.get(key + "_l", 0.0))
	var band: float = float(ctx.get(key + "_b", 0.0))
	var fq: float = minf(2.0 * sin(PI * minf(fc, float(rate) * 0.4) / float(rate)), 1.0)
	var high: float = n - low - q * band
	band += fq * high
	low += fq * band
	ctx[key + "_l"] = low
	ctx[key + "_b"] = band
	return band


## Low-pass satu kutub: state di ctx[key].
static func _lp(ctx: Dictionary, key: String, n: float, k: float) -> float:
	var v: float = float(ctx.get(key, 0.0))
	v += (n - v) * k
	ctx[key] = v
	return v


## Detak pendek (klik) pada slot waktu: kembalikan lt (detik sejak awal slot) bila slot aktif, atau -1.
static func _slot(t: float, rate_hz: float, salt: float, thr: float) -> float:
	var q: float = t * rate_hz
	var k: float = floorf(q)
	if _hs(k, salt) > thr:
		return (q - k) / rate_hz
	return -1.0


# ---------------------------------------------------------------- 12. METEOR STRIKE
static func _meteor(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	var ph: float = float(ctx.get("ph", 0.0))
	var ph2: float = float(ctx.get("ph2", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		var x: float = 0.0
		var pr: float = clampf((t - 0.12) / 0.83, 0.0, 1.0)
		if t < 0.97:
			ph += TAU * (2000.0 - 1300.0 * pr) / r
			x += sin(ph) * pr * pr * 0.14
			x += _svf(ctx, "a", n, 250.0 + 1100.0 * pr, rate) * pr * 0.5
		var tc: float = t - 0.95
		if tc >= 0.0:
			ph2 += TAU * (46.0 + 70.0 * exp(-tc * 12.0)) / r
			x += sin(ph2) * exp(-tc * 2.2) * minf(tc / 0.003, 1.0) * 2.2
			var lpn: float = _lp(ctx, "lp1", n, 0.03 + 0.5 * exp(-tc * 30.0))
			x += lpn * exp(-tc * 3.2) * 3.0
			x += (n - _lp(ctx, "lp2", n, 0.3)) * exp(-tc * 50.0) * 1.1
			if t > 1.05 and t < 2.4:
				var lt: float = _slot(t, 14.0, 1.0, 0.55)
				if lt >= 0.0:
					x += n * exp(-lt * 420.0) * 0.4 * (1.0 - (t - 1.05) / 1.35)
			x += _lp(ctx, "lp3", n, 0.05) * 0.9 * smoothstep(1.0, 1.4, t) * (1.0 - smoothstep(2.4, 3.4, t))
		buf[i] = x
	ctx["ph"] = ph
	ctx["ph2"] = ph2
	_finish(buf, i0, i1, rate, 1.1)


# ---------------------------------------------------------------- 13. TIDAL CRASH
static func _tsunami(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	var ph: float = float(ctx.get("ph", 0.0))
	var ph2: float = float(ctx.get("ph2", 0.0))
	var ph3: float = float(ctx.get("ph3", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		var pr: float = smoothstep(0.3, 1.2, t)
		var x: float = _svf(ctx, "a", n, 180.0 + 1500.0 * pr + 120.0 * sin(t * 5.0), rate) * pr * (1.0 - 0.5 * smoothstep(1.2, 1.5, t)) * 0.8
		ph += TAU * (50.0 + 12.0 * pr) / r
		x += sin(ph) * pr * 0.3
		var tc: float = t - 1.18
		if tc >= 0.0:
			x += _lp(ctx, "lp1", n, 0.25) * exp(-tc * 2.5) * 3.0
			x += (n - _lp(ctx, "lp2", n, 0.35)) * exp(-tc * 5.0) * 1.0
			ph2 += TAU * (38.0 + 30.0 * exp(-tc * 6.0)) / r
			x += sin(ph2) * exp(-tc * 3.0) * minf(tc / 0.004, 1.0) * 1.6
			x += _svf(ctx, "b", n, 900.0 + 500.0 * sin(t * 2.3), rate) * smoothstep(0.0, 0.3, tc) * (1.0 - smoothstep(1.4, 3.4, t)) * 0.7
		if t > 1.5 and t < 3.3:
			var lt: float = _slot(t, 18.0, 4.0, 0.62)
			if lt >= 0.0:
				var f0: float = 450.0 + 900.0 * _hs(floorf(t * 18.0), 9.0)
				ph3 += TAU * f0 * (1.0 + 7.0 * lt) / r
				x += sin(ph3) * exp(-lt * 55.0) * 0.22
		buf[i] = x
	ctx["ph"] = ph
	ctx["ph2"] = ph2
	ctx["ph3"] = ph3
	_finish(buf, i0, i1, rate, 1.1)


# ---------------------------------------------------------------- 14. SOUL HARVEST
static func _reaper(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	if not ctx.has("bells"):
		var ev: Array = []
		ev.append(_be(0.66, _hz(76.0), 0.35, 0.8, rate))
		ev.append(_be(0.66, _hz(76.0) * 1.505, 0.2, 0.6, rate))
		ev.append(_be(2.5, _hz(50.0), 0.4, 1.0, rate))
		ev.append(_be(2.62, _hz(81.0), 0.3, 0.9, rate))
		ev.append(_be(2.72, _hz(88.0), 0.22, 0.9, rate))
		ev.append(_be(2.84, _hz(93.0), 0.18, 1.0, rate))
		ev.append_array(_scatter(rng, rate, 8, 2.65, 0.7, 1.0, [81.0, 84.0, 88.0, 91.0, 93.0], 0.05, 0.12, 0.4, 0.8))
		ctx["bells"] = ev
	var ph: float = float(ctx.get("ph", 0.0))
	var ph2: float = float(ctx.get("ph2", 0.0))
	var ph3: float = float(ctx.get("ph3", 0.0))
	var hzs: Array = [_hz(38.0), _hz(41.0), _hz(45.0), _hz(50.0)]
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		var x: float = _pad(t, hzs, 0.6) * smoothstep(0.1, 1.0, t) * (1.0 - smoothstep(2.7, 3.4, t)) * 0.06
		var sw: float = t - 0.58
		if sw >= 0.0 and sw < 0.3:
			x += _svf(ctx, "a", n, 3200.0 - 2200.0 * clampf(sw / 0.3, 0.0, 1.0), rate) * sin(clampf(sw / 0.3, 0.0, 1.0) * PI) * 1.1
		var th: float = t - 0.66
		if th >= 0.0:
			ph2 += TAU * 70.0 / r
			x += sin(ph2) * exp(-th * 12.0) * 0.9 + (n - _lp(ctx, "lp1", n, 0.3)) * exp(-th * 90.0) * 0.8
		var st: float = t - 0.72
		if st >= 0.0 and st < 1.95:
			var s: float = smoothstep(0.0, 1.9, st)
			ph += TAU * (300.0 + 650.0 * s + 12.0 * sin(t * 6.0)) / r
			var env: float = smoothstep(0.0, 0.25, st) * (1.0 - smoothstep(1.6, 1.95, st))
			x += (sin(ph) + 0.35 * sin(ph * 2.0)) * env * 0.13
			x += _svf(ctx, "b", n, 3800.0, rate, 0.15) * env * (0.5 + 0.5 * sin(t * 9.0)) * 0.22
		var tg: float = t - 2.5
		if tg >= 0.0:
			ph3 += TAU * 52.0 / r
			x += sin(ph3) * exp(-tg * 8.0) * 0.8
		buf[i] = x
	ctx["ph"] = ph
	ctx["ph2"] = ph2
	ctx["ph3"] = ph3
	_bells(buf, i0, i1, rate, ctx["bells"])
	_finish(buf, i0, i1, rate, 1.15)


# ---------------------------------------------------------------- 15. DIMENSION RIFT
static func _portal(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	if not ctx.has("bells"):
		var ev: Array = []
		ev.append(_be(2.3, _hz(96.0), 0.3, 0.5, rate))
		ev.append_array(_scatter(rng, rate, 16, 2.35, 0.9, 1.0, [91.0, 96.0, 100.0, 103.0, 108.0], 0.08, 0.2, 0.3, 0.6))
		ctx["bells"] = ev
	var ph: float = float(ctx.get("ph", 0.0))
	var ph2: float = float(ctx.get("ph2", 0.0))
	var ph3: float = float(ctx.get("ph3", 0.0))
	var ph4: float = float(ctx.get("ph4", 0.0))
	var ph5: float = float(ctx.get("ph5", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		var x: float = 0.0
		var op: float = smoothstep(0.1, 0.8, t) * (1.0 - smoothstep(2.0, 2.3, t))
		if t < 2.3:
			var pr: float = smoothstep(0.1, 0.85, t)
			ph += TAU * (120.0 + 900.0 * pr * pr) / r
			x += sin(ph + 2.0 * sin(ph * 0.5)) * pr * (1.0 - smoothstep(0.85, 1.0, t)) * 0.18
			ph2 += TAU * 70.0 / r
			ph3 += TAU * 71.6 / r
			x += (sin(ph2) + sin(ph3)) * op * 0.14
			x += _svf(ctx, "a", n, 400.0 + 2600.0 * (0.5 + 0.5 * sin(t * 6.0)), rate) * op * 0.35
		var sk: float = t - 0.85
		if sk >= 0.0 and sk < 1.0:
			ph4 += TAU * (850.0 - 740.0 * smoothstep(0.0, 1.0, sk)) / r
			x += (sin(ph4) + 0.4 * sin(ph4 * 2.0)) * sin(sk / 1.0 * PI) * 0.2
		var tc: float = t - 2.0
		if tc >= 0.0 and tc < 0.3:
			ph5 += TAU * (100.0 + 2400.0 * (tc / 0.3)) / r
			x += sin(ph5) * (tc / 0.3) * 0.25
		var tb: float = t - 2.3
		if tb >= 0.0:
			x += sin(TAU * (45.0 + 40.0 * exp(-tb * 8.0)) * tb) * exp(-tb * 5.0) * 2.0
			x += _lp(ctx, "lp1", n, 0.3) * exp(-tb * 8.0) * 1.8
			x += (n - _lp(ctx, "lp2", n, 0.4)) * exp(-tb * 30.0) * 0.8
		buf[i] = x
	ctx["ph"] = ph
	ctx["ph2"] = ph2
	ctx["ph3"] = ph3
	ctx["ph4"] = ph4
	ctx["ph5"] = ph5
	_bells(buf, i0, i1, rate, ctx["bells"])
	_finish(buf, i0, i1, rate, 1.15)


# ---------------------------------------------------------------- 16. SANDS OF TIME
static func _sands(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	if not ctx.has("bells"):
		var ev: Array = []
		ev.append(_be(0.25, _hz(96.0), 0.25, 0.6, rate))
		ev.append(_be(0.25, _hz(96.0) * 1.505, 0.15, 0.5, rate))
		ev.append(_be(0.9, _hz(52.0), 0.45, 1.2, rate))
		ev.append(_be(0.9, _hz(52.0) * 2.0, 0.2, 1.0, rate))
		ev.append(_be(2.85, _hz(91.0), 0.18, 0.9, rate))
		ev.append(_be(2.95, _hz(96.0), 0.15, 0.9, rate))
		ev.append_array(_scatter(rng, rate, 10, 1.2, 1.8, 1.0, [88.0, 91.0, 96.0, 100.0], 0.05, 0.12, 0.3, 0.6))
		ctx["bells"] = ev
		var ticks: Array = []
		var tk: float = 0.4
		var step: float = 0.45
		while tk < 2.2:
			ticks.append(tk)
			tk += step
			step *= 0.93
		ctx["ticks"] = ticks
	var ticks2: Array = ctx["ticks"]
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		var x: float = 0.0
		for k in range(ticks2.size()):
			var lt: float = t - float(ticks2[k])
			if lt >= 0.0 and lt < 0.06:
				var f: float = 1800.0 if k % 2 == 0 else 1300.0
				x += sin(TAU * f * lt) * exp(-lt * 160.0) * 0.4 + n * exp(-lt * 400.0) * 0.2
		var fl: float = smoothstep(0.9, 1.3, t) * (1.0 - smoothstep(2.6, 3.4, t))
		x += _svf(ctx, "a", n, 5200.0, rate, 0.2) * fl * 0.35
		x += _svf(ctx, "b", n, 500.0 + 500.0 * sin(t * 1.7), rate) * smoothstep(1.1, 1.8, t) * (1.0 - smoothstep(2.6, 3.4, t)) * 0.5
		buf[i] = x
	_bells(buf, i0, i1, rate, ctx["bells"])
	_finish(buf, i0, i1, rate, 1.1)


# ---------------------------------------------------------------- 17. GRAND FINALE
static func _firework(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	if not ctx.has("bells"):
		var ev: Array = []
		ev.append_array(_scatter(rng, rate, 30, 1.65, 1.6, 1.2, [93.0, 96.0, 100.0, 103.0, 105.0, 108.0, 112.0], 0.06, 0.18, 0.25, 0.55))
		ctx["bells"] = ev
	var ph: float = float(ctx.get("ph", 0.0))
	var ph2: float = float(ctx.get("ph2", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		var x: float = 0.0
		if t > 0.12 and t < 0.72:
			x += (n - _lp(ctx, "lp0", n, 0.4)) * 0.22 * (0.5 + 0.5 * _hs(floorf(t * 90.0), 2.0))
		if t >= 0.7 and t < 1.62:
			var pr: float = (t - 0.7) / 0.9
			ph += TAU * (600.0 + 2000.0 * pr * pr) / r
			x += sin(ph) * 0.2 * (1.0 - smoothstep(1.55, 1.62, t))
			x += _svf(ctx, "a", n, 800.0 + 2500.0 * pr, rate) * 0.3
		for b in 3:
			var tb: float = t - [1.6, 1.9, 2.2][b]
			if tb >= 0.0:
				var am: float = [1.0, 0.55, 0.6][b]
				ph2 += TAU * (60.0 + 30.0 * exp(-tb * 10.0)) / r * 0.0
				x += sin(TAU * (60.0 + 30.0 * exp(-tb * 10.0)) * tb) * exp(-tb * 4.0) * 1.6 * am
				x += _lp(ctx, "lp" + str(b + 1), n, 0.2) * exp(-tb * 3.0) * 2.2 * am
		if t > 1.7 and t < 3.2:
			var lt: float = _slot(t, 34.0, 6.0, 0.5)
			if lt >= 0.0:
				x += n * exp(-lt * 500.0) * 0.5 * (1.0 - smoothstep(1.7, 3.2, t))
		buf[i] = x
	ctx["ph"] = ph
	ctx["ph2"] = ph2
	_bells(buf, i0, i1, rate, ctx["bells"])
	_finish(buf, i0, i1, rate, 1.1)


# ---------------------------------------------------------------- 18. ORBITAL STRIKE
static func _orbital(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	if not ctx.has("beeps"):
		var bp: Array = []
		for k in range(10):
			bp.append(0.2 + 0.8 * pow(float(k) / 10.0, 0.8))
		ctx["beeps"] = bp
	var bps: Array = ctx["beeps"]
	var ph: float = float(ctx.get("ph", 0.0))
	var ph2: float = float(ctx.get("ph2", 0.0))
	var ph3: float = float(ctx.get("ph3", 0.0))
	var ph4: float = float(ctx.get("ph4", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		var x: float = 0.0
		for k in range(bps.size()):
			var lt: float = t - float(bps[k])
			if lt >= 0.0 and lt < 0.05:
				x += sin(TAU * 1800.0 * lt) * minf(lt / 0.002, 1.0) * (1.0 - lt / 0.05) * 0.3
		var lc: float = t - 1.0
		if lc >= 0.0 and lc < 0.12:
			x += sin(TAU * 2400.0 * lc) * (1.0 - lc / 0.12) * 0.3
		if t >= 1.0 and t < 1.3:
			var pr: float = (t - 1.0) / 0.3
			ph += TAU * (80.0 + 800.0 * pr) / r
			x += (fposmod(ph / TAU, 1.0) * 2.0 - 1.0) * pr * 0.2
		var tb: float = t - 1.3
		if tb >= 0.0:
			var env: float = smoothstep(0.0, 0.05, tb) * (1.0 - smoothstep(0.9, 1.3, tb))
			ph2 += TAU * (90.0 + 6.0 * sin(t * 40.0)) / r
			x += (fposmod(ph2 / TAU, 1.0) * 2.0 - 1.0) * env * 0.35
			x += _svf(ctx, "a", n, 1300.0 + 300.0 * sin(t * 25.0), rate) * env * 0.8
			ph3 += TAU * (620.0 + 80.0 * sin(t * 30.0)) / r
			x += sin(ph3 + 3.0 * sin(ph3 * 0.5)) * env * 0.12
			ph4 += TAU * (50.0 + 30.0 * exp(-tb * 6.0)) / r
			x += sin(ph4) * exp(-tb * 3.0) * minf(tb / 0.004, 1.0) * 2.0
			x += _lp(ctx, "lp1", n, 0.2) * exp(-tb * 6.0) * 2.0
			var lt2: float = _slot(t, 40.0, 3.0, 0.6)
			if lt2 >= 0.0 and t < 2.5:
				x += n * exp(-lt2 * 600.0) * 0.4
			x += _lp(ctx, "lp2", n, 0.05) * 0.6 * smoothstep(0.6, 1.2, tb) * (1.0 - smoothstep(2.0, 3.3, t))
		buf[i] = x
	ctx["ph"] = ph
	ctx["ph2"] = ph2
	ctx["ph3"] = ph3
	ctx["ph4"] = ph4
	_finish(buf, i0, i1, rate, 1.1)


# ---------------------------------------------------------------- 19. CURSED SEAL
static func _hex(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	if not ctx.has("bells"):
		var ev: Array = []
		ev.append(_be(1.97, _hz(43.0), 0.5, 1.0, rate))
		ev.append(_be(1.97, _hz(43.0) * 2.756, 0.2, 0.7, rate))
		ev.append_array(_scatter(rng, rate, 22, 2.6, 0.8, 1.0, [86.0, 89.0, 93.0, 98.0, 101.0], 0.06, 0.16, 0.25, 0.5))
		ctx["bells"] = ev
	var ph: float = float(ctx.get("ph", 0.0))
	var ph2: float = float(ctx.get("ph2", 0.0))
	var hzs: Array = [_hz(38.0), _hz(41.0), _hz(45.0), _hz(50.0)]
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		var x: float = _pad(t, hzs, 0.8) * smoothstep(0.1, 1.0, t) * (1.0 - smoothstep(2.0, 2.7, t)) * 0.07
		x += _svf(ctx, "a", n, 3500.0 + 800.0 * sin(t * 3.0), rate, 0.15) * 0.09 * smoothstep(0.2, 0.8, t) * (1.0 - smoothstep(1.8, 2.1, t))
		if t > 0.55 and t < 1.6:
			var lt: float = _slot(t, 22.0, 2.0, 0.45)
			if lt >= 0.0:
				x += (sin(TAU * 2300.0 * lt) + 0.7 * sin(TAU * 3100.0 * lt)) * exp(-lt * 150.0) * 0.22
		if t > 1.4 and t < 1.98:
			var pr: float = (t - 1.4) / 0.58
			ph += TAU * (220.0 - 170.0 * pr) / r
			x += (fposmod(ph / TAU, 1.0) * 2.0 - 1.0) * pr * 0.2
		var tb: float = t - 1.97
		if tb >= 0.0:
			ph2 += TAU * 43.0 / r
			x += sin(ph2) * exp(-tb * 4.0) * 1.0
		var ts: float = t - 2.6
		if ts >= 0.0:
			x += _lp(ctx, "lp1", n, 0.35) * exp(-ts * 10.0) * 1.0
			x += (n - _lp(ctx, "lp2", n, 0.4)) * exp(-ts * 22.0) * 0.6
		buf[i] = x
	ctx["ph"] = ph
	ctx["ph2"] = ph2
	_bells(buf, i0, i1, rate, ctx["bells"])
	_finish(buf, i0, i1, rate, 1.15)


# ---------------------------------------------------------------- 20. POP!
static func _balloon(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	if not ctx.has("bells"):
		var ev: Array = []
		ev.append_array(_scatter(rng, rate, 16, 2.0, 1.4, 1.0, [96.0, 100.0, 103.0, 105.0, 108.0], 0.06, 0.16, 0.2, 0.45))
		ctx["bells"] = ev
	var ph: float = float(ctx.get("ph", 0.0))
	var ph2: float = float(ctx.get("ph2", 0.0))
	var ph3: float = float(ctx.get("ph3", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		var x: float = 0.0
		if t > 0.1 and t < 1.9:
			var pr: float = smoothstep(0.1, 1.8, t)
			var pump: float = 0.5 + 0.5 * sin(t * 11.0)
			x += _svf(ctx, "a", n, 2500.0 + 1500.0 * pr, rate, 0.2) * (0.2 + 0.2 * pump) * (1.0 - smoothstep(1.8, 1.9, t))
			ph += TAU * (300.0 + 900.0 * pow(pr, 1.5)) / r
			x += sin(ph) * (0.7 + 0.3 * sin(t * 160.0)) * 0.1 * pr
		if t > 1.55 and t < 1.95:
			var tp: float = (t - 1.55) / 0.4
			ph2 += TAU * (900.0 + 1400.0 * tp) / r
			x += sin(ph2) * tp * 0.2
		var tc: float = t - 1.95
		if tc >= 0.0:
			x += n * exp(-tc * 60.0) * 3.0
			ph3 += TAU * 180.0 / r
			x += sin(ph3) * exp(-tc * 35.0) * 1.6
			x += _svf(ctx, "b", n, 6000.0, rate, 0.2) * exp(-tc * 1.5) * (0.4 + 0.6 * _hs(floorf(t * 60.0), 5.0)) * 0.45
			if tc > 0.15 and tc < 0.5:
				var th: float = tc - 0.15
				var f: float = 330.0 if th < 0.17 else 440.0
				var sq: float = 1.0 if fposmod(th * f, 1.0) < 0.5 else -1.0
				x += sq * 0.1 * (1.0 - smoothstep(0.3, 0.35, th))
		buf[i] = x
	ctx["ph"] = ph
	ctx["ph2"] = ph2
	ctx["ph3"] = ph3
	_bells(buf, i0, i1, rate, ctx["bells"])
	_finish(buf, i0, i1, rate, 1.1)


# ---------------------------------------------------------------- 21. ABDUCTION
static func _ufo(buf: PackedFloat32Array, i0: int, i1: int, rate: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: float = float(rate)
	if not ctx.has("bells"):
		var ev: Array = []
		var arp: Array = [96.0, 100.0, 103.0, 108.0, 112.0]
		for k in range(arp.size()):
			ev.append(_be(2.3 + 0.05 * float(k), _hz(float(arp[k])), 0.2, 0.4, rate))
		ctx["bells"] = ev
	var ph: float = float(ctx.get("ph", 0.0))
	var ph2: float = float(ctx.get("ph2", 0.0))
	var ph3: float = float(ctx.get("ph3", 0.0))
	for i in range(i0, i1):
		var t: float = float(i) / r
		var n: float = rng.randf() * 2.0 - 1.0
		var x: float = 0.0
		var ex: float = clampf((t - 2.5) / 0.7, 0.0, 1.0)
		var env: float = smoothstep(0.1, 0.7, t) * (1.0 - smoothstep(2.6, 3.3, t))
		ph += TAU * (180.0 + 60.0 * sin(TAU * 6.0 * t)) * (1.0 + 1.5 * ex * ex) / r
		x += (sin(ph) + 0.4 * sin(ph * 2.0 + 1.0)) * env * 0.22
		var bn: float = smoothstep(0.55, 0.8, t) * (1.0 - smoothstep(2.35, 2.5, t))
		x += _svf(ctx, "a", n, 2500.0, rate, 0.2) * bn * 0.15
		var sk: float = t - 0.85
		if sk >= 0.0 and sk < 1.5:
			ph2 += TAU * (300.0 + 1100.0 * smoothstep(0.0, 1.45, sk) + 14.0 * sin(t * 8.0)) / r
			x += sin(ph2) * sin(sk / 1.5 * PI) * 0.2
		var tz: float = t - 2.3
		if tz >= 0.0:
			x += (n - _lp(ctx, "lp1", n, 0.3)) * exp(-tz * 40.0) * 0.7
			ph3 += TAU * (60.0 + 40.0 * exp(-tz * 10.0)) / r
			x += sin(ph3) * exp(-tz * 7.0) * 0.8
		if t >= 2.5:
			x += _svf(ctx, "b", n, 400.0 + 3600.0 * ex, rate) * sin(ex * PI) * 0.9
		buf[i] = x
	ctx["ph"] = ph
	ctx["ph2"] = ph2
	ctx["ph3"] = ph3
	_bells(buf, i0, i1, rate, ctx["bells"])
	_finish(buf, i0, i1, rate, 1.1)
