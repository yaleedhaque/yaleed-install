#!/usr/bin/env bash
# =============================================================================
#  yaleed-install — ONE-COMMAND restore of the full yaleed environment
#
#  On a brand-new Linux machine, paste ONE line:
#
#     bash -c "$(curl -fsSL https://raw.githubusercontent.com/yaleedhaque/yaleed-install/main/install.sh)"
#
#  WHAT IT DOES
#    1. Installs prerequisites (git, curl, gpg, gh).
#    2. Authenticates to GitHub once (device code — the only manual step).
#    3. Pulls the PRIVATE backup repo.
#    4. Hands off to its bootstrap, which decrypts the encrypted bundle
#       (asks for the vault passphrase ONCE) and restores:
#         configs, skills, agents, MCP servers, memory, shell dotfiles,
#         systemd timers, the vault, EVERY key/password, and the yaleed binary.
#    5. Enables the daily auto-backup timer, so the new machine starts
#       backing itself up immediately.
#
#  What you need before running:
#    - GitHub access to the yaleedhaque account  (this is the gate)
#    - The vault passphrase                      (Gmail draft: "opencode vault passphrase")
#
#  THIS FILE CONTAINS NO SECRETS. It is safe to be public. It only fetches and
#  runs the private repo's bootstrap; every secret lives encrypted in the bundle.
# =============================================================================
set -euo pipefail

REPO_SLUG="yaleedhaque/opencode-dotfiles"
REPO_URL="https://github.com/${REPO_SLUG}.git"
WORK="${YALEED_CLONE_WORK:-$HOME/.yaleed-clone}"

c()  { printf '\033[1;36m%s\033[0m\n' "$*"; }
ok() { printf '  \033[1;32m✓\033[0m %s\n' "$*"; }
w()  { printf '  \033[1;33m!\033[0m %s\n' "$*"; }
die(){ printf '  \033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

clear 2>/dev/null || true
cat <<'BANNER'

  ┌──────────────────────────────────────────────────────────────┐
  │   YALEED — ONE-CLICK RESTORE                                 │
  │   Rebuilds this machine to match the latest backup.          │
  └──────────────────────────────────────────────────────────────┘

BANNER

# ---------------------------------------------------------------------------
# 1. Prerequisites
# ---------------------------------------------------------------------------
c "[1/5] Prerequisites"
SUDO=""
[[ ${EUID:-$(id -u)} -ne 0 ]] && command -v sudo >/dev/null && SUDO="sudo"

need_pkgs=()
for pkg in git curl gpg; do
  command -v "$pkg" >/dev/null 2>&1 || need_pkgs+=("$pkg")
done
if [[ ${#need_pkgs[@]} -gt 0 ]]; then
  c "  installing: ${need_pkgs[*]}"
  $SUDO apt-get update -qq 2>/dev/null || true
  $SUDO apt-get install -y -qq "${need_pkgs[@]}" 2>/dev/null || die "could not install ${need_pkgs[*]}"
fi
ok "git, curl, gpg present"

# gh CLI — needed for the private repo + release assets
if ! command -v gh >/dev/null 2>&1; then
  c "  installing gh CLI…"
  $SUDO mkdir -p -m 755 /etc/apt/keyrings
  ( curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | $SUDO tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null \
    && $SUDO chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null \
    && $SUDO apt-get update -qq \
    && $SUDO apt-get install -y -qq gh ) 2>/dev/null \
    || die "gh install failed — install it manually: https://github.com/cli/cli#installation"
fi
ok "gh CLI present"

# ---------------------------------------------------------------------------
# 2. GitHub auth (the ONE manual step)
# ---------------------------------------------------------------------------
c "[2/5] GitHub authentication"
if gh auth status >/dev/null 2>&1; then
  ok "already authenticated"
else
  cat <<'AUTH'

  GitHub access is required to reach the private backup repo.
  A one-time code will appear — open the URL and paste it.

AUTH
  read -r -p "  Press Enter to start authentication… " _x
  gh auth login --hostname github.com --git-protocol https --web 2>/dev/null \
    || gh auth login --hostname github.com --git-protocol https
  gh auth status >/dev/null 2>&1 || die "GitHub authentication failed"
  ok "authenticated"
fi
gh auth setup-git >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# 3. Fetch the private backup repo
# ---------------------------------------------------------------------------
c "[3/5] Fetching the backup repo"
mkdir -p "$WORK"
if [[ -d "$WORK/opencode-dotfiles/.git" ]]; then
  ( cd "$WORK/opencode-dotfiles" && git pull -q --ff-only 2>/dev/null ) || true
  ok "repo already present at $WORK/opencode-dotfiles"
else
  gh repo clone "$REPO_SLUG" "$WORK/opencode-dotfiles" -- -q 2>/dev/null \
    || git clone -q "$REPO_URL" "$WORK/opencode-dotfiles" 2>/dev/null \
    || die "clone failed"
  ok "cloned to $WORK/opencode-dotfiles"
fi

# ---------------------------------------------------------------------------
# 4. Hand off to the real bootstrap
# ---------------------------------------------------------------------------
c "[4/5] Running the restore"
BOOT="$WORK/opencode-dotfiles/contrib/bootstrap/yaleed-bootstrap"
[[ -f "$BOOT" ]] || BOOT="$WORK/opencode-dotfiles/scripts/yaleed-bootstrap.sh"
[[ -f "$BOOT" ]] || die "bootstrap script not found in the repo"
chmod +x "$BOOT" 2>/dev/null || true

cat <<'PP'

  Next it will ask for the vault passphrase.
  → it is in your Gmail draft: "opencode vault passphrase"
  → it decrypts the bundle that contains all keys and passwords.
  → press Enter with nothing to skip decryption (configs still restore, secrets stay locked).

PP
bash "$BOOT"

# ---------------------------------------------------------------------------
# 5. Done
# ---------------------------------------------------------------------------
c "[5/5] Verify"
if command -v yaleed >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/yaleed" ]]; then
  V="$("$HOME/.local/bin/yaleed" --version 2>/dev/null | head -1 || echo 'installed')"
  ok "yaleed $V"
else
  w "yaleed binary not on PATH — open a new terminal, or check ~/.local/bin"
fi

cat <<'DONE'

  ┌──────────────────────────────────────────────────────────────┐
  │   ✅ RESTORE COMPLETE                                        │
  └──────────────────────────────────────────────────────────────┘

  Open a NEW terminal, then:
      yaleed

  What is NOT restored (hardware/OS specific — do these by hand):
      1. Mount the Windows/D: partition, then re-clone project repos
         (list: ~/.config/opencode/shared/project-paths or the bundle's
         misc/project-paths.txt)
      2. GRUB brightness params, if this machine needs them
      3. Test WARP / hotspot / phone-link systemd services
      4. Ai-Browser-Toolkit venv (playwright) — its own setup handles it

  The daily auto-backup timer is now ENABLED — this machine backs itself up
  to the same private repo. You can move on.

DONE
