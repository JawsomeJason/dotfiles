# Agent notes for dotfiles

The public base of Jason's dotfiles: a chezmoi source plus the `dotfiles` command that applies it
together with any private layers. README.md says what lives where.

Where to look:

- `home/` is the chezmoi source (see `.chezmoiroot`). chezmoi renames files on the way out:
  `dot_zshrc.tmpl` becomes `~/.zshrc`, `private_` sets mode 600 or 700, `.tmpl` means a Go
  template, `symlink_` writes a link, and `modify_` scripts rewrite an existing file from stdin.
- `cli/dotfiles` is the command. Each subcommand is one file in `cli/commands/<name>.sh`, whose
  first comment line is its usage and second line its summary; `dotfiles help` reads them.
  Shared helpers, including the layer list, are in `cli/lib/common.sh`. The CLI must run on stock
  macOS bash 3.2: no associative arrays, no `mapfile`, no `${var,,}`.
- `scripts/` holds checks: `check-secrets.sh`, `check-words.sh` and `shell-snapshot.zsh`.
- `docs/v2-migration.md` tracks the current migration and roadmap. Update it when a step lands.

Rules:

- This repo is public. Never name an employer, client, internal host, account ID or private
  machine here, in files, file names, commit messages or the commit identity. Job-specific files
  belong in a private layer. `scripts/check-words.sh` enforces this from the words that layers
  install; never bypass the hooks with `--no-verify`.
- Never put a token, password or key in this repo. Put it in `~/.config/zsh/local.zsh`, or render
  it from 1Password with `onepasswordRead`.
- Edit files here, never the copies in `~`. Preview with `dotfiles diff`, then `dotfiles apply`.
- Per-machine answers (`work`, `gitName`, `gitEmail`, `personalHost`, `tailnetDomain`,
  `personalKeychainRef`) come from `home/.chezmoi.toml.tmpl`. Lines for work machines go inside
  `{{ if .work }}`, personal-only lines inside `{{ if not .work }}`, and lines that only need a tool
  installed use a shell check like `[[ -d ~/.cargo ]]`. Whole files only some machines get go in
  `home/.chezmoiignore`.
- Every file in `~` has one owner. Never manage a path a layer manages; layers extend the shell
  through `~/.config/zsh/work/*.zsh`.
- To prove a shell change is safe, run `scripts/shell-snapshot.zsh` before and after and diff the
  outputs. To test the CLI without touching the real config, point `DOTFILES_BASE_CONFIG` and
  `DOTFILES_LAYERS_DIR` at test copies.
