class_name UpdateConfig
extends RefCounted
## ======================================================================================
##  PENGATURAN AUTO UPDATE  (satu-satunya file yang perlu Anda isi)
## ======================================================================================
## Cara kerja singkat:
##   - Saat game dibuka (setelah splash, SEBELUM loading screen) game menanyakan ke GitHub Releases
##     apakah ada rilis yang lebih baru dari versi game ini (project.godot -> config/version).
##   - Kalau ada: pemain HARUS update (tombol UPDATE SEKARANG) atau game ditutup (tombol KELUAR).
##   - Kalau tidak ada / tidak ada internet: game langsung lanjut ke loading screen (game tetap bisa offline).
##
## Panduan lengkap membuat rilis ada di UPDATE_GUIDE.md.

## Alamat repository GitHub: https://github.com/<GITHUB_OWNER>/<GITHUB_REPO>
## WAJIB DIISI. Repository harus PUBLIC (supaya game bisa mengunduh tanpa login).
const GITHUB_OWNER := "EquinoxInteractive"
const GITHUB_REPO := "BoxSiegeGodot"

## false = hanya rilis resmi terbaru (yang TIDAK ditandai "Pre-release") yang dianggap update.
## true  = rilis Pre-release juga dihitung (berguna untuk beta tester).
const INCLUDE_PRERELEASE := false

## Batas waktu (detik) menunggu GitHub saat mengecek. Lewat dari ini = dianggap offline, game lanjut.
const CHECK_TIMEOUT := 12.0

## Download dianggap macet kalau tidak ada data baru selama sekian detik.
const STALL_TIMEOUT := 25.0

## Lama minimal layar "memeriksa" tampil (detik) supaya animasinya sempat terlihat.
const MIN_CHECK_SHOW := 1.1

## Lama layar "game sudah terbaru" tampil sebelum masuk ke loading screen (detik).
const UPTODATE_SHOW := 1.0

## Nama file di Release untuk tiap platform. Pencocokan memakai akhiran / kata kunci, jadi nama bebas, contoh:
##   Windows : BoxSiege.exe            (atau BoxSiege-Windows.exe / BoxSiege-Windows.zip)
##   Linux   : BoxSiege.x86_64         (atau BoxSiege-Linux.zip yang berisi file .x86_64)
##   macOS   : BoxSiege.zip            (hasil export macOS; berisi BoxSiege.app)

## Mengubah ke false = fitur auto update dimatikan total (game langsung ke loading screen).
const ENABLED := true

## ---- pengujian di Godot Editor ------------------------------------------------------
## Di Godot Editor (F5) auto update TIDAK berjalan (supaya tidak mengganggu saat Anda mengembangkan game).
## Mau melihat tampilannya di editor? Isi salah satu nilai di bawah, jalankan game, lalu KOSONGKAN lagi:
##   "update"   = simulasi ada update (unduhan palsu, tanpa internet, tidak mengganti file apa pun)
##   "uptodate" = simulasi game sudah terbaru
##   "offline"  = simulasi tidak ada internet
##   "error"    = simulasi unduhan gagal
##   "blocked"  = simulasi folder game tidak bisa ditulis
const EDITOR_SIMULATE := ""


static func is_configured() -> bool:
	return GITHUB_OWNER != "" and GITHUB_REPO != "" \
		and not GITHUB_OWNER.begins_with("GANTI_") and not GITHUB_REPO.begins_with("GANTI_")
