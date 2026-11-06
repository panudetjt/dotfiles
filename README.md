# dotfiles — จัดการด้วย mise เอง ([mise dotfiles](https://mise.jdx.dev/dotfiles.html))

**เครื่องมือเดียวจบ** — mise เป็นทั้ง toolchain SSOT และ dotfiles manager (mise-single-source บริสุทธิ์) · ครอบคลุมสอง OS: macOS + Linux/WSL2 (platform files `mise.macos.toml` / `mise.linux.toml` — WSL แยกเพิ่มด้วย `env.WSL_DISTRO_NAME` ใน template)

## เครื่องใหม่ — 3 คำสั่ง

```sh
git clone https://github.com/panudetjt/dotfiles.git ~/src/dotfiles && cd ~/src/dotfiles
./install.sh                       # ติดตั้ง mise แบบ zero-trust (โหลด binary เวอร์ชัน pin + เทียบ sha256 ก่อนติดตั้ง)
mise trust && mise dot apply       # trust แล้ว deploy ทุกไฟล์ (มี --dry-run ให้ดูก่อน)
```

- `install.sh` — ไม่มี curl|sh ไม่มี installer script ปลอม: hash จาก 2 แหล่ง (binary ที่ใช้จริง × API digest) · fallback wget เอง · libc-aware (glibc/musl)
- `mise dot apply` — แตะ**เฉพาะ** entry ที่ประกาศใน `mise.toml` ("Only declared paths are managed") · ดูก่อนเสมอ: `mise dot diff`
- อัปเดตเครื่อง: `cd ~/src/dotfiles && git pull && mise dot apply`

## ใช้งานรายวัน

```sh
cd ~/src/dotfiles           # repo นี้ (หรือ mise dot paths ดู path)
mise dot diff               # ดูว่า apply จะเปลี่ยนอะไร — ก่อนทุก apply
mise dot apply              # เขียนจริง
mise dot status             # สถานะทุก entry
mise dot unapply ~/.bashrc  # ถอย (ปฏิเสธถ้าไฟล์ถูกแก้เอง — ต้อง --force)
mise dot add ~/.newfile     # ดูดไฟล์ใหม่เข้า repo
mise outdated               # tools เก่าไหม → mise upgrade --bump
```

## โครง

| ไฟล์ | ปลายทาง | หมายเหตุ |
|---|---|---|
| `mise.toml` | — | **ประกาศ [dotfiles] ทั้งหมด** + [vars] |
| `mise.linux.toml` / `mise.macos.toml` | — | platform files — entry ต่อ OS (`auto_env = true` ตั้งใน config/mise.toml) |
| `bashrc` `profile` | `~/.bashrc` `~/.profile` (linux) | mode = copy |
| `zshrc` `zprofile` | `~/.zshrc` `~/.zprofile` (macos) | macos-only ผ่าน platform file |
| `gitconfig.tera` | `~/.gitconfig` | mode = template (Tera — `os()`, `env.WSL_DISTRO_NAME`) |
| `tmux.conf` `vimrc` | `~/.tmux.conf` `~/.vimrc` | mode = symlink |
| `config/mise.toml` | `~/.config/mise/config.toml` | toolchain SSOT (+ auto_env) — mise เขียนไฟล์นี้ก่อนแล้วอ่านซ้ำในรอบเดียว |
| `install.sh` + `install/mise-pinned.sha256` | — | zero-trust mise installer (5 แพลตฟอร์ม pin) |
| `scripts/dep-*.sh` | — | dependency automation (ดู workflows) |

secrets: **repo นี้ยังไม่เก็บ secret** — mise มี age values ในตัว (experimental) + fnox/SOPS เมื่อจำเป็น — ห้าม commit รหัสเปล่า

## Dependency updates (อัตโนมัติ)

cron รายสัปดาห์ (`dep-check.yml`) → issue พร้อม release notes · ยกเวอร์ชัน = dispatch `dep-bump.yml` (recompute hash ×5 แพลตฟอร์ม → chain-test ใน container → PR) · tools = `mise outdated` → `mise upgrade --bump` · Dependabot = github-actions เท่านั้น

## Dev loop ใน container

`bash scripts/dep-chain-test.sh` — พิสูจน์ห่วงโซ่ zero-trust ใน container สะอาดทุกครั้งหลังแก้ pins

`.devcontainer/` = ใช้งาน/ทดสอบใน container · history เดิม (ยุค macOS 2021–2023) = branch [`archive/pre-ai-era`](https://github.com/panudetjt/dotfiles/tree/archive/pre-ai-era)
