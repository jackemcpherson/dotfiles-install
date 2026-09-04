# dotfiles-install

Installer for the private `dotfiles` CLI. This repository is public so the
script can be fetched without credentials; the binary it installs comes from
a private repository's releases and needs a fine-grained token.

```bash
export DOTFILES_TOKEN=github_pat_...
curl -fsSL \
  https://github.com/jackemcpherson/dotfiles-install/raw/main/install.sh | bash
```

The script downloads the latest `dotfiles-darwin-arm64` release asset,
verifies its SHA-256, and installs it as `~/.local/bin/dotfiles`.

| Variable         | Purpose                                            |
|------------------|----------------------------------------------------|
| `DOTFILES_TOKEN` | Required. Token with Contents read on the repo.    |
| `DOTFILES_REPO`  | `owner/name`, default `jackemcpherson/dotfiles`.   |
| `DOTFILES_BIN`   | Install directory, default `~/.local/bin`.         |
| `DOTFILES_TAG`   | Release tag to install, default latest.            |

Only Apple Silicon macOS is supported.
