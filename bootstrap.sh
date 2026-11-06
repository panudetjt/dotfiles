#!/bin/sh
# bootstrap.sh — คำสั่งเดียวตั้งเครื่องใหม่ทั้งชุด (แบบ mise.run)
#
#   curl -fsLS https://raw.githubusercontent.com/panudetjt/dotfiles/main/bootstrap.sh | sh
#
# ทำอะไร: clone dotfiles → ติดตั้ง mise แบบ zero-trust (pin + sha256) → trust → dot apply
#         → wizard เลือก tier (mobile/rust — interactive เมื่อมี terminal)
# ข้อกำหนด: curl หรือ wget (mise.run ก็เหมือนกัน) · ทุกอย่างอยู่ใน $HOME ไม่ใช้ sudo
# ความเชื่อถือ: script นี้สั้น อ่านก่อน pipe ได้ (curl -fsLS <url เดียวกัน> แล้วอ่าน) —
#              ไบนารี mise ที่โหลดต่อ ผ่าน sha256 ที่ pin ใน repo (install.sh ตรวจให้)
set -eu

REPO="https://github.com/panudetjt/dotfiles.git"
TARGET="${DOTFILES_DIR:-$HOME/src/dotfiles}"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }

dl() { if command -v curl >/dev/null 2>&1; then curl -fsSL "$1"; else wget -qO- "$1"; fi }
dl_to() { if command -v curl >/dev/null 2>&1; then curl -fsSL -o "$2" "$1"; else wget -qO "$2" "$1"; fi }

command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || {
    echo "ต้องมี curl หรือ wget ก่อน (เช่น: apt install curl)" >&2; exit 1; }

# ---------- 1) ได้ repo มาไว้ ~/src/dotfiles ----------
if [ -d "$TARGET/.git" ]; then
    say "repo มีอยู่แล้วที่ $TARGET — git pull"
    git -C "$TARGET" pull --ff-only
elif command -v git >/dev/null 2>&1; then
    say "clone dotfiles → $TARGET"
    mkdir -p "$(dirname "$TARGET")"
    git clone --depth 1 "$REPO" "$TARGET"
else
    warn "เครื่องนี้ไม่มี git — ใช้ tarball แทน (อัปเดตภายหลังให้ apt/brew install git แล้ว git pull)"
    mkdir -p "$(dirname "$TARGET")"
    dl "https://github.com/panudetjt/dotfiles/archive/refs/heads/main.tar.gz" | tar xz -C "$(dirname "$TARGET")"
    rm -rf "$TARGET" && mv "$(dirname "$TARGET")/dotfiles-main" "$TARGET"
fi

export PATH="$HOME/.local/bin:$PATH"
cd "$TARGET"

# ---------- 2) mise (pinned + sha256 — install.sh ตรวจให้) ----------
if command -v mise >/dev/null 2>&1; then
    say "mise มีอยู่แล้ว: $(mise --version 2>/dev/null | head -1)"
else
    say "ติดตั้ง mise (zero-trust — binary จาก GitHub Releases + sha256 pin)"
    sh install.sh
fi

# ---------- 3) trust + dot apply (แตะเฉพาะไฟล์ที่ประกาศ) ----------
say "trust + deploy dotfiles"
mise trust
if ! mise dot apply; then
    warn "dot apply ไม่ผ่านทั้งหมด — ส่วนใหญ่เพราะมีไฟล์เดิมของเครื่องอยู่ (mise ปฏิเสธทับให้เอง)"
    warn "ดูความต่าง: mise dot diff · เลือกเก็บแล้วรัน mise dot apply ซ้ำ (หรือ --force ถ้ามั่นใจ)"
    warn "ที่เหลือทั้งชุดติดตั้งไปแล้ว — แก้ conflict แล้ว apply เพิ่มได้ภายหลัง"
fi

# ---------- 4) wizard เลือก tier (mobile/rust) — interactive เมื่อมี terminal ----------
say "shell ใหม่จะได้ tools ทันที (mise shims อยู่ใน ~/.profile + activate ใน common.sh)"
if [ -t 0 ] || [ -t 1 ]; then
    say "wizard: เลือก tier ที่เครื่องนี้ต้องใช้ (base node/pnpm/bun ติดตั้งไปแล้ว)"
    sh setup.sh < /dev/tty
else
    warn "(ไม่มี terminal แบบ interactive — ข้าม wizard: รัน ./setup.sh เองเมื่อพร้อมเลือก tier)"
fi

say "เสร็จ! เปิด terminal ใหม่ (หรือ: source ~/.bashrc) แล้วลอง: mise doctor · git config --global user.email"
say "tier เพิ่มภายหลัง: cd $TARGET && ./setup.sh · แก้ config: แก้ใน repo → mise dot diff → mise dot apply"
