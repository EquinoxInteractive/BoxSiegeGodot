class_name UpdateCore
extends RefCounted
## ======================================================================================
##  INTI AUTO UPDATE  (logika saja, tanpa tampilan; tampilan ada di updater.gd)
## ======================================================================================
## - baca versi game, bandingkan dengan rilis GitHub
## - pilih file rilis yang cocok untuk OS pemain (Windows .exe / Linux .x86_64 / macOS .zip)
## - setelah unduhan selesai: cek SHA-256 (kalau GitHub menyediakan), siapkan file
## - pasang: game TIDAK bisa menimpa dirinya sendiri saat berjalan, jadi sebuah skrip kecil (.bat / .sh)
##   dijalankan di luar game: menunggu game tertutup, mengganti file, lalu membuka game baru.

const UA := "BoxSiege-Updater"
const API_HOST := "https://api.github.com"
const STATE_PATH := "user://update_state.cfg"
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des"]


# ------------------------------------------------------------------ platform & versi
static func platform_key() -> String:
	match OS.get_name():
		"Windows":
			return "windows"
		"macOS":
			return "macos"
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return "linux"
	return ""


static func platform_label() -> String:
	match platform_key():
		"windows":
			return "WINDOWS"
		"macos":
			return "MACOS"
		"linux":
			return "LINUX"
	return OS.get_name().to_upper()


static func current_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## "v1.2.3-beta.1" -> {ok, nums:[1,2,3], pre:"beta.1"}
static func parse_version(v: String) -> Dictionary:
	var re := RegEx.new()
	re.compile("(\\d+(?:\\.\\d+){0,3})(-[0-9A-Za-z.\\-]+)?")
	var m: RegExMatch = re.search(v)
	if m == null:
		return {"ok": false, "nums": [0], "pre": ""}
	var nums: Array = []
	for p in m.get_string(1).split("."):
		nums.append(int(p))
	return {"ok": true, "nums": nums, "pre": m.get_string(2).trim_prefix("-")}


## -1 : a < b,  0 : sama,  1 : a > b
static func compare_versions(a: String, b: String) -> int:
	var pa: Dictionary = parse_version(a)
	var pb: Dictionary = parse_version(b)
	var na: Array = pa["nums"]
	var nb: Array = pb["nums"]
	var n: int = maxi(na.size(), nb.size())
	for i in n:
		var x: int = int(na[i]) if i < na.size() else 0
		var y: int = int(nb[i]) if i < nb.size() else 0
		if x != y:
			return 1 if x > y else -1
	var ra: String = pa["pre"]
	var rb: String = pb["pre"]
	if ra == rb:
		return 0
	if ra == "":
		return 1                 # 1.0.0 lebih baru dari 1.0.0-beta
	if rb == "":
		return -1
	return 1 if ra > rb else -1


static func is_newer(remote: String, local: String) -> bool:
	if not bool(parse_version(remote)["ok"]):
		return false
	return compare_versions(remote, local) > 0


# ------------------------------------------------------------------ rilis GitHub
static func releases_url(api_base: String) -> String:
	var base: String = api_base if api_base != "" else API_HOST
	return "%s/repos/%s/%s/releases?per_page=15" % [base, UpdateConfig.GITHUB_OWNER, UpdateConfig.GITHUB_REPO]


static func api_headers() -> PackedStringArray:
	return PackedStringArray(["User-Agent: " + UA, "Accept: application/vnd.github+json", "X-GitHub-Api-Version: 2022-11-28"])


static func download_headers() -> PackedStringArray:
	return PackedStringArray(["User-Agent: " + UA, "Accept: application/octet-stream"])


## Dari respons API (daftar rilis) ambil rilis dengan versi tertinggi. Hasil: {} kalau tidak ada rilis.
static func pick_latest_release(body: String) -> Dictionary:
	var data: Variant = JSON.parse_string(body)
	var list: Array = []
	if typeof(data) == TYPE_ARRAY:
		list = data
	elif typeof(data) == TYPE_DICTIONARY and (data as Dictionary).has("tag_name"):
		list = [data]
	var best: Dictionary = {}
	for r in list:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = r
		if bool(d.get("draft", false)):
			continue
		if bool(d.get("prerelease", false)) and not UpdateConfig.INCLUDE_PRERELEASE:
			continue
		var tag: String = String(d.get("tag_name", ""))
		if tag == "" or not bool(parse_version(tag)["ok"]):
			continue
		if best.is_empty() or compare_versions(tag, String(best["tag"])) > 0:
			best = {
				"tag": tag,
				"version": tag.trim_prefix("v").trim_prefix("V"),
				"name": String(d.get("name", "")),
				"body": String(d.get("body", "")),
				"published": String(d.get("published_at", "")),
				"url": String(d.get("html_url", "")),
				"assets": d.get("assets", []),
			}
	return best


static func _asset_score(n: String, plat: String) -> int:
	match plat:
		"windows":
			if n.ends_with(".exe"):
				return 100
			if n.ends_with(".zip") and n.contains("win"):
				return 60
		"linux":
			if n.ends_with(".x86_64"):
				return 100
			if n.ends_with(".zip") and n.contains("linux"):
				return 60
		"macos":
			if n.ends_with(".zip") and (n.contains("mac") or n.contains("osx")):
				return 100
			if n.ends_with(".zip") and not (n.contains("win") or n.contains("linux")):
				return 50
	return 0


## Pilih file rilis untuk OS ini. Hasil: {name, size, url, digest} atau {}.
static func pick_asset(assets: Array, plat: String) -> Dictionary:
	var best: Dictionary = {}
	var best_score: int = 0
	for a in assets:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = a
		var name: String = String(d.get("name", ""))
		var url: String = String(d.get("browser_download_url", ""))
		if name == "" or url == "":
			continue
		var sc: int = _asset_score(name.to_lower(), plat)
		if sc > best_score:
			best_score = sc
			var dg: String = String(d.get("digest", ""))
			best = {"name": name, "size": int(d.get("size", 0)), "url": url,
					"digest": dg.trim_prefix("sha256:") if dg.begins_with("sha256:") else ""}
	return best


# ------------------------------------------------------------------ teks
## Catatan rilis (Markdown) -> BBCode sederhana untuk RichTextLabel.
static func notes_to_bbcode(body: String) -> String:
	var re_img := RegEx.new()
	re_img.compile("!\\[[^\\]]*\\]\\([^)]*\\)")
	var re_link := RegEx.new()
	re_link.compile("\\[([^\\]]*)\\]\\([^)]*\\)")
	var re_html := RegEx.new()
	re_html.compile("<[^>]+>")
	var re_head := RegEx.new()
	re_head.compile("^\\s{0,3}#{1,6}\\s+(.*)$")
	var re_bul := RegEx.new()
	re_bul.compile("^\\s*[-*+]\\s+(.*)$")
	var out: PackedStringArray = PackedStringArray()
	var blank: bool = false
	for raw in body.replace("\r", "").split("\n"):
		var line: String = String(raw)
		line = re_img.sub(line, "", true)
		line = re_link.sub(line, "$1", true)
		line = re_html.sub(line, "", true)
		line = line.replace("**", "").replace("__", "").replace("`", "")
		if line.strip_edges() == "":
			blank = true
			continue
		if line.strip_edges().begins_with("Full Changelog") or line.strip_edges().begins_with("**Full Changelog"):
			continue
		if blank and not out.is_empty():
			out.append("")
		blank = false
		var h: RegExMatch = re_head.search(line)
		if h != null:
			out.append("[color=#ffd23f]%s[/color]" % _esc(h.get_string(1).strip_edges()))
			continue
		var b: RegExMatch = re_bul.search(line)
		if b != null:
			out.append("[color=#3de0ff]•[/color]  %s" % _esc(b.get_string(1).strip_edges()))
			continue
		out.append(_esc(line.strip_edges()))
	var text: String = "\n".join(out).strip_edges()
	if text == "":
		text = "Perbaikan dan peningkatan umum."
	return text


static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


static func fmt_bytes(b: float) -> String:
	if b < 1024.0:
		return "%d B" % int(b)
	if b < 1024.0 * 1024.0:
		return "%.0f KB" % (b / 1024.0)
	if b < 1024.0 * 1024.0 * 1024.0:
		return "%.1f MB" % (b / 1048576.0)
	return "%.2f GB" % (b / 1073741824.0)


static func fmt_eta(sec: float) -> String:
	if sec < 0.0 or sec > 359999.0:
		return "--:--"
	var s: int = int(ceil(sec))
	if s >= 3600:
		return "%d:%02d:%02d" % [floori(s / 3600.0), floori((s % 3600) / 60.0), s % 60]
	return "%02d:%02d" % [floori(s / 60.0), s % 60]


## "2026-11-08T01:02:03Z" -> "8 Nov 2026"
static func fmt_date(iso: String) -> String:
	if iso.length() < 10:
		return ""
	var y: String = iso.substr(0, 4)
	var m: int = int(iso.substr(5, 2))
	var d: int = int(iso.substr(8, 2))
	if m < 1 or m > 12:
		return ""
	return "%d %s %s" % [d, MONTHS[m - 1], y]


# ------------------------------------------------------------------ lokasi & izin
static func exe_path() -> String:
	return OS.get_executable_path()


static func mac_app_path() -> String:
	var app: String = exe_path().get_base_dir().get_base_dir().get_base_dir()
	return app if app.ends_with(".app") else ""


static func dir_writable(dir: String) -> bool:
	var probe: String = dir.path_join(".boxsiege_write_test")
	var f: FileAccess = FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(probe)
	return true


## Pesan kendala kalau game TIDAK bisa memperbarui dirinya di lokasi sekarang. "" = aman.
static func install_blocker(plat: String) -> String:
	match plat:
		"windows", "linux":
			var dir: String = exe_path().get_base_dir()
			if not dir_writable(dir):
				return "Folder game tidak bisa ditulis, jadi update tidak bisa dipasang di sini.\n\nPindahkan game ke folder biasa (misalnya Documents atau Desktop), lalu buka lagi dari sana."
		"macos":
			var app: String = mac_app_path()
			if app == "":
				return "Update hanya bisa dipasang kalau game dijalankan dari BoxSiege.app."
			if app.contains("/AppTranslocation/") or app.begins_with("/Volumes/"):
				return "Game sedang dijalankan dari lokasi sementara (Downloads atau file ZIP/DMG) yang dikunci oleh macOS.\n\nPindahkan BoxSiege.app ke folder Applications atau Desktop, buka lagi dari sana, lalu update."
			if not dir_writable(app.get_base_dir()):
				return "Folder tempat BoxSiege.app berada tidak bisa ditulis.\n\nPindahkan BoxSiege.app ke Applications atau Desktop, lalu buka lagi dari sana."
		_:
			return "Sistem operasi ini belum didukung oleh auto update."
	return ""


static func update_dir() -> String:
	var d: String = ProjectSettings.globalize_path("user://update")
	DirAccess.make_dir_recursive_absolute(d)
	return d


## Tempat file unduhan disimpan. Windows/Linux: di folder game (supaya penggantian = rename, aman & cepat).
static func download_path(plat: String) -> String:
	if plat == "macos":
		return update_dir().path_join("BoxSiege-update.zip")
	return exe_path() + ".update-part"


static func cleanup_leftovers() -> void:
	for p in [exe_path() + ".update-part", exe_path() + ".update-new"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	var ud: String = ProjectSettings.globalize_path("user://update")
	if DirAccess.dir_exists_absolute(ud):
		for f in DirAccess.get_files_at(ud):
			DirAccess.remove_absolute(ud.path_join(f))


# ------------------------------------------------------------------ setelah unduhan (dijalankan di thread)
## Cek SHA-256, ekstrak kalau ZIP, cek isi file. Hasil: {ok, error, staged}
static func finalize(dl_path: String, plat: String, asset_name: String, digest: String) -> Dictionary:
	if not FileAccess.file_exists(dl_path):
		return {"ok": false, "error": "File unduhan tidak ditemukan."}
	if digest != "":
		var got: String = FileAccess.get_sha256(dl_path)
		if got.to_lower() != digest.to_lower():
			DirAccess.remove_absolute(dl_path)
			return {"ok": false, "error": "File unduhan rusak (checksum tidak cocok). Coba unduh ulang."}
	if plat == "macos":
		if _magic(dl_path, 2) != PackedByteArray([0x50, 0x4B]):
			DirAccess.remove_absolute(dl_path)
			return {"ok": false, "error": "File update macOS bukan ZIP yang valid."}
		return {"ok": true, "staged": dl_path}

	var staged: String = exe_path() + ".update-new"
	if FileAccess.file_exists(staged):
		DirAccess.remove_absolute(staged)
	if asset_name.to_lower().ends_with(".zip"):
		var zr := ZIPReader.new()
		if zr.open(dl_path) != OK:
			DirAccess.remove_absolute(dl_path)
			return {"ok": false, "error": "File ZIP update tidak bisa dibuka."}
		var want: String = ".exe" if plat == "windows" else ".x86_64"
		var pick: String = ""
		for f in zr.get_files():
			if String(f).to_lower().ends_with(want):
				pick = String(f)
				break
		if pick == "":
			zr.close()
			DirAccess.remove_absolute(dl_path)
			return {"ok": false, "error": "Di dalam ZIP update tidak ada file game untuk platform ini."}
		var bytes: PackedByteArray = zr.read_file(pick)
		zr.close()
		var out: FileAccess = FileAccess.open(staged, FileAccess.WRITE)
		if out == null:
			DirAccess.remove_absolute(dl_path)
			return {"ok": false, "error": "Tidak bisa menulis file update di folder game."}
		out.store_buffer(bytes)
		out.close()
		DirAccess.remove_absolute(dl_path)
	else:
		if DirAccess.rename_absolute(dl_path, staged) != OK:
			return {"ok": false, "error": "Tidak bisa menyiapkan file update di folder game."}

	var sz: int = _file_size(staged)
	var head: PackedByteArray = _magic(staged, 4)
	var good: bool = sz > 1048576
	if plat == "windows":
		good = good and head.size() >= 2 and head[0] == 0x4D and head[1] == 0x5A          # "MZ"
	else:
		good = good and head == PackedByteArray([0x7F, 0x45, 0x4C, 0x46])                  # ELF
	if not good:
		DirAccess.remove_absolute(staged)
		return {"ok": false, "error": "File update tidak valid untuk platform ini."}
	return {"ok": true, "staged": staged}


static func _magic(path: String, n: int) -> PackedByteArray:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var b: PackedByteArray = f.get_buffer(n)
	f.close()
	return b


static func _file_size(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var n: int = f.get_length()
	f.close()
	return n


# ------------------------------------------------------------------ pemasangan (skrip di luar game)
const SH_LINUX := """#!/bin/sh
# BoxSiege updater (Linux): tunggu game tutup, ganti file, buka lagi.
PID="$1"; SRC="$2"; DST="$3"
trap '' HUP
i=0
while kill -0 "$PID" 2>/dev/null && [ "$i" -lt 100 ]; do sleep 0.3; i=$((i+1)); done
sleep 0.2
chmod +x "$SRC" 2>/dev/null
if ! mv -f "$SRC" "$DST" 2>/dev/null; then
  cp -f "$SRC" "$DST" 2>/dev/null && rm -f "$SRC"
fi
chmod +x "$DST" 2>/dev/null
cd "$(dirname "$DST")" 2>/dev/null
rm -f "$0"
nohup "$DST" >/dev/null 2>&1 &
"""

const SH_MAC := """#!/bin/bash
# BoxSiege updater (macOS): tunggu game tutup, ganti BoxSiege.app dengan versi baru, buka lagi.
PID="$1"; ZIP="$2"; APP="$3"
trap '' HUP
i=0
while kill -0 "$PID" 2>/dev/null && [ "$i" -lt 100 ]; do sleep 0.3; i=$((i+1)); done
sleep 0.3
WORK="$(mktemp -d "$(dirname "$APP")/.boxsiege-update.XXXXXX" 2>/dev/null || mktemp -d "${TMPDIR:-/tmp}/boxsiege-update.XXXXXX")"
if [ -n "$WORK" ]; then
  /usr/bin/ditto -x -k "$ZIP" "$WORK" 2>/dev/null || /usr/bin/unzip -q -o "$ZIP" -d "$WORK" 2>/dev/null
  NEWAPP="$(/usr/bin/find "$WORK" -maxdepth 2 -name '*.app' -type d 2>/dev/null | head -n 1)"
  if [ -n "$NEWAPP" ]; then
    BACKUP="${APP}.old-update"
    rm -rf "$BACKUP"
    if mv "$APP" "$BACKUP" 2>/dev/null; then
      if mv "$NEWAPP" "$APP" 2>/dev/null; then
        rm -rf "$BACKUP"
      else
        rm -rf "$APP"
        mv "$BACKUP" "$APP"
      fi
    fi
  fi
  rm -rf "$WORK"
fi
rm -f "$ZIP"
/usr/bin/xattr -dr com.apple.quarantine "$APP" 2>/dev/null
chmod -R +x "$APP/Contents/MacOS" 2>/dev/null
rm -f "$0"
/usr/bin/open -n "$APP"
"""

const BAT_WIN := """@echo off
chcp 65001 >nul
rem BoxSiege updater (Windows): tunggu game tutup, ganti file, buka lagi.
set "TARGET=%TARGET%"
set "NEWFILE=%NEWFILE%"
set "TRIES=0"
:retry
move /y "%NEWFILE%" "%TARGET%" >nul 2>&1
if not errorlevel 1 goto launch
set /a TRIES+=1
if %TRIES% GEQ 120 goto giveup
ping -n 2 127.0.0.1 >nul
goto retry
:launch
ping -n 2 127.0.0.1 >nul
cd /d "%WORKDIR%"
start "" "%TARGET%"
goto cleanup
:giveup
del /f /q "%NEWFILE%" >nul 2>&1
cd /d "%WORKDIR%"
start "" "%TARGET%"
:cleanup
(goto) 2>nul & del "%~f0"
"""


static func _win_path(p: String) -> String:
	return p.replace("/", "\\").replace("%", "%%")


## Jalankan skrip pemasang di luar game. Setelah ini pemanggil harus segera menutup game.
## staged: Windows/Linux = file game baru; macOS = ZIP. Hasil: {ok, error}
static func launch_installer(plat: String, staged: String) -> Dictionary:
	var dir: String = update_dir()
	var pid: int = OS.get_process_id()
	var script_path: String = ""
	var pid_new: int = -1
	match plat:
		"windows":
			var target: String = exe_path()
			var txt: String = BAT_WIN.replace("%TARGET%", "@@T@@").replace("%NEWFILE%", "@@N@@").replace("%WORKDIR%", "@@W@@")
			txt = txt.replace("@@T@@", _win_path(target)).replace("@@N@@", _win_path(staged)).replace("@@W@@", _win_path(target.get_base_dir()))
			script_path = dir.path_join("boxsiege_update.bat")
			if not _write_text(script_path, txt.replace("\n", "\r\n")):
				return {"ok": false, "error": "Tidak bisa membuat skrip pemasang."}
			pid_new = OS.create_process("cmd.exe", ["/c", script_path.replace("/", "\\")])
		"linux":
			script_path = dir.path_join("boxsiege_update.sh")
			if not _write_text(script_path, SH_LINUX):
				return {"ok": false, "error": "Tidak bisa membuat skrip pemasang."}
			pid_new = OS.create_process("/bin/sh", [script_path, str(pid), staged, exe_path()])
		"macos":
			script_path = dir.path_join("boxsiege_update.sh")
			if not _write_text(script_path, SH_MAC):
				return {"ok": false, "error": "Tidak bisa membuat skrip pemasang."}
			pid_new = OS.create_process("/bin/bash", [script_path, str(pid), staged, mac_app_path()])
		_:
			return {"ok": false, "error": "Platform belum didukung."}
	if pid_new <= 0:
		return {"ok": false, "error": "Skrip pemasang gagal dijalankan."}
	return {"ok": true}


static func _write_text(path: String, text: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


# ------------------------------------------------------------------ status "baru saja diupdate"
static func mark_updated(version: String) -> void:
	var cf := ConfigFile.new()
	cf.set_value("state", "updated_to", version)
	cf.save(STATE_PATH)


## Kalau game baru saja dibuka ulang oleh updater: kembalikan versi tujuan (sekali saja), kalau tidak "".
static func consume_updated_flag() -> String:
	var cf := ConfigFile.new()
	if cf.load(STATE_PATH) != OK:
		return ""
	var v: String = String(cf.get_value("state", "updated_to", ""))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE_PATH))
	if v != "" and compare_versions(current_version(), v) >= 0:
		return v
	return ""


# ------------------------------------------------------------------ simulasi (editor)
static func fake_release() -> Dictionary:
	var cur: Dictionary = parse_version(current_version())
	var nums: Array = cur["nums"]
	var major: int = int(nums[0]) if nums.size() > 0 else 1
	var minor: int = int(nums[1]) if nums.size() > 1 else 0
	var ver: String = "%d.%d.0" % [major, minor + 1]
	return {
		"tag": "v" + ver, "version": ver, "name": "Update " + ver,
		"body": "## Baru\n- Skin karakter & senjata premium berlevel (LV1 - LV3)\n- Finisher kill terakhir gaya Valorant\n- 10 aksesoris beranimasi baru\n\n## Perbaikan\n- Replay kini menampilkan efek skin\n- Peningkatan performa Campaign\n- Beberapa bug kecil diperbaiki",
		"published": Time.get_datetime_string_from_system(true) + "Z", "url": "", "assets": [],
		"asset": {"name": "BoxSiege-sim", "size": 48 * 1048576, "url": "", "digest": ""},
	}
