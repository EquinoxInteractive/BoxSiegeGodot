# BOXSIEGE (Godot 4.3) — Tahap 1

Buka dengan **Godot 4.3+** (Import → pilih `project.godot`) lalu tekan **F5**.
Renderer: GL Compatibility. Resolusi dasar 1280x720 (stretch otomatis).

## Isi tahap ini
- Menu: PLAY / SETTING (volume musik, tersimpan) / QUIT
- PLAY → pilih 2/3/4 pemain → pilih karakter, senjata, map, waktu (0:30 – 5:00)
- Game: tembak-tembakan, 3 darah/pemain, 1-5 kemenangan round = menang match (diatur di menu BATTLE, default 3)
- Map (7): Earth, Hell (lava), Snow (air es + es licin + bongkahan hanyut), Desert (platform rapuh + kaktus), Jungle (jamur pantul + kayu bergerak), Safari (duri + platform bergerak), Temple (duri + panah dinding + piramida)
- Senjata utama (dipilih di SELECT): Smith, Kurval, Flamer, Scream. Pistol = cadangan otomatis saat peluru Scream habis. Pisau (knife) dimiliki semua pemain, ganti dengan tombol KNIFE.
- Power up (muncul acak di arena):
  - Speed Boost (10 detik) & Jump Boost (10 detik)
  - Heal: langsung +1 darah
  - Shield (7 detik): menahan 2 damage apa pun (peluru, pisau, panah, lava, duri, jatuh), lalu pecah; darah tidak berkurang selama shield ada
  - Invisible (3 detik): pemain menghilang
  - Ammo Refill: peluru senjata utama penuh lagi (Scream yang sedang memakai pistol kembali ke Scream dengan 3 peluru)
  - Swap Position (3 detik): tidak bisa menembak; tekan tembak untuk mengacak posisi semua pemain yang hidup, atau tunggu sampai habis
- Tambah power up baru: ikon `assets/sprites/powerups/<nama>.png`, tambah `<nama>` ke `POWERUP_TYPES` (game.gd) dan `apply_powerup` (player.gd)
- Waktu habis: darah terbanyak menang; seri → SUDDEN DEATH

## Kontrol
| Pemain | Gerak | Lompat | Turun platform | Tembak | Pisau (ganti) |
|---|---|---|---|---|---|
| P1 | A / D | W | S | F | G |
| P2 | ← / → | ↑ | ↓ | / | . |
| P3 | J / L | I | K | H | U |
| P4 | Numpad 4 / 6 | Numpad 8 | Numpad 5 | Numpad 0 | Numpad . |

Gamepad: controller ke-N yang terhubung = pemain ke-N (otomatis, hot-plug). Boleh banyak controller sekaligus.
- Gerak: stick kiri / D-pad, Lompat: ✕ (A) / D-pad atas / L1, Turun: stick/D-pad bawah
- Tembak: □ (X), Pisau: △ (Y), Pause: OPTIONS (Start)
- Semua menu (Main Menu, Select Fighter, Pause) bisa dipakai dengan controller; glyph tombol berganti otomatis PlayStation/Xbox/keyboard.
ESC = pause.

## Struktur
- `scripts/global.gd`  autoload: data karakter/senjata/map, audio, setting, helper UI
- `scripts/map_data.gd` layout tiap map (tambah map baru di sini + aktifkan di `Global.MAPS`)
- `scripts/hazards.gd` semua rintangan (platform bergerak/rapuh, duri, jamur pantul, panah dinding, es, partikel)
- `scripts/player.gd`, `bullet.gd`, `powerup.gd`, `game.gd`, `menu.gd`, `select.gd`
- `assets/` sprite, musik (OGG), sfx, font

## Menambah konten nanti
- **Map baru**: tambah fungsi di `map_data.gd`, set `enabled: true` di `Global.MAPS`
- **Senjata baru**: tambah entri di `Global.WEAPONS` (damage, ammo, cooldown, auto, ...) + masukkan id ke `WEAPON_ORDER`; efek visual di `scripts/weapon_fx.gd`
- **Power up baru**: tambah ikon di `assets/sprites/powerups`, tambah ke `POWERUP_TYPES` (game.gd) dan `apply_powerup` (player.gd)
- Nama game: ubah `GAME_TITLE` di `global.gd` (logo menu: `assets/sprites/ui/title.png`, icon app: `icon.jpg`)

Catatan lisensi: font Badaboom (Blambot) hanya untuk proyek non-profit/sesuai lisensinya, lihat `assets/fonts/badaboom_license.txt`.


## UI baru
- `scripts/ui_input.gd` (autoload `UIInput`): input terpadu semua controller + keyboard, auto-repeat, notifikasi controller terhubung/terputus, getar.
- `scripts/ui_kit.gd` (class `UIKit`): komponen UI (tombol miring, glyph tombol PS, prompt bar, background animasi, poster karakter, transisi layar).
- Setting baru: Music, Sound FX, Vibration, Screen Shake, Fullscreen (tersimpan).


## Choose Your Fighter + Battle Settings
**Layar CHOOSE YOUR FIGHTER** (`scripts/select.gd`, gaya fighting game PS)
- Grid 4x4 berisi SEMUA 16 karakter; karakter bisa dipakai pemain mana saja (urutan di `Global.CHARACTERS`).
- Tiap pemain punya kursor warna sendiri + panel potret besar (P1/P3 kiri, P2/P4 kanan).
- Satu karakter hanya boleh dipakai satu pemain: yang sudah dikunci diberi lencana pemilik, pemain lain ditolak ("TAKEN BY Px").
- Alur: gerak kursor -> tombol tembak/accept = kunci fighter -> pilih senjata utama (kiri/kanan) -> tombol tembak = READY.
- Kotak RANDOM (atau TAB / Y) mengacak karakter yang masih bebas. Back = batal selangkah.
- Semua READY -> hitung mundur 3-2-1 -> BATTLE SETTINGS (confirm = lewati, back = batalkan).

**Layar BATTLE SETTINGS** (`scripts/battle.gd`, `scenes/battle.tscn`), dari atas ke bawah:
MAP -> TIME (0:30 - 5:00 atau INFINITE) -> ROUNDS (1-4) -> POWER-UPS ON/OFF -> POWER-UP AMOUNT (FEW/NORMAL/MANY/CHAOS) -> POWER-UP LIST -> START.
- POWER-UP LIST: ke-7 power up (heal, jump, speed, shield, invisible, ammo_refill, swap_position) bisa ALLOWED / BANNED (bawaan semua ALLOWED), plus ALLOW ALL / BAN ALL.
- Waktu INFINITE: timer menampilkan simbol tak hingga, ronde berakhir hanya kalau ada pemenang.
- Pengaturan tersimpan otomatis di `user://match.cfg`.
- Power up baru: tambahkan ke `Global.POWERUP_ORDER` + `Global.POWERUPS` (daftar izin dan spawn otomatis ikut).

## Sound per round (round_1 ... round_16)
- Letak file: `assets/sfx/round_<N>.mp3` (boleh juga `.wav` / `.ogg`), contoh `assets/sfx/round_9.mp3` ... `assets/sfx/round_16.mp3`.
- Suara FINAL ROUND: `assets/sfx/final_round.mp3`.
- Cukup taruh file dengan nama itu, game otomatis memakainya (buka project di Godot sekali supaya file di-import).
- Selama `round_9` - `round_16` belum ada, game memakai file round tertinggi yang sudah ada (round_8). Logic: `Global.play_round_sfx()` di `global.gd`, batas `MAX_ROUND_SFX = 16`.
- Menang maksimal 5 round (`Global.MAX_WINS`). FINAL ROUND muncul saat SEMUA pemain sudah punya (target - 1) kemenangan; dengan 4 pemain & target 5 = 16 round dulu, baru final.

## Sound baru (assets/sfx/*.wav, dibuat lewat sintesis, sound lama tetap ada)
UI: ui_hover, ui_move, ui_confirm, ui_back, ui_toggle_on, ui_toggle_off, ui_slider, ui_error, ui_pause, ui_resume, ui_whoosh, ui_ready, ui_start, ui_marimba, ui_panel, count_beep, count_go
Game: timer_tick, timer_urgent, round_win, round_draw, win_pip, pu_spawn, land, respawn, crumble_warn, crumble_fall, bounce_pad, arrow_fire, lava_burn, spike_hit, shield_break, knife_hit, wall_impact, swap_shuffle, alarm_sting, match_fanfare


## Mode CAMPAIGN (single player) - BARU

Menu utama -> CAMPAIGN -> pilih fighter & senjata -> peta level. 35 level di 7 dunia (tiap dunia 5 level, boss di level ke-5).
Kontrol sama dengan P1 di mode versus. Senjata, power up, rintangan, dan peta memakai sistem yang sudah ada.

| File | Fungsi |
|---|---|
| `scripts/campaign.gd` | Alur level: wave, skor, combo, bintang, perk, game over, tamat (mewarisi `game.gd`) |
| `scripts/campaign_data.gd` | Data 35 level, musuh, boss, perk, kesulitan, penyimpanan progres (`user://campaign.cfg`) |
| `scripts/ai_brain.gd` | Otak musuh (input sama seperti pemain) |
| `scripts/nav_map.gd` | Peta navigasi musuh (platform, lompat, jamur pantul) |
| `scripts/campaign_hub.gd` | Layar peta level |
| `assets/sprites/campaign/`, `assets/sprites/powerups/{nuke,freeze}.png` | Ikon perk, bintang, power up baru |
| `assets/sfx/*`, `assets/music/music_{campaign,boss}.ogg` | Suara & musik baru |

Menambah level / musuh / perk: edit `campaign_data.gd` (lihat komentar di bagian atas file).
Power up khusus campaign: NUKE (damage semua musuh) dan FREEZE (musuh membeku 4.5 detik).


## UPDATE: 3 map baru (Ocean, Space, Factory) + 15 level campaign
Map versus kini 10: Earth, Hell, Snow, Desert, Jungle, Safari, Temple, **Ocean, Space, Factory**. Semua simetris kiri-kanan.

| Map | Rintangan baru | Catatan |
|---|---|---|
| OCEAN "Shipwreck Bay" | **Geyser laut** (buih + garis merah dulu, lalu melontarkan ke atas; bisa menyelamatkan dari jurang), **meriam kapal** di kedua dinding, papan lapuk | peluru meriam setinggi dek A/B |
| SPACE "Orbital Station" | **Lift anti-gravitasi** (kolom cahaya biru, selalu aktif), **portal** kiri<->kanan (jeda 1 detik) | lantai penuh tanpa jurang |
| FACTORY "Iron Foundry" | **Ban berjalan** (lantai menyeret ke tengah, dek atas ke luar), **gergaji bulat** di rel | gergaji kena = -1 darah + terpental seperti duri |

Campaign sekarang **10 dunia x 5 level = 50 level** (level 36-50, boss di level 40 / 45 / 50):
SHIPWRECK BAY (CAPTAIN BLACKTIDE), STAR STATION (ALIEN OVERLORD), IRON FOUNDRY (THE IRON TYRANT = boss akhir baru).
Kurva kesulitan level 1-35 tidak berubah; 36-50 melanjutkan ke atas. Save lama yang sudah tamat level 35 otomatis membuka level 36.

File baru/berubah: `scripts/hazards.gd` (UpdraftVent, Portal, Conveyor, SawBlade, kind "cannon"), `map_data.gd`, `game.gd`, `campaign_data.gd`, `campaign.gd`, `campaign_hub.gd`, `battle.gd`, `global.gd`, `assets/sprites/stages/{ocean,space,factory}[_floor].png`.
Perbaikan bug lama: `campaign.gd` gagal dimuat karena variabel `kills` bentrok dengan `game.gd` -> diganti `kill_total`.
Buka project di Godot sekali supaya gambar baru di-import.


## Campaign: 5 CHAPTER (250 level)
- Chapter 1 FIRST BLOOD (level 1-50), Chapter 2 AFTERSHOCK (51-100), Chapter 3 LAST SIEGE (101-150), Chapter 4 DARK HORIZON (151-200), Chapter 5 NO MERCY (201-250). Tiap chapter mengulang 10 dunia x 5 level; nomor level di layar kembali ke 1 di tiap chapter.
- Chapter 2 & 3 memakai map varian (`scripts/map_variants.gd`), Chapter 4 & 5 memakai 20 map baru (`scripts/map_variants_late.gd`: tata letak, rintangan & warna berbeda; semua simetris kiri-kanan, platform terjangkau lompatan, spawn bebas rintangan).
- Musuh elit: VETERAN, ASSASSIN, MARKSMAN, JUGGERNAUT. Total 50 boss (1 per dunia per chapter); Chapter 4 & 5 punya 20 boss baru (IRON CONSUL ... THE FINAL ENGINE).
- Keseimbangan: komposisi musuh Chapter 4 / 5 dihitung dari anggaran ancaman Chapter 3 pada posisi yang sama (x1.06 / x1.12), tiap dunia mulai lebih ringan lalu menanjak sampai boss. `CampaignData.difficulty()`: Ch2 0.42-1.30, Ch3 0.62-1.40, Ch4 0.78-1.46, Ch5 0.92-1.52.
- Pilih chapter di LEVEL MAP: pelat CHAPTER di atas peta (panah kiri / kanan, chip nomor 1-5 yang bisa diklik; gembok = terkunci, bintang = tamat; arahkan kursor ke chip untuk melihat nama chapter), roda mouse di atas pelat, TAB / Y (controller) = chapter berikutnya, PageUp / PageDown = sebelumnya.
- Chapter terbuka setelah level terakhir chapter sebelumnya (boss) ditamatkan. Save lama tetap kompatibel; yang sudah tamat Chapter 3 otomatis membuka Chapter 4.
- Tambah level: edit `_levels_ch2()` ... `_levels_ch5()` di `campaign_data.gd`.


## SHOP, INVENTORY & KOIN (BARU)

**Koin** didapat dari menyelesaikan level CAMPAIGN (`Cosmetics.award_level()` di `scripts/cosmetics.gd`):
- Nilai dasar level = `60 + 1.2 x nomor level` (boss x1.5), dikali bintang: 1* x1.0, 2* x1.35, 3* x1.8.
- Pertama kali selesai = nilai penuh. Main ulang = hanya 20% (minimal 5 koin).
- Kalau bintang naik dibanding sebelumnya, selisih nilainya dibayarkan juga (mengejar bintang tetap terasa).
- Hasilnya tampil sebagai baris **COINS** di panel LEVEL CLEAR. Saldo koin ada di Shop & tombol Shop di menu.
- Save: `user://cosmetics.cfg` (terpisah dari `campaign.cfg`).

**Tombol SHOP & INVENTORY** ada di menu utama, terpisah di kanan bawah (tekan KANAN dari daftar menu, atau klik mouse).

**SHOP** (`scenes/shop.tscn`): tab Character Skins / Weapon Skins / Accessories. Skin karakter dibeli PER karakter (24 x 10 = 240),
skin senjata 6 senjata x 5 = 30, aksesoris 31 buah (slot HEAD / FACE / NECK / BACK). Harga mengikuti rarity
(common / rare / epic / legendary) dan desainnya.

**INVENTORY** (`scenes/inventory.tscn`):
- ACCESSORIES: pilih karakter + skin, lalu pasang aksesoris per slot. Tiap karakter dan tiap skin menyimpan set sendiri
  (aksesoris yang sama boleh dipakai di banyak karakter). Ada pratinjau langsung.
- CHARACTER SKINS / WEAPON SKINS: lihat yang dimiliki dan yang masih terkunci.
- Skin **PISTOL** dan **PISAU** diganti di sini (dua senjata ini tidak ada di layar pilih karakter).

**Memakai skin** (Campaign & Versus, layar Choose Your Fighter): kunci karakter -> pilih skin karakter (kalau punya) ->
pilih senjata -> pilih skin senjata (kalau punya) -> READY. Kalau tidak punya skin, tahap itu dilewati otomatis.
Pilihan terakhir diingat; campaign memakai pilihan terakhir tersebut.

**File baru**: `scripts/cosmetics.gd` (ekonomi, save, tekstur), `scripts/cosmetics_data.gd` (katalog; DIHASILKAN),
`scripts/cosmetic_ui.gd` (layar Shop/Inventory + tombol dock), `scripts/shop.gd`, `scripts/inventory.gd`.
**Aset**: `assets/sprites/skins/<karakter>/<skin>.png (+_die)`, `assets/sprites/weaponskins/<senjata>/<skin>.png`,
`assets/sprites/accessories/<id>.png`, `assets/sprites/ui/coin.png`.

**Membuat ulang / menambah aset**: `cd tools && python3 gen_all.py` (butuh Python 3, Pillow, numpy, opencv-python).
Tema skin ada di `tools/skins.py`, skin senjata di `tools/weaponskins.py`, aksesoris di `tools/accessories.py`.
Katalog `scripts/cosmetics_data.gd` ikut dibuat ulang otomatis.

Catatan: buka project di Godot sekali supaya PNG baru di-import (butuh beberapa menit karena ada ~750 gambar baru).
