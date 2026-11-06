#!/bin/sh
# ติดตั้ง mise แบบ zero-trust: โหลด binary เวอร์ชัน pin ตรงจาก GitHub Releases
# แล้วเทียบ sha256 กับ install/mise-pinned.sha256 — ไม่ผ่าน = หยุด — ไม่มี curl|sh
# รันจาก root ของ repo นี้: ./install.sh
set -eu
VER=2026.11.2
case "$(uname -s)" in
    Darwin)
        [ "$(uname -m)" = arm64 ] || { echo "mise pin ไม่มี darwin-x64 — เพิ่มใน install/mise-pinned.sha256 ก่อน" >&2; exit 1; }
        asset="mise-v$VER-macos-arm64"
        expect="90684d13d9125cf207c45b19dbdbf19baf8d5d0e3e10109f236b1b4d027416c0"
        ;;
    Linux)
        if [ -e /lib/ld-musl-x86_64.so.1 ] || ldd --version 2>/dev/null | grep -q musl; then
            asset="mise-v$VER-linux-x64-musl"
            expect="fa4f10af83e7131854ceecdf909fc4e4717c8b4d4eb921cf38451d61f118d267"
        else
            asset="mise-v$VER-linux-x64"
            expect="62cad463c1413f05398ca339168a8f655120b6f0b0b8adce3bc6758bafaf0602"
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
