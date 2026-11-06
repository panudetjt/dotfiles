#!/usr/bin/env bash
# dep-check — ตรวจ dependency ที่ pin ไว้ใน dotfiles เทียบ latest บน GitHub
# รายงาน stdout เป็น markdown — ไม่เขียนไฟล์ใดๆ (report-only)
# ใช้ได้ทั้งเครื่อง local และ GitHub Actions (cron รายสัปดาห์ → เปิด/อัปเดต issue)
# เรียก: bash scripts/dep-check.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

pin_version() { grep -oE '^# pinned-version: [0-9.]+' "$ROOT/$1" | grep -oE '[0-9.]+' | head -1; }
api() { curl -fsSL "https://api.github.com$1"; }
latest() { api "/repos/$1/releases/latest" | python3 -c 'import json,sys;print(json.load(sys.stdin)["tag_name"].lstrip("v"))'; }
notes() { api "/repos/$1/releases/tags/v$2" | python3 -c '
import json,sys
r=json.load(sys.stdin)
print(r["html_url"])
body=(r.get("body") or "").strip() or "(release ไม่มี notes)"
print(body[:400] + ("…" if len(body)>400 else ""))'; }

check() { # <ชื่อ> <owner/repo> <pinfile>
  local name="$1" repo="$2" pinfile="$3" pinned latest_v
  pinned="$(pin_version "$pinfile")"
  latest_v="$(latest "$repo")"
  echo "### $name"
  if [ "$pinned" = "$latest_v" ]; then
    echo "- ✅ UP-TO-DATE — pinned \`$pinned\` = latest"
  else
    echo "- 🔔 UPDATE AVAILABLE — pinned \`$pinned\` → latest \`$latest_v\`"
    echo "- อะไรเปลี่ยน (release notes):"
    notes "$repo" "$latest_v" | sed 's/^/  > /'
    echo "- ยกเวอร์ชัน: \`workflow_dispatch → dep-bump → $name $latest_v\` (recompute hash + container chain-test + PR)"
  fi
  echo
}

echo "# dependency check — $(date -u "+%F %H:%M UTC")"
echo
check mise jdx/mise install/mise-pinned.sha256

echo "### tools ใน mise (เวอร์ชัน pin อยู่ \`dot_config/mise/config.toml\`)"
if command -v mise >/dev/null 2>&1; then
  # รันบน config จริงของเครื่อง (trust อยู่แล้ว) — ถ้าเครื่อง drift จาก repo จะถูกชี้ด้วย
  live="${MISE_CONFIG:-$HOME/.config/mise/config.toml}"
  if [ -f "$live" ] && ! diff -q "$live" "$ROOT/config/mise.toml" >/dev/null 2>&1; then
    echo "- ⚠️ **config จริงของเครื่อง ≠ repo** (\`$live\` vs \`config/mise.toml\`) — sync ก่อน: แก้ใน repo แล้ว \`mise dot apply\`"
  fi
  tmpd="$(mktemp -d)"; trap 'rm -rf "$tmpd"' EXIT
  if mise outdated > "$tmpd/outdated.txt" 2>/dev/null && [ -s "$tmpd/outdated.txt" ]; then
    sed 's/^/    /' "$tmpd/outdated.txt"
    echo "- ยกเครื่องจริง: \`mise upgrade --bump\` (เขียน config.toml ให้เอง — commit ตามปกติ)"
  else
    echo "- ✅ ทุก tool ตรงตาม wanted (หรือตรวจไม่ได้ — รัน \`mise outdated\` บนเครื่องจริงดู)"
  fi
else
  echo "- (ไม่มี mise บนเครื่องนี้ — ข้าม)"
fi
