# dotfiles

Jason's dotfiles for his Macs, managed with [chezmoi](https://www.chezmoi.io) and driven by a small
`dotfiles` command. A few questions asked once per machine decide which parts each one gets.

This is version 2. The bash-era setup from 2013 to 2021 lives at the
[`v1.0.0` tag](https://github.com/JawsomeJason/dotfiles/tree/v1.0.0).

## Everyday use

- `dotfiles` in a terminal opens a menu of every command: pick one, pick the options you want, and
  it shows the equivalent command line before running it. In scripts, bare `dotfiles` is `status`.
- `dotfiles status` shows what differs between the repos and your home folder.
- `dotfiles diff` shows the exact changes `dotfiles apply` would make.
- `dotfiles apply` writes the base, then each layer, into your home folder.
- `dotfiles sync` pulls every layer's repo, then applies.
- `dotfiles layers` lists the layers on this machine and whether they have local changes.
- `cd "$(dotfiles path)"` goes to this repo, so you can commit and push.
- `dotfiles doctor` checks every layer, the machine's answers, forbidden words and Homebrew drift,
  and reports what needs fixing without changing anything.
- `dotfiles edit [layer]` opens a layer's repo in your editor.
- `dotfiles hosts` lists your tailnet machines with descriptions from `~/.config/dotfiles/devices`
  (one `name = description` per line, kept on each machine) and whether each is online.
- `dotfiles help` lists every command, including plugins. Every command is described in
  [`docs/cli.md`](docs/cli.md), and zsh completes commands, options and layer names.

- `dotfiles install <package>` installs with Homebrew and records it in the base `Brewfile`, so
  every machine gets it; `-l job` or `-l <employer>` keeps it to work machines and `--personal`
  to personal ones. `dotfiles remove <package>` (or `uninstall`) takes it out of whichever
  Brewfile lists it and uninstalls it. Both commit and push the Brewfile they change.

Add `-n` to preview `apply` or `sync`, `-l <layer>` to act on one layer, and `-v` to see each
chezmoi and git command. Edit files in this repo, not the copies in your home folder;
`dotfiles apply` overwrites those copies.

## Setting up a new Mac

```sh
curl -fsSL https://raw.githubusercontent.com/JawsomeJason/dotfiles/main/install.sh | bash
```

`install.sh` installs Homebrew, git, chezmoi, gh and gum, clones this repo to `~/code/dotfiles`,
and runs `dotfiles setup`. Setup works through numbered steps, each one checking the machine's real
state first, so it asks only for what is missing and is safe to rerun after a stop:

- The machine's answers, saved in `~/.config/chezmoi/chezmoi.toml`: whether it is a work machine,
  the git author name and email, the personal machine's short hostname and the domain that reaches
  tailnet machines by name (together they set up `ssh personal`, which tries `<host>.<domain>`
  first and falls back to `<host>.local`), and optionally a 1Password `op://` reference to the
  personal machine's login password, which `personal` sends with each connection so the remote
  keychain unlocks without a prompt.
- Applying this base, after showing the diff.
- Signing in to GitHub and setting a personal git email in this repo.
- On a work machine, the private layers (see the `dotjob` layer's `PLAYBOOK.md`).

`dotfiles setup -n` lists the steps still to do. Every question has a flag, and `--yes` takes the
defaults, so agents run it without prompts: see `dotfiles help setup`. To change an answer later,
edit `~/.config/chezmoi/chezmoi.toml` and run `dotfiles apply`.

## Layers

A machine can stack private layers on top of this public base. Each layer is its own chezmoi
source with its own config at `~/.config/chezmoi-layers/<NN-name>/chezmoi.toml`, and `dotfiles`
applies the base first, then each layer in name order:

```sh
mkdir -p ~/.config/chezmoi-layers/10-example
printf 'sourceDir = "%s"\n' ~/code/example-layer > ~/.config/chezmoi-layers/10-example/chezmoi.toml
dotfiles apply
```

Rules that keep layers from fighting:

- Every file has exactly one owner. `dotfiles apply` stops when two layers manage the same path.
- Layers add shell setup by dropping files into `~/.config/zsh/work/`. The base `~/.zshrc` sources
  them in name order, so a later layer's file wins.
- A layer can list words in `~/.config/dotfiles/forbidden-words.d/`. This repo's hooks refuse any
  commit that contains one, in files, file names, messages or the author identity, and CI checks
  every push against the same list kept in a repository secret.
- Any executable named `dotfiles-<name>` on your PATH becomes `dotfiles <name>`, so a layer can add
  commands without this repo knowing about them.

## What goes where

Every machine:

- `~/.zshrc`: nvm with automatic `.nvmrc` switching, aliases, the cctab hook, the LCARS prompt,
  autosuggestions and syntax highlighting, and the work-layer hook.
- `~/.zprofile`, `~/.gitconfig` (name and email from the machine's answers),
  `~/.config/git/ignore` and `~/.config/gh/config.yml`.
- `~/.config/zsh/lcars-prompt.zsh`, plus the Ghostty LCARS theme and the Ghostty config that turns
  it on.
- `~/.local/bin/dotfiles`, a link to `cli/dotfiles` in this repo.
- `~/.config/dotfiles/env`, the machine's answers for layers and plugins to read.
- `~/.ssh/config.d/dotfiles` with the `personal` host, plus one `Include` line at the top of
  `~/.ssh/config`. Skipped when the personal host is blank.

Work machines only: the `--chrome` flag on `cc`.

Every machine except the personal one: the `personal` function, which opens a shell there or runs
a command with its aliases loaded.

Every Mac: SSH logins start with the login keychain locked. `~/.zshrc` unlocks it with a password the
connecting machine forwarded, or asks for it once in that session when none arrived. The receiving
machine's SSH server has to accept the variable once:

```sh
echo 'AcceptEnv DOTFILES_KEYCHAIN_PASSWORD' | sudo tee /etc/ssh/sshd_config.d/200-dotfiles.conf
```

Personal machines only: the Go, Cargo, rustup and bun paths, the openclaw completion, and
`~/.zshenv`, which loads the shell setup into non-interactive SSH commands.

Machine-local and never in git: `~/.config/zsh/local.zsh`, which `~/.zshrc` loads. It holds every
token and anything else only one machine needs, and has mode 600.

## Packages

Each layer keeps a `Brewfile` at its repo root: this repo's lists what every Mac gets, and its
`Brewfile.personal` adds what only personal machines get. Whenever a Brewfile changes,
`dotfiles apply` runs `brew bundle install --no-upgrade` for it. Nothing is ever upgraded or
removed automatically; `dotfiles remove` is the only way a package leaves. `dotfiles setup`
installs anything a Brewfile lists that is still missing.

## Secrets

No secret goes in this repo. The pre-commit hook runs `scripts/check-secrets.sh`, which refuses
anything shaped like a token, and `scripts/check-words.sh`, which refuses forbidden words. chezmoi
turns the hooks on for every machine.

To move a token from `local.zsh` into 1Password, store it there and render it from a template:

```sh
# home/private_dot_config/zsh/private_secrets.zsh.tmpl
export FIGMA_ACCESS_TOKEN={{ onepasswordRead "op://Private/Figma/token" | quote }}
```

Then source `~/.config/zsh/secrets.zsh` from `local.zsh` and delete the old line.

## Checking a change

`scripts/shell-snapshot.zsh` prints what an interactive shell ends up with: aliases, functions,
hooks, options, PATH, and every environment variable with its value hashed. Save its output before
a change and diff it with the output after.

## Roadmap

[`docs/v2-migration.md`](docs/v2-migration.md) tracks the move to version 2 and what comes next.
