class_name CampaignData
extends RefCounted
## Data mode CAMPAIGN (single player): 5 chapter x 10 dunia x 5 level = 250 level, jenis musuh, boss, perk, dan penyimpanan progres.
##
## Cara menambah / mengubah konten:
##   - Level      : edit LEVELS (urutan = nomor level). Tiap wave = daftar [jenis_musuh, jumlah].
##   - Musuh baru : tambah entri di ENEMIES (senjata memakai Global.WEAPONS, sprite memakai Global.CHARACTERS).
##   - Perk baru  : tambah di PERKS + efeknya di apply_perks() (atau di campaign.gd untuk efek khusus).
##   - Kesulitan  : lihat difficulty() dan enemy_stats() di bawah.

const SAVE_PATH := "user://campaign.cfg"
## 5 CHAPTER x 50 level = 250 level. Tiap chapter mengulang 10 dunia x 5 level (nomor level tampil kembali ke 1 di tiap chapter).
## Chapter 4 & 5 memakai varian map sendiri (MapVariantsLate) dan boss baru; kesulitan naik dari chapter ke chapter.
const CHAPTERS := 5
const CHAPTER_SIZE := 50
const TOTAL_LEVELS := 250
const CHAPTER_NAMES := ["FIRST BLOOD", "AFTERSHOCK", "LAST SIEGE", "DARK HORIZON", "NO MERCY"]
## Jumlah level sebelum dunia OCEAN / SPACE / FACTORY ditambahkan (kurva kesulitan asli 1..35 tidak diubah;
## level 36-50 melanjutkan kurva itu ke atas).
const BASE_LEVELS := 35
## Versi format save. v1 = 30 level (4 level di 5 dunia pertama), v2 = 35 level (5 level di tiap dunia).
const SAVE_VERSION := 2
const LEGACY_LEVELS := 30
## Pemetaan nomor level save lama (v1, indeks = nomor lama - 1) ke nomor baru, supaya bintang / skor / progres lama tidak tertukar.
const LEGACY_TO_NEW := [
	1, 2, 3, 5,          # GREEN FIELDS   (level baru: CROSSFIRE = 4)
	6, 7, 8, 10,         # CANOPY         (level baru: VINE TANGLE = 9)
	11, 13, 14, 15,      # FROZEN PASS    (level baru: ICE FLOE = 12)
	16, 18, 19, 20,      # DUNE RUINS     (level baru: CACTUS ALLEY = 17)
	21, 23, 24, 25,      # THORN SAVANNA  (level baru: TALL GRASS = 22)
	26, 27, 28, 29, 30,  # INFERNO
	31, 32, 33, 34, 35,  # ZIGGURAT
]
const START_LIVES := 3
const MAX_LIVES := 5

# ------------------------------------------------------------------ dunia
## levels = [pertama, terakhir] DI DALAM CHAPTER (1..50). Tiap dunia berisi 5 level; level terakhir tiap dunia adalah BOSS.
## Chapter 2 - 5 memakai daftar dunia yang sama; nomor level global = (chapter - 1) * 50 + nomor level di chapter.
const WORLDS := [
	{"id": "earth", "name": "GREEN FIELDS", "levels": [1, 5]},
	{"id": "jungle", "name": "CANOPY", "levels": [6, 10]},
	{"id": "snow", "name": "FROZEN PASS", "levels": [11, 15]},
	{"id": "desert", "name": "DUNE RUINS", "levels": [16, 20]},
	{"id": "safari", "name": "THORN SAVANNA", "levels": [21, 25]},
	{"id": "hell", "name": "INFERNO", "levels": [26, 30]},
	{"id": "temple", "name": "ZIGGURAT", "levels": [31, 35]},
	{"id": "ocean", "name": "SHIPWRECK BAY", "levels": [36, 40]},
	{"id": "space", "name": "STAR STATION", "levels": [41, 45]},
	{"id": "factory", "name": "IRON FOUNDRY", "levels": [46, 50]},
]

# ------------------------------------------------------------------ musuh
## weapon  : id senjata (Global.WEAPONS). knife_only = hanya memakai pisau.
## hp      : darah dasar (pemain = 3). speed / jump = pengali gerak. dmg = pengali damage (sebelum skala level).
## range   : jarak tempur yang disukai AI (px). chars = indeks karakter (Global.CHARACTERS) yang boleh dipakai.
## burst   : [min, max] tembakan beruntun sebelum jeda. skin = indeks warna / sprite senjata (1..3 = P2..P4).
const ENEMIES := {
	"grunt": {"name": "GRUNT", "weapon": "smith", "hp": 1.6, "speed": 0.82, "jump": 1.0, "dmg": 0.8, "range": 320.0,
		"burst": [1, 3], "chars": [0, 1, 4, 5], "skin": 1, "score": 100, "shield": false, "rate": 1.15},
	"rusher": {"name": "RUSHER", "weapon": "smith", "knife_only": true, "hp": 1.5, "speed": 1.12, "jump": 1.05, "dmg": 0.36, "range": 28.0,
		"burst": [1, 1], "chars": [3, 7, 15], "skin": 3, "score": 120, "shield": false, "rate": 1.0},
	"gunner": {"name": "GUNNER", "weapon": "kurval", "hp": 2.2, "speed": 0.72, "jump": 1.0, "dmg": 0.72, "range": 430.0,
		"burst": [1, 2], "chars": [2, 6, 14], "skin": 2, "score": 160, "shield": false, "rate": 1.2},
	"burner": {"name": "BURNER", "weapon": "flamer", "hp": 2.8, "speed": 0.86, "jump": 1.0, "dmg": 0.3, "range": 150.0,
		"burst": [8, 16], "chars": [10, 11], "skin": 3, "score": 180, "shield": false, "rate": 1.7},
	"sniper": {"name": "SNIPER", "weapon": "scream", "hp": 2.0, "speed": 0.7, "jump": 1.0, "dmg": 0.5, "range": 560.0,
		"burst": [1, 1], "chars": [8, 9, 12], "skin": 1, "score": 220, "shield": false, "rate": 1.0},
	"guard": {"name": "GUARD", "weapon": "smith", "hp": 2.6, "speed": 0.66, "jump": 0.95, "dmg": 0.8, "range": 300.0,
		"burst": [2, 4], "chars": [13, 12, 5], "skin": 2, "score": 200, "shield": true, "rate": 1.15},
	"hopper": {"name": "HOPPER", "weapon": "pistol", "hp": 1.7, "speed": 1.0, "jump": 1.38, "dmg": 2.2, "range": 280.0,
		"burst": [2, 4], "chars": [1, 7, 15], "skin": 1, "score": 140, "shield": false, "rate": 1.0},
	"brute": {"name": "BRUTE", "weapon": "kurval", "hp": 5.5, "speed": 0.7, "jump": 0.95, "dmg": 0.8, "range": 360.0,
		"burst": [2, 3], "chars": [2, 14, 12], "skin": 3, "score": 450, "shield": false, "rate": 1.0, "size": 1.3},
	# ---- boss: darah besar, badan besar, perilaku khusus (lihat "traits" di campaign.gd)
	"boss_bandit": {"name": "BANDIT BOSS", "weapon": "smith", "hp": 9.0, "speed": 0.9, "jump": 1.1, "dmg": 0.9, "range": 340.0,
		"burst": [3, 6], "chars": [2], "skin": 2, "score": 1500, "shield": false, "rate": 1.0, "size": 1.45,
		"boss": true, "traits": ["enrage", "summon"]},
	"boss_warden": {"name": "JUNGLE WARDEN", "weapon": "flamer", "hp": 11.0, "speed": 0.82, "jump": 1.15, "dmg": 0.34, "range": 190.0,
		"burst": [12, 22], "chars": [11], "skin": 3, "score": 2000, "shield": false, "rate": 1.4, "size": 1.5,
		"boss": true, "traits": ["enrage", "leap"]},
	"boss_frost": {"name": "FROST SNIPER", "weapon": "scream", "hp": 10.0, "speed": 0.8, "jump": 1.1, "dmg": 0.55, "range": 600.0,
		"burst": [1, 1], "chars": [9], "skin": 1, "score": 2500, "shield": true, "rate": 0.8, "size": 1.45,
		"boss": true, "traits": ["enrage", "summon"]},
	"boss_sandking": {"name": "SAND KING", "weapon": "kurval", "hp": 13.0, "speed": 0.92, "jump": 1.1, "dmg": 0.8, "range": 380.0,
		"burst": [2, 4], "chars": [6], "skin": 2, "score": 3000, "shield": false, "rate": 0.85, "size": 1.5,
		"boss": true, "traits": ["enrage", "dash"]},
	"boss_queen": {"name": "THORN QUEEN", "weapon": "smith", "hp": 14.0, "speed": 1.0, "jump": 1.3, "dmg": 0.95, "range": 330.0,
		"burst": [4, 8], "chars": [10], "skin": 3, "score": 3500, "shield": true, "rate": 0.85, "size": 1.45,
		"boss": true, "traits": ["enrage", "leap", "summon"]},
	"boss_inferno": {"name": "INFERNO LORD", "weapon": "flamer", "hp": 17.0, "speed": 0.95, "jump": 1.15, "dmg": 0.4, "range": 210.0,
		"burst": [14, 26], "chars": [3], "skin": 3, "score": 4500, "shield": false, "rate": 1.25, "size": 1.55,
		"boss": true, "traits": ["enrage", "dash", "summon"]},
	"boss_final": {"name": "THE BLACK SPIDER", "weapon": "scream", "hp": 22.0, "speed": 1.0, "jump": 1.25, "dmg": 0.6, "range": 520.0,
		"burst": [1, 1], "chars": [14], "skin": 2, "score": 10000, "shield": true, "rate": 0.7, "size": 1.6,
		"boss": true, "traits": ["enrage", "dash", "leap", "summon"]},
	# ---- boss dunia 8-10 (OCEAN, SPACE, FACTORY)
	"boss_captain": {"name": "CAPTAIN BLACKTIDE", "weapon": "kurval", "hp": 16.0, "speed": 0.98, "jump": 1.2, "dmg": 0.9, "range": 400.0,
		"burst": [2, 4], "chars": [18], "skin": 2, "score": 5500, "shield": false, "rate": 0.8, "size": 1.5,
		"boss": true, "traits": ["enrage", "leap", "summon"]},
	"boss_overlord": {"name": "ALIEN OVERLORD", "weapon": "scream", "hp": 19.0, "speed": 1.0, "jump": 1.25, "dmg": 0.6, "range": 540.0,
		"burst": [1, 1], "chars": [23], "skin": 3, "score": 7500, "shield": true, "rate": 0.7, "size": 1.55,
		"boss": true, "traits": ["enrage", "dash", "summon"]},
	"boss_tyrant": {"name": "THE IRON TYRANT", "weapon": "flamer", "hp": 22.0, "speed": 0.96, "jump": 1.2, "dmg": 0.46, "range": 230.0,
		"burst": [16, 28], "chars": [16], "skin": 1, "score": 15000, "shield": true, "rate": 1.2, "size": 1.65,
		"boss": true, "traits": ["enrage", "dash", "leap", "summon"]},
	# ---- musuh elit baru (muncul di CHAPTER 2 & 3)
	"veteran": {"name": "VETERAN", "weapon": "smith", "hp": 3.0, "speed": 0.84, "jump": 1.0, "dmg": 0.85, "range": 330.0,
		"burst": [2, 4], "chars": [18, 20], "skin": 2, "score": 230, "shield": true, "rate": 1.05},
	"assassin": {"name": "ASSASSIN", "weapon": "smith", "knife_only": true, "hp": 1.9, "speed": 1.28, "jump": 1.2, "dmg": 0.5, "range": 28.0,
		"burst": [1, 1], "chars": [17, 19], "skin": 3, "score": 200, "shield": false, "rate": 0.9},
	"marksman": {"name": "MARKSMAN", "weapon": "scream", "hp": 2.6, "speed": 0.74, "jump": 1.0, "dmg": 0.55, "range": 600.0,
		"burst": [1, 1], "chars": [22, 23], "skin": 1, "score": 280, "shield": true, "rate": 0.9},
	"juggernaut": {"name": "JUGGERNAUT", "weapon": "flamer", "hp": 7.0, "speed": 0.68, "jump": 0.9, "dmg": 0.34, "range": 170.0,
		"burst": [10, 18], "chars": [21, 16], "skin": 3, "score": 500, "shield": false, "rate": 1.5, "size": 1.35},
	# ---- boss CHAPTER 2
	"boss_king": {"name": "BANDIT KING", "weapon": "smith", "hp": 11.0, "speed": 0.95, "jump": 1.15, "dmg": 0.9, "range": 360.0,
		"burst": [3, 6], "chars": [5], "skin": 2, "score": 2500, "shield": false, "rate": 0.95, "size": 1.45,
		"boss": true, "traits": ["enrage", "summon", "dash"]},
	"boss_titan": {"name": "VINE TITAN", "weapon": "flamer", "hp": 13.0, "speed": 0.88, "jump": 1.2, "dmg": 0.36, "range": 200.0,
		"burst": [12, 22], "chars": [1], "skin": 3, "score": 3000, "shield": false, "rate": 1.35, "size": 1.5,
		"boss": true, "traits": ["enrage", "leap", "summon"]},
	"boss_weaver": {"name": "ICE WEAVER", "weapon": "scream", "hp": 12.0, "speed": 0.85, "jump": 1.15, "dmg": 0.55, "range": 620.0,
		"burst": [1, 1], "chars": [8], "skin": 1, "score": 3500, "shield": true, "rate": 0.8, "size": 1.45,
		"boss": true, "traits": ["enrage", "dash", "summon"]},
	"boss_pharaoh": {"name": "SCARAB PHARAOH", "weapon": "kurval", "hp": 15.0, "speed": 0.95, "jump": 1.15, "dmg": 0.85, "range": 400.0,
		"burst": [2, 4], "chars": [13], "skin": 2, "score": 4000, "shield": false, "rate": 0.8, "size": 1.5,
		"boss": true, "traits": ["enrage", "dash", "summon"]},
	"boss_warlord": {"name": "SAVANNA WARLORD", "weapon": "smith", "hp": 16.0, "speed": 1.0, "jump": 1.3, "dmg": 1.0, "range": 340.0,
		"burst": [5, 9], "chars": [7], "skin": 3, "score": 4500, "shield": true, "rate": 0.8, "size": 1.5,
		"boss": true, "traits": ["enrage", "leap", "dash"]},
	"boss_cyclops": {"name": "CYCLOPS DEMON", "weapon": "flamer", "hp": 19.0, "speed": 0.95, "jump": 1.15, "dmg": 0.42, "range": 220.0,
		"burst": [14, 26], "chars": [21], "skin": 3, "score": 5500, "shield": false, "rate": 1.25, "size": 1.55,
		"boss": true, "traits": ["enrage", "dash", "summon"]},
	"boss_priest": {"name": "GHOST PRIEST", "weapon": "scream", "hp": 22.0, "speed": 1.0, "jump": 1.25, "dmg": 0.6, "range": 540.0,
		"burst": [1, 1], "chars": [19], "skin": 2, "score": 6500, "shield": true, "rate": 0.7, "size": 1.55,
		"boss": true, "traits": ["enrage", "leap", "summon"]},
	"boss_general": {"name": "DROWNED GENERAL", "weapon": "kurval", "hp": 18.0, "speed": 1.0, "jump": 1.2, "dmg": 0.9, "range": 420.0,
		"burst": [2, 4], "chars": [17], "skin": 3, "score": 7000, "shield": false, "rate": 0.78, "size": 1.5,
		"boss": true, "traits": ["enrage", "leap", "summon"]},
	"boss_vamp": {"name": "STAR VAMPIRE", "weapon": "scream", "hp": 21.0, "speed": 1.0, "jump": 1.25, "dmg": 0.62, "range": 560.0,
		"burst": [1, 1], "chars": [20], "skin": 1, "score": 8000, "shield": true, "rate": 0.7, "size": 1.55,
		"boss": true, "traits": ["enrage", "dash", "summon"]},
	"boss_foreman": {"name": "THE FOREMAN", "weapon": "flamer", "hp": 24.0, "speed": 0.98, "jump": 1.2, "dmg": 0.48, "range": 240.0,
		"burst": [16, 28], "chars": [4], "skin": 2, "score": 9000, "shield": true, "rate": 1.15, "size": 1.65,
		"boss": true, "traits": ["enrage", "dash", "leap", "summon"]},
	"boss_marshal": {"name": "FIELD MARSHAL", "weapon": "smith", "hp": 13.0, "speed": 1.0, "jump": 1.25, "dmg": 0.95, "range": 360.0,
		"burst": [4, 8], "chars": [15], "skin": 1, "score": 5000, "shield": true, "rate": 0.8, "size": 1.5,
		"boss": true, "traits": ["enrage", "dash", "summon"]},
	"boss_elder": {"name": "ELDER WARDEN", "weapon": "flamer", "hp": 15.0, "speed": 0.92, "jump": 1.25, "dmg": 0.4, "range": 210.0,
		"burst": [14, 24], "chars": [0], "skin": 2, "score": 5500, "shield": false, "rate": 1.3, "size": 1.55,
		"boss": true, "traits": ["enrage", "leap", "summon"]},
	"boss_emperor": {"name": "FROST EMPEROR", "weapon": "scream", "hp": 14.0, "speed": 0.9, "jump": 1.2, "dmg": 0.58, "range": 640.0,
		"burst": [1, 1], "chars": [12], "skin": 3, "score": 6000, "shield": true, "rate": 0.75, "size": 1.5,
		"boss": true, "traits": ["enrage", "dash", "summon"]},
	"boss_sultan": {"name": "SANDSTORM SULTAN", "weapon": "kurval", "hp": 17.0, "speed": 1.0, "jump": 1.2, "dmg": 0.9, "range": 410.0,
		"burst": [2, 5], "chars": [22], "skin": 1, "score": 6500, "shield": false, "rate": 0.75, "size": 1.55,
		"boss": true, "traits": ["enrage", "dash", "leap"]},
	"boss_thornking": {"name": "KING OF THORNS", "weapon": "smith", "hp": 18.0, "speed": 1.05, "jump": 1.35, "dmg": 1.0, "range": 350.0,
		"burst": [6, 10], "chars": [11], "skin": 2, "score": 7000, "shield": true, "rate": 0.78, "size": 1.5,
		"boss": true, "traits": ["enrage", "leap", "summon"]},
	"boss_archdemon": {"name": "ARCH DEMON", "weapon": "flamer", "hp": 21.0, "speed": 1.0, "jump": 1.2, "dmg": 0.46, "range": 230.0,
		"burst": [16, 28], "chars": [21], "skin": 3, "score": 8500, "shield": false, "rate": 1.2, "size": 1.6,
		"boss": true, "traits": ["enrage", "dash", "summon"]},
	"boss_serpent": {"name": "SERPENT GOD", "weapon": "scream", "hp": 24.0, "speed": 1.05, "jump": 1.3, "dmg": 0.62, "range": 560.0,
		"burst": [1, 1], "chars": [14], "skin": 1, "score": 9500, "shield": true, "rate": 0.68, "size": 1.6,
		"boss": true, "traits": ["enrage", "dash", "leap", "summon"]},
	"boss_leviathan": {"name": "LEVIATHAN", "weapon": "kurval", "hp": 20.0, "speed": 1.0, "jump": 1.25, "dmg": 0.95, "range": 440.0,
		"burst": [3, 5], "chars": [18], "skin": 2, "score": 10000, "shield": true, "rate": 0.72, "size": 1.6,
		"boss": true, "traits": ["enrage", "dash", "summon"]},
	"boss_devourer": {"name": "STAR DEVOURER", "weapon": "scream", "hp": 23.0, "speed": 1.05, "jump": 1.3, "dmg": 0.64, "range": 580.0,
		"burst": [1, 1], "chars": [23], "skin": 3, "score": 12000, "shield": true, "rate": 0.65, "size": 1.65,
		"boss": true, "traits": ["enrage", "dash", "leap", "summon"]},
	"boss_omega": {"name": "THE OMEGA CORE", "weapon": "flamer", "hp": 26.0, "speed": 1.0, "jump": 1.25, "dmg": 0.5, "range": 250.0,
		"burst": [18, 30], "chars": [16], "skin": 1, "score": 25000, "shield": true, "rate": 1.1, "size": 1.7,
		"boss": true, "traits": ["enrage", "dash", "leap", "summon"]},
	# ---- boss CHAPTER 4 (DARK HORIZON)
	"boss_consul": {"name": "IRON CONSUL", "weapon": "smith", "hp": 14.0, "speed": 1.0, "jump": 1.25, "dmg": 0.95, "range": 360.0,
		"burst": [4, 8], "chars": [12], "skin": 2, "score": 6000, "shield": true, "rate": 0.8, "size": 1.5,
		"boss": true, "traits": ["enrage", "dash", "summon"]},
	"boss_overmind": {"name": "FUNGAL OVERMIND", "weapon": "flamer", "hp": 16.0, "speed": 0.92, "jump": 1.25, "dmg": 0.42, "range": 210.0,
		"burst": [14, 24], "chars": [17], "skin": 3, "score": 6500, "shield": false, "rate": 1.25, "size": 1.55,
		"boss": true, "traits": ["enrage", "leap", "summon"]},
	"boss_matriarch": {"name": "BLIZZARD MATRIARCH", "weapon": "scream", "hp": 15.0, "speed": 0.92, "jump": 1.2, "dmg": 0.6, "range": 650.0,
		"burst": [1, 1], "chars": [9], "skin": 1, "score": 7000, "shield": true, "rate": 0.72, "size": 1.5,
		"boss": true, "traits": ["enrage", "dash", "summon"]},
	"boss_sovereign": {"name": "TOMB SOVEREIGN", "weapon": "kurval", "hp": 18.0, "speed": 1.0, "jump": 1.2, "dmg": 0.92, "range": 420.0,
		"burst": [2, 5], "chars": [19], "skin": 2, "score": 7500, "shield": false, "rate": 0.74, "size": 1.55,
		"boss": true, "traits": ["enrage", "dash", "leap"]},
	"boss_empress": {"name": "VULTURE EMPRESS", "weapon": "smith", "hp": 19.0, "speed": 1.08, "jump": 1.4, "dmg": 1.0, "range": 350.0,
		"burst": [6, 10], "chars": [3], "skin": 3, "score": 8000, "shield": true, "rate": 0.76, "size": 1.5,
		"boss": true, "traits": ["enrage", "leap", "summon"]},
	"boss_seraph": {"name": "ASH SERAPH", "weapon": "flamer", "hp": 22.0, "speed": 1.0, "jump": 1.25, "dmg": 0.48, "range": 235.0,
		"burst": [16, 28], "chars": [15], "skin": 3, "score": 9000, "shield": false, "rate": 1.15, "size": 1.6,
		"boss": true, "traits": ["enrage", "dash", "summon"]},
	"boss_oracle": {"name": "MOON ORACLE", "weapon": "scream", "hp": 25.0, "speed": 1.05, "jump": 1.3, "dmg": 0.64, "range": 580.0,
		"burst": [1, 1], "chars": [20], "skin": 2, "score": 10000, "shield": true, "rate": 0.66, "size": 1.6,
		"boss": true, "traits": ["enrage", "dash", "leap", "summon"]},
	"boss_admiral": {"name": "KRAKEN ADMIRAL", "weapon": "kurval", "hp": 21.0, "speed": 1.0, "jump": 1.25, "dmg": 0.96, "range": 450.0,
		"burst": [3, 5], "chars": [18], "skin": 1, "score": 11000, "shield": true, "rate": 0.7, "size": 1.6,
		"boss": true, "traits": ["enrage", "leap", "summon"]},
	"boss_reaper": {"name": "VOID REAPER", "weapon": "scream", "hp": 24.0, "speed": 1.05, "jump": 1.3, "dmg": 0.66, "range": 600.0,
		"burst": [1, 1], "chars": [23], "skin": 1, "score": 12500, "shield": true, "rate": 0.64, "size": 1.65,
		"boss": true, "traits": ["enrage", "dash", "leap", "summon"]},
	"boss_colossus": {"name": "CHROME COLOSSUS", "weapon": "flamer", "hp": 27.0, "speed": 1.0, "jump": 1.25, "dmg": 0.52, "range": 255.0,
		"burst": [18, 30], "chars": [16], "skin": 2, "score": 18000, "shield": true, "rate": 1.1, "size": 1.7,
		"boss": true, "traits": ["enrage", "dash", "leap", "summon"]},
	# ---- boss CHAPTER 5 (NO MERCY)
	"boss_harbinger": {"name": "THE HARBINGER", "weapon": "smith", "hp": 15.0, "speed": 1.02, "jump": 1.3, "dmg": 1.0, "range": 370.0,
		"burst": [4, 8], "chars": [13], "skin": 3, "score": 8000, "shield": true, "rate": 0.78, "size": 1.5,
		"boss": true, "traits": ["enrage", "dash", "summon"]},
	"boss_worldroot": {"name": "WORLD ROOT", "weapon": "flamer", "hp": 17.0, "speed": 0.95, "jump": 1.3, "dmg": 0.45, "range": 215.0,
		"burst": [14, 24], "chars": [10], "skin": 3, "score": 8500, "shield": false, "rate": 1.2, "size": 1.6,
		"boss": true, "traits": ["enrage", "leap", "summon"]},
	"boss_tyrant_ice": {"name": "GLACIAL TYRANT", "weapon": "scream", "hp": 16.0, "speed": 0.95, "jump": 1.25, "dmg": 0.62, "range": 660.0,
		"burst": [1, 1], "chars": [8], "skin": 1, "score": 9000, "shield": true, "rate": 0.7, "size": 1.55,
		"boss": true, "traits": ["enrage", "dash", "summon"]},
	"boss_mummy": {"name": "MUMMY LORD", "weapon": "kurval", "hp": 19.0, "speed": 1.02, "jump": 1.25, "dmg": 0.95, "range": 430.0,
		"burst": [2, 5], "chars": [6], "skin": 2, "score": 9500, "shield": false, "rate": 0.72, "size": 1.6,
		"boss": true, "traits": ["enrage", "dash", "leap"]},
	"boss_apex": {"name": "APEX PREDATOR", "weapon": "smith", "hp": 20.0, "speed": 1.12, "jump": 1.45, "dmg": 1.05, "range": 340.0,
		"burst": [6, 10], "chars": [22], "skin": 3, "score": 10000, "shield": true, "rate": 0.74, "size": 1.55,
		"boss": true, "traits": ["enrage", "leap", "dash"]},
	"boss_overfiend": {"name": "THE OVERFIEND", "weapon": "flamer", "hp": 23.0, "speed": 1.02, "jump": 1.3, "dmg": 0.5, "range": 240.0,
		"burst": [16, 28], "chars": [21], "skin": 3, "score": 11500, "shield": false, "rate": 1.12, "size": 1.65,
		"boss": true, "traits": ["enrage", "dash", "summon"]},
	"boss_deity": {"name": "SKULL DEITY", "weapon": "scream", "hp": 26.0, "speed": 1.08, "jump": 1.35, "dmg": 0.68, "range": 590.0,
		"burst": [1, 1], "chars": [14], "skin": 2, "score": 13000, "shield": true, "rate": 0.64, "size": 1.65,
		"boss": true, "traits": ["enrage", "dash", "leap", "summon"]},
	"boss_abyss": {"name": "ABYSS QUEEN", "weapon": "kurval", "hp": 22.0, "speed": 1.02, "jump": 1.3, "dmg": 1.0, "range": 460.0,
		"burst": [3, 5], "chars": [7], "skin": 1, "score": 14000, "shield": true, "rate": 0.68, "size": 1.65,
		"boss": true, "traits": ["enrage", "leap", "summon"]},
	"boss_galaxy": {"name": "GALAXY EATER", "weapon": "scream", "hp": 25.0, "speed": 1.08, "jump": 1.35, "dmg": 0.7, "range": 610.0,
		"burst": [1, 1], "chars": [4], "skin": 3, "score": 16000, "shield": true, "rate": 0.62, "size": 1.7,
		"boss": true, "traits": ["enrage", "dash", "leap", "summon"]},
	"boss_engine": {"name": "THE FINAL ENGINE", "weapon": "flamer", "hp": 30.0, "speed": 1.02, "jump": 1.3, "dmg": 0.56, "range": 260.0,
		"burst": [20, 32], "chars": [16], "skin": 1, "score": 40000, "shield": true, "rate": 1.05, "size": 1.75,
		"boss": true, "traits": ["enrage", "dash", "leap", "summon"]},
}

# ------------------------------------------------------------------ level
## Format (level global 1..250): {"name", "map", "waves": [[["musuh", jumlah], ...], ...], "pu": [min, maks] detik antar power up, "cap": maks power up di arena, "hint": teks}
## Level yang berisi "boss_*" otomatis menjadi level BOSS (musik & intro khusus).
static func _lv(level_name: String, map_id: String, waves: Array, pu: Array = [11.0, 16.0], cap: int = 2, hint: String = "") -> Dictionary:
	return {"name": level_name, "map": map_id, "waves": waves, "pu": pu, "cap": cap, "hint": hint}


## CHAPTER 1 (level 1-50).
static func _levels_ch1() -> Array:
	return [
		# ---------------- DUNIA 1: GREEN FIELDS (earth)
		_lv("WARM UP", "earth", [[["grunt", 1]], [["grunt", 2]]], [10.0, 14.0], 2, "MOVE, JUMP AND SHOOT - KNIFE = SWITCH WEAPON"),
		_lv("TWO FRONTS", "earth", [[["grunt", 2]], [["grunt", 2], ["rusher", 1]]], [10.0, 14.0], 2, "GRAB POWER-UPS DROPPED BY ENEMIES"),
		_lv("HIGH GROUND", "earth", [[["grunt", 2], ["rusher", 1]], [["gunner", 1], ["grunt", 2]]], [10.0, 15.0], 2, "PLATFORMS: PRESS DOWN TO DROP"),
		_lv("CROSSFIRE", "earth", [[["grunt", 3]], [["grunt", 1], ["rusher", 2]], [["gunner", 1], ["grunt", 2]]], [9.5, 14.0], 2, "SHIELD POWER-UP BLOCKS 2 HITS - GRAB IT"),
		_lv("THE BANDIT", "earth", [[["grunt", 2]], [["boss_bandit", 1]]], [9.0, 13.0], 2),
		# ---------------- DUNIA 2: CANOPY (jungle)
		_lv("TREETOPS", "jungle", [[["grunt", 2], ["hopper", 1]], [["gunner", 1], ["rusher", 2]]], [10.0, 15.0], 2, "MUSHROOMS LAUNCH YOU SKYWARD"),
		_lv("HOP SCOTCH", "jungle", [[["hopper", 2], ["grunt", 1]], [["gunner", 2]], [["burner", 1], ["grunt", 2]]], [10.0, 15.0], 2),
		_lv("SMOKE SIGNAL", "jungle", [[["burner", 1], ["rusher", 2]], [["gunner", 1], ["hopper", 2]], [["guard", 1], ["grunt", 2]]], [10.0, 14.0], 2),
		_lv("VINE TANGLE", "jungle", [[["hopper", 3], ["rusher", 1]], [["burner", 1], ["gunner", 1], ["grunt", 1]], [["guard", 1], ["hopper", 2]]], [9.5, 14.0], 2, "TIME YOUR JUMPS ON THE MOVING LOGS"),
		_lv("THE WARDEN", "jungle", [[["hopper", 2]], [["boss_warden", 1]]], [9.0, 13.0], 3),
		# ---------------- DUNIA 3: FROZEN PASS (snow)
		_lv("THIN ICE", "snow", [[["sniper", 1], ["grunt", 2]], [["guard", 1], ["rusher", 2]]], [10.0, 14.0], 2, "ICE IS SLIPPERY - WATCH THE WATER"),
		_lv("ICE FLOE", "snow", [[["gunner", 1], ["grunt", 2]], [["rusher", 2], ["hopper", 1]], [["sniper", 1], ["guard", 1], ["grunt", 1]]], [10.0, 14.0], 2, "RIDE THE ICE FLOE ACROSS THE WATER"),
		_lv("WHITEOUT", "snow", [[["gunner", 2], ["hopper", 2]], [["sniper", 1], ["burner", 1], ["grunt", 1]], [["guard", 2], ["rusher", 1]]], [9.0, 13.0], 3),
		_lv("COLD SNAP", "snow", [[["rusher", 3], ["hopper", 2]], [["sniper", 2], ["grunt", 2]], [["burner", 2], ["guard", 1]]], [9.0, 13.0], 3),
		_lv("FROST SNIPER", "snow", [[["gunner", 1], ["grunt", 2]], [["boss_frost", 1]]], [8.0, 12.0], 3),
		# ---------------- DUNIA 4: DUNE RUINS (desert)
		_lv("MIRAGE", "desert", [[["guard", 2], ["gunner", 1]], [["burner", 2], ["hopper", 2]]], [9.0, 13.0], 3, "CRUMBLING STONE - DON'T STAND STILL"),
		_lv("CACTUS ALLEY", "desert", [[["hopper", 2], ["grunt", 1]], [["sniper", 1], ["guard", 1], ["rusher", 2]], [["burner", 2], ["gunner", 1]]], [9.0, 13.0], 3, "CACTI HURT - JUMP OVER THEM"),
		_lv("SAND TRAP", "desert", [[["sniper", 2], ["gunner", 1], ["grunt", 2]], [["rusher", 4]], [["guard", 1], ["burner", 2]]], [9.0, 13.0], 3),
		_lv("DUST STORM", "desert", [[["hopper", 3], ["rusher", 2]], [["sniper", 2], ["guard", 2]], [["burner", 2], ["gunner", 2], ["grunt", 2]]], [8.0, 12.0], 3),
		_lv("THE SAND KING", "desert", [[["guard", 2], ["rusher", 2]], [["boss_sandking", 1]]], [8.0, 12.0], 3),
		# ---------------- DUNIA 5: THORN SAVANNA (safari)
		_lv("THORNY PATH", "safari", [[["gunner", 2], ["hopper", 2]], [["guard", 2], ["burner", 1]]], [9.0, 13.0], 3, "SPIKES HURT - ENEMIES FEEL THEM TOO"),
		_lv("TALL GRASS", "safari", [[["rusher", 2], ["grunt", 2]], [["gunner", 2], ["hopper", 1]], [["sniper", 1], ["guard", 1], ["burner", 1]]], [9.0, 13.0], 3, "RIDE THE MOVING PLATFORMS OVER THE SPIKES"),
		_lv("PRIDE LANDS", "safari", [[["sniper", 2], ["rusher", 3]], [["brute", 1], ["grunt", 2]], [["burner", 2], ["hopper", 2]]], [8.0, 12.0], 3),
		_lv("STAMPEDE", "safari", [[["rusher", 5]], [["gunner", 2], ["guard", 2]], [["brute", 1], ["sniper", 1], ["hopper", 2]]], [8.0, 12.0], 3),
		_lv("THORN QUEEN", "safari", [[["hopper", 3], ["guard", 1]], [["boss_queen", 1]]], [8.0, 11.0], 3),
		# ---------------- DUNIA 6: INFERNO (hell)
		_lv("EMBER GATE", "hell", [[["burner", 2], ["gunner", 2]], [["guard", 2], ["sniper", 1], ["rusher", 2]]], [8.0, 12.0], 3, "LAVA BURNS - FALLING COSTS A HEART"),
		_lv("CINDER RUN", "hell", [[["hopper", 4], ["rusher", 2]], [["brute", 1], ["sniper", 2]], [["burner", 3], ["guard", 2]]], [8.0, 11.0], 3),
		_lv("MAGMA HALLS", "hell", [[["sniper", 2], ["gunner", 3]], [["brute", 2], ["rusher", 3]], [["burner", 2], ["guard", 2], ["hopper", 2]]], [7.0, 11.0], 3),
		_lv("HELLFIRE", "hell", [[["brute", 2], ["burner", 2]], [["sniper", 3], ["hopper", 3]], [["guard", 3], ["gunner", 2], ["rusher", 3]]], [7.0, 10.0], 4),
		_lv("INFERNO LORD", "hell", [[["burner", 2], ["guard", 2]], [["boss_inferno", 1]]], [7.0, 10.0], 4),
		# ---------------- DUNIA 7: ZIGGURAT (temple)
		_lv("FIRST TRIAL", "temple", [[["gunner", 3], ["hopper", 3]], [["guard", 3], ["sniper", 2]], [["brute", 1], ["burner", 2], ["rusher", 3]]], [7.0, 10.0], 3, "ARROW TRAPS FIRE FROM THE WALLS"),
		_lv("STONE SENTINELS", "temple", [[["sniper", 3], ["guard", 3]], [["brute", 2], ["hopper", 3]], [["burner", 3], ["gunner", 3]]], [7.0, 10.0], 3),
		_lv("SERPENT'S COIL", "temple", [[["rusher", 6], ["hopper", 3]], [["brute", 2], ["sniper", 2], ["guard", 2]], [["burner", 3], ["gunner", 3], ["hopper", 3]]], [7.0, 10.0], 4),
		_lv("GAUNTLET", "temple", [[["brute", 2], ["sniper", 3]], [["guard", 4], ["burner", 3]], [["brute", 2], ["gunner", 3], ["rusher", 4], ["hopper", 2]]], [6.0, 9.0], 4),
		_lv("THE BLACK SPIDER", "temple", [[["brute", 2], ["sniper", 2]], [["boss_final", 1]]], [6.0, 9.0], 4),
		# ---------------- DUNIA 8: SHIPWRECK BAY (ocean)
		_lv("LOW TIDE", "ocean", [[["gunner", 3], ["hopper", 3]], [["guard", 2], ["sniper", 2], ["rusher", 3]], [["burner", 2], ["grunt", 3], ["hopper", 2]]], [8.0, 11.0], 3, "GEYSERS ERUPT AFTER THE FOAM WARNING - THEY CAN LIFT YOU"),
		_lv("CANNON DECK", "ocean", [[["sniper", 3], ["guard", 3]], [["brute", 1], ["hopper", 3], ["rusher", 3]], [["gunner", 3], ["burner", 3], ["guard", 2]]], [7.0, 10.0], 3, "SHIP CANNONS FIRE ACROSS THE DECK - WATCH THE RED LINE"),
		_lv("RIPTIDE", "ocean", [[["rusher", 6], ["hopper", 3]], [["brute", 2], ["sniper", 2], ["gunner", 2]], [["burner", 3], ["guard", 3], ["hopper", 3]]], [7.0, 10.0], 4, "FALLING IN THE WATER COSTS A HEART - RIDE A GEYSER BACK UP"),
		_lv("DEAD MAN'S CHEST", "ocean", [[["brute", 2], ["sniper", 3]], [["guard", 4], ["burner", 3]], [["brute", 2], ["gunner", 3], ["rusher", 4], ["hopper", 3]]], [7.0, 10.0], 4),
		_lv("CAPTAIN BLACKTIDE", "ocean", [[["brute", 2], ["guard", 2]], [["boss_captain", 1]]], [7.0, 10.0], 4),
		# ---------------- DUNIA 9: STAR STATION (space)
		_lv("AIRLOCK", "space", [[["gunner", 3], ["hopper", 4]], [["sniper", 3], ["guard", 3], ["rusher", 3]], [["brute", 1], ["burner", 3], ["hopper", 3]]], [7.0, 10.0], 3, "STEP INTO A PORTAL TO WARP TO THE OTHER SIDE"),
		_lv("ZERO G", "space", [[["hopper", 5], ["sniper", 2]], [["brute", 2], ["gunner", 3], ["guard", 3]], [["burner", 3], ["rusher", 5], ["sniper", 2]]], [7.0, 10.0], 4, "ANTI-GRAV LIFTS CARRY YOU TO THE UPPER DECK"),
		_lv("WARP DRIVE", "space", [[["rusher", 7], ["hopper", 3]], [["brute", 2], ["sniper", 3], ["guard", 3]], [["burner", 4], ["gunner", 4], ["hopper", 3]]], [6.0, 9.0], 4, "ENEMIES USE PORTALS TOO - WATCH BOTH SIDES"),
		_lv("METEOR BELT", "space", [[["brute", 3], ["sniper", 3]], [["guard", 4], ["burner", 4]], [["brute", 2], ["gunner", 4], ["rusher", 5], ["hopper", 3]]], [6.0, 9.0], 4),
		_lv("ALIEN OVERLORD", "space", [[["brute", 2], ["sniper", 3]], [["boss_overlord", 1]]], [6.0, 9.0], 4),
		# ---------------- DUNIA 10: IRON FOUNDRY (factory)
		_lv("ASSEMBLY LINE", "factory", [[["gunner", 4], ["hopper", 3]], [["guard", 3], ["sniper", 3], ["brute", 1]], [["burner", 3], ["rusher", 5], ["grunt", 3]]], [6.0, 9.0], 4, "CONVEYORS DRAG YOU - SAWS SLICE"),
		_lv("SCRAPYARD", "factory", [[["brute", 3], ["hopper", 4]], [["sniper", 4], ["guard", 4]], [["burner", 4], ["gunner", 4], ["rusher", 4]]], [6.0, 9.0], 4, "THE FLOOR BELTS PUSH TOWARD THE SAW - KEEP MOVING"),
		_lv("FURNACE ROOM", "factory", [[["rusher", 8], ["hopper", 4]], [["brute", 3], ["sniper", 3], ["guard", 3]], [["burner", 4], ["gunner", 4], ["hopper", 4]]], [6.0, 9.0], 4),
		_lv("SHUTDOWN", "factory", [[["brute", 3], ["sniper", 4]], [["guard", 5], ["burner", 4]], [["brute", 3], ["gunner", 4], ["rusher", 5], ["hopper", 4]]], [6.0, 8.0], 4),
		_lv("THE IRON TYRANT", "factory", [[["brute", 3], ["sniper", 3], ["guard", 2]], [["boss_tyrant", 1]]], [6.0, 8.0], 4),
	]


## CHAPTER 2 "AFTERSHOCK" (level 51-100 = level 1-50 di chapter ini). Map: varian Chapter 2 (MapVariants).
## Komposisi musuh tiap level dibuat per tema dunia dan dihitung supaya anggaran ancamannya naik mulus
## (tiap dunia mulai lebih ringan lalu menanjak sampai boss, seperti Chapter 1, tetapi dengan musuh elit baru).
static func _levels_ch2() -> Array:
	return [
		# ======================================================================== CHAPTER 2: AFTERSHOCK (level 51-100)
		# ---------------- DUNIA 1: GREEN FIELDS (earth)
		_lv("SECOND SUNRISE", "earth", [[["grunt", 2], ["rusher", 2]], [["gunner", 2], ["grunt", 2], ["hopper", 1]], [["veteran", 1], ["grunt", 3], ["hopper", 2]]], [9.0, 13.0], 2, "HILLS ARE COVER - DUCK BEHIND THEM TO DODGE BULLETS"),
		_lv("HILL CREST", "earth", [[["grunt", 2], ["hopper", 3], ["rusher", 1]], [["gunner", 2], ["guard", 1], ["grunt", 2]], [["veteran", 1], ["gunner", 1], ["rusher", 3], ["hopper", 1]]], [9.0, 13.0], 2),
		_lv("BATTLE LINE", "earth", [[["gunner", 3], ["grunt", 3]], [["guard", 2], ["rusher", 3], ["hopper", 1]], [["veteran", 2], ["gunner", 1], ["sniper", 1], ["grunt", 1]]], [9.0, 13.0], 2),
		_lv("CROSSING GUARD", "earth", [[["hopper", 3], ["rusher", 3], ["grunt", 2]], [["gunner", 2], ["veteran", 1], ["sniper", 1], ["assassin", 1]], [["guard", 2], ["gunner", 2], ["grunt", 1], ["assassin", 1]]], [8.5, 12.5], 3),
		_lv("BANDIT KING", "earth", [[["grunt", 3], ["guard", 1], ["gunner", 2], ["hopper", 1], ["rusher", 2]], [["boss_king", 1]]], [8.0, 12.0], 3),
		# ---------------- DUNIA 2: CANOPY (jungle)
		_lv("CANOPY RETURN", "jungle", [[["rusher", 3], ["assassin", 2]], [["hopper", 4], ["assassin", 2]], [["grunt", 3], ["hopper", 5]]], [9.0, 13.0], 2, "BOUNCE SHROOMS LAUNCH YOU TO THE HIGH BRANCH"),
		_lv("LIANA LEAP", "jungle", [[["rusher", 4], ["burner", 2]], [["hopper", 3], ["burner", 1], ["assassin", 2]], [["grunt", 2], ["hopper", 4], ["assassin", 2]]], [9.0, 13.0], 2),
		_lv("POISON DART", "jungle", [[["gunner", 3], ["burner", 2]], [["hopper", 3], ["gunner", 2], ["burner", 2]], [["grunt", 3], ["rusher", 2], ["hopper", 6]]], [8.5, 12.5], 3),
		_lv("STRANGLER FIG", "jungle", [[["grunt", 3], ["gunner", 2], ["burner", 2]], [["gunner", 2], ["burner", 2], ["assassin", 3]], [["hopper", 5], ["burner", 2], ["assassin", 2]]], [8.5, 12.5], 3),
		_lv("VINE TITAN", "jungle", [[["hopper", 4], ["burner", 2]], [["boss_titan", 1], ["rusher", 4], ["veteran", 1]]], [8.0, 12.0], 3),
		# ---------------- DUNIA 3: FROZEN PASS (snow)
		_lv("POLAR NIGHT", "snow", [[["guard", 2], ["marksman", 1]], [["gunner", 2], ["sniper", 2], ["guard", 2]], [["gunner", 3], ["guard", 2], ["marksman", 1]]], [9.0, 13.0], 2, "TWO ICE POOLS - HOP THE FLOES OR CROSS ON THE ISLAND"),
		_lv("DEEP FREEZE", "snow", [[["gunner", 3], ["assassin", 1], ["marksman", 1]], [["grunt", 2], ["sniper", 3], ["guard", 2]], [["sniper", 3], ["assassin", 2], ["marksman", 1]]], [9.0, 13.0], 2),
		_lv("GLACIER RUN", "snow", [[["grunt", 2], ["sniper", 3], ["marksman", 1]], [["hopper", 2], ["gunner", 3], ["sniper", 3]], [["gunner", 3], ["sniper", 3], ["assassin", 2]]], [8.5, 12.5], 3),
		_lv("WHITE WALL", "snow", [[["sniper", 3], ["guard", 2], ["veteran", 1]], [["hopper", 2], ["sniper", 4], ["assassin", 2]], [["grunt", 4], ["sniper", 4], ["assassin", 2]]], [8.5, 12.5], 3),
		_lv("ICE WEAVER", "snow", [[["hopper", 2], ["gunner", 3], ["sniper", 2]], [["boss_weaver", 1], ["gunner", 2], ["guard", 2], ["sniper", 2]]], [8.0, 12.0], 3),
		# ---------------- DUNIA 4: DUNE RUINS (desert)
		_lv("OASIS MIRAGE", "desert", [[["assassin", 3], ["burner", 2]], [["hopper", 3], ["guard", 2], ["assassin", 2]], [["hopper", 3], ["guard", 2], ["burner", 3]]], [9.0, 13.0], 3, "CACTI HURT - THE STONE BRIDGE CRUMBLES"),
		_lv("SCORPION PIT", "desert", [[["hopper", 3], ["burner", 2], ["assassin", 2]], [["assassin", 4], ["sniper", 2], ["veteran", 1]], [["burner", 2], ["guard", 3], ["assassin", 3]]], [8.5, 12.5], 3),
		_lv("BURIED GATE", "desert", [[["hopper", 4], ["guard", 2], ["assassin", 2]], [["guard", 2], ["assassin", 3], ["marksman", 2]], [["assassin", 3], ["guard", 3], ["brute", 1]]], [8.5, 12.5], 3),
		_lv("SAND SERPENT", "desert", [[["assassin", 3], ["burner", 3], ["marksman", 1]], [["assassin", 3], ["guard", 4], ["veteran", 1]], [["burner", 4], ["guard", 4], ["marksman", 1]]], [8.0, 12.0], 3),
		_lv("SCARAB PHARAOH", "desert", [[["assassin", 2], ["burner", 3], ["veteran", 1]], [["boss_pharaoh", 1], ["hopper", 3], ["burner", 2], ["brute", 1]]], [8.0, 12.0], 3),
		# ---------------- DUNIA 5: THORN SAVANNA (safari)
		_lv("WATERHOLE TRUCE", "safari", [[["rusher", 5], ["hopper", 2], ["gunner", 2]], [["rusher", 6], ["gunner", 2], ["marksman", 1]], [["rusher", 5], ["sniper", 2], ["veteran", 2]]], [8.5, 12.5], 3, "SPIKE LANES - RIDE THE SWINGING PLATFORMS"),
		_lv("HYENA CALL", "safari", [[["assassin", 4], ["sniper", 1], ["marksman", 1]], [["hopper", 4], ["assassin", 4], ["veteran", 1]], [["rusher", 6], ["assassin", 3], ["brute", 1]]], [8.5, 12.5], 3),
		_lv("DRY SEASON", "safari", [[["rusher", 6], ["gunner", 2], ["assassin", 2]], [["rusher", 6], ["hopper", 3], ["gunner", 3]], [["rusher", 6], ["hopper", 4], ["sniper", 2]]], [8.0, 12.0], 3),
		_lv("BUFFALO CHARGE", "safari", [[["rusher", 4], ["gunner", 2], ["assassin", 2]], [["rusher", 5], ["assassin", 2], ["brute", 1]], [["hopper", 4], ["gunner", 3], ["brute", 1]], [["rusher", 6], ["assassin", 3], ["marksman", 1]]], [8.0, 11.0], 3),
		_lv("SAVANNA WARLORD", "safari", [[["assassin", 2], ["sniper", 2]], [["assassin", 3], ["brute", 1]], [["boss_warlord", 1], ["gunner", 2], ["assassin", 1], ["brute", 1]]], [8.0, 11.0], 3),
		# ---------------- DUNIA 6: INFERNO (hell)
		_lv("ASHEN SHORE", "hell", [[["burner", 2], ["sniper", 2], ["marksman", 1]], [["burner", 3], ["veteran", 2], ["marksman", 1]], [["hopper", 3], ["burner", 4], ["veteran", 2]]], [8.0, 12.0], 3, "STEPPING STONES CRUMBLE OVER THE LAVA"),
		_lv("OBSIDIAN STEPS", "hell", [[["burner", 4], ["assassin", 2], ["veteran", 1]], [["burner", 3], ["marksman", 2], ["brute", 1]], [["sniper", 3], ["assassin", 4], ["marksman", 2]]], [8.0, 11.0], 3),
		_lv("BRIMSTONE", "hell", [[["hopper", 2], ["burner", 3], ["marksman", 1]], [["burner", 4], ["marksman", 1], ["brute", 1]], [["sniper", 2], ["marksman", 2], ["juggernaut", 1]], [["burner", 3], ["marksman", 1], ["juggernaut", 1]]], [7.5, 11.0], 3),
		_lv("CINDER STORM", "hell", [[["burner", 4], ["sniper", 1], ["veteran", 1]], [["burner", 3], ["assassin", 2], ["marksman", 2]], [["burner", 4], ["veteran", 2], ["brute", 1]], [["sniper", 3], ["brute", 1], ["juggernaut", 1]]], [7.5, 10.5], 4),
		_lv("CYCLOPS DEMON", "hell", [[["assassin", 3], ["burner", 2]], [["burner", 3], ["assassin", 1], ["marksman", 1]], [["boss_cyclops", 1], ["burner", 3], ["sniper", 1], ["veteran", 1]]], [7.5, 10.5], 4),
		# ---------------- DUNIA 7: ZIGGURAT (temple)
		_lv("SUN GATE", "temple", [[["assassin", 1], ["veteran", 2], ["marksman", 2]], [["sniper", 3], ["guard", 2], ["marksman", 2]], [["assassin", 2], ["veteran", 3], ["marksman", 2]]], [8.0, 11.0], 3, "PILLARS BLOCK BULLETS - ARROWS FLY AT TWO HEIGHTS"),
		_lv("COURT OF SPEARS", "temple", [[["burner", 1], ["guard", 2], ["veteran", 2]], [["guard", 3], ["assassin", 2], ["veteran", 2]], [["assassin", 2], ["sniper", 3], ["brute", 1]], [["sniper", 2], ["veteran", 2], ["marksman", 2]]], [8.0, 11.0], 3),
		_lv("HALL OF ECHOES", "temple", [[["sniper", 2], ["assassin", 2], ["marksman", 2]], [["sniper", 4], ["guard", 3], ["burner", 1]], [["guard", 3], ["assassin", 2], ["veteran", 3]], [["sniper", 3], ["guard", 2], ["marksman", 2]]], [7.5, 10.5], 4),
		_lv("PRIEST'S WRATH", "temple", [[["assassin", 2], ["sniper", 2], ["veteran", 2]], [["gunner", 2], ["sniper", 3], ["veteran", 3]], [["assassin", 3], ["veteran", 3], ["marksman", 2]], [["assassin", 4], ["burner", 3], ["brute", 1]]], [7.5, 10.5], 4),
		_lv("GHOST PRIEST", "temple", [[["sniper", 2], ["veteran", 2]], [["sniper", 2], ["veteran", 1], ["brute", 1]], [["boss_priest", 1], ["sniper", 2], ["veteran", 2], ["marksman", 1]]], [7.5, 10.5], 4),
		# ---------------- DUNIA 8: SHIPWRECK BAY (ocean)
		_lv("SUNKEN HOLD", "ocean", [[["guard", 2], ["assassin", 4], ["veteran", 1]], [["hopper", 4], ["assassin", 4], ["veteran", 1]], [["hopper", 5], ["assassin", 3], ["marksman", 2]]], [8.0, 11.0], 3, "GEYSER IN THE FLOOR - CANNONS FIRE AT TWO HEIGHTS"),
		_lv("BARNACLE ROW", "ocean", [[["hopper", 4], ["guard", 2], ["veteran", 1]], [["hopper", 6], ["burner", 2], ["guard", 2]], [["guard", 1], ["assassin", 4], ["veteran", 2]], [["assassin", 4], ["guard", 1], ["marksman", 2]]], [7.5, 10.5], 4),
		_lv("MAELSTROM", "ocean", [[["hopper", 3], ["assassin", 3], ["marksman", 1]], [["gunner", 3], ["assassin", 5], ["guard", 1]], [["gunner", 3], ["assassin", 4], ["marksman", 2]], [["assassin", 5], ["burner", 1], ["marksman", 2]]], [7.5, 10.5], 4),
		_lv("DAVY'S LOCKER", "ocean", [[["hopper", 4], ["assassin", 3], ["marksman", 1]], [["hopper", 5], ["assassin", 5], ["guard", 1]], [["gunner", 2], ["assassin", 3], ["marksman", 2], ["brute", 1]], [["hopper", 5], ["assassin", 4], ["brute", 1]]], [7.0, 10.0], 4),
		_lv("DROWNED GENERAL", "ocean", [[["guard", 2], ["assassin", 2], ["veteran", 1]], [["gunner", 2], ["assassin", 3], ["brute", 1]], [["boss_general", 1], ["guard", 1], ["assassin", 3], ["juggernaut", 1]]], [7.0, 10.0], 4),
		# ---------------- DUNIA 9: STAR STATION (space)
		_lv("DOCK 7", "space", [[["hopper", 4], ["assassin", 2], ["marksman", 2]], [["burner", 1], ["assassin", 4], ["sniper", 4]], [["hopper", 5], ["assassin", 3], ["veteran", 1], ["marksman", 2]]], [7.5, 10.5], 3, "PORTALS ON THE FLOOR - LIFT IN THE MIDDLE TO THE TOP"),
		_lv("SOLAR FLARE", "space", [[["gunner", 3], ["assassin", 2], ["sniper", 2]], [["hopper", 5], ["burner", 2], ["sniper", 3]], [["gunner", 3], ["marksman", 3], ["brute", 1]], [["hopper", 4], ["assassin", 2], ["sniper", 3]]], [7.0, 10.0], 4),
		_lv("GRAVITY WELL", "space", [[["hopper", 4], ["gunner", 2], ["assassin", 3]], [["hopper", 5], ["sniper", 3], ["assassin", 3]], [["hopper", 5], ["sniper", 3], ["marksman", 2]], [["assassin", 3], ["marksman", 2], ["juggernaut", 1]]], [7.0, 10.0], 4),
		_lv("DARK MATTER", "space", [[["assassin", 2], ["veteran", 2], ["marksman", 2]], [["hopper", 6], ["assassin", 4], ["burner", 1], ["veteran", 1]], [["hopper", 6], ["gunner", 3], ["veteran", 1], ["juggernaut", 1]], [["assassin", 4], ["sniper", 4], ["burner", 1], ["veteran", 1]]], [6.5, 9.5], 4),
		_lv("STAR VAMPIRE", "space", [[["gunner", 2], ["assassin", 2], ["marksman", 2]], [["assassin", 2], ["marksman", 1], ["juggernaut", 1]], [["boss_vamp", 1], ["sniper", 2], ["marksman", 1], ["juggernaut", 1]]], [6.5, 9.5], 4),
		# ---------------- DUNIA 10: IRON FOUNDRY (factory)
		_lv("MOLTEN CASTING", "factory", [[["guard", 2], ["veteran", 2], ["marksman", 1]], [["hopper", 2], ["guard", 3], ["marksman", 2]], [["burner", 2], ["veteran", 2], ["marksman", 2]], [["guard", 2], ["assassin", 2], ["veteran", 2]]], [7.0, 9.5], 3, "CONVEYORS DRAG YOU TO THE SAW - FLYING SAW UNDER THE CATWALK"),
		_lv("PRESS FLOOR", "factory", [[["hopper", 2], ["veteran", 2], ["marksman", 2]], [["veteran", 2], ["marksman", 2], ["brute", 1]], [["burner", 2], ["guard", 3], ["veteran", 3]], [["assassin", 1], ["guard", 4], ["veteran", 3]]], [6.5, 9.0], 4),
		_lv("COOLING TOWER", "factory", [[["hopper", 2], ["guard", 3], ["veteran", 2]], [["assassin", 3], ["guard", 4], ["juggernaut", 1]], [["burner", 2], ["guard", 3], ["brute", 1], ["juggernaut", 1]], [["veteran", 3], ["marksman", 2], ["juggernaut", 1]]], [6.5, 9.0], 4),
		_lv("MELTDOWN", "factory", [[["assassin", 1], ["veteran", 3], ["marksman", 2]], [["gunner", 1], ["guard", 3], ["veteran", 3], ["marksman", 2]], [["gunner", 3], ["guard", 3], ["brute", 1], ["juggernaut", 1]], [["burner", 3], ["veteran", 2], ["marksman", 2], ["brute", 1]]], [6.0, 8.5], 4),
		_lv("THE FOREMAN", "factory", [[["burner", 2], ["veteran", 2], ["marksman", 1]], [["burner", 3], ["assassin", 1], ["marksman", 2]], [["boss_foreman", 1], ["burner", 2], ["guard", 3], ["brute", 1]]], [6.0, 8.5], 4),
	]


## CHAPTER 3 "LAST SIEGE" (level 101-150 = level 1-50 di chapter ini). Map: varian Chapter 3.
static func _levels_ch3() -> Array:
	return [
		# ======================================================================== CHAPTER 3: LAST SIEGE (level 101-150)
		# ---------------- DUNIA 1: GREEN FIELDS (earth)
		_lv("TOXIC DAWN", "earth", [[["hopper", 3], ["gunner", 3]], [["assassin", 2], ["guard", 2], ["sniper", 1]], [["gunner", 3], ["guard", 2], ["veteran", 1]]], [8.0, 12.0], 3, "ACID POOL: FALLING COSTS A HEART - RIDE THE MOVING BRIDGE"),
		_lv("SLUDGE BRIDGE", "earth", [[["gunner", 2], ["guard", 2], ["marksman", 1]], [["sniper", 2], ["veteran", 2], ["marksman", 1]], [["guard", 2], ["veteran", 2], ["brute", 1]]], [8.0, 12.0], 3),
		_lv("BLIGHT FIELD", "earth", [[["gunner", 3], ["guard", 2], ["marksman", 1]], [["hopper", 3], ["sniper", 2], ["veteran", 2]], [["gunner", 3], ["assassin", 2], ["veteran", 2]]], [8.0, 11.0], 3),
		_lv("ROT PATH", "earth", [[["hopper", 1], ["gunner", 3], ["guard", 3]], [["gunner", 3], ["guard", 2], ["marksman", 2]], [["gunner", 4], ["veteran", 2], ["marksman", 2]]], [7.5, 11.0], 4),
		_lv("FIELD MARSHAL", "earth", [[["gunner", 2], ["guard", 2], ["veteran", 1]], [["boss_marshal", 1], ["sniper", 2], ["assassin", 2], ["marksman", 1]]], [7.5, 11.0], 4),
		# ---------------- DUNIA 2: CANOPY (jungle)
		_lv("THORN WEAVE", "jungle", [[["hopper", 3], ["assassin", 3]], [["assassin", 3], ["veteran", 1], ["marksman", 1]], [["hopper", 3], ["assassin", 3], ["sniper", 2]]], [8.0, 12.0], 3, "THORNS IN THE MIDDLE - CROSS ON THE SLIDING LOG"),
		_lv("NIGHT BLOOM", "jungle", [[["hopper", 3], ["assassin", 2], ["burner", 2]], [["assassin", 2], ["burner", 3], ["brute", 1]], [["burner", 2], ["sniper", 3], ["brute", 1]]], [8.0, 11.0], 3),
		_lv("PREDATOR'S DEN", "jungle", [[["burner", 4], ["veteran", 1], ["marksman", 1]], [["assassin", 4], ["sniper", 2], ["marksman", 1]], [["hopper", 5], ["burner", 3], ["sniper", 2]]], [7.5, 11.0], 4),
		_lv("BRAMBLE KING", "jungle", [[["hopper", 4], ["burner", 3], ["sniper", 2]], [["hopper", 4], ["assassin", 4], ["sniper", 2]], [["hopper", 6], ["brute", 1], ["juggernaut", 1]]], [7.5, 10.5], 4),
		_lv("ELDER WARDEN", "jungle", [[["hopper", 4], ["assassin", 2], ["marksman", 1]], [["boss_elder", 1], ["burner", 1], ["sniper", 2], ["juggernaut", 1]]], [7.5, 10.5], 4),
		# ---------------- DUNIA 3: FROZEN PASS (snow)
		_lv("WHITE NIGHT", "snow", [[["sniper", 2], ["veteran", 2], ["marksman", 1]], [["assassin", 1], ["veteran", 1], ["marksman", 2]], [["assassin", 2], ["guard", 3], ["marksman", 2]]], [8.0, 11.0], 3, "THIN ICE IN THE MIDDLE BREAKS - THE FLOES DRIFT"),
		_lv("SHATTERED ICE", "snow", [[["sniper", 3], ["assassin", 2], ["guard", 2]], [["sniper", 3], ["marksman", 2], ["brute", 1]], [["assassin", 2], ["marksman", 3], ["brute", 1]]], [7.5, 11.0], 3),
		_lv("FROST BITE", "snow", [[["gunner", 2], ["sniper", 3], ["marksman", 2]], [["sniper", 3], ["guard", 3], ["marksman", 2]], [["guard", 3], ["sniper", 4], ["juggernaut", 1]]], [7.5, 10.5], 4),
		_lv("ABSOLUTE ZERO", "snow", [[["sniper", 2], ["veteran", 2], ["marksman", 1]], [["gunner", 1], ["guard", 4], ["brute", 1]], [["sniper", 2], ["marksman", 2], ["juggernaut", 1]], [["sniper", 2], ["marksman", 2], ["brute", 1]]], [7.0, 10.5], 4),
		_lv("FROST EMPEROR", "snow", [[["gunner", 1], ["sniper", 4]], [["gunner", 2], ["guard", 2], ["marksman", 1]], [["boss_emperor", 1], ["sniper", 2], ["veteran", 2], ["marksman", 1]]], [7.0, 10.5], 4),
		# ---------------- DUNIA 4: DUNE RUINS (desert)
		_lv("QUICKSAND", "desert", [[["assassin", 3], ["veteran", 1], ["marksman", 1]], [["rusher", 4], ["hopper", 3], ["assassin", 3]], [["rusher", 4], ["assassin", 3], ["burner", 3]]], [7.5, 10.5], 3, "QUICKSAND IN THE CANYON - STONE BRIDGES CRUMBLE"),
		_lv("TOMB ROBBERS", "desert", [[["rusher", 4], ["assassin", 3], ["burner", 2]], [["rusher", 6], ["assassin", 4], ["veteran", 1]], [["rusher", 6], ["hopper", 3], ["assassin", 4]]], [7.5, 10.5], 4),
		_lv("SCORCH NOON", "desert", [[["rusher", 3], ["burner", 2], ["assassin", 2]], [["assassin", 3], ["burner", 2], ["juggernaut", 1]], [["rusher", 4], ["burner", 3], ["assassin", 3]], [["hopper", 3], ["assassin", 3], ["juggernaut", 1]]], [7.0, 10.0], 4),
		_lv("SAND DEVILS", "desert", [[["rusher", 4], ["hopper", 3], ["burner", 2]], [["assassin", 3], ["burner", 3], ["brute", 1]], [["rusher", 5], ["hopper", 3], ["assassin", 4]], [["hopper", 3], ["burner", 3], ["assassin", 3]]], [7.0, 10.0], 4),
		_lv("SANDSTORM SULTAN", "desert", [[["rusher", 4], ["burner", 3]], [["hopper", 2], ["assassin", 1], ["juggernaut", 1]], [["boss_sultan", 1], ["rusher", 4], ["hopper", 3], ["assassin", 2]]], [7.0, 10.0], 4),
		# ---------------- DUNIA 5: THORN SAVANNA (safari)
		_lv("BONE YARD", "safari", [[["hopper", 3], ["assassin", 2], ["veteran", 2]], [["hopper", 5], ["sniper", 1], ["veteran", 3]], [["rusher", 4], ["assassin", 3], ["veteran", 3]]], [7.5, 10.5], 3, "LONG SPIKE LANES AND FAST PLATFORMS - KEEP MOVING"),
		_lv("VULTURE CIRCLE", "safari", [[["rusher", 3], ["assassin", 2], ["marksman", 2]], [["hopper", 4], ["veteran", 2], ["brute", 1]], [["assassin", 2], ["veteran", 2], ["brute", 1]], [["rusher", 4], ["hopper", 4], ["brute", 1]]], [7.0, 10.5], 4),
		_lv("LAST WATERHOLE", "safari", [[["assassin", 2], ["veteran", 2], ["marksman", 1]], [["rusher", 4], ["hopper", 5], ["assassin", 3]], [["hopper", 5], ["veteran", 2], ["juggernaut", 1]], [["hopper", 4], ["assassin", 3], ["brute", 1]]], [7.0, 10.0], 4),
		_lv("APEX HUNT", "safari", [[["hopper", 4], ["assassin", 3], ["marksman", 1]], [["assassin", 4], ["veteran", 3], ["marksman", 1]], [["veteran", 3], ["marksman", 1], ["brute", 2]], [["assassin", 4], ["brute", 1], ["juggernaut", 1]]], [6.5, 10.0], 4),
		_lv("KING OF THORNS", "safari", [[["rusher", 2], ["hopper", 3], ["assassin", 2]], [["rusher", 3], ["hopper", 3], ["brute", 1]], [["boss_thornking", 1], ["rusher", 3], ["veteran", 2], ["brute", 1]]], [6.5, 10.0], 4),
		# ---------------- DUNIA 6: INFERNO (hell)
		_lv("BLACK FLAME", "hell", [[["assassin", 1], ["burner", 3], ["veteran", 2]], [["burner", 4], ["veteran", 2], ["marksman", 1]], [["burner", 4], ["sniper", 3], ["marksman", 2]]], [7.0, 10.0], 3, "A STONE PILLAR IN THE LAVA - STAIRS OF PLATFORMS TO THE TOP"),
		_lv("BURNING CAGE", "hell", [[["burner", 2], ["sniper", 2], ["marksman", 1]], [["burner", 4], ["veteran", 2], ["marksman", 1]], [["hopper", 4], ["veteran", 2], ["marksman", 2]], [["burner", 3], ["veteran", 2], ["brute", 1]]], [7.0, 10.0], 4),
		_lv("LAVA TIDE", "hell", [[["burner", 4], ["sniper", 1], ["marksman", 1]], [["hopper", 3], ["burner", 4], ["veteran", 2]], [["burner", 4], ["brute", 1], ["juggernaut", 1]], [["burner", 4], ["marksman", 2], ["brute", 1]]], [6.5, 9.5], 4),
		_lv("DEMON GATE", "hell", [[["burner", 4], ["sniper", 2], ["marksman", 1]], [["burner", 4], ["veteran", 2], ["juggernaut", 1]], [["burner", 3], ["veteran", 2], ["brute", 1], ["juggernaut", 1]], [["sniper", 2], ["marksman", 2], ["brute", 2]]], [6.5, 9.5], 4),
		_lv("ARCH DEMON", "hell", [[["hopper", 1], ["burner", 4], ["sniper", 1]], [["burner", 1], ["brute", 1], ["juggernaut", 1]], [["boss_archdemon", 1], ["burner", 3], ["assassin", 1], ["brute", 1]]], [6.5, 9.5], 4),
		# ---------------- DUNIA 7: ZIGGURAT (temple)
		_lv("DARK DESCENT", "temple", [[["sniper", 2], ["assassin", 2], ["veteran", 1]], [["sniper", 2], ["guard", 2], ["marksman", 2]], [["assassin", 2], ["veteran", 2], ["marksman", 2]], [["sniper", 2], ["veteran", 2], ["marksman", 2]]], [7.0, 10.0], 3, "A VOID PIT AROUND THE STAIRS - SPIKES AND ARROWS ON THE LEDGES"),
		_lv("SERPENT TONGUE", "temple", [[["assassin", 2], ["sniper", 2], ["veteran", 2]], [["gunner", 2], ["veteran", 3], ["marksman", 2]], [["assassin", 4], ["marksman", 2], ["brute", 1]], [["gunner", 1], ["sniper", 3], ["veteran", 3]]], [6.5, 9.5], 4),
		_lv("COILED TRIAL", "temple", [[["sniper", 2], ["veteran", 2], ["marksman", 2]], [["sniper", 3], ["assassin", 3], ["marksman", 2]], [["sniper", 2], ["veteran", 2], ["marksman", 2], ["brute", 1]], [["gunner", 2], ["assassin", 4], ["sniper", 4]]], [6.5, 9.5], 4),
		_lv("FANG OF GODS", "temple", [[["assassin", 3], ["sniper", 3], ["guard", 2]], [["gunner", 2], ["veteran", 2], ["marksman", 2], ["juggernaut", 1]], [["gunner", 1], ["sniper", 4], ["guard", 2], ["veteran", 3]], [["gunner", 3], ["guard", 2], ["sniper", 3], ["marksman", 2]]], [6.0, 9.0], 4),
		_lv("SERPENT GOD", "temple", [[["sniper", 2], ["veteran", 1], ["marksman", 1]], [["guard", 2], ["assassin", 2], ["marksman", 2]], [["boss_serpent", 1], ["guard", 2], ["veteran", 2], ["marksman", 2]]], [6.0, 9.0], 4),
		# ---------------- DUNIA 8: SHIPWRECK BAY (ocean)
		_lv("TIDE BREAKER", "ocean", [[["hopper", 3], ["assassin", 2], ["guard", 2]], [["assassin", 3], ["guard", 3], ["marksman", 1]], [["guard", 4], ["veteran", 2], ["marksman", 1]], [["hopper", 4], ["gunner", 3], ["guard", 2]]], [7.0, 10.0], 3, "WIDE CHASM - GEYSERS AND ROTTEN PLANKS - CANNONS AT TWO HEIGHTS"),
		_lv("IRON TENTACLES", "ocean", [[["gunner", 3], ["assassin", 3], ["marksman", 1]], [["hopper", 4], ["gunner", 4], ["guard", 3]], [["gunner", 5], ["marksman", 2], ["brute", 1]], [["hopper", 4], ["gunner", 4], ["assassin", 3]]], [6.5, 9.5], 4),
		_lv("SIREN'S SONG", "ocean", [[["hopper", 4], ["gunner", 3], ["assassin", 2]], [["gunner", 4], ["assassin", 3], ["brute", 1]], [["hopper", 4], ["gunner", 3], ["guard", 3], ["assassin", 3]], [["hopper", 6], ["marksman", 1], ["brute", 2]]], [6.5, 9.5], 4),
		_lv("ABYSS GATE", "ocean", [[["gunner", 4], ["guard", 4], ["veteran", 1]], [["hopper", 6], ["veteran", 1], ["marksman", 1], ["brute", 2]], [["hopper", 5], ["assassin", 4], ["marksman", 1], ["brute", 1]], [["hopper", 4], ["gunner", 3], ["assassin", 3], ["brute", 1]]], [6.0, 9.0], 4),
		_lv("LEVIATHAN", "ocean", [[["hopper", 3], ["gunner", 3], ["guard", 2]], [["hopper", 4], ["gunner", 3], ["assassin", 3]], [["boss_leviathan", 1], ["gunner", 3], ["assassin", 3], ["brute", 1]]], [6.0, 9.0], 4),
		# ---------------- DUNIA 9: STAR STATION (space)
		_lv("REACTOR LEAK", "space", [[["sniper", 2], ["guard", 2], ["veteran", 1]], [["sniper", 3], ["burner", 2], ["assassin", 3]], [["burner", 2], ["assassin", 4], ["veteran", 2]], [["burner", 1], ["veteran", 2], ["marksman", 3]]], [6.5, 9.5], 3, "LIFTS CARRY YOU TO THE UPPER DECKS - PORTALS UP THERE"),
		_lv("PLASMA STORM", "space", [[["assassin", 3], ["guard", 1], ["marksman", 2]], [["sniper", 4], ["marksman", 2], ["brute", 1]], [["assassin", 4], ["guard", 2], ["sniper", 4]], [["veteran", 2], ["marksman", 3], ["brute", 1]]], [6.0, 9.0], 4),
		_lv("CRITICAL MASS", "space", [[["assassin", 3], ["guard", 2], ["marksman", 2]], [["burner", 1], ["assassin", 4], ["marksman", 2], ["brute", 1]], [["sniper", 3], ["assassin", 3], ["marksman", 2], ["brute", 1]], [["assassin", 2], ["marksman", 2], ["brute", 1], ["juggernaut", 1]]], [6.0, 9.0], 4),
		_lv("EVENT HORIZON", "space", [[["assassin", 4], ["guard", 2], ["veteran", 2]], [["sniper", 4], ["veteran", 2], ["marksman", 2], ["brute", 1]], [["burner", 3], ["marksman", 3], ["brute", 1], ["juggernaut", 1]], [["sniper", 3], ["guard", 2], ["assassin", 3], ["juggernaut", 1]]], [6.0, 8.5], 4),
		_lv("STAR DEVOURER", "space", [[["assassin", 3], ["veteran", 1], ["marksman", 2]], [["sniper", 3], ["guard", 2], ["juggernaut", 1]], [["boss_devourer", 1], ["assassin", 3], ["veteran", 2], ["juggernaut", 1]]], [6.0, 8.5], 4),
		# ---------------- DUNIA 10: IRON FOUNDRY (factory)
		_lv("FINAL ASSEMBLY", "factory", [[["assassin", 2], ["burner", 2], ["veteran", 1]], [["guard", 3], ["assassin", 2], ["marksman", 2]], [["guard", 3], ["burner", 3], ["assassin", 3]], [["burner", 1], ["guard", 3], ["veteran", 3]]], [6.0, 8.5], 3, "FASTER BELTS, WIDER SAW - AND A FLYING SAW IN THE MIDDLE"),
		_lv("SCRAP CRUSHER", "factory", [[["assassin", 2], ["veteran", 2], ["marksman", 2]], [["veteran", 2], ["marksman", 2], ["brute", 1]], [["guard", 2], ["veteran", 2], ["marksman", 2], ["brute", 1]], [["guard", 3], ["veteran", 3], ["marksman", 2]]], [6.0, 8.5], 4),
		_lv("OVERCLOCK", "factory", [[["assassin", 3], ["veteran", 2], ["marksman", 2]], [["guard", 3], ["marksman", 2], ["brute", 1], ["juggernaut", 1]], [["guard", 3], ["assassin", 3], ["marksman", 2], ["brute", 1]], [["guard", 2], ["veteran", 2], ["marksman", 2], ["juggernaut", 1]]], [6.0, 8.0], 4),
		_lv("SELF DESTRUCT", "factory", [[["burner", 1], ["veteran", 2], ["marksman", 2]], [["guard", 3], ["brute", 2], ["juggernaut", 1]], [["guard", 3], ["assassin", 2], ["brute", 1], ["juggernaut", 1]], [["guard", 3], ["assassin", 2], ["veteran", 2], ["juggernaut", 1]], [["burner", 1], ["veteran", 3], ["marksman", 3]]], [5.5, 8.0], 4),
		_lv("THE OMEGA CORE", "factory", [[["assassin", 2], ["guard", 2], ["veteran", 2]], [["burner", 3], ["marksman", 2], ["brute", 1]], [["boss_omega", 1], ["veteran", 2], ["marksman", 2], ["juggernaut", 1]]], [5.5, 8.0], 4),
	]


## CHAPTER 4 "DARK HORIZON" (level 151-200 = level 1-50 di chapter ini). Map: varian Chapter 4 (MapVariantsLate v3).
## Komposisi musuh dihitung dari anggaran ancaman Chapter 3 pada posisi yang sama (x1.06), lalu dibagi per wave dengan kurva naik;
## tiap dunia memakai musuh bertema dunia itu. Boss tiap dunia datang bersama pengawal di wave terakhir.
static func _levels_ch4() -> Array:
	return [
		# ======================================================================== CHAPTER 4: DARK HORIZON (level 151-200)
		# ---------------- DUNIA 1: GREEN FIELDS (earth)
		_lv("BLOOD DAWN", "earth", [[["gunner", 3], ["veteran", 1]], [["grunt", 4], ["hopper", 5]], [["sniper", 4], ["guard", 2]]], [7.5, 11.5], 3, "BOUNCE PADS AND SPIKES ON THE FLOOR - THE MOUND IS COVER"),
		_lv("SCARRED HILLS", "earth", [[["grunt", 4], ["veteran", 2]], [["veteran", 2], ["marksman", 3]], [["assassin", 5], ["marksman", 2]]], [7.5, 11.5], 3),
		_lv("IRON HARVEST", "earth", [[["hopper", 5], ["veteran", 2]], [["gunner", 5], ["veteran", 2]], [["grunt", 5], ["gunner", 3], ["veteran", 2]]], [7.5, 10.5], 3),
		_lv("WINDMILL SIEGE", "earth", [[["rusher", 4], ["guard", 4]], [["gunner", 3], ["guard", 3], ["veteran", 2]], [["grunt", 5], ["hopper", 4], ["sniper", 3]]], [7.0, 10.5], 4),
		_lv("IRON CONSUL", "earth", [[["assassin", 4], ["marksman", 2]], [["boss_consul", 1], ["hopper", 5], ["gunner", 2]]], [7.0, 10.5], 4),
		# ---------------- DUNIA 2: CANOPY (jungle)
		_lv("SPORE RAIN", "jungle", [[["sniper", 2], ["marksman", 2]], [["hopper", 6], ["assassin", 2]], [["hopper", 6], ["burner", 4]]], [7.5, 11.5], 3, "A VINE LIFT RISES TO THE CANOPY - SPIKES GUARD THE FLOOR"),
		_lv("ROOT MAZE", "jungle", [[["assassin", 3], ["burner", 3]], [["assassin", 3], ["veteran", 3]], [["hopper", 4], ["rusher", 5], ["assassin", 3]]], [7.5, 10.5], 3),
		_lv("FIREFLY HOLLOW", "jungle", [[["rusher", 7], ["veteran", 1]], [["rusher", 5], ["burner", 2], ["veteran", 2]], [["assassin", 2], ["veteran", 3], ["marksman", 3]]], [7.0, 10.5], 4),
		_lv("FANGED CANOPY", "jungle", [[["rusher", 5], ["gunner", 4]], [["hopper", 6], ["gunner", 2], ["veteran", 2]], [["hopper", 5], ["burner", 3], ["veteran", 3]]], [7.0, 10.0], 4),
		_lv("FUNGAL OVERMIND", "jungle", [[["sniper", 4], ["veteran", 2]], [["boss_overmind", 1], ["hopper", 4], ["assassin", 3]]], [7.0, 10.0], 4),
		# ---------------- DUNIA 3: FROZEN PASS (snow)
		_lv("AVALANCHE", "snow", [[["gunner", 3], ["guard", 2]], [["guard", 4], ["veteran", 2]], [["gunner", 3], ["guard", 2], ["veteran", 2]]], [7.5, 10.5], 3, "THE WHOLE FLOOR IS ICE - STOP EARLY OR YOU SLIDE"),
		_lv("DRIFT WALL", "snow", [[["sniper", 4], ["marksman", 2]], [["gunner", 4], ["sniper", 2], ["brute", 1]], [["gunner", 5], ["guard", 2], ["marksman", 2]]], [7.0, 10.5], 3),
		_lv("ICICLE FALLS", "snow", [[["guard", 3], ["veteran", 3]], [["gunner", 4], ["guard", 3], ["marksman", 2]], [["guard", 3], ["marksman", 3], ["juggernaut", 2]]], [7.0, 10.0], 4),
		_lv("GLASS CANYON", "snow", [[["marksman", 2], ["brute", 1]], [["assassin", 2], ["guard", 4]], [["gunner", 3], ["assassin", 2], ["sniper", 3]], [["sniper", 4], ["veteran", 2], ["brute", 1]]], [6.5, 10.0], 4),
		_lv("BLIZZARD MATRIARCH", "snow", [[["gunner", 2], ["assassin", 2]], [["gunner", 3], ["assassin", 3]], [["boss_matriarch", 1], ["sniper", 2], ["guard", 2], ["veteran", 3]]], [6.5, 10.0], 4),
		# ---------------- DUNIA 4: DUNE RUINS (desert)
		_lv("SCORPION NEST", "desert", [[["burner", 3], ["veteran", 2]], [["assassin", 4], ["veteran", 3]], [["hopper", 3], ["rusher", 5], ["burner", 4]]], [7.0, 10.0], 3, "CACTI ON THE SAND - THE STONE STEPS CRUMBLE"),
		_lv("HEAT HAZE", "desert", [[["veteran", 3], ["marksman", 2]], [["assassin", 3], ["burner", 2], ["veteran", 3]], [["burner", 3], ["marksman", 3], ["brute", 2]]], [7.0, 10.0], 4),
		_lv("CURSED SANDS", "desert", [[["assassin", 3], ["burner", 2]], [["rusher", 4], ["veteran", 3]], [["burner", 3], ["marksman", 2], ["juggernaut", 1]], [["hopper", 5], ["assassin", 2], ["burner", 4]]], [6.5, 9.5], 4),
		_lv("SPHINX GATE", "desert", [[["burner", 3], ["juggernaut", 1]], [["rusher", 4], ["assassin", 5]], [["hopper", 5], ["rusher", 4], ["burner", 3]], [["hopper", 6], ["burner", 3], ["marksman", 3]]], [6.5, 9.5], 4),
		_lv("TOMB SOVEREIGN", "desert", [[["hopper", 4], ["burner", 2]], [["hopper", 4], ["veteran", 2]], [["boss_sovereign", 1], ["hopper", 6], ["veteran", 3]]], [6.5, 9.5], 4),
		# ---------------- DUNIA 5: THORN SAVANNA (safari)
		_lv("BAOBAB SHADE", "safari", [[["hopper", 6], ["rusher", 5]], [["rusher", 5], ["gunner", 3], ["assassin", 3]], [["rusher", 7], ["assassin", 3], ["veteran", 2]]], [7.0, 10.0], 3, "SPIKE LANES - RIDE THE MOVING PLATFORMS TO THE BAOBAB"),
		_lv("HYENA PACK", "safari", [[["rusher", 4], ["assassin", 3]], [["gunner", 3], ["assassin", 4]], [["hopper", 6], ["marksman", 3]], [["assassin", 3], ["veteran", 2], ["brute", 2]]], [6.5, 10.0], 4),
		_lv("DRY RIVER", "safari", [[["gunner", 4], ["brute", 1]], [["assassin", 5], ["brute", 1]], [["gunner", 4], ["veteran", 2], ["brute", 1]], [["hopper", 6], ["rusher", 3], ["veteran", 3]]], [6.5, 9.5], 4),
		_lv("WARTHOG RUN", "safari", [[["hopper", 6], ["rusher", 4]], [["rusher", 3], ["gunner", 2], ["assassin", 4]], [["rusher", 4], ["veteran", 2], ["marksman", 3]], [["hopper", 6], ["rusher", 4], ["brute", 2]]], [6.0, 9.5], 4),
		_lv("VULTURE EMPRESS", "safari", [[["assassin", 2], ["brute", 1]], [["assassin", 3], ["veteran", 2]], [["boss_empress", 1], ["hopper", 1], ["rusher", 4], ["assassin", 4]]], [6.0, 9.5], 4),
		# ---------------- DUNIA 6: INFERNO (hell)
		_lv("EMBER RAIN", "hell", [[["sniper", 3], ["marksman", 3]], [["burner", 2], ["veteran", 2], ["marksman", 3]], [["assassin", 5], ["burner", 3], ["veteran", 2]]], [6.5, 9.5], 3, "LAVA ALL AROUND - FERRY PLATFORMS CARRY YOU ACROSS"),
		_lv("SCORCHED GATE", "hell", [[["veteran", 2], ["marksman", 2]], [["burner", 3], ["veteran", 3]], [["burner", 4], ["marksman", 2], ["brute", 1]], [["sniper", 4], ["veteran", 2], ["brute", 2]]], [6.5, 9.5], 4),
		_lv("COAL MINE", "hell", [[["veteran", 3], ["brute", 1]], [["burner", 3], ["marksman", 3]], [["burner", 4], ["sniper", 3], ["marksman", 2]], [["sniper", 4], ["veteran", 2], ["marksman", 3]]], [6.0, 9.0], 4),
		_lv("BLAZE WALK", "hell", [[["sniper", 3], ["brute", 2]], [["assassin", 3], ["burner", 3], ["brute", 1]], [["assassin", 3], ["sniper", 4], ["veteran", 2]], [["marksman", 3], ["brute", 2], ["juggernaut", 2]]], [6.0, 9.0], 4),
		_lv("ASH SERAPH", "hell", [[["burner", 2], ["veteran", 2]], [["burner", 2], ["sniper", 3]], [["boss_seraph", 1], ["burner", 2], ["sniper", 3], ["marksman", 2]]], [6.0, 9.0], 4),
		# ---------------- DUNIA 7: ZIGGURAT (temple)
		_lv("MOONLIT STEPS", "temple", [[["sniper", 2], ["marksman", 2]], [["sniper", 4], ["marksman", 2]], [["sniper", 3], ["guard", 2], ["veteran", 2]], [["sniper", 3], ["guard", 3], ["veteran", 2]]], [6.5, 9.5], 3, "PILLARS BLOCK BULLETS - ARROWS FLY AT TWO HEIGHTS"),
		_lv("SILENT HALL", "temple", [[["sniper", 4], ["guard", 2]], [["assassin", 3], ["guard", 4]], [["gunner", 4], ["assassin", 2], ["veteran", 3]], [["sniper", 4], ["marksman", 2], ["brute", 2]]], [6.0, 9.0], 4),
		_lv("STONE ORACLE", "temple", [[["guard", 3], ["marksman", 2]], [["assassin", 2], ["sniper", 3], ["veteran", 3]], [["sniper", 4], ["guard", 4], ["brute", 1]], [["assassin", 5], ["sniper", 3], ["marksman", 3]]], [6.0, 9.0], 4),
		_lv("ECLIPSE", "temple", [[["veteran", 4], ["brute", 1]], [["gunner", 5], ["marksman", 2], ["brute", 1]], [["assassin", 4], ["guard", 3], ["marksman", 3]], [["sniper", 4], ["veteran", 4], ["marksman", 3]]], [5.5, 8.5], 4),
		_lv("MOON ORACLE", "temple", [[["assassin", 2], ["veteran", 2]], [["guard", 3], ["veteran", 2]], [["boss_oracle", 1], ["gunner", 3], ["guard", 2], ["marksman", 3]]], [5.5, 8.5], 4),
		# ---------------- DUNIA 8: SHIPWRECK BAY (ocean)
		_lv("BARNACLE BAY", "ocean", [[["gunner", 3], ["marksman", 2]], [["hopper", 6], ["marksman", 2]], [["hopper", 6], ["gunner", 3], ["assassin", 2]], [["hopper", 4], ["gunner", 5], ["assassin", 3]]], [6.5, 9.5], 3, "GEYSERS LIFT YOU TO THE DECK - CANNONS FIRE AT TWO HEIGHTS"),
		_lv("ROTTEN HULL", "ocean", [[["assassin", 3], ["guard", 3]], [["hopper", 4], ["gunner", 3], ["assassin", 3]], [["hopper", 4], ["gunner", 5], ["guard", 3]], [["gunner", 5], ["veteran", 4], ["marksman", 2]]], [6.0, 9.0], 4),
		_lv("GHOST FLEET", "ocean", [[["assassin", 4], ["veteran", 2]], [["hopper", 5], ["veteran", 2], ["marksman", 2]], [["gunner", 5], ["marksman", 3], ["brute", 1]], [["gunner", 3], ["assassin", 5], ["guard", 4]]], [6.0, 9.0], 4),
		_lv("TIDAL FURY", "ocean", [[["hopper", 5], ["marksman", 3]], [["hopper", 5], ["veteran", 2], ["brute", 2]], [["gunner", 3], ["guard", 4], ["marksman", 3]], [["gunner", 4], ["assassin", 4], ["guard", 4]]], [5.5, 8.5], 4),
		_lv("KRAKEN ADMIRAL", "ocean", [[["gunner", 4], ["guard", 2]], [["hopper", 4], ["assassin", 5]], [["boss_admiral", 1], ["guard", 4], ["veteran", 2], ["brute", 2]]], [5.5, 8.5], 4),
		# ---------------- DUNIA 9: STAR STATION (space)
		_lv("DEBRIS FIELD", "space", [[["sniper", 3], ["marksman", 2]], [["hopper", 6], ["sniper", 3]], [["assassin", 3], ["veteran", 2], ["marksman", 2]], [["assassin", 5], ["burner", 3], ["marksman", 2]]], [6.0, 9.0], 3, "LIFTS AND PORTALS ON THE UPPER DECKS - WATCH BOTH SIDES"),
		_lv("COMET TAIL", "space", [[["assassin", 4], ["sniper", 2]], [["hopper", 5], ["assassin", 3], ["veteran", 2]], [["hopper", 5], ["assassin", 4], ["burner", 3]], [["hopper", 5], ["assassin", 4], ["marksman", 3]]], [5.5, 8.5], 4),
		_lv("ORBIT BREAK", "space", [[["assassin", 3], ["brute", 2]], [["burner", 3], ["veteran", 2], ["marksman", 2]], [["assassin", 5], ["marksman", 3], ["brute", 1]], [["sniper", 4], ["veteran", 3], ["marksman", 3]]], [5.5, 8.5], 4),
		_lv("SOLAR WIND", "space", [[["assassin", 5], ["marksman", 2]], [["assassin", 4], ["sniper", 4], ["brute", 1]], [["assassin", 5], ["veteran", 2], ["juggernaut", 2]], [["hopper", 6], ["assassin", 3], ["marksman", 3]]], [5.5, 8.0], 4),
		_lv("VOID REAPER", "space", [[["assassin", 3], ["veteran", 2]], [["assassin", 3], ["marksman", 3]], [["boss_reaper", 1], ["burner", 4], ["sniper", 2], ["veteran", 3]]], [5.5, 8.0], 4),
		# ---------------- DUNIA 10: IRON FOUNDRY (factory)
		_lv("SCRAP HEAP", "factory", [[["burner", 3], ["marksman", 2]], [["gunner", 4], ["guard", 3]], [["guard", 2], ["veteran", 2], ["marksman", 3]], [["burner", 3], ["guard", 3], ["marksman", 3]]], [5.5, 8.0], 3, "BELTS DRAG YOU TOWARD THE MOLTEN PIT - A SAW GUARDS THE BRIDGE"),
		_lv("BLAST FURNACE", "factory", [[["assassin", 3], ["guard", 3]], [["assassin", 3], ["guard", 3], ["brute", 1]], [["assassin", 4], ["veteran", 2], ["marksman", 2]], [["assassin", 5], ["guard", 3], ["marksman", 3]]], [5.5, 8.0], 4),
		_lv("STEEL RAIN", "factory", [[["guard", 2], ["veteran", 4]], [["gunner", 3], ["guard", 2], ["juggernaut", 2]], [["assassin", 4], ["veteran", 2], ["marksman", 3]], [["burner", 4], ["marksman", 3], ["brute", 2]]], [5.5, 7.5], 4),
		_lv("OVERLOAD", "factory", [[["burner", 3], ["juggernaut", 1]], [["burner", 3], ["veteran", 3]], [["burner", 3], ["guard", 3], ["veteran", 2]], [["burner", 3], ["guard", 4], ["marksman", 3]], [["burner", 4], ["marksman", 3], ["juggernaut", 2]]], [5.0, 7.5], 4),
		_lv("CHROME COLOSSUS", "factory", [[["burner", 3], ["marksman", 2]], [["veteran", 3], ["marksman", 2]], [["boss_colossus", 1], ["guard", 3], ["veteran", 3], ["marksman", 2]]], [5.0, 7.5], 4),
	]


## CHAPTER 5 "NO MERCY" (level 201-250 = level 1-50 di chapter ini). Map: varian Chapter 5 (MapVariantsLate v4).
## Komposisi musuh dihitung dari anggaran ancaman Chapter 3 pada posisi yang sama (x1.12), lalu dibagi per wave dengan kurva naik;
## tiap dunia memakai musuh bertema dunia itu. Boss tiap dunia datang bersama pengawal di wave terakhir.
static func _levels_ch5() -> Array:
	return [
		# ======================================================================== CHAPTER 5: NO MERCY (level 201-250)
		# ---------------- DUNIA 1: GREEN FIELDS (earth)
		_lv("ROLLING THUNDER", "earth", [[["assassin", 2], ["veteran", 2]], [["gunner", 4], ["veteran", 2]], [["gunner", 5], ["guard", 2]]], [7.0, 11.0], 3, "FLOATING ISLANDS OVER THE STORM - FALLING COSTS A HEART"),
		_lv("BROKEN SKY", "earth", [[["assassin", 4], ["marksman", 1]], [["hopper", 6], ["gunner", 3]], [["gunner", 2], ["guard", 3], ["veteran", 2]]], [7.0, 11.0], 3),
		_lv("SCORCHED EARTH", "earth", [[["gunner", 4], ["veteran", 2]], [["gunner", 4], ["sniper", 4]], [["grunt", 4], ["gunner", 4], ["veteran", 2]]], [7.0, 10.0], 3),
		_lv("THE LONG MARCH", "earth", [[["hopper", 6], ["gunner", 4]], [["grunt", 5], ["rusher", 3], ["gunner", 4]], [["grunt", 5], ["hopper", 5], ["veteran", 2]]], [6.5, 10.0], 4),
		_lv("THE HARBINGER", "earth", [[["sniper", 4], ["veteran", 2]], [["boss_harbinger", 1], ["hopper", 5], ["veteran", 2]]], [6.5, 10.0], 4),
		# ---------------- DUNIA 2: CANOPY (jungle)
		_lv("OVERGROWTH", "jungle", [[["hopper", 3], ["burner", 3]], [["burner", 4], ["veteran", 2]], [["hopper", 6], ["veteran", 3]]], [7.0, 11.0], 3, "A SPIKE CARPET ON THE FLOOR - CROSS ON THE CRUMBLING LOGS"),
		_lv("MOSS CRYPT", "jungle", [[["rusher", 5], ["veteran", 2]], [["sniper", 4], ["marksman", 2]], [["assassin", 3], ["sniper", 4], ["brute", 1]]], [7.0, 10.0], 3),
		_lv("STRANGLEHOLD", "jungle", [[["hopper", 6], ["veteran", 2]], [["hopper", 5], ["assassin", 3], ["sniper", 2]], [["assassin", 4], ["marksman", 2], ["brute", 2]]], [6.5, 10.0], 4),
		_lv("WITHERING GLADE", "jungle", [[["gunner", 3], ["assassin", 4]], [["burner", 3], ["sniper", 3], ["marksman", 2]], [["hopper", 6], ["assassin", 3], ["veteran", 3]]], [6.5, 9.5], 4),
		_lv("WORLD ROOT", "jungle", [[["hopper", 5], ["marksman", 3]], [["boss_worldroot", 1], ["rusher", 6], ["assassin", 2]]], [6.5, 9.5], 4),
		# ---------------- DUNIA 3: FROZEN PASS (snow)
		_lv("AURORA FALL", "snow", [[["veteran", 2], ["marksman", 2]], [["sniper", 3], ["marksman", 3]], [["gunner", 4], ["guard", 2], ["marksman", 2]]], [7.0, 10.0], 4, "THIN ICE SHEETS OVER THE LAKE - HOP THE FLOES"),
		_lv("FROZEN LAKE", "snow", [[["guard", 3], ["veteran", 3]], [["gunner", 3], ["sniper", 2], ["veteran", 3]], [["gunner", 3], ["sniper", 4], ["marksman", 2]]], [6.5, 10.0], 4),
		_lv("BLACK ICE", "snow", [[["sniper", 3], ["guard", 2], ["veteran", 2]], [["assassin", 3], ["sniper", 4], ["veteran", 2]], [["gunner", 5], ["guard", 3], ["veteran", 3]]], [6.5, 9.5], 4),
		_lv("SILENT BLIZZARD", "snow", [[["gunner", 4], ["brute", 1]], [["sniper", 3], ["marksman", 3]], [["assassin", 2], ["sniper", 3], ["marksman", 2]], [["gunner", 3], ["sniper", 4], ["veteran", 2]]], [6.0, 9.5], 4),
		_lv("GLACIAL TYRANT", "snow", [[["sniper", 2], ["veteran", 2]], [["sniper", 3], ["marksman", 2]], [["boss_tyrant_ice", 1], ["gunner", 4], ["sniper", 3], ["marksman", 1]]], [6.0, 9.5], 4),
		# ---------------- DUNIA 4: DUNE RUINS (desert)
		_lv("BURIED KINGS", "desert", [[["burner", 4], ["marksman", 1]], [["assassin", 4], ["burner", 3], ["veteran", 1]], [["rusher", 5], ["burner", 3], ["marksman", 2]]], [6.5, 9.5], 4, "A CRUMBLING BRIDGE OVER QUICKSAND - ARROWS FROM THE WALLS"),
		_lv("GOLDEN VAULT", "desert", [[["rusher", 7], ["assassin", 3]], [["hopper", 6], ["assassin", 3], ["marksman", 2]], [["hopper", 6], ["rusher", 2], ["assassin", 4]]], [6.5, 9.5], 4),
		_lv("TRAPPED TOMB", "desert", [[["hopper", 3], ["juggernaut", 1]], [["burner", 2], ["veteran", 2]], [["hopper", 6], ["brute", 1]], [["hopper", 5], ["rusher", 7]], [["rusher", 3], ["assassin", 4], ["veteran", 2]]], [6.0, 9.0], 4),
		_lv("SAND CURSE", "desert", [[["rusher", 3], ["juggernaut", 1]], [["burner", 3], ["marksman", 2]], [["assassin", 5], ["brute", 1]], [["hopper", 6], ["rusher", 3], ["marksman", 2]], [["hopper", 5], ["rusher", 4], ["marksman", 3]]], [6.0, 9.0], 4),
		_lv("MUMMY LORD", "desert", [[["rusher", 4], ["assassin", 2]], [["rusher", 5], ["marksman", 2]], [["boss_mummy", 1], ["assassin", 3], ["marksman", 2], ["juggernaut", 1]]], [6.0, 9.0], 4),
		# ---------------- DUNIA 5: THORN SAVANNA (safari)
		_lv("CARRION HILL", "safari", [[["hopper", 6], ["rusher", 5]], [["rusher", 6], ["assassin", 3], ["marksman", 2]], [["hopper", 4], ["rusher", 5], ["gunner", 3]]], [6.5, 9.5], 4, "THE FLOOR IS A SPIKE FIELD - HOP THE MOVING PLATFORMS"),
		_lv("CIRCLING WINGS", "safari", [[["rusher", 4], ["gunner", 3]], [["gunner", 5], ["marksman", 1]], [["gunner", 3], ["assassin", 2], ["veteran", 3]], [["hopper", 5], ["assassin", 4], ["veteran", 2]]], [6.0, 9.5], 4),
		_lv("BLEACHED BONES", "safari", [[["hopper", 4], ["rusher", 3]], [["assassin", 3], ["veteran", 2]], [["hopper", 6], ["marksman", 2]], [["rusher", 6], ["assassin", 3], ["veteran", 1]], [["rusher", 3], ["veteran", 3], ["brute", 2]]], [6.0, 9.0], 4),
		_lv("APEX TRAIL", "safari", [[["hopper", 5], ["rusher", 2]], [["hopper", 3], ["assassin", 4]], [["rusher", 5], ["assassin", 5]], [["rusher", 3], ["assassin", 3], ["brute", 2]], [["hopper", 2], ["rusher", 7], ["veteran", 3]]], [5.5, 9.0], 4),
		_lv("APEX PREDATOR", "safari", [[["gunner", 4], ["veteran", 1]], [["hopper", 5], ["assassin", 3]], [["boss_apex", 1], ["rusher", 4], ["assassin", 3], ["veteran", 2]]], [5.5, 9.0], 4),
		# ---------------- DUNIA 6: INFERNO (hell)
		_lv("BRAND OF FIRE", "hell", [[["assassin", 5], ["burner", 3]], [["burner", 3], ["veteran", 3], ["marksman", 2]], [["assassin", 3], ["veteran", 4], ["marksman", 2]]], [6.0, 9.0], 4, "A BRIDGE OVER THE LAVA - ARROWS FLY FROM THE WALLS"),
		_lv("CHAIN OF SOULS", "hell", [[["marksman", 3], ["brute", 1]], [["marksman", 3], ["brute", 1]], [["assassin", 3], ["burner", 3], ["sniper", 3]], [["burner", 3], ["sniper", 4], ["marksman", 3]]], [6.0, 9.0], 4),
		_lv("MOLTEN CHOIR", "hell", [[["burner", 2], ["juggernaut", 1]], [["assassin", 3], ["veteran", 2]], [["veteran", 3], ["marksman", 2]], [["veteran", 2], ["marksman", 3], ["juggernaut", 1]], [["burner", 4], ["sniper", 3], ["marksman", 2]]], [5.5, 8.5], 4),
		_lv("FURNACE OF SINS", "hell", [[["burner", 1], ["sniper", 3]], [["marksman", 3], ["juggernaut", 1]], [["brute", 2], ["juggernaut", 2]], [["assassin", 4], ["veteran", 2], ["marksman", 2]], [["assassin", 2], ["veteran", 3], ["juggernaut", 2]]], [5.5, 8.5], 4),
		_lv("THE OVERFIEND", "hell", [[["burner", 2], ["marksman", 2]], [["burner", 3], ["veteran", 2]], [["boss_overfiend", 1], ["burner", 2], ["veteran", 2], ["marksman", 3]]], [5.5, 8.5], 4),
		# ---------------- DUNIA 7: ZIGGURAT (temple)
		_lv("SKULL STAIRS", "temple", [[["assassin", 3], ["veteran", 2]], [["assassin", 5], ["veteran", 1]], [["sniper", 3], ["guard", 4], ["marksman", 1]], [["gunner", 3], ["sniper", 3], ["guard", 4]]], [6.0, 9.0], 4, "THE THRONE ISLAND IN THE VOID - LEAP THE GAP"),
		_lv("BONE CHOIR", "temple", [[["sniper", 4], ["veteran", 1]], [["assassin", 4], ["sniper", 3], ["marksman", 1]], [["gunner", 4], ["sniper", 2], ["marksman", 3]], [["assassin", 5], ["sniper", 3], ["veteran", 3]]], [5.5, 8.5], 4),
		_lv("ROYAL CRYPT", "temple", [[["gunner", 4], ["veteran", 1]], [["assassin", 4], ["veteran", 2]], [["sniper", 3], ["guard", 3], ["brute", 1]], [["assassin", 5], ["guard", 2], ["marksman", 2]], [["gunner", 4], ["sniper", 4], ["marksman", 2]]], [5.5, 8.5], 4),
		_lv("FALLEN IDOL", "temple", [[["gunner", 4], ["brute", 1]], [["sniper", 3], ["marksman", 3]], [["gunner", 4], ["guard", 3], ["marksman", 1]], [["sniper", 4], ["veteran", 2], ["marksman", 3]], [["gunner", 5], ["veteran", 3], ["marksman", 3]]], [5.0, 8.0], 4),
		_lv("SKULL DEITY", "temple", [[["gunner", 3], ["veteran", 2]], [["sniper", 3], ["brute", 2]], [["boss_deity", 1], ["gunner", 2], ["sniper", 4], ["guard", 3]]], [5.0, 8.0], 4),
		# ---------------- DUNIA 8: SHIPWRECK BAY (ocean)
		_lv("HARBOR SIREN", "ocean", [[["gunner", 3], ["assassin", 3]], [["assassin", 3], ["marksman", 3]], [["hopper", 3], ["assassin", 4], ["marksman", 2]], [["hopper", 3], ["gunner", 4], ["assassin", 5]]], [6.0, 9.0], 4, "WAVES BETWEEN THE DOCKS - FERRIES AND A GEYSER IN THE MIDDLE"),
		_lv("BROKEN MAST", "ocean", [[["assassin", 3], ["veteran", 3]], [["hopper", 4], ["guard", 3], ["marksman", 2]], [["gunner", 3], ["assassin", 4], ["marksman", 3]], [["assassin", 5], ["marksman", 3], ["brute", 2]]], [5.5, 8.5], 4),
		_lv("DROWNED BELLS", "ocean", [[["marksman", 2], ["brute", 1]], [["hopper", 6], ["veteran", 2]], [["gunner", 3], ["assassin", 3], ["guard", 2]], [["hopper", 5], ["gunner", 3], ["veteran", 3]], [["gunner", 5], ["assassin", 5], ["brute", 1]]], [5.5, 8.5], 4),
		_lv("CRIMSON TIDE", "ocean", [[["guard", 3], ["brute", 1]], [["assassin", 3], ["veteran", 3]], [["hopper", 5], ["veteran", 2], ["marksman", 2]], [["hopper", 6], ["assassin", 4], ["guard", 2]], [["gunner", 4], ["guard", 3], ["veteran", 4]]], [5.0, 8.0], 4),
		_lv("ABYSS QUEEN", "ocean", [[["hopper", 6], ["veteran", 2]], [["assassin", 4], ["guard", 3]], [["boss_abyss", 1], ["hopper", 4], ["gunner", 3], ["marksman", 2]]], [5.0, 8.0], 4),
		# ---------------- DUNIA 9: STAR STATION (space)
		_lv("WARP FRACTURE", "space", [[["hopper", 4], ["assassin", 4]], [["assassin", 5], ["sniper", 3]], [["hopper", 4], ["veteran", 2], ["marksman", 3]], [["assassin", 3], ["sniper", 4], ["veteran", 3]]], [5.5, 8.5], 4, "FLOOR PORTALS LINK BOTH SIDES - A LIFT CARRIES YOU UP"),
		_lv("NEXUS GATE", "space", [[["burner", 4], ["veteran", 2]], [["sniper", 2], ["veteran", 2], ["marksman", 3]], [["assassin", 5], ["veteran", 2], ["marksman", 2]], [["sniper", 4], ["veteran", 3], ["brute", 2]]], [5.0, 8.0], 4),
		_lv("PULSE ARRAY", "space", [[["sniper", 2], ["marksman", 2]], [["assassin", 4], ["marksman", 2]], [["sniper", 3], ["veteran", 2], ["marksman", 2]], [["assassin", 4], ["burner", 3], ["sniper", 3]], [["hopper", 6], ["veteran", 3], ["marksman", 3]]], [5.0, 8.0], 4),
		_lv("STELLAR COLLAPSE", "space", [[["assassin", 3], ["burner", 3]], [["assassin", 4], ["burner", 4]], [["assassin", 3], ["marksman", 2], ["brute", 2]], [["hopper", 6], ["sniper", 4], ["veteran", 2]], [["hopper", 5], ["assassin", 5], ["marksman", 2]]], [5.0, 7.5], 4),
		_lv("GALAXY EATER", "space", [[["hopper", 4], ["brute", 2]], [["assassin", 5], ["veteran", 2]], [["boss_galaxy", 1], ["hopper", 1], ["assassin", 4], ["sniper", 4]]], [5.0, 7.5], 4),
		# ---------------- DUNIA 10: IRON FOUNDRY (factory)
		_lv("ASSEMBLY ZERO", "factory", [[["burner", 2], ["guard", 4]], [["veteran", 3], ["marksman", 3]], [["gunner", 4], ["assassin", 3], ["marksman", 2]], [["gunner", 4], ["burner", 4], ["veteran", 3]]], [5.0, 7.5], 4, "BELTS PUSH YOU TO THE CENTER - SAWS GUARD THE MIDDLE"),
		_lv("FINAL SHIFT", "factory", [[["gunner", 3], ["veteran", 3]], [["guard", 3], ["veteran", 2], ["marksman", 2]], [["burner", 4], ["veteran", 2], ["brute", 2]], [["guard", 3], ["veteran", 4], ["brute", 2]]], [5.0, 7.5], 4),
		_lv("KILL SWITCH", "factory", [[["guard", 3], ["juggernaut", 1]], [["assassin", 5], ["guard", 2]], [["burner", 3], ["guard", 3], ["marksman", 2]], [["veteran", 3], ["marksman", 2], ["juggernaut", 2]], [["assassin", 5], ["guard", 3], ["marksman", 3]]], [5.0, 7.5], 4),
		_lv("CORE BREACH", "factory", [[["assassin", 4], ["brute", 1]], [["assassin", 2], ["guard", 4], ["juggernaut", 1]], [["burner", 4], ["guard", 3], ["juggernaut", 1]], [["gunner", 5], ["guard", 4], ["juggernaut", 1]], [["gunner", 5], ["guard", 4], ["juggernaut", 2]]], [5.0, 7.5], 4),
		_lv("THE FINAL ENGINE", "factory", [[["burner", 3], ["guard", 3]], [["burner", 3], ["veteran", 3]], [["boss_engine", 1], ["veteran", 4], ["marksman", 3], ["brute", 1]]], [5.0, 7.5], 4),
	]


static var _levels_cache: Array = []


## Semua level (250): chapter 1 sampai 5. Daftar dibangun sekali lalu disimpan.
static func levels() -> Array:
	if _levels_cache.is_empty():
		var all: Array = _levels_ch1()
		for lv in _levels_ch2():
			var d2: Dictionary = lv
			d2["variant"] = 1
			all.append(d2)
		for lv in _levels_ch3():
			var d3: Dictionary = lv
			d3["variant"] = 2
			all.append(d3)
		for lv in _levels_ch4():
			var d4: Dictionary = lv
			d4["variant"] = 3
			all.append(d4)
		for lv in _levels_ch5():
			var d5: Dictionary = lv
			d5["variant"] = 4
			all.append(d5)
		_levels_cache = all
	return _levels_cache


static func level(n: int) -> Dictionary:
	var all: Array = levels()
	return all[clampi(n, 1, all.size()) - 1]


# ------------------------------------------------------------------ chapter
## Chapter (0..4) tempat level global n berada.
static func chapter_of(n: int) -> int:
	return clampi((n - 1) / CHAPTER_SIZE, 0, CHAPTERS - 1)


## Nomor level di dalam chapter (1..50). Tampilan level selalu memakai nomor ini, jadi Chapter 2 & 3 mulai lagi dari LEVEL 1.
static func local_n(n: int) -> int:
	return (n - 1) % CHAPTER_SIZE + 1


## Nomor level global dari chapter + nomor level di chapter.
static func global_n(chapter: int, local: int) -> int:
	return chapter * CHAPTER_SIZE + local


## Level pertama / terakhir sebuah chapter (nomor global).
static func chapter_first(chapter: int) -> int:
	return chapter * CHAPTER_SIZE + 1


static func chapter_last(chapter: int) -> int:
	return (chapter + 1) * CHAPTER_SIZE


static func chapter_name(chapter: int) -> String:
	return String(CHAPTER_NAMES[clampi(chapter, 0, CHAPTERS - 1)])


## Teks nomor level untuk UI: "LEVEL 7" (chapter 1) atau "CH2  LEVEL 7".
static func level_text(n: int) -> String:
	if chapter_of(n) == 0:
		return "LEVEL %d" % local_n(n)
	return "CH%d  LEVEL %d" % [chapter_of(n) + 1, local_n(n)]


## Indeks varian map (0 = asli, 1..4 = Chapter 2..5).
static func map_variant(n: int) -> int:
	return chapter_of(n)


static func is_boss_level(n: int) -> bool:
	for wave in level(n)["waves"]:
		for e in wave:
			if bool((ENEMIES[String(e[0])] as Dictionary).get("boss", false)):
				return true
	return false


## Nomor dunia (indeks WORLDS, 0..9) untuk sebuah level. Dihitung dari nomor level DI DALAM chapter.
static func world_of(n: int) -> int:
	var ln: int = local_n(n)
	for i in WORLDS.size():
		var r: Array = WORLDS[i]["levels"]
		if ln >= int(r[0]) and ln <= int(r[1]):
			return i
	return WORLDS.size() - 1


## Level pertama dunia tempat level n berada (titik checkpoint).
static func checkpoint_of(n: int) -> int:
	return chapter_of(n) * CHAPTER_SIZE + int((WORLDS[world_of(n)]["levels"] as Array)[0])


## Kesulitan 0..1 menurut nomor level.
## Level 1..35 memakai kurva asli (0..1). Level 36..50 melanjutkan ke atas sampai 1.3 (dipakai untuk darah musuh;
## sisanya dibatasi di 1.0 lewat enemy_stats()).
## Chapter 2: 0.42 -> 1.30, Chapter 3: 0.62 -> 1.40, Chapter 4: 0.78 -> 1.46, Chapter 5: 0.92 -> 1.52 (mulai lebih ringan di tiap
## chapter lalu menanjak, tetapi selalu di atas chapter sebelumnya pada posisi yang sama).
static func difficulty(n: int) -> float:
	var ch: int = chapter_of(n)
	var l: float = float(local_n(n) - 1)
	if ch == 1:
		return 0.42 + l / 49.0 * 0.88
	if ch == 2:
		return 0.62 + l / 49.0 * 0.78
	if ch == 3:
		return 0.78 + l / 49.0 * 0.68
	if ch == 4:
		return 0.92 + l / 49.0 * 0.60
	return clampf(l / float(BASE_LEVELS - 1), 0.0, 1.3)


## Statistik musuh akhir (sudah diskalakan menurut level).
static func enemy_stats(kind: String, n: int) -> Dictionary:
	var base: Dictionary = (ENEMIES[kind] as Dictionary).duplicate()
	var d_ext: float = difficulty(n)            # bisa > 1.0 di dunia 8-10
	var d: float = minf(d_ext, 1.0)             # reaksi, dodge, kecepatan: dibatasi supaya tetap adil
	base["hp"] = float(base["hp"]) * lerpf(1.0, 1.75, d_ext)
	base["speed"] = float(base["speed"]) * lerpf(0.92, 1.08, d)
	base["dmg"] = float(base["dmg"]) * lerpf(0.78, 1.22, d) * (1.0 + 0.5 * (d_ext - d))
	# 8 level pertama dibuat lebih ramah (tutorial): musuh lebih lemah, lebih lambat menembak
	var ease_k: float = clampf(float(n - 1) / 8.0, 0.0, 1.0)   # >= level 9 (termasuk chapter 2 & 3) = 1.0
	base["dmg"] = float(base["dmg"]) * lerpf(0.62, 1.0, ease_k)
	base["rate"] = float(base.get("rate", 1.0)) * lerpf(1.5, 1.0, ease_k)
	base["reaction"] = lerpf(0.62, 0.20, d) + (1.0 - ease_k) * 0.3   # jeda sebelum mulai menembak setelah target terlihat (detik)
	base["dodge"] = lerpf(0.10, 0.62, d)           # peluang menghindar peluru
	base["aim_tol"] = lerpf(30.0, 46.0, d)         # toleransi selisih tinggi saat menembak (px)
	return base


# ------------------------------------------------------------------ perk
## max = jumlah tumpukan maksimum. weight = peluang muncul di pilihan. icon = nama file di assets/sprites/campaign/.
const PERKS := {
	"heavy": {"name": "HEAVY ROUNDS", "desc": "+12% WEAPON DAMAGE", "max": 5, "weight": 10, "color": Color("ff8a3a")},
	"quick": {"name": "QUICK TRIGGER", "desc": "+10% FIRE RATE", "max": 5, "weight": 10, "color": Color("ffd23f")},
	"pockets": {"name": "DEEP POCKETS", "desc": "+20% AMMO CAPACITY", "max": 5, "weight": 9, "color": Color("ff9d2e")},
	"swift": {"name": "SWIFT SOLES", "desc": "+6% RUN SPEED", "max": 5, "weight": 8, "color": Color("ff5d4d")},
	"spring": {"name": "SPRING STEP", "desc": "+5% JUMP HEIGHT", "max": 3, "weight": 6, "color": Color("3d8bff")},
	"iron": {"name": "IRON SKIN", "desc": "-10% DAMAGE TAKEN", "max": 5, "weight": 9, "color": Color("9aa7c7")},
	"heart": {"name": "EXTRA HEART", "desc": "+1 MAX HEART", "max": 2, "weight": 3, "color": Color("ff4a6a")},
	"vampire": {"name": "VAMPIRE", "desc": "KILLS MAY HEAL YOU", "max": 3, "weight": 5, "color": Color("c0306a")},
	"aegis": {"name": "AEGIS", "desc": "START LEVELS WITH A SHIELD", "max": 1, "weight": 4, "color": Color("73d9ff")},
	"scavenger": {"name": "SCAVENGER", "desc": "ENEMIES DROP MORE POWER-UPS", "max": 3, "weight": 7, "color": Color("4be3a0")},
	"blade": {"name": "SHARP KNIFE", "desc": "+25% KNIFE DAMAGE", "max": 3, "weight": 5, "color": Color("dfe8ff")},
	"wind": {"name": "SECOND WIND", "desc": "+1 LIFE", "max": 99, "weight": 3, "color": Color("b36bff")},
}


static func perk_count(perks: Dictionary, id: String) -> int:
	return int(perks.get(id, 0))


## Terapkan semua perk ke pemain (dipanggil sebelum Player.reset()).
static func apply_perks(p: Player, perks: Dictionary) -> void:
	p.dmg_out = 1.0 + 0.12 * perk_count(perks, "heavy")
	p.rate_scale = pow(0.9, perk_count(perks, "quick"))
	p.ammo_mult = 1.0 + 0.2 * perk_count(perks, "pockets")
	p.speed_scale = 1.0 + 0.06 * perk_count(perks, "swift")
	p.jump_scale = 1.0 + 0.05 * perk_count(perks, "spring")
	p.dmg_in = pow(0.9, perk_count(perks, "iron"))
	p.max_hp = float(Global.MAX_HP + perk_count(perks, "heart"))
	p.knife_mult = 1.0 + 0.25 * perk_count(perks, "blade")


## 3 pilihan perk acak (tanpa kembar, yang sudah maksimal tidak muncul). Boss level -> perk langka lebih sering.
static func roll_perks(perks: Dictionary, rng: RandomNumberGenerator, count: int = 3) -> Array[String]:
	var pool: Array[String] = []
	for id in PERKS:
		var p: Dictionary = PERKS[id]
		if id == "wind":
			continue          # SECOND WIND hanya dari hadiah boss
		if perk_count(perks, id) < int(p["max"]):
			pool.append(id)
	var out: Array[String] = []
	while out.size() < count and not pool.is_empty():
		var total: float = 0.0
		for id in pool:
			total += float((PERKS[id] as Dictionary)["weight"])
		var r: float = rng.randf() * total
		var pick: String = pool[0]
		for id in pool:
			r -= float((PERKS[id] as Dictionary)["weight"])
			if r <= 0.0:
				pick = id
				break
		out.append(pick)
		pool.erase(pick)
	return out


# ------------------------------------------------------------------ run (satu permainan campaign)
static func new_run() -> Dictionary:
	return {"active": true, "level": 1, "lives": START_LIVES, "score": 0, "perks": {},
		"ckpt_level": 1, "ckpt_lives": START_LIVES, "ckpt_score": 0, "ckpt_perks": {}, "practice": false}


## Simpan titik checkpoint (awal tiap dunia) supaya GAME OVER bisa lanjut dari sana.
static func mark_checkpoint(run: Dictionary) -> void:
	run["ckpt_level"] = int(run["level"])
	run["ckpt_lives"] = maxi(int(run["lives"]), 2)
	run["ckpt_score"] = int(run["score"])
	run["ckpt_perks"] = (run["perks"] as Dictionary).duplicate()


## Kembalikan run ke checkpoint terakhir (setelah GAME OVER).
static func restore_checkpoint(run: Dictionary) -> void:
	run["level"] = int(run["ckpt_level"])
	run["lives"] = int(run["ckpt_lives"])
	run["score"] = int(run["ckpt_score"])
	run["perks"] = (run["ckpt_perks"] as Dictionary).duplicate()


# ------------------------------------------------------------------ penyimpanan
static func load_save() -> Dictionary:
	var data := {"unlocked": 1, "hi_score": 0, "stars": {}, "best": {}, "grades": {}, "fighter": {}, "complete": false, "run": {}}
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return data
	# save lama (v1, 30 level) otomatis dipetakan ke nomor level baru (v2, 35 level)
	var legacy: bool = int(cfg.get_value("meta", "version", 1)) < SAVE_VERSION
	var unlocked: int = int(cfg.get_value("progress", "unlocked", 1))
	if legacy:
		unlocked = legacy_level(unlocked)
	data["unlocked"] = clampi(unlocked, 1, TOTAL_LEVELS)
	data["hi_score"] = int(cfg.get_value("progress", "hi_score", 0))
	data["complete"] = bool(cfg.get_value("progress", "complete", false))
	var stars: Dictionary = {}
	var best: Dictionary = {}
	var grades: Dictionary = {}
	for n in range(1, TOTAL_LEVELS + 1):
		stars[n] = 0
		best[n] = 0
		grades[n] = 0
	if legacy:
		for old_n in range(1, LEGACY_LEVELS + 1):
			var new_n: int = legacy_level(old_n)
			stars[new_n] = clampi(int(cfg.get_value("stars", str(old_n), 0)), 0, 3)
			best[new_n] = int(cfg.get_value("best", str(old_n), 0))
			grades[new_n] = clampi(int(cfg.get_value("grades", str(old_n), 0)), 0, 4)
	else:
		for n in range(1, TOTAL_LEVELS + 1):
			stars[n] = clampi(int(cfg.get_value("stars", str(n), 0)), 0, 3)
			best[n] = int(cfg.get_value("best", str(n), 0))
			grades[n] = clampi(int(cfg.get_value("grades", str(n), 0)), 0, 4)
	# save lama belum menyimpan rank: perkiraan dari bintang (1=C, 2=B, 3=A). Rank S hanya tercatat dari permainan baru.
	for n in range(1, TOTAL_LEVELS + 1):
		grades[n] = maxi(int(grades[n]), int(stars[n]))
	# save dari versi 35 level: kalau level 35 sudah dituntaskan, dunia baru (level 36+) otomatis terbuka
	if int(data["unlocked"]) == BASE_LEVELS and (int(stars[BASE_LEVELS]) > 0 or int(best[BASE_LEVELS]) > 0 or bool(data["complete"])):
		data["unlocked"] = BASE_LEVELS + 1
	# save lama (50 level): kalau level terakhir sebuah chapter sudah dituntaskan, chapter berikutnya otomatis terbuka
	var ul: int = int(data["unlocked"])
	if ul < TOTAL_LEVELS and (int(stars[ul]) > 0 or int(best[ul]) > 0) and ul % CHAPTER_SIZE == 0:
		data["unlocked"] = ul + 1
	if int(stars[TOTAL_LEVELS]) == 0 and int(best[TOTAL_LEVELS]) == 0:
		data["complete"] = false      # "complete" kini berarti level 250 (akhir Chapter 3) selesai
	data["stars"] = stars
	data["best"] = best
	data["grades"] = grades
	var f_ch: int = int(cfg.get_value("fighter", "character", -1))
	var f_wp: String = String(cfg.get_value("fighter", "weapon", ""))
	if f_ch >= 0 and f_wp != "":
		var fgt: Dictionary = {"character": f_ch, "weapon": f_wp}
		for k in FIGHTER_LOOK_KEYS:
			if cfg.has_section_key("fighter", k):
				fgt[k] = String(cfg.get_value("fighter", k, ""))
		data["fighter"] = fgt
	var run_v: Variant = cfg.get_value("run", "data", {})
	if run_v is Dictionary and not (run_v as Dictionary).is_empty():
		var r: Dictionary = (run_v as Dictionary).duplicate(true)
		if r.has("level") and r.has("lives") and r.has("perks"):
			if legacy:
				r["level"] = legacy_level(int(r["level"]))
				if r.has("ckpt_level"):
					r["ckpt_level"] = legacy_level(int(r["ckpt_level"]))
			data["run"] = r
	return data


## Nomor level save lama (v1) -> nomor level sekarang.
static func legacy_level(old_n: int) -> int:
	return int(LEGACY_TO_NEW[clampi(old_n, 1, LEGACY_LEVELS) - 1])


static func save_all(data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.set_value("progress", "unlocked", int(data["unlocked"]))
	cfg.set_value("progress", "hi_score", int(data["hi_score"]))
	cfg.set_value("progress", "complete", bool(data["complete"]))
	for n in range(1, TOTAL_LEVELS + 1):
		cfg.set_value("stars", str(n), int((data["stars"] as Dictionary).get(n, 0)))
		cfg.set_value("best", str(n), int((data["best"] as Dictionary).get(n, 0)))
		cfg.set_value("grades", str(n), int((data.get("grades", {}) as Dictionary).get(n, 0)))
	cfg.set_value("run", "data", data.get("run", {}))
	var fighter: Dictionary = data.get("fighter", {})
	if not fighter.is_empty():
		cfg.set_value("fighter", "character", int(fighter["character"]))
		cfg.set_value("fighter", "weapon", String(fighter["weapon"]))
		# skin karakter + skin senjata (utama / pistol / pisau) ikut ditulis ke file save
		for k in FIGHTER_LOOK_KEYS:
			if fighter.has(k):
				cfg.set_value("fighter", k, String(fighter[k]))
	cfg.save(SAVE_PATH)


## Catat hasil level: bintang & skor terbaik, buka level berikutnya.
static func record_result(level_n: int, stars: int, score_gain: int, total_score: int, grade: int = 0) -> void:
	var data: Dictionary = load_save()
	var st: Dictionary = data["stars"]
	st[level_n] = maxi(int(st.get(level_n, 0)), stars)
	var gr: Dictionary = data["grades"]
	gr[level_n] = maxi(int(gr.get(level_n, 0)), maxi(grade, stars))   # rank terbaik tersimpan
	var bs: Dictionary = data["best"]
	bs[level_n] = maxi(int(bs.get(level_n, 0)), score_gain)
	data["unlocked"] = maxi(int(data["unlocked"]), mini(level_n + 1, TOTAL_LEVELS))
	data["hi_score"] = maxi(int(data["hi_score"]), total_score)
	if level_n >= TOTAL_LEVELS:
		data["complete"] = true
	save_all(data)


const FIGHTER_LOOK_KEYS := ["skin", "wskin", "pskin", "kskin"]


## Karakter & senjata CAMPAIGN yang terakhir dipilih (tersimpan di save, jadi tidak perlu memilih lagi).
## `looks` = entri pilihan dari layar select ({"skin", "wskin", "pskin", "kskin", ...}): skin karakter & skin senjata
## (utama, pistol, pisau) ikut disimpan supaya CAMPAIGN memakai tampilan yang sama dengan yang dipilih (bukan cuma karakter + senjata).
static func save_fighter(character: int, weapon: String, looks: Dictionary = {}) -> void:
	var data: Dictionary = load_save()
	var f: Dictionary = {"character": character, "weapon": weapon}
	for k in FIGHTER_LOOK_KEYS:
		f[k] = String(looks.get(k, ""))
	data["fighter"] = f
	save_all(data)


## Pilihan tersimpan yang masih valid, atau {} kalau belum pernah memilih (atau datanya tidak valid lagi).
static func saved_fighter() -> Dictionary:
	var f: Dictionary = load_save().get("fighter", {})
	if f.is_empty():
		return {}
	var ch: int = int(f.get("character", -1))
	var wp: String = String(f.get("weapon", ""))
	if ch < 0 or ch >= Global.character_count():
		return {}
	if not Global.WEAPON_ORDER.has(wp) or not bool(Global.WEAPONS[wp]["enabled"]):
		return {}
	var res: Dictionary = {"character": ch, "weapon": wp}
	# skin hanya disertakan kalau memang tersimpan (save lama tidak punya): tanpa kunci "skin" = pakai skin terakhir karakter itu
	for k in FIGHTER_LOOK_KEYS:
		if f.has(k):
			res[k] = String(f[k])
	# save lama (belum menyimpan skin senjata): pakai skin senjata terakhir yang dipilih di layar select
	if not f.has("wskin"):
		res["wskin"] = Cosmetics.last_wskin(wp)
	if not f.has("pskin"):
		res["pskin"] = Cosmetics.last_wskin("pistol")
	if not f.has("kskin"):
		res["kskin"] = Cosmetics.last_wskin("knife")
	return res


static func save_run(run: Dictionary) -> void:
	var data: Dictionary = load_save()
	data["run"] = run.duplicate(true)
	save_all(data)


static func clear_run() -> void:
	var data: Dictionary = load_save()
	data["run"] = {}
	save_all(data)


static func total_stars(data: Dictionary) -> int:
	var t: int = 0
	for n in range(1, TOTAL_LEVELS + 1):
		t += int((data["stars"] as Dictionary).get(n, 0))
	return t


## Rank hasil level: 0 = belum, 1 = C, 2 = B, 3 = A, 4 = S (3 bintang + tanpa damage).
static func grade_rank(stars: int, flawless: bool) -> int:
	if stars >= 3:
		return 4 if flawless else 3
	return clampi(stars, 0, 2)


static func grade_letter(rank: int) -> String:
	match rank:
		4: return "S"
		3: return "A"
		2: return "B"
		1: return "C"
	return ""


static func grade_color(rank: int) -> Color:
	match rank:
		4: return Color("ffd23f")
		3: return Color("4be3a0")
		2: return Color("4fd8ff")
	return Color("b8c0d8")


## Titik bintang 5 sudut (10 titik) untuk digambar di UI.
static func star_points(center: Vector2, r: float, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var rad: float = r if i % 2 == 0 else r * 0.46
		var a: float = -PI * 0.5 + rot + float(i) * PI / 5.0
		pts.append(center + Vector2(cos(a), sin(a)) * rad)
	return pts
