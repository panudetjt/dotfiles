# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# mise shims — login/non-interactive shells ต้องมี tools ด้วย (interactive ได้เพิ่มจาก
# mise activate ใน common.sh — แต่ .bashrc early-return ก่อนถึง common เมื่อ non-interactive)
case ":$PATH:" in
  *":$HOME/.local/share/mise/shims:"*) ;;
  *) [ -d "$HOME/.local/share/mise/shims" ] && export PATH="$HOME/.local/share/mise/shims:$PATH" ;;
esac

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# Vite+ bin (guarded — เครื่องที่ไม่ติดตั้งไม่ต้อง error ทุก login)
[ -f "$HOME/.config/vite-plus/env" ] && . "$HOME/.config/vite-plus/env"


# (Antigravity installer line ตัด — hardcode /home/jame และซ้ำกับ ~/.local/bin block ข้างบน)
