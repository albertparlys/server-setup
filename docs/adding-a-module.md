# Menambah Module Baru

Module adalah fungsi `mod_<nama>` yang **idempotent** (aman diulang). Karena
di-discover otomatis lewat `compgen -A function`, kamu cuma perlu menulis
fungsinya — tidak ada daftar pusat yang harus diubah selain deskripsi.

## Di mana menaruhnya?

- **Lintas-distro** (installer resmi via `curl`/`tar` ke `$HOME`, tidak terikat
  package manager) → [`lib/modules.sh`](../lib/modules.sh). Contoh: `fvm`, `composer`.
- **Spesifik distro** (pakai `apt-get`/`dnf`/`pacman`) → definisikan di
  [`scripts/setup-ubuntu.sh`](../scripts/setup-ubuntu.sh) (atau script OS terkait),
  pada blok "MODULE KHUSUS UBUNTU", dan extend `MOD_DESC` di situ. Contoh: `php`,
  `postgres`, `mariadb`. Pastikan fungsi didefinisikan **sebelum** blok parse
  argumen agar `--list` dan menu menemukannya.

## Langkah

### 1. Tulis fungsi `mod_<nama>` di `lib/modules.sh`

Pola wajib: **cek dulu, baru pasang**, dan lapor lewat helper (`log/ok/skip`).

```bash
mod_lazygit() {
  if have lazygit; then
    skip "lazygit sudah ada"
    return
  fi
  # ... perintah instalasi ...
  curl -fsSL https://example.com/install.sh | sh
  ok "lazygit"
}
```

Pegangan:

- Pakai `have <cmd>` / `[ -d ... ]` / `[ -x ... ]` untuk deteksi "sudah ada".
- Helper tersedia dari `lib/common.sh`: `log`, `ok`, `skip`, `warn`, `die`,
  `have`, `ARCH`, `inject_block`, `in_arr`.
- Utamakan installer ruang-user (`$HOME`) supaya lintas-distro. Butuh root? pakai
  `sudo` eksplisit (lihat `mod_go`/`mod_docker`).
- Untuk arsitektur, pakai variabel `ARCH` (`amd64`/`arm64`/`armhf`).
- Untuk menambah PATH/env tool ke shell, edit blok di `setup_shell_env`
  (`lib/modules.sh`) — jangan menulis ke rc secara ad-hoc.

### 2. Daftarkan deskripsi di `MOD_DESC`

Di `lib/modules.sh`, tambahkan satu baris (dipakai menu & dokumentasi):

```bash
declare -A MOD_DESC=(
  ...
  [lazygit]="lazygit - TUI untuk git"
)
```

### 3. (Opsional) jadikan default

Kalau ingin terpasang tanpa diminta, tambahkan ke `MODULES` di
[`scripts/setup-ubuntu.sh`](../scripts/setup-ubuntu.sh):

```bash
MODULES=(
  nvm pnpm dotfiles lazygit
)
```

Kalau tidak, user memanggilnya eksplisit: `bash setup.sh lazygit`.

### 4. Update dokumentasi

Tambahkan baris ke tabel di [`docs/modules.md`](modules.md).

### 5. Validasi

```bash
bash -n scripts/setup-ubuntu.sh
shellcheck lib/modules.sh        # kalau ada
bash setup.sh --list             # module baru harus muncul
```

Jangan jalankan instalasi sungguhan di mesin dev kecuali memang mau memasangnya.
