# server-setup

> Provisioning remote server jadi gampang. Modal cuma **internet + git**.

Sekumpulan script idempotent untuk menyiapkan server baru (saat ini: **Ubuntu**)
dengan paket sistem, tool CLI, runtime/SDK, dan dotfiles — sekali jalan, aman
diulang. Dirancang biar dari server kosong cukup satu baris perintah.

- ✅ **Idempotent** — aman dijalankan berkali-kali, yang sudah ada di-skip.
- ✅ **Modular** — pilih per-server module mana yang dipasang.
- ✅ **Multi-OS ready** — dispatcher deteksi OS otomatis (Ubuntu sekarang, OS lain tinggal nambah).
- ✅ **Non-interaktif friendly** — cocok untuk `curl | bash` maupun otomasi.

---

## Persyaratan

- Koneksi **internet**.
- **git** (kalau belum ada, `bootstrap.sh` coba memasangnya otomatis via apt/dnf/pacman).
- User **biasa yang punya `sudo`** — **jangan jalankan sebagai root**.
- OS **Ubuntu** (turunan seperti Linux Mint / Pop!_OS di-route otomatis lewat dispatcher).

---

## Quick start

### Cara 1 — satu baris dari nol (rekomendasi)

Di server yang baru, cukup:

```bash
curl -fsSL https://raw.githubusercontent.com/albertparlys/server-setup/main/bootstrap.sh | bash
```

`bootstrap.sh` akan: pasang git kalau perlu → clone repo ke `~/server-setup` →
jalankan `setup.sh`.

Mau pilih module tertentu? Teruskan argumen dengan `-s --`:

```bash
# default + uv, rust, docker
curl -fsSL https://raw.githubusercontent.com/albertparlys/server-setup/main/bootstrap.sh | bash -s -- uv rust docker

# HANYA uv (abaikan default)
curl -fsSL https://raw.githubusercontent.com/albertparlys/server-setup/main/bootstrap.sh | bash -s -- --only uv
```

> 🔒 **Keamanan:** `curl | bash` artinya Anda mempercayai isi script. Disarankan
> baca dulu `bootstrap.sh`/`setup.sh` di repo ini, atau pakai Cara 2 (clone) supaya
> bisa diperiksa sebelum dijalankan.

### Cara 2 — clone dulu, jalankan kemudian

```bash
git clone https://github.com/albertparlys/server-setup.git
cd server-setup
bash setup.sh                 # auto-deteksi OS, pakai default
```

---

## Pemakaian

Semua perintah lewat `setup.sh` (dispatcher). Argumen diteruskan apa adanya ke
script OS yang sesuai.

```bash
bash setup.sh                  # default module untuk OS terdeteksi
bash setup.sh uv go docker     # default + uv, go, docker
bash setup.sh --only uv rust   # HANYA uv & rust (abaikan default)
bash setup.sh --menu           # menu interaktif (whiptail/fzf/angka)
bash setup.sh --defaults       # paksa default, lewati menu
bash setup.sh --list           # daftar semua module
bash setup.sh --no-apt         # lewati paket apt
bash setup.sh --no-brew        # lewati Homebrew + formula
bash setup.sh --list-os        # OS yang punya script di repo ini
bash setup.sh --help           # bantuan
```

Default module: **nvm, pnpm, dotfiles**.

---

## Module yang tersedia

| Module       | Default | Memasang                                   |
| ------------ | :-----: | ------------------------------------------ |
| `nvm`        |   ✅    | Node.js via nvm + versi LTS                |
| `pnpm`       |   ✅    | pnpm package manager                       |
| `dotfiles`   |   ✅    | aliases (bash/zsh) + `~/.tmux.remote.conf` |
| `uv`         |    —    | uv — Python pkg/proj manager (Astral)      |
| `rust`       |    —    | Rust via rustup (+ cargo)                  |
| `go`         |    —    | Go toolchain dari go.dev                   |
| `bun`        |    —    | Bun runtime                                |
| `deno`       |    —    | Deno runtime                               |
| `fvm`        |    —    | Flutter Version Management (`~/fvm/bin`)    |
| `composer`   |    —    | PHP Composer (butuh `php`)                  |
| `docker`     |    —    | Docker Engine (+ user ke grup docker)      |
| `php` †      |    —    | PHP cli + ekstensi umum                     |
| `postgres` † |    —    | PostgreSQL server + client                  |
| `mariadb` †  |    —    | MariaDB server + client                     |

† Module khusus Ubuntu (berbasis apt). Detail & cek idempotensi tiap module:
**[docs/modules.md](docs/modules.md)**.

Contoh box dev penuh:

```bash
bash setup.sh uv rust go php composer fvm docker postgres mariadb
```

### Paket yang selalu dipasang

- **apt:** `build-essential procps curl file git ca-certificates unzip gnupg pass tmux btop net-tools htop ncdu iotop sysstat iftop nethogs ripgrep jq httpie`
- **brew:** `fzf zoxide bat eza fd lazygit git-delta tealdeer neovim`

  > Nama binary: `bat`, `eza`, `fd`, `rg` (ripgrep), `delta` (git-delta), `tldr` (tealdeer), `nvim` (neovim), `http`/`https` (httpie).

Daftar ini diatur di bagian `KONFIGURASI` pada [`scripts/setup-ubuntu.sh`](scripts/setup-ubuntu.sh) — tinggal tambah nama paket.

---

## Struktur repo

```
server-setup/
├── bootstrap.sh          # entry curl|bash: pasang git → clone → setup.sh
├── setup.sh              # dispatcher: deteksi OS → scripts/setup-<id>.sh
├── lib/                  # helper reusable (di-source, lintas-OS)
│   ├── common.sh         #   logging, have(), ARCH, inject_block, in_arr
│   ├── modules.sh        #   semua mod_* + setup_shell_env + MOD_DESC
│   └── menu.sh           #   list_modules, choose_modules (menu interaktif)
├── scripts/
│   └── setup-ubuntu.sh   # provisioner Ubuntu (konfigurasi + alur apt/brew)
├── docs/                 # dokumentasi
├── examples/             # skenario pemakaian
├── README.md  CLAUDE.md  LICENSE  .gitignore  .editorconfig
```

Alur eksekusi: **`bootstrap.sh`** → **`setup.sh`** (deteksi OS) → **`scripts/setup-<os>.sh`** (men-source **`lib/`**).

---

## Mengembangkan

- **Nambah paket/module di Ubuntu** → [docs/adding-a-module.md](docs/adding-a-module.md)
- **Nambah OS baru** (debian, fedora, dll) → [docs/adding-an-os.md](docs/adding-an-os.md)
- **Contoh pemakaian** → [examples/](examples/)

---

## Catatan

- Setelah selesai, muat ulang shell: `source ~/.bashrc` (atau logout & SSH lagi).
- Module **docker**: butuh logout/login agar bisa `docker` tanpa `sudo`.
- Module **dotfiles**: `pass` butuh GPG key dulu (`gpg --full-generate-key` lalu `pass init <key>`).

---

## Lisensi

[MIT](LICENSE).
