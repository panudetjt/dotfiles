#!/bin/sh
# setup.sh — lazy install wizard: เลือกเฉพาะชั้นที่ "เครื่องนี้" ต้องใช้
#
# โครง lazy:
#   base (มากับ dotfiles อยู่แล้ว — เบา) : node lts / pnpm / bun + dotfiles ทั้งชุด
#   tier เสริม (opt-in — wizard เขียน ~/.config/mise/config.local.toml):
#     --mobile : java (openjdk-21) + ANDROID env (+ Android SDK ถ้ายังไม่มี — ~2-3 GB, ถามก่อน)
#     --rust   : rust 1.99.1 (project เช่น thamdu/tham-libs pin เองอยู่แล้ว — tier นี้ไว้ใช้นอก project)
#   เครื่องมือใน project ที่ pin mise.toml เอง mise จะ install อัตโนมัติเมื่อใช้ครั้งแรก (lazy โดย mise)
#
# ใช้: ./setup.sh                (interactive — ถามทีละชั้น)
#      ./setup.sh --rust        (scripted)
#      ./setup.sh --mobile --rust --yes   (ไม่ถามยืนยัน ยกเว้นขั้นโหลด SDK หนัก)
#      SKIP_INSTALL=1 ./setup.sh ...      (เขียน config เท่านั้น ไม่รัน mise install)
set -eu

WANT_MOBILE=0; WANT_RUST=0; ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        --mobile) WANT_MOBILE=1 ;;
        --rust)   WANT_RUST=1 ;;
        --all)    WANT_MOBILE=1; WANT_RUST=1 ;;
        --yes)    ASSUME_YES=1 ;;
        *) echo "flag ไม่รู้จัก: $arg (ใช้ --mobile --rust --all --yes)" >&2; exit 2 ;;
    esac
done

ask() { # ask "คำถาม" default(y/n) → คืน 0 เมื่อตอบใช่
    q="$1"; def="${2:-n}"
    if [ "$ASSUME_YES" = 1 ]; then
        [ "$def" = y ] && return 0 || return 1
    fi
    printf "%s [y/N] " "$q"
    read -r a || a=""
    case "$a" in y|Y) return 0 ;; *) return 1 ;; esac
}

CFG_DIR="$HOME/.config/mise"
CFG="$CFG_DIR/config.local.toml"
mkdir -p "$CFG_DIR"

TOOLS=""; ENV_BLOCK=""

# ---------- tier: rust ----------
if [ "$WANT_RUST" = 0 ] && [ "$ASSUME_YES" = 0 ] && [ -t 0 ]; then
    ask "ใช่ rust นอก project ไหม (thamdu/tham-libs pin เองอยู่แล้ว — นอก project เช่น tltk-rs ต้องมี)? (rust 1.99.1 ~1 GB)" && WANT_RUST=1
fi
if [ "$WANT_RUST" = 1 ]; then
    TOOLS="$TOOLS
rust = \"1.99.1\""
fi

# ---------- tier: mobile ----------
if [ "$WANT_MOBILE" = 0 ] && [ "$ASSUME_YES" = 0 ] && [ -t 0 ]; then
    ask "ทำ mobile/Android dev บนเครื่องนี้ไหม (java + Android SDK — SDK โหลด ~2-3 GB ถามอีกรอบ)?" && WANT_MOBILE=1
fi
if [ "$WANT_MOBILE" = 1 ]; then
    TOOLS="$TOOLS
java = \"openjdk-21.0.2\""
    ENV_BLOCK="$ENV_BLOCK
ANDROID_HOME = \"{{ env.HOME }}/Android/Sdk\"
_.path = [\"{{ env.HOME }}/Android/Sdk/platform-tools\", \"{{ env.HOME }}/Android/Sdk/emulator\", \"{{ env.HOME }}/Android/Sdk/cmdline-tools/latest/bin\"]"
fi

if [ -z "$TOOLS" ] && [ -z "$ENV_BLOCK" ]; then
    echo "base-only — ไม่ต้องเขียน config.local.toml (ถ้ามีไฟล์เก่าของ tier เก่า ลบเองได้: $CFG)"
    exit 0
fi

# ---------- เขียน config.local.toml (ไฟล์นี้ wizard เป็นคนเขียนคนเดียว — รันซ้ำเขียนทับ) ----------
{
    echo "# ~/.config/mise/config.local.toml — tier เสริมของเครื่องนี้ (เขียนโดย setup.sh เมื่อ $(date -u '+%F'))"
    echo "# base (node/pnpm/bun) มาจาก config.toml ที่ dotfiles deploy — ไฟล์นี้เพิ่มเฉพาะของ opt-in"
    if [ -n "$TOOLS" ]; then
        echo ""
        echo "[tools]"
        printf '%s\n' "$TOOLS"
    fi
    if [ -n "$ENV_BLOCK" ]; then
        echo ""
        echo "[env]"
        printf '%s\n' "$ENV_BLOCK"
    fi
} > "$CFG"

if ! mise trust "$CFG" >/dev/null 2>&1; then
    echo "WARNING: mise trust config.local.toml ไม่สำเร็จ — รัน: mise trust $CFG" >&2
fi
echo "เขียนแล้ว: $CFG"

# ---------- Android SDK (หนักสุด — ถามเสมอ แม้ --yes) ----------
if [ "$WANT_MOBILE" = 1 ] && [ ! -d "$HOME/Android/Sdk" ]; then
    echo ""
    echo "Android SDK ยังไม่มีบนเครื่อง (~2-3 GB ดิสก์):"
    echo "  1) โหลด Android cmdline-tools จาก dl.google.com"
    echo "  2) sdkmanager --licenses + install platform-tools / platforms;android-36 / build-tools;36.0.0 / emulator"
    if ask "จะโหลด Android SDK ตอนนี้เลยไหม? (ข้ามได้ — env พร้อมไว้แล้ว ค่อยรัน ./setup.sh ซ้ำภายหลัง)" n; then
        case "$(uname -s)" in
            Darwin) ct="commandlinetools-mac-11076708_latest.zip" ;;
            *)      ct="commandlinetools-linux-11076708_latest.zip" ;;
        esac
        dl() { if command -v curl >/dev/null 2>&1; then curl -fSL -o "$2" "$1"; else wget -qO "$2" "$1"; fi; }
        tmp="$(mktemp -d)"
        echo "โหลด $ct ..."
        dl "https://dl.google.com/android/repository/$ct" "$tmp/ct.zip" \
            && unzip -q "$tmp/ct.zip" -d "$tmp" \
            && mkdir -p "$HOME/Android/Sdk/cmdline-tools" \
            && mv "$tmp/cmdline-tools" "$HOME/Android/Sdk/cmdline-tools/latest"
        rm -rf "$tmp"
        yes | "$HOME/Android/Sdk/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null
        "$HOME/Android/Sdk/cmdline-tools/latest/bin/sdkmanager" "platform-tools" "platforms;android-36" "build-tools;36.0.0" "emulator"
        echo "Android SDK พร้อม (~$HOME/Android/Sdk)"
    else
        echo "ข้าม — เมื่อต้องใช้ mobile รัน: ./setup.sh --mobile (env รออยู่แล้ว SDK จะโหลดตอนนั้น)"
    fi
fi

# ---------- mise install (ข้ามได้ด้วย SKIP_INSTALL=1 — เช่น รันใน CI/containers) ----------
if [ "${SKIP_INSTALL:-}" = 1 ]; then
    echo "(SKIP_INSTALL=1 — ไม่รัน mise install)"
else
    echo "mise install ตาม tier ที่เลือก ..."
    mise install
fi
echo "เสร็จ — tools เช็คได้ด้วย: mise ls · แก้ tier ภายหลัง = รัน ./setup.sh ซ้ำ"
