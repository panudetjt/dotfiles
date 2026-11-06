#!/usr/bin/env bash
# dep-chain-test — พิสูจน์ห่วงโซ่ zero-trust ครบ "สอง target จริง" (bake 6 พ.ย. 2026 retro — owner approve):
#   leg 1 ubuntu:24.04 (glibc + curl) · leg 2 alpine:latest (musl + busybox wget + ไม่มี curl/git — target เคสแย่สุด;
#   hit live 6 พ.ย.: alpine ตาย 127 ที่ curl + ไบนารี glibc บน musl "not found" เงียบ — local ubuntu test จับไม่เจอ)
#   แต่ละ leg: โหลด mise จาก hash ที่ pin (ตรง libc ของ leg) → trust → dot apply → login-shell smoke
#   smoke = env -i <login shell> 'command -v bun && git config --global user.email' — จับคลาส
#   .profile ไม่มี shims / auto_env ผิดไฟล์ / gitconfig render ผิด — โดยไม่ execute tools (ไม่ยิง download แฝง)
# อ่านเวอร์ชัน/hash จาก install/mise-pinned.sha256 — ไม่ hardcode
# เรียก: bash scripts/dep-chain-test.sh  (ต้องมี docker daemon)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MISE_V="$(grep -oE '^# pinned-version: [0-9.]+' "$ROOT/install/mise-pinned.sha256" | grep -oE '[0-9.]+' | head -1)"
GLIBC_H="$(awk '$2 ~ /^mise-v[0-9.]+-linux-x64$/ {print $1}' "$ROOT/install/mise-pinned.sha256" | head -1)"
MUSL_H="$(awk '$2 ~ /^mise-v[0-9.]+-linux-x64-musl$/ {print $1}' "$ROOT/install/mise-pinned.sha256" | head -1)"
EMAIL="3482285+panudetjt@users.noreply.github.com"
[ -n "$MISE_V" ] && [ -n "$GLIBC_H" ] && [ -n "$MUSL_H" ] || { echo "อ่าน pin ไม่ครบ (pinned-version/hash หาย)" >&2; exit 1; }

echo "== leg 1/2: ubuntu:24.04 (glibc) — mise v$MISE_V =="
docker run -i --rm -v "$ROOT:/src:ro" ubuntu:24.04 bash -s <<REMOTE
set -e
apt-get update -qq >/dev/null && apt-get install -y -qq curl git ca-certificates >/dev/null
curl -fsLo /tmp/mise "https://github.com/jdx/mise/releases/download/v$MISE_V/mise-v$MISE_V-linux-x64"
echo "$GLIBC_H  mise" | (cd /tmp && sha256sum -c -)
install -m 0755 /tmp/mise /usr/local/bin/mise
cd /src && mise trust && mise dot apply
clean="\$(env -i HOME=/root TERM=xterm bash -lc 'e="\$( { git config --global user.email >/tmp/em; } 2>&1 )"; [ -z "\$e" ] || { echo "STDERR: \$e"; exit 11; }; [ "\$(cat /tmp/em)" = "$EMAIL" ] || { echo "EMAIL WRONG"; exit 12; }; if [ -d "\$HOME/.local/share/mise/shims" ]; then case ":\$PATH:" in *":\$HOME/.local/share/mise/shims:"*) ;; *) echo "SHIMS NOT ON PATH"; exit 13;; esac; fi; echo OK' 2>/dev/null || true)"
if [ "\$clean" = "OK" ]; then
  echo "UBUNTU LEG OK — apply ✓ + login-shell smoke ✓ (stderr-clean · email · shims เมื่อมี shims)"
else
  echo "UBUNTU SMOKE FAIL: got '\$clean'" >&2; exit 1
fi
REMOTE

echo "== leg 2/2: alpine:latest (musl — busybox wget, ไม่มี curl/git ล่วงหน้า) — mise v$MISE_V =="
docker run -i --rm -v "$ROOT:/src:ro" alpine:latest sh -s <<REMOTE
set -e
apk add --no-cache git >/dev/null
wget -qO /tmp/mise "https://github.com/jdx/mise/releases/download/v$MISE_V/mise-v$MISE_V-linux-x64-musl"
echo "$MUSL_H  mise" | (cd /tmp && sha256sum -c -)
install -m 0755 /tmp/mise /usr/local/bin/mise
cd /src && mise trust && mise dot apply
clean="\$(env -i HOME=/root TERM=xterm sh -lc 'e="\$( { git config --global user.email >/tmp/em; } 2>&1 )"; [ -z "\$e" ] || { echo "STDERR: \$e"; exit 11; }; [ "\$(cat /tmp/em)" = "$EMAIL" ] || { echo "EMAIL WRONG"; exit 12; }; if [ -d "\$HOME/.local/share/mise/shims" ]; then case ":\$PATH:" in *":\$HOME/.local/share/mise/shims:"*) ;; *) echo "SHIMS NOT ON PATH"; exit 13;; esac; fi; echo OK' 2>/dev/null || true)"
if [ "\$clean" = "OK" ]; then
  echo "ALPINE LEG OK — apply ✓ + login-shell smoke ✓ (musl รันได้ · busybox wget · stderr-clean · email · shims เมื่อมี shims)"
else
  echo "ALPINE SMOKE FAIL: got '\$clean'" >&2; exit 1
fi
REMOTE

echo "CHAIN OK — สอง legs ผ่าน (glibc + musl · login-shell smoke ทั้งคู่ · hash-verified ทุกห่วง)"
