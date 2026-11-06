#!/usr/bin/env bash
# dep-chain-test — พิสูจน์ห่วงโซ่ zero-trust mise-only ใน container สะอาด (ubuntu:24.04):
#   ติดตั้ง mise จาก hash ที่ pin ใน install/mise-pinned.sha256
#   → trust repo → mise dot apply → ยืนยันไฟล์ที่ render
# อ่านเวอร์ชัน/hash จากไฟล์ pin — ไม่ hardcode
# เรียก: bash scripts/dep-chain-test.sh  (ต้องมี docker daemon)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MISE_V="$(grep -oE '^# pinned-version: [0-9.]+' "$ROOT/install/mise-pinned.sha256" | grep -oE '[0-9.]+' | head -1)"
MISE_H="$(awk '$2 ~ /^mise-v[0-9.]+-linux-x64$/ {print $1}' "$ROOT/install/mise-pinned.sha256" | head -1)"
[ -n "$MISE_V" ] && [ -n "$MISE_H" ] || { echo "อ่าน pin ไม่ครบ" >&2; exit 1; }

docker run -i --rm -v "$ROOT:/src:ro" ubuntu:24.04 bash -s <<REMOTE
set -e
apt-get update -qq >/dev/null && apt-get install -y -qq curl git ca-certificates >/dev/null
echo "== ห่วง 1: mise v$MISE_V จาก hash ที่ pin =="
curl -fsLo /tmp/mise "https://github.com/jdx/mise/releases/download/v$MISE_V/mise-v$MISE_V-linux-x64"
echo "$MISE_H  mise" | (cd /tmp && sha256sum -c -)
install -m 0755 /tmp/mise /usr/local/bin/mise
echo "== ห่วง 2: trust + dot apply =="
cd /src && mise trust && mise dot apply
echo "== ห่วง 3: ยืนยัน =="
email="\$(git config --global user.email)"
[ "\$email" = "3482285+panudetjt@users.noreply.github.com" ] && echo "CHAIN OK — mise v$MISE_V ✓ → trust ✓ → dot apply ✓ (gitconfig rendered ถูกต้อง, hash-verified ทุกห่วง)" || { echo "EMAIL MISMATCH: \$email" >&2; exit 1; }
REMOTE
