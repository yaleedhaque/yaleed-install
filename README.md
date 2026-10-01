# yaleed-install

**One-command restore of a full yaleed environment onto a fresh Linux machine.**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yaleedhaque/yaleed-install/main/install.sh)"
```

## What it does
1. Installs prerequisites (`git`, `curl`, `gpg`, `gh`)
2. Authenticates to GitHub once (device code — the only manual step)
3. Pulls the private backup repo `yaleedhaque/opencode-dotfiles`
4. Runs its bootstrap, which decrypts the encrypted bundle (asks for the vault
   passphrase once) and restores configs, skills, agents, MCP servers, memory,
   shell dotfiles, systemd timers, the vault, **every key/password**, and the
   `yaleed` binary

## What you need first
- GitHub access to the `yaleedhaque` account — **this is the gate**
- The vault passphrase — stored in a Gmail draft titled *"opencode vault passphrase"*

## This repo contains no secrets
It holds a single installer script. Every secret lives AES256-encrypted inside the
release bundle in the private repo. Publishing this script leaks nothing — it only
fetches and runs the private bootstrap.

## Full manual procedure
See `RESTORE.md` in the private repo for the step-by-step version, and for what
to do if the passphrase is lost.
