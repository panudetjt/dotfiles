#!/usr/bin/env bash
# dep-chain-test — พิสูจน์ห่วงโซ่ zero-trust ครบใน container สะอาด (ubuntu:24.04):
#   ติดตั้ง chezmoi จาก hash ที่ pin ใน install/chezmoi-pinned.sha256
#   → apply dotfiles → run_once ติดตั้ง mise จาก hash ที่ pin → ยืนยันเวอร์ชัน
# อ่านเวอร์ชัน/hash จากไฟล์ pin ทั้งหมด — ไม่ hardcode
# เรียก: bash scripts/dep-chain-test.sh  (ต้องมี docker daemon)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CZ_V="$(grep -oE '^# pinned-version: [0-9.]+' "$ROOT/install/chezmoi-pinned.sha256" | grep -oE '[0-9.]+' | head -1)"
CZ_H="$(awk '$2=="chezmoi-linux-amd64"{print $1}' "$ROOT/install/chezmoi-pinned.sha256")"
MISE_V="$(grep -oE '^# pinned-version: [0-9.]+' "$ROOT/install/mise-pinned.sha256" | grep -oE '[0-9.]+' | head -1)"
[ -n "$CZ_V" ] && [ -n "$CZ_H" ] && [ -n "$MISE_V" ] || { echo "อ่าน pin ไม่ครบ (pinned-version comment หาย?)" >&2; exit 1; }

docker run -i --rm -v "$ROOT:/src:ro" ubuntu:24.04 bash -s <<REMOTE
set -e
apt-get update -qq >/dev/null && apt-get install -y -qq curl git ca-certificates >/dev/null
echo "== ห่วง 1: chezmoi v$CZ_V จาก hash ที่ pin =="
curl -fsLo /tmp/chezmoi "https://github.com/twpayne/chezmoi/releases/download/v$CZ_V/chezmoi-linux-amd64"
echo "$CZ_H  chezmoi" | (cd /tmp && sha256sum -c -)
install -m 0755 /tmp/chezmoi /usr/local/bin/chezmoi
echo "== ห่วง 2: apply dotfiles (run_once ติดตั้ง mise แบบ pinned เอง) =="
chezmoi init --source /src --apply
echo "== ห่วง 3: ยืนยัน =="
got="\$(/root/.local/bin/mise --version | grep -oE '[0-9]{4}[.][0-9]{2}[.][0-9]+' | head -1)"
if [ "\$got" = "$MISE_V" ]; then
  echo "CHAIN OK — chezmoi v$CZ_V ✓ → apply ✓ → mise v\$got ✓ (hash-verified ทุกห่วง ไม่มี curl|sh)"
else
  echo "MISE MISMATCH: ได้ v\$got แต่ pin = v$MISE_V" >&2
  exit 1
fi
REMOTE
