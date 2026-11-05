# dotfiles — มาเนจด้วย [chezmoi](https://www.chezmoi.io/)

ครอบคลุมสอง OS: macOS (zsh/oh-my-zsh) และ Linux/WSL2 (bash) — เลือกอัตโนมัติด้วย template `.chezmoi.os` + WSL จำแนกผ่าน kernel

## การติดตั้ง chezmoi — เลือกตามระดับความเชื่อถือที่ต้องการ

**ระดับ 1 — ผ่าน mise (เฉพาะเครื่องที่มี mise อยู่แล้ว เช่น เครื่องหลักของเรา):**

```sh
mise use -g ubi:twpayne/chezmoi
```

mise(ubi) โหลดจาก GitHub Releases ของตัวเอง — ตรวจซ้ำแล้วว่า binary ตรง digest ของ release (`442ebbe0…` 6 พ.ย. 2026) — **ไม่มี `curl | sh` ในสายนี้** · **เครื่องเปล่าไม่ต้องมี mise มาก่อน — ข้ามไประดับ 2 ได้เลย** (chezmoi ติดตั้งได้โดยไม่ใช้ mise แล้ว apply จะติดตั้ง mise ให้เอง)

**ระดับ 2 — ตรวจ checksum เอง (กัน script ปลอมสนิท — ไม่พึ่ง package manager):**

```sh
# โหลด binary เวอร์ชันที่เรา pin ไว้ (แก้ arch ตามเครื่อง: linux-amd64 / darwin-arm64)
curl -fsLo chezmoi https://github.com/twpayne/chezmoi/releases/download/v2.74.0/chezmoi-linux-amd64
# ตรวจกับ hash ที่จดไว้ใน repo นี้ (ต้องผ่านก่อน ถึงจะไปต่อ)
sha256sum -c <(grep linux-amd64 install/chezmoi-pinned.sha256 | sed 's|chezmoi-linux-amd64|chezmoi|')
chmod +x chezmoi && mkdir -p ~/.local/bin && mv chezmoi ~/.local/bin/
```

hash ใน `install/chezmoi-pinned.sha256` มาจากสองแหล่งอิสระที่ตรงกัน: ① `digest` ของ asset จาก GitHub API ตอนจับ release ② ผล `sha256sum` ของ binary ที่เครื่องเราใช้จริง · อัปเกรดเวอร์ชัน = เปลี่ยนเลข + hash ใหม่แล้วจดที่มาเสมอ

**ระดับ 3 — one-liner ทางการ (สะดวกสุด · ความเสี่ยง: เชื่อ TLS + โดเมน get.chezmoi.io ณ วันรัน — ถ้าอยากดูของก่อน: `curl -fsLS get.chezmoi.io -o install.sh` อ่านแล้วค่อย `sh install.sh`):**

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply panudetjt/dotfiles
```

**จบด้วย (ทุกระดับ):**

```sh
chezmoi init panudetjt/dotfiles --apply
```

- ติดตั้ง [mise](https://mise.jdx.dev/) อัตโนมัติ (`run_once_install-tools.sh`) — **zero-trust เหมือนกัน: โหลด mise binary เวอร์ชันที่ pin (v2026.10.15) ตรงจาก GitHub Releases แล้วเทียบ sha256 กับ `install/mise-pinned.sha256` ก่อนติดตั้ง — hash ไม่ตรง = หยุด** (ไม่มี mise.run/curl|sh แล้ว) · tools ตาม `dot_config/mise/config.toml` mise ดึงเองเมื่อ activate ครั้งแรก
- macOS: ติดตั้ง [Homebrew](https://brew.sh) ก่อน แล้ว `brew bundle` จาก `Brewfile` รันเอง
- **ทุกครั้งก่อนเขียนไฟล์จริง: `chezmoi diff` — ดูก่อนเสมอ**

## ใช้งานรายวัน

```sh
chezmoi cd                 # เข้า repo นี้ (source state)
chezmoi add ~/.bashrc      # ดูดไฟล์เครื่องเข้า repo (แปลงชื่อ .bashrc → dot_bashrc ให้เอง)
chezmoi edit ~/.bashrc     # แก้ source โดยตรง
chezmoi diff               # ดูว่า apply จะเปลี่ยนอะไร — ก่อนทุก apply
chezmoi apply              # เขียนจริงลง $HOME
chezmoi update             # git pull แล้ว apply ต่อ (ดึงของเครื่องอื่น)
chezmoi doctor             # ตรวจสุขภาพการติดตั้ง
```

กติกาชื่อไฟล์ใน repo: `.bashrc` → `dot_bashrc` · template ต่อท้าย `.tmpl` · สคริปต์ติดตั้งขึ้นต้น `run_once_` · ไฟล์ที่**ไม่**ต้องการไป $HOME ใส่ชื่อไว้ใน `.chezmoiignore` (รองรับ template — ดูที่มีอยู่)

## ค่าต่อเครื่อง + OS branching

- ค่ากลาง (name/email สำหรับ gitconfig) อยู่ `.chezmoi.toml.tmpl` — แก้ที่นี่ไฟล์เดียว
- แยก OS ใน template: `{{ if eq .chezmoi.os "darwin" }}...{{ end }}` (macOS) · `.chezmoi.arch` · WSL: ดู kernel มี "Microsoft" (pattern ใน `dot_gitconfig`/docs ของ chezmoi)
- secrets: **repo นี้ยังไม่เก็บ secret ใด** — ถ้าจะเพิ่ม ใช้ encryption ของ chezmoi (age/gpg) หรือ password-manager integration (1Password/Bitwarden ฯลฯ) — ห้าม commit รหัสเปล่าเด็ดขาด

## ห่วงโซ่ความเชื่อถือ (zero-trust ทีละห่วง)

| ห่วง | ติดตั้งอย่างไร | ใครตรวจ |
|---|---|---|
| chezmoi | binary จาก GitHub Releases ตรง + `sha256sum -c` กับ `install/chezmoi-pinned.sha256` | เรา (hash จาก binary ที่ใช้จริง × API digest — เขามี Sigstore เพิ่มอีกชั้น) |
| mise | binary จาก GitHub Releases ตรง + เทียบ sha256 pin ใน `run_once_install-tools.sh` | เรา (linux-x64 ยืนยัน ×2: ใช้งานจริง × API digest · upstream มี SHASUMS256 + minisign/GPG) |
| tools ใน mise (bun/node/rust/…) | mise โหลดตามเวอร์ชันที่ pin ใน `dot_config/mise/config.toml` | mise ตรวจ checksum ของ upstream เอง (node/python ฯลฯ) + เวอร์ชันถูก lock ใน config ที่อยู่ใน repo — ไม่มีอะไรลอย |
| brew + Brewfile (macOS) | owner ติดตั้ง brew เองตามเว็บทางการ | อยู่นอกห่วงโซ่อัตโนมัติ — เจตนา |

กติกาอัปเกรดที่ pin: เปลี่ยนเวอร์ชัน → จับ hash ใหม่จาก **2 แหล่ง** (API digest + binary ที่รันจริงอย่างน้อย 1 ชุด) → แก้ไฟล์ pin + template พร้อมกัน → จดที่มาใน comment เสมอ — hash ที่ pin ทำให้**หลัง capture ไม่มีใครเปลี่ยนของได้เงียบๆ** (reproducible); ความเชื่อถือตอน capture มาจาก GitHub HTTPS + การใช้งานจริง + ลายเซ็นของ upstream

## Dependency updates (อัตโนมัติ)

| สิ่ง | กลไก | จังหวะ |
|---|---|---|
| chezmoi / mise (pins) | **`dep-check.yml`** (cron รายสัปดาห์) ตรวจ latest บน GitHub → เปิด/อัปเดต issue พร้อม release notes ("อะไรเปลี่ยนบ้าง") | อัตโนมัติ |
| ยกเวอร์ชัน pin | **`dep-bump.yml`** (workflow_dispatch: tool + version) → `scripts/dep-bump.sh` โหลด binary ทุกแพลตฟอร์ม เทียบ sha256 = API digest → patch pin + template → **container chain-test** → เปิด PR พร้อม receipts | เรียกเองตาม issue |
| tools ใน mise (bun/node/rust/…) | รัน `mise outdated` ดู → `mise upgrade --bump` เขียน `dot_config/mise/config.toml` เอง → commit ตามปกติ | ตามสบาย |
| เวอร์ชัน actions ใน workflows | **Dependabot** (`.github/dependabot.yml` — ecosystem: github-actions) | รายสัปดาห์ |

> ทำไมไม่ใช้ Dependabot/Renovate กับ pins หลัก: มันเปลี่ยนเลขเวอร์ชันได้แต่**หา sha256 ใหม่ให้ไม่ได้** — hash คือ anchor ของห่วงโซ่ zero-trust ที่ต้อง recompute จาก release จริงเสมอ (จึงเป็น workflow เราเอง + ชั้น "ใช้จริง 1 เครื่องก่อน" ยังเป็นของมนุษย์)

## Dev loop ใน container

```sh
chezmoi docker run -p apt ubuntu:24.04 panudetjt   # ephemeral env: ติดตั้ง + init --apply + shell ใน container ใหม่
```

- รองรับ podman (ชื่อ alias) + เลือก package manager ด้วย `-p` (apk/apt-get/dnf/...)
- ทดสอบโครงเองข้าม distro: `assets/docker/` (alpine/archlinux/fedora/voidlinux)
- ทดสอบแบบไม่แตะ $HOME: `chezmoi apply --destination /tmp/fakehome`

## โครงไฟล์

| ไฟล์ | ปลายทาง | OS |
|---|---|---|
| `dot_bashrc` | `~/.bashrc` | ทุก OS (ใช้จริงบน Linux/WSL2) |
| `dot_profile` | `~/.profile` | Linux/WSL2 |
| `dot_zshrc.tmpl`, `dot_zprofile.tmpl` | `~/.zshrc`, `~/.zprofile` | macOS เท่านั้น (`darwin` guard) |
| `dot_gitconfig.tmpl` | `~/.gitconfig` | ทุก OS (pager `bat` macOS) |
| `dot_tmux.conf`, `dot_vimrc` | `~/.tmux.conf`, `~/.vimrc` | ทุก OS |
| `dot_config/mise/config.toml` | `~/.config/mise/config.toml` | ทุก OS — toolchain SSOT |
| `run_once_install-tools.sh.tmpl` | (รันสคริปต์) | ติดตั้ง mise + brew bundle (darwin) |
| `install/chezmoi-pinned.sha256` | — | hash ที่ pin ไว้สำหรับติดตั้งระดับ 2 |

`.devcontainer/` = ใช้งาน/ทดสอบใน container · history เดิมของ repo (ยุค macOS 2021–2023) อยู่ branch [`archive/pre-ai-era`](https://github.com/panudetjt/dotfiles/tree/archive/pre-ai-era)
