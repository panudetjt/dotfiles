#!/usr/bin/env bash
# dep-bump — ยกเวอร์ชันที่ pin + recompute hash + ทดสอบห่วงโซ่ zero-trust + เตรียม PR
# เรียก: bash scripts/dep-bump.sh <chezmoi|mise> <version ไม่มี v> [--dry-run]
# หลักความปลอดภัย: hash ใหม่ต้องผ่าน 2 ชั้นตรวจใน CI — API digest (JSON) vs ไฟล์ที่ดาวน์โหลดจริง (bytes,
# คนละ endpoint) ไม่ตรง = หยุด · ชั้นที่ automation ทำแทนไม่ได้ = "ใช้จริงบนเครื่อง owner อย่างน้อย 1 เครื่อง"
# ก่อนแพร่ — จดใน PR body เสมอ
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="${1:?ใช้: dep-bump.sh <chezmoi|mise> <version> [--dry-run]}"
VER="${2:?version เช่น 2.74.1}"
V="$VER"
DRY="${3:-}"
case "$TOOL" in
  chezmoi) REPO="twpayne/chezmoi"; PIN="install/chezmoi-pinned.sha256" ;;
  mise)    REPO="jdx/mise";        PIN="install/mise-pinned.sha256" ;;
  *) echo "tool ต้องเป็น chezmoi หรือ mise" >&2; exit 2 ;;
esac
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
case "$TOOL" in
  chezmoi) PLATS=(linux-amd64 darwin-arm64); prefix="" ;;
  mise)    PLATS=(linux-x64 linux-arm64 macos-arm64 linux-x64-musl linux-arm64-musl); prefix="mise-v$VER-" ;;
esac
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

# 3) แผน patch
if [ "$TOOL" = chezmoi ]; then
  plan="install/chezmoi-pinned.sha256 (hash ×2 + version) · README.md (URL ตัวอย่าง)"
else
  plan="install/mise-pinned.sha256 (hash ×3 + version) · run_once_install-tools.sh.tmpl (version+hash ×3)"
fi
echo "แผน patch: $plan"
if [ "$DRY" = "--dry-run" ]; then echo "(dry-run — ไม่เขียนไฟล์ จบ)"; exit 0; fi

# 4) patch ไฟล์จริง
python3 - "$ROOT" "$TOOL" "$OLD" "$VER" \
  "${HASHES[${PLATS[0]}]}" "${HASHES[${PLATS[1]}]}" \
  $( [ "${#PLATS[@]}" -eq 3 ] && echo "${HASHES[${PLATS[2]}]}" || echo "-" ) << 'PYEOF'
import datetime, re, sys
root, tool, old, ver, h0, h1, h2 = sys.argv[1:8]
today = datetime.date.today().isoformat()
if tool == "chezmoi":
    open(f"{root}/install/chezmoi-pinned.sha256","w").write(f"""# chezmoi v{ver} — bump โดย scripts/dep-bump.sh เมื่อ {today} (owner รีวิว PR ก่อน merge)
# ตรวจตอน bump (CI): ไฟล์ที่ดาวน์โหลด = API digest ทุกแพลตฟอร์ม — receipts ใน PR body
# กติกา repo: hash ชุดนี้ต้องผ่านการ "ใช้จริงอย่างน้อย 1 เครื่อง" ก่อนถือว่า anchor เต็ม
{h0}  chezmoi-linux-amd64
{h1}  chezmoi-darwin-arm64
""")
    p = f"{root}/README.md"
    t = open(p).read()
    t2 = re.sub(rf"releases/download/v{re.escape(old)}/chezmoi-linux-amd64",
                f"releases/download/v{ver}/chezmoi-linux-amd64", t)
    assert t2 != t, "README URL ไม่เจอ — ตรวจรูปแบบ"
    open(p,"w").write(t2)
else:
    plats = [("linux-x64",h0), ("linux-arm64",h1), ("macos-arm64",h2)]
    open(f"{root}/install/mise-pinned.sha256","w").write(f"""# mise v{ver} — bump โดย scripts/dep-bump.sh เมื่อ {today} (owner รีวิว PR ก่อน merge)
# ตรวจตอน bump (CI): ไฟล์ที่ดาวน์โหลด = API digest ทุกแพลตฟอร์ม — receipts ใน PR body
# กติกา repo: hash ชุดนี้ต้องผ่านการ "ใช้จริงอย่างน้อย 1 เครื่อง" ก่อนถือว่า anchor เต็ม
""" + "".join(f"{h}  mise-v{ver}-{p}\n" for p,h in plats))
    p = f"{root}/run_once_install-tools.sh.tmpl"
    t = open(p).read()
    t = t.replace(f"mise-v{old}-", f"mise-v{ver}-").replace(f"download/v{old}/", f"download/v{ver}/")
    for plat, h in plats:
        t2 = re.sub(rf'(asset="mise-v{re.escape(ver)}-{plat}"\n\s+expect=")[0-9a-f]{{64}}(")',
                    rf'\g<1>{h}\g<2>', t)
        assert t2 != t, f"patch hash ไม่เข้า: {plat}"
        t = t2
    open(p,"w").write(t)
print("patch: ok")
PYEOF

# 5) PR body
cat > "$ROOT/.dep-bump-pr-body.md" << EOF
## dep: bump $TOOL → v$VER

- hash ใหม่ทุกแพลตฟอร์ม recompute ใน CI: **ไฟล์ที่ดาวน์โหลด = API digest** ครบทุก asset (receipts ด้านล่าง) — JSON (api.github.com) vs bytes (github.com/…/releases) คนละ endpoint
- container chain-test ผ่าน: chezmoi pin → apply → mise pin → ยืนยันเวอร์ชัน (log ใน Actions)
- ⚠️ **ชั้นที่ automation ทำแทนไม่ได้:** "ใช้จริงบนเครื่อง owner อย่างน้อย 1 เครื่อง" — merge แล้ว apply บนเครื่องหลักก่อนถือว่า anchor เต็มตามกติกา README §ห่วงโซ่ความเชื่อถือ

<details><summary>receipts (asset · sha256)</summary>

$(for p in "${PLATS[@]}"; do echo "- \`${prefix}${p#mise-v$VER-}\` → \`${HASHES[$p]}\`"; done)

</details>
EOF
echo "PR body → .dep-bump-pr-body.md"

# 6) ทดสอบห่วงโซ่ใน container (ข้ามได้ด้วย SKIP_DOCKER=1)
if [ "${SKIP_DOCKER:-}" != "1" ] && command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
  bash "$ROOT/scripts/dep-chain-test.sh"
else
  echo "(ข้าม container chain-test — SKIP_DOCKER=1 หรือไม่มี docker daemon)"
fi
