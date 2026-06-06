# Contoh Pemakaian

Skenario nyata, tinggal copy-paste. Ganti URL raw kalau fork/branch berbeda.

`RAW` = `https://raw.githubusercontent.com/albertparlys/server-setup/main/bootstrap.sh`

## Dari nol (server baru) — `curl | bash`

```bash
# Default (nvm + pnpm + dotfiles)
curl -fsSL "$RAW" | bash

# Server Node.js
curl -fsSL "$RAW" | bash -s -- nvm pnpm

# Box dev lengkap
curl -fsSL "$RAW" | bash -s -- uv rust go docker bun deno

# Python-only (cuma uv, tanpa default)
curl -fsSL "$RAW" | bash -s -- --only uv

# Dari branch lain, ke folder khusus
curl -fsSL "$RAW" | REPO_REF=dev DEST_DIR=/opt/server-setup bash -s -- docker
```

> `-s --` artinya: argumen sesudahnya diteruskan ke `setup.sh`.

## Sudah clone repo

```bash
cd server-setup

bash setup.sh                    # auto-deteksi OS, default
bash setup.sh uv go docker       # default + uv, go, docker
bash setup.sh --only nvm pnpm    # HANYA node stack
bash setup.sh --menu             # pilih lewat menu interaktif
bash setup.sh --defaults         # default, tanpa menu (cocok untuk skrip)
bash setup.sh --no-brew uv       # lewati Homebrew, pasang uv
```

## Inspeksi tanpa mengubah apa pun

```bash
bash setup.sh --list             # daftar module
bash setup.sh --list-os          # OS yang didukung
bash setup.sh --help             # bantuan
```

## Banyak server sekaligus

```bash
for host in web1 web2 db1; do
  ssh "$host" 'curl -fsSL "https://raw.githubusercontent.com/albertparlys/server-setup/main/bootstrap.sh" | bash -s -- --defaults docker'
done
```

## Pola lama (scp satu file) — masih bisa

Karena `setup-ubuntu.sh` kini men-source `lib/`, untuk pola scp salin folder repo,
bukan satu file:

```bash
rsync -a server-setup/ user@host:~/server-setup/
ssh user@host 'bash ~/server-setup/setup.sh --defaults'
```
