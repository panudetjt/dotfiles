# ~/.zshrc — macOS (zsh default shell) — preamble บาง ๆ + behavior ร่วมจาก common
# (stack เก่า ยุค 2021: oh-my-zsh/spaceship/nvm/volta — ตัดทิ้งตามการตัดสิน "ยึด linux เป็นหลัก" 6 พ.ย. 2026
#  ของเดิมหายืนยันคืนได้จาก git history / branch archive/pre-ai-era)
case $- in *i*) ;; *) return;; esac

HISTFILE="$HOME/.zsh_history"
HISTSIZE=1000
SAVEHIST=2000
setopt APPEND_HISTORY HIST_IGNORE_DUPS SHARE_HISTORY

autoload -Uz compinit && compinit

# prompt สีเดียวกับ bash ฝั่ง linux (user@host:dir$)
PS1='%F{green}%n@%m%f:%F{blue}%~%f$ '

# พฤติกรรมร่วม (PATH/aliases/mise activate/daily) — ไฟล์เดียวกับฝั่ง linux
[ -f "$HOME/.config/shell/common.sh" ] && . "$HOME/.config/shell/common.sh"
