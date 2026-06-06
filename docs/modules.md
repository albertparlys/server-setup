# Daftar Module

Module = fungsi `mod_<nama>` di [`lib/modules.sh`](../lib/modules.sh). Semua
**idempotent**: kalau sudah terpasang, dilewati (`skip`).

Lihat module yang tersedia kapan saja:

```bash
bash setup.sh --list
```

## Tabel module

| Module     | Default | Memasang                          | Cek "sudah ada"                       | Lokasi              |
| ---------- | :-----: | --------------------------------- | ------------------------------------- | ------------------- |
| `nvm`      |   ✅    | nvm + Node.js LTS                 | `$NVM_DIR/nvm.sh` ada                  | `~/.nvm`            |
| `pnpm`     |   ✅    | pnpm                              | `have pnpm`                           | `~/.local/share/pnpm` |
| `dotfiles` |   ✅    | aliases + tmux config             | blok bertanda diganti tiap run        | `~/.bashrc`, `~/.tmux.remote.conf` |
| `uv`       |    —    | uv + uvx (Astral)                 | `have uv`                            | `~/.local/bin`      |
| `rust`     |    —    | rustup + cargo                    | `have rustc` atau `~/.cargo` ada      | `~/.cargo`          |
| `go`       |    —    | Go toolchain resmi                | `/usr/local/go/bin/go` ada            | `/usr/local/go`     |
| `docker`   |    —    | Docker Engine + grup docker       | `have docker`                        | sistem              |
| `bun`      |    —    | Bun runtime                       | `have bun`                           | `~/.bun`            |
| `deno`     |    —    | Deno runtime                      | `have deno`                          | `~/.deno`           |
| `fvm`      |    —    | Flutter Version Management        | `~/fvm/bin/fvm` ada                   | `~/fvm`             |
| `composer` |    —    | PHP Composer (butuh `php`)        | `have composer`                       | `/usr/local/bin`    |
| `php` †    |    —    | PHP cli + ekstensi umum           | `have php`                            | sistem (apt)        |
| `postgres` † |  —    | PostgreSQL server + client        | `have psql`                           | sistem (apt)        |
| `mariadb` † |   —    | MariaDB server + client           | `have mariadb`/`mysql`                | sistem (apt)        |

† Module **khusus Ubuntu** (berbasis apt) — didefinisikan di
[`scripts/setup-ubuntu.sh`](../scripts/setup-ubuntu.sh), bukan `lib/modules.sh`.
OS lain mendefinisikan versinya sendiri. Lihat [adding-a-module.md](adding-a-module.md).

## Catatan per module

- **nvm** — ambil tag rilis terbaru dari GitHub API; fallback ke `v0.40.1` bila
  gagal. Setelah pasang, `nvm install --lts` dan set sebagai default.
- **go** — versi diambil dari `https://go.dev/VERSION?m=text`. Arsitektur dipetakan
  dari `ARCH` (`amd64`/`arm64`/`armhf` → `amd64`/`arm64`/`armv6l`). Pakai `sudo`.
- **docker** — pakai installer resmi `get.docker.com`, lalu menambahkan user ke
  grup `docker`. **Perlu logout/login** agar bisa `docker` tanpa `sudo`.
- **dotfiles** — menulis aliases (git/ls/tmux) ke `~/.bashrc` & `~/.zshrc` (kalau
  ada) lewat blok bertanda, plus `~/.tmux.remote.conf` yang di-`source` dari
  `~/.tmux.conf` (tidak menimpa config tmux yang sudah ada).
- **fvm** — installer resmi `fvm.app/install.sh`, user-local ke `~/fvm/bin` (tanpa
  sudo). PATH ditambahkan otomatis oleh `setup_shell_env`.
- **composer** — installer resmi getcomposer.org **dengan verifikasi signature
  SHA-384**; batal kalau checksum tidak cocok. Butuh `php` sudah ada (kalau tidak,
  module ini di-skip). Dipasang ke `/usr/local/bin/composer` (pakai sudo).
- **php** — `php-cli` + ekstensi umum (curl, mbstring, xml, zip, bcmath, intl, gd).
  Di Ubuntu 24.04 = PHP 8.3.
- **postgres** — paket `postgresql` + `postgresql-contrib` bawaan Ubuntu. Cek service:
  `sudo systemctl status postgresql`. Untuk versi terbaru, pakai repo PGDG (manual).
- **mariadb** — `mariadb-server` + `mariadb-client`. Setelah pasang, amankan dengan
  `sudo mariadb-secure-installation`.

## PATH/env

`setup_shell_env` (selalu dijalankan di akhir) menulis satu blok ke `~/.bashrc`
(& `~/.zshrc` bila ada) yang mengatur PATH untuk semua tool di atas plus inisialisasi
`zoxide` dan `fzf`. Blok ini idempotent (diganti tiap run).

Setelah setup: `source ~/.bashrc` atau logout & SSH lagi.
