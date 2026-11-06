# ~/.config/shell/common.sh — พฤติกรรมร่วมของทุกเชลล์ (bash บน Linux/WSL2 · zsh บน macOS)
# SSOT เดียว: แก้ที่ repo (~/src/dotfiles/shell-common.sh) แล้ว `mise dot apply` — ทั้งสอง OS ได้เหมือนกัน
# baseline = Linux/WSL2 (ตัดสิน 6 พ.ย. 2026 — ยึดฝั่ง linux เป็นหลัก ฝั่ง macos เก่าทิ้ง)

export PATH="$HOME/.local/bin:$PATH"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Go (ถ้ามี)
[ -d /usr/local/go/bin ] && export PATH="$PATH:/usr/local/go/bin"

# Vite+ bin (guarded — มีเฉพาะเครื่องที่ติดตั้ง)
[ -f "$HOME/.config/vite-plus/env" ] && . "$HOME/.config/vite-plus/env"

# Snap packages (linux — ที่อื่นไม่มี dir ก็ข้าม)
case ":$PATH:" in
  *":/snap/bin:"*) ;;
  *) [ -d /snap/bin ] && export PATH="$PATH:/snap/bin" ;;
esac

# ls/grep colors — ls ต่าง OS (GNU --color vs BSD -G) ที่เหลือเหมือนกัน
case "$(uname -s)" in
    Darwin) alias ls='ls -G' ;;
    *) [ -x /usr/bin/dircolors ] && eval "$(dircolors -b)" 2>/dev/null ; alias ls='ls --color=auto' ;;
esac
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias fgrep='grep --color=auto'
alias egrep='egrep --color=auto'

# claude / agent aliases
alias claudez="claude --allow-dangerously-skip-permissions --settings ~/.claude/zai-settings.json"
alias clauded="claude --allow-dangerously-skip-permissions"
alias agyd="agy --dangerously-skip-permissions"

# Disable oh-my-openagent anonymous telemetry
export OMO_SEND_ANONYMOUS_TELEMETRY=0
export OMO_DISABLE_POSTHOG=1

# >>> daily >>>
# สร้างโดย ~/work/sp/daily/scripts/install.sh — block นี้ย้ายมาอยู่ repo แล้ว (ระวัง: daily installer
# รันซ้ำจะเขียนไปที่ ~/.bashrc live แทนที่จะเป็นไฟล์นี้ — ถ้าเจอ drift ให้ dot diff จับ)
export DAILY_DIR="$HOME/work/sp/daily/wiki/config"
export DAILY_WIKI="$HOME/work/sp/daily/wiki"
# <<< daily <<<

export CARGO_TARGET_DIR=/tmp/t-m2-20-target

# mise — toolchain activation (bash/zsh ต่างกันแค่ argument)
if [ -x "$HOME/.local/bin/mise" ]; then
    if [ -n "${ZSH_VERSION:-}" ]; then
        eval "$($HOME/.local/bin/mise activate zsh)"
    else
        eval "$($HOME/.local/bin/mise activate bash)"
    fi
fi
