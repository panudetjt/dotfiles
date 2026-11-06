#!/bin/sh
# ติดตั้ง mise แบบ zero-trust: โหลด binary เวอร์ชัน pin ตรงจาก GitHub Releases
# แล้วเทียบ sha256 กับ install/mise-pinned.sha256 — ไม่ผ่าน = หยุด — ไม่มี curl|sh
# รันจาก root ของ repo นี้: ./install.sh
set -eu
VER=2026.10.15
case "$(uname -s)" in
    Darwin)
        [ "$(uname -m)" = arm64 ] || { echo "mise pin ไม่มี darwin-x64 — เพิ่มใน install/mise-pinned.sha256 ก่อน" >&2; exit 1; }
        asset="mise-v$VER-macos-arm64"
        expect="826c4833fa7437a63f6027b86bc10c8b61b1163dc793c03ecde92f68ad167890"
        ;;
    Linux)
        if [ -e /lib/ld-musl-x86_64.so.1 ] || ldd --version 2>/dev/null | grep -q musl; then
            asset="mise-v$VER-linux-x64-musl"
            expect="5daa5f70c1588bb27ffecb275b46dbafcab0f6fc93a893138ba4d8cae6074b60"
        else
            asset="mise-v$VER-linux-x64"
            expect="e3b186d4c70627f27037be615becaf4acfb30e41fb6a1819486717dc94e4e2a9"
        fi
        ;;
    *) echo "OS ไม่รองรับ: $(uname -s)" >&2; exit 1 ;;
esac
if command -v mise >/dev/null 2>&1 && [ "$(mise --version | grep -oE '[0-9]{4}[.][0-9]{2}[.][0-9]+' | head -1)" = "$VER" ]; then
    echo "mise v$VER มีอยู่แล้ว — ข้าม"
    exit 0
fi
dl() { if command -v curl >/dev/null 2>&1; then curl -fsSL -o "$2" "$1"; else wget -qO "$2" "$1"; fi; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
dl "https://github.com/jdx/mise/releases/download/v$VER/$asset" "$tmp/mise"
actual="$(sha256sum "$tmp/mise" | cut -d' ' -f1)"
if [ "$actual" != "$expect" ]; then
    echo "sha256 MISMATCH ($actual != $expect) — ไฟล์ไม่ตรงที่ pin ไว้ หยุดติดตั้ง" >&2
    exit 1
fi
mkdir -p "$HOME/.local/bin"
install -m 0755 "$tmp/mise" "$HOME/.local/bin/mise"
echo "mise installed (pinned + checksum verified): $($HOME/.local/bin/mise --version)"
