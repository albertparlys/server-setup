# Menambah Dukungan OS Baru

Dispatcher [`setup.sh`](../setup.sh) memetakan `ID` dari `/etc/os-release` ke
`scripts/setup-<id>.sh`. Jadi menambah OS = **membuat satu file** dengan nama
yang benar; dispatcher otomatis menemukannya.

## 1. Cari `ID` OS target

Di mesin OS tersebut:

```bash
. /etc/os-release && echo "$ID  (ID_LIKE=$ID_LIKE)"
# contoh: debian, fedora, arch, almalinux, opensuse-leap
```

Nama file harus persis `scripts/setup-$ID.sh`.

> **ID_LIKE:** turunan otomatis dapat fallback tanpa file baru. Misal Raspberry Pi
> OS (`ID=raspbian`, `ID_LIKE=debian`) akan memakai `scripts/setup-debian.sh` bila
> ada. Jadi bikin script untuk **distro induk** sering kali sudah cukup.

## 2. Salin orchestrator Ubuntu sebagai template

```bash
cp scripts/setup-ubuntu.sh scripts/setup-debian.sh   # contoh: debian
```

## 3. Sesuaikan bagian spesifik OS

Yang **reusable tetap dipakai apa adanya** (di-source dari `lib/`): semua `mod_*`,
`setup_shell_env`, menu, dan helper. Yang perlu diganti di file baru:

- **Header & `usage()`** — ganti "Ubuntu" → nama OS.
- **Guard OS** — ganti cek `[ "$ID" = "ubuntu" ]` jadi `ID` yang sesuai (atau
  longgarkan ke `$ID_LIKE`). Tetap larang root + wajib `sudo`.
- **Package manager** — ganti blok `apt-get` dengan padanannya:
  - Debian: sama seperti Ubuntu (`apt-get`), nama paket bisa beda sedikit.
  - Fedora/RHEL: `sudo dnf install -y ...`
  - Arch: `sudo pacman -Sy --noconfirm ...`
  - openSUSE: `sudo zypper install -y ...`
- **`APT_PKGS`** — sesuaikan nama paket ke repo OS itu (mis. `net-tools` vs
  `iproute2`). Pertahankan blok `BREW_PKGS` kalau Homebrew dipakai juga.

Pertahankan pola: parse arg → guard → package manager → loop `MODULES` →
`setup_shell_env`, dan tetap **idempotent**.

## 4. Verifikasi dispatcher menemukannya

```bash
bash setup.sh --list-os     # OS baru harus muncul
bash -n scripts/setup-debian.sh
shellcheck scripts/setup-debian.sh   # kalau ada
```

## 5. Update dokumentasi

- Tabel/keterangan OS di [`README.md`](../README.md).
- Sebutkan paket khusus OS bila ada di [`docs/modules.md`](modules.md).
