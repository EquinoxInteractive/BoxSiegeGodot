class_name AboutData
extends RefCounted
## ======================================================================================
##  ABOUT US  -  ISI / KONTEN (edit file ini saja untuk mengubah teks, tim, link, dan logo)
## ======================================================================================
## Semua teks yang tampil di layar "ABOUT US" ada di sini. Tampilan / animasinya ada di
## `about_ui.gd` dan tidak perlu disentuh kalau Anda hanya ingin mengganti isi.
##
## Token yang bisa dipakai di dalam teks:
##   {game}    -> nama game          (Global.GAME_TITLE)
##   {engine}  -> nama engine        (ENGINE_NAME di bawah)
##   {year}    -> tahun copyright    (COPYRIGHT_YEAR di bawah)
##   {license} -> nama lisensi source code (LICENSE_NAME di bawah)
##
## Warna ditulis sebagai kode hex tanpa "#", contoh "ff4a5a".


# ------------------------------------------------------------------ tombol di menu utama
const BUTTON_TITLE := "ABOUT US"
const BUTTON_SUBTITLE := "MEET THE DEVELOPERS"
const SCREEN_TITLE := "ABOUT US"


# ------------------------------------------------------------------ studio
const STUDIO_NAME_TOP := "EQUINOX"          # baris besar
const STUDIO_NAME_BOTTOM := "INTERACTIVE"   # baris kedua
const STUDIO_TAGLINE := "INDEPENDENT GAME STUDIO"
const STUDIO_LOGO := "res://assets/sprites/about/equinox.png"

const ENGINE_NAME := "Godot Engine"
const COPYRIGHT_YEAR := "2026"

## Lisensi SOURCE CODE game ini. HARUS sama persis dengan file LICENSE di repository GitHub Anda
## (contoh: "MIT License", "GNU GPL v3", "Apache License 2.0", "Mozilla Public License 2.0").
const LICENSE_NAME := "MIT License"


# ------------------------------------------------------------------ nama tab (urutan halaman)
const PAGE_TITLES := ["ABOUT", "TEAM", "INFO", "LEGAL"]


# ------------------------------------------------------------------ halaman 1: ABOUT
const ABOUT_HEADING := "ABOUT US"
const ABOUT_TEXT := "{game} is an indie game crafted by a passionate team of three. Built with {engine}, it brings together creativity, challenge and a deep love for immersive gameplay. It is designed for players who appreciate thoughtful design and smooth, responsive mechanics."

const MESSAGE_HEADING := "MESSAGE FROM THE DEVELOPERS"
const MESSAGE_TEXT := "Our first project as a tiny team of three beginner programmers and lifelong geeks, building cool things simply because we love it."
const MESSAGE_SIGNATURE := "THE EQUINOX INTERACTIVE TEAM"


# ------------------------------------------------------------------ halaman 2: TEAM
const TEAM_HEADING := "DEVELOPMENT TEAM"
const TEAM_STUDIO_LABEL := "STUDIO"
const TEAM_HINT := "CLICK TO VISIT"                  # muncul di kartu yang punya link, saat kursor di atasnya
const TEAM_NO_LINK := "NO LINK AVAILABLE YET"        # toast kalau kartu tanpa link ditekan

## Tambah / hapus / ubah anggota di sini (disarankan 3 orang agar kartunya pas di layar).
## "logo"   : path gambar (persegi, disarankan 256x256 PNG)
## "accent" : warna kartu anggota (hex)
## "url"    : link yang dibuka saat kartu diklik (ISI SENDIRI; boleh link apa saja: website, GitHub, Instagram, YouTube,
##            itch.io, portfolio, "mailto:nama@email.com", dll). Kosongkan ("") kalau belum ada: kartu tidak membuka apa-apa.
## Controller / keyboard: di halaman TEAM tekan ATAS / BAWAH untuk memilih kartu, lalu ACCEPT untuk membuka linknya.
const TEAM := [
	{
		"name": "BadutZY",
		"roles": ["Lead Programmer"],
		"logo": "res://assets/sprites/about/badutzy.png",
		"accent": "ff4a5a",
		"url": "https://badutzy.vercel.app/",
	},
	{
		"name": "SwimmingFox",
		"roles": ["Sprite Maker"],
		"logo": "res://assets/sprites/about/swimmingfox.png",
		"accent": "4fd8ff",
		"url": "https://github.com/Marrwertz",
	},
	{
		"name": "Ari8Bit",
		"roles": ["Project Manager"],
		"logo": "res://assets/sprites/about/ari8bit.png",
		"accent": "4be3a0",
		"url": "https://ariaja.pages.dev/",
	},
]


# ------------------------------------------------------------------ halaman 3: INFO
const TECH_HEADING := "TECHNICAL INFO"
## [label, value]
const TECH_INFO := [
	["VERSION", "Beta 3.5"],
	["PLATFORM", "Windows"],
	["ENGINE", "Godot Engine 4.7"],
	["RELEASE DATE", "Oktober 2026"],
]

const CONTACT_HEADING := "CONTACT"
## "icon"     : logo (SVG/PNG putih, di assets/sprites/about/icons/) yang digambar di dalam lingkaran
## "accent"   : warna cincin lingkaran + sorotan baris (hex)
## "fill"     : (opsional) warna isi lingkaran (hex). Kalau tidak ada = accent yang digelapkan
## "gradient" : (opsional) daftar warna hex (kiri-bawah -> kanan-atas) untuk isi lingkaran bergradasi (dipakai Instagram)
## "url"      : link yang dibuka saat baris diklik / ACCEPT. Kosongkan ("") kalau belum ada (tidak bisa diklik)
## "value"    : teks yang tampil di layar (tidak harus sama dengan url)
const CONTACT := [
	{
		"label": "WEBSITE",
		"value": "EquinoxInteractive",
		"url": "https://equinoxinteractive.vercel.app",
		"icon": "res://assets/sprites/about/icons/globe.svg",
		"accent": "4fd8ff",
		"fill": "1c6f9c",
	},
	{
		"label": "INSTAGRAM",
		"value": "equinox.interactive",
		"url": "https://www.instagram.com/equinox.interactive",
		"icon": "res://assets/sprites/about/icons/instagram.svg",
		"accent": "ff5fa2",
		"gradient": ["feda75", "fa7e1e", "d62976", "962fbf", "4f5bd5"],
	},
	{
		"label": "TWITTER / X",
		"value": "EquinoxIntratve",
		"url": "https://x.com/EquinoxIntratve",
		"icon": "res://assets/sprites/about/icons/x.svg",
		"accent": "e8e8f0",
		"fill": "000000",
	},
	# TODO: ganti USERNAME/REPO dengan alamat repository GitHub game ini (di "value" DAN di "url").
	{
		"label": "GITHUB",
		"value": "EquinoxInteractive",
		"url": "https://github.com/EquinoxInteractive",
		"icon": "res://assets/sprites/about/icons/github.svg",
		"accent": "c9d1d9",
		"fill": "161b22",
	},
]
const CONTACT_HINT := "CLICK TO OPEN"


# ------------------------------------------------------------------ halaman 4: LEGAL
const ACK_HEADING := "ACKNOWLEDGEMENTS"
const ACK_TEXT := "This product contains third-party assets from external creators, including audio, fonts and graphics. All contributors are credited with attribution, and every asset remains under its original license, which may differ from the license of the source code."

const LEGAL_HEADING := "LEGAL"
const LEGAL_COPYRIGHT := "© {year} EQUINOX INTERACTIVE"
const LEGAL_RIGHTS := "OPEN SOURCE  -  {license}"
const LEGAL_TEXT_1 := "{game} is free and open source software, released under the {license}. The source code is available on GitHub."
const LEGAL_TEXT_2 := "Third-party assets and trademarks remain the property of their respective owners and keep their original licenses."


# ------------------------------------------------------------------ helper
## Mengganti token {game} / {engine} / {year} / {license} di dalam teks.
static func fill(s: String) -> String:
	return s.replace("{game}", Global.GAME_TITLE) \
		.replace("{engine}", ENGINE_NAME) \
		.replace("{year}", COPYRIGHT_YEAR) \
		.replace("{license}", LICENSE_NAME)
