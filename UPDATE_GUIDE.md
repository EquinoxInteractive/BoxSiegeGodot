# Auto Update BoxSiege

Urutan saat game dibuka: **Splash → Pengecek Update → Loading Screen → Menu**.

- Ada versi baru di GitHub → kartu **UPDATE TERSEDIA**. Pemain harus menekan **UPDATE SEKARANG** (progress bar, verifikasi SHA-256, pasang, game dibuka ulang otomatis) atau **KELUAR** (game ditutup). Tidak ada tombol lewati.
- Sudah terbaru → centang hijau sebentar → loading screen.
- Tidak ada internet / GitHub tidak menjawab → game tetap dibuka (game ini offline-friendly).

## 1. Setup satu kali
1. Buka `scripts/update_config.gd`, isi `GITHUB_OWNER` dan `GITHUB_REPO` (repository harus **Public**).
2. Versi game ada di `project.godot` → `config/version="3.5.0"`. Ini patokan yang dibandingkan dengan tag rilis.
3. Export dengan `binary_format/embed_pck=true` (Windows & Linux) — sudah begitu di `export_presets.cfg`.
4. Rilis pertama (yang sudah berisi fitur ini) harus dibagikan manual ke pemain, karena versi lama belum punya updater.

## 2. Setiap kali merilis update
1. Naikkan versi di `project.godot`, misalnya `3.5.1`.
2. Export 3 platform.
3. Di GitHub: **Releases → Draft a new release**, tag `v3.5.1` (harus sama dengan versi di project, boleh pakai awalan `v`).
4. Isi deskripsi rilis — ini tampil sebagai **APA YANG BARU** (Markdown sederhana didukung: `## Judul`, `- poin`).
5. Upload file (nama bebas, dikenali dari akhiran):

| Platform | File | Catatan |
|---|---|---|
| Windows | `BoxSiege.exe` | hasil export Windows |
| Linux | `BoxSiege.x86_64` | hasil export Linux |
| macOS | `BoxSiege.zip` | hasil export macOS (berisi `BoxSiege.app`) |

Jika memakai ZIP untuk Windows/Linux, beri kata `windows` / `linux` pada nama ZIP; di dalamnya harus ada `.exe` / `.x86_64`.
6. **Publish release**. Jangan centang Pre-release (kecuali `INCLUDE_PRERELEASE = true`).

## 3. Catatan penting
- **macOS**: jalankan game dari `BoxSiege.app` yang sudah dipindah ke Applications/Desktop (bukan langsung dari Downloads/ZIP). Kalau tidak, game akan menampilkan petunjuk memindahkannya.
- **Windows/Linux**: folder game harus bisa ditulis (bukan `Program Files`).
- Batas GitHub API tanpa login 60 permintaan/jam per IP; jika terlewati game dianggap offline dan tetap berjalan.
- Cek update tidak jalan di Godot Editor. Untuk melihat tampilannya isi `EDITOR_SIMULATE` di `update_config.gd` (`"update"`, `"uptodate"`, `"offline"`, `"error"`, `"blocked"`), lalu kosongkan lagi.
- Matikan fitur: `ENABLED := false`.
- Teks "VERSION" di halaman About (`about_data.gd`, saat ini "Beta 3.5") ditulis manual; sesuaikan tiap rilis.

## 4. File yang ditambahkan
`scripts/update_config.gd` (pengaturan), `scripts/update_core.gd` (logika & pemasang per OS), `scripts/updater.gd` + `scenes/updater.tscn` (tampilan), `scripts/splash.gd` (diubah: lanjut ke updater), `project.godot` (versi).
