# CLAUDE.md

Panduan untuk Claude Code (claude.ai/code) saat bekerja di repositori ini.

## Apa ini

Kumpulan **script Bash idempotent** untuk provisioning remote server. Bukan
aplikasi — tidak ada build step, tidak ada dependency manager. Tujuan: dari
server kosong (modal **internet + git**) jadi siap pakai lewat satu perintah.

OS yang didukung sekarang: **Ubuntu**. Arsitektur sudah disiapkan multi-OS.

## Arsitektur & alur eksekusi

```
bootstrap.sh  →  setup.sh  →  scripts/setup-<os>.sh  →  source lib/*.sh
(curl|bash)      (dispatcher)   (orchestrator OS)         (helper + module)
```

- **`bootstrap.sh`** — entry `curl | bash`. Pasang git bila perlu, clone repo ke
  `$DEST_DIR` (default `~/server-setup`), lalu `exec setup.sh "$@"`. Dibaca dari
  stdin, jadi **tidak boleh** mengandalkan `$0`/`BASH_SOURCE` untuk lokasi diri.
- **`setup.sh`** — dispatcher. Baca `/etc/os-release`, petakan `$ID` →
  `scripts/setup-$ID.sh`, fallback ke `$ID_LIKE` (set `SETUP_FORCE_OS=1` saat
  fallback). Semua argumen diteruskan apa adanya. Tidak memasang apa pun sendiri.
- **`scripts/setup-<os>.sh`** — orchestrator spesifik OS. Berisi **konfigurasi**
  (`APT_PKGS`, `BREW_PKGS`, `MODULES`) + **alur** (parse arg → guard → package
  manager → loop module → `setup_shell_env`). Men-source `lib/`.
- **`lib/`** — kode reusable lintas-OS, **di-source bukan dieksekusi**:
  - `common.sh` — `log/ok/skip/warn/die`, `have()`, `ARCH`, `inject_block`, `in_arr`.
  - `modules.sh` — semua fungsi `mod_*`, `setup_shell_env`, dan map `MOD_DESC`.
  - `menu.sh` — `list_modules`, `choose_modules` (whiptail → fzf → fallback angka).

## Konvensi (ikuti saat mengedit)

- **Idempotensi wajib.** Setiap pemasangan dibungkus cek lebih dulu (`have <cmd>`,
  `[ -d ... ]`, dll) dan lapor `skip` kalau sudah ada. Asumsikan script dijalankan
  ulang berkali-kali.
- **`set -eo pipefail` hanya di script utama** (`bootstrap.sh`, `setup.sh`,
  `scripts/*.sh`). File `lib/*.sh` **tidak** meng-set opsi shell — cuma mendefinisikan
  fungsi/variabel, dan punya **include guard** (`_RS_*_LOADED`).
- **Komentar berbahasa Indonesia**, gaya santai-teknis seperti kode yang sudah ada.
  Pertahankan nada itu.
- **Logging lewat helper**, bukan `echo` mentah: `log` (langkah), `ok` (sukses),
  `skip` (dilewati), `warn` (peringatan ke stderr), `die` (error + exit).
- **Edit file rc lewat `inject_block`** (blok bertanda `# >>> ... >>>`), supaya
  re-run mengganti blok lama, bukan menumpuk.
- **Letak module berdasarkan portabilitas:**
  - **Lintas-distro** (installer resmi via `curl` ke `$HOME`, dll) → `lib/modules.sh`.
    Contoh: `nvm`, `uv`, `rust`, `go`, `docker`, `fvm`, `composer`.
  - **Spesifik distro** (apt/dnf/pacman) → didefinisikan di `scripts/setup-<os>.sh`,
    dan `MOD_DESC[<nama>]` di-extend di sana juga. Contoh di Ubuntu: `php`,
    `postgres`, `mariadb`. `compgen` tetap menemukannya karena di-define sebelum
    parse argumen.
- **Path lib di-resolve relatif ke diri sendiri**:
  `_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` lalu source dari situ.

## Menambah sesuatu

- **Paket apt/brew (Ubuntu):** tambah nama ke `APT_PKGS`/`BREW_PKGS` di
  `scripts/setup-ubuntu.sh`. Selesai.
- **Module baru:** tulis `mod_<nama>()` di `lib/modules.sh` + daftarkan di
  `MOD_DESC`. Lihat `docs/adding-a-module.md`.
- **OS baru:** salin `scripts/setup-ubuntu.sh` → `scripts/setup-<id>.sh`, ganti
  bagian package manager. Dispatcher otomatis menemukannya. Lihat
  `docs/adding-an-os.md`.

## Validasi (lakukan sebelum menganggap selesai)

```bash
bash -n setup.sh bootstrap.sh scripts/setup-ubuntu.sh   # cek sintaks
shellcheck setup.sh bootstrap.sh scripts/*.sh lib/*.sh  # kalau shellcheck ada
bash scripts/setup-ubuntu.sh --list                     # aman: keluar sebelum guard/instalasi
bash setup.sh --help                                    # aman
```

⚠️ **JANGAN** menjalankan `bash setup.sh` / `setup-ubuntu.sh` tanpa flag aman di
mesin dev — itu **benar-benar memasang** paket & mengubah `~/.bashrc`,
`~/.tmux.conf`, dsb. Yang aman untuk diuji: `--list`, `--help`, `--list-os`,
`-h`, dan `bash -n`.

## Commit

Repo memakai gaya **Conventional Commits** (mis. `feat:`, `fix:`, `docs:`,
`refactor:`). Commit/push **hanya jika diminta** user.
