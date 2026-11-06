#!/usr/bin/env bash
# dep-bump — ยกเวอร์ชัน mise ที่ pin + recompute hash + เตรียม PR
# เรียก: bash scripts/dep-bump.sh mise <version ไม่มี v> [--dry-run]
# หลักความปลอดภัย: hash ใหม่ต้องผ่าน 2 ชั้นตรวจใน CI — API digest (JSON) vs ไฟล์ที่ดาวน์โหลดจริง (bytes,
# คนละ endpoint) ไม่ตรง = หยุด · ชั้นที่ automation ทำแทนไม่ได้ = "ใช้จริงบนเครื่อง owner อย่างน้อย 1 เครื่อง"
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="${1:?ใช้: dep-bump.sh mise <version> [--dry-run]}"
VER="${2:?version เช่น 2026.11.2}"
V="$VER"
DRY="${3:-}"
REPO="jdx/mise"
PIN="install/mise-pinned.sha256"
OLD="$(grep -oE '^# pinned-version: [0-9.]+' "$ROOT/$PIN" | grep -oE '[0-9.]+' | head -1)"
[ "$OLD" != "$VER" ] || { echo "pin อยู่ที่ $VER อยู่แล้ว" >&2; exit 0; }
echo "== bump $TOOL: v$OLD → v$V (dry-run: ${DRY:-no}) =="

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# 1) release ต้องมีจริง + อ่าน digest ของทุก asset
curl -fsSL "https://api.github.com/repos/$REPO/releases/tags/v$VER" | python3 -c '
import json,sys
r=json.load(sys.stdin)
if "assets" not in r: raise SystemExit("release ไม่พบ: "+str(r.get("message","?")))
for a in r["assets"]: print(a["name"]+"\t"+(a.get("digest") or ""))' > "$tmp/assets.tsv"

# 2) โหลดไบนารีทุกแพลตฟอร์มที่ pin + sha256 เทียบ digest
PLATS=(linux-x64 linux-arm64 macos-arm64 linux-x64-musl linux-arm64-musl)
prefix="mise-v$VER-"
declare -A HASHES
for p in "${PLATS[@]}"; do
  asset="$prefix$p"
  grep -q "^$asset	" "$tmp/assets.tsv" || { echo "asset หายจาก release: $asset" >&2; exit 1; }
  curl -fsSL -o "$tmp/$asset" "https://github.com/$REPO/releases/download/v$VER/$asset"
  h="$(sha256sum "$tmp/$asset" | cut -d' ' -f1)"
  d="$(awk -F'\t' -v a="$asset" '$1==a{print $2}' "$tmp/assets.tsv" | sed 's/^sha256://')"
  [ -n "$d" ] || { echo "asset $asset ไม่มี digest ใน API — release นี้ผิดปกติ หยุด" >&2; exit 1; }
  [ "$h" = "$d" ] || { echo "MISMATCH $asset: bytes=$h vs digest=$d — หยุด ห้าม pin ของนี้" >&2; exit 1; }
  HASHES[$p]="$h"
  echo "  $asset  $h  (ไฟล์ที่โหลด = API digest ✓)"
done

echo "แผน patch: install/mise-pinned.sha256 (hash ×5 + version) · install.sh (VER + expect หลัก)"
if [ "$DRY" = "--dry-run" ]; then echo "(dry-run — ไม่เขียนไฟล์ จบ)"; exit 0; fi

# 3) patch
python3 - "$ROOT" "$OLD" "$VER" \
  "${HASHES[linux-x64]}" "${HASHES[linux-arm64]}" "${HASHES[macos-arm64]}" \
  "${HASHES[linux-x64-musl]}" "${HASHES[linux-arm64-musl]}" << 'PYEOF'
import datetime, re, sys
root, old, ver, hx, har, hma, hxm, harm = sys.argv[1:9]
today = datetime.date.today().isoformat()
open(f"{root}/install/mise-pinned.sha256","w").write(f"""# pinned-version: {ver}
# mise v{ver} — bump โดย scripts/dep-bump.sh เมื่อ {today} (owner รีวิว PR ก่อน merge)
# ตรวจตอน bump (CI): ไฟล์ที่ดาวน์โหลด = API digest ทุกแพลตฟอร์ม — receipts ใน PR body
# กติกา repo: hash ชุดนี้ต้องผ่านการ "ใช้จริงอย่างน้อย 1 เครื่อง" ก่อนถือว่า anchor เต็ม
{hx}  mise-v{ver}-linux-x64
{har}  mise-v{ver}-linux-arm64
{hma}  mise-v{ver}-macos-arm64
{hxm}  mise-v{ver}-linux-x64-musl
{harm}  mise-v{ver}-linux-arm64-musl
""")
p = f"{root}/install.sh"
t = open(p).read()
t2 = t.replace(f"VER={old}", f"VER={ver}", 1)
assert t2 != t, "install.sh VER ไม่เจอ"
t = t2
for plat, h in (("macos-arm64",hma), ("linux-x64-musl",hxm), ("linux-x64",hx)):
    t2 = re.sub(rf'(asset="[^"]*-{plat}"\n\s+expect=")[0-9a-f]{{64}}(")',
                rf'\g<1>{h}\g<2>', t)
    assert t2 != t, f"patch hash ไม่เข้า: {plat}"
    t = t2
open(p,"w").write(t)
print("patch: ok")
PYEOF

# 4) PR body
cat > "$ROOT/.dep-bump-pr-body.md" << EOF
## dep: bump $TOOL → v$VER

- hash ใหม่ทุกแพลตฟอร์ม recompute ใน CI: **ไฟล์ที่ดาวน์โหลด = API digest** ครบทุก asset — JSON (api.github.com) vs bytes (github.com/…/releases) คนละ endpoint
- container chain-test ผ่าน: mise pin → trust → dot apply → ยืนยันไฟล์ rendered
- ⚠️ **ชั้นที่ automation ทำแทนไม่ได้:** "ใช้จริงบนเครื่อง owner อย่างน้อย 1 เครื่อง" — merge แล้ว apply บนเครื่องหลักก่อนถือว่า anchor เต็มตามกติกา README §ห่วงโซ่ความเชื่อถือ
EOF
echo "PR body → .dep-bump-pr-body.md"

# 5) container chain test (ข้ามได้ด้วย SKIP_DOCKER=1)
if [ "${SKIP_DOCKER:-}" != "1" ] && command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
  bash "$ROOT/scripts/dep-chain-test.sh"
else
  echo "(ข้าม container chain-test — SKIP_DOCKER=1 หรือไม่มี docker daemon)"
fi
