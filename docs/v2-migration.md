# Version 2 migration

Goal: one modern, public dotfiles repo. The old bash-era setup stays findable at `v1.0.0`, the
previous private chezmoi repo is retired, and job-specific configuration lives in private layers
this repo never names.

Status legend: `[x]` done, `[ ]` to do, `[~]` waiting on Jason.

## Decisions

- Versions follow semver. `v1.0.0` is the 2013 to 2021 bash setup. `v2.0.0` is this chezmoi base.
  Each version gets an annotated tag and a GitHub release.
- 2.0 starts as a fresh tree on top of the 1.0 history: one commit removes the 1.0 files, the next
  adds 2.0. The previous private repo's history is not published; it survives in the private
  employer layer, which was seeded from it.
- Three kinds of repo, applied in this order on each machine:
  - this public base, on every machine;
  - a private shared work layer (`dotjob`), on every work machine, holding reusable work tools;
  - one private layer per employer, so one job's machine never holds another job's configuration.
- Each layer is a separate chezmoi source with its own config in
  `~/.config/chezmoi-layers/<NN-name>/`. chezmoi keeps a state database beside each config, so
  layers never share state. Every file has exactly one owner, and `dotfiles apply` stops when two
  layers manage the same path. Overrides happen at runtime through sorted includes such as
  `~/.config/zsh/work/*.zsh`.
- Nothing job-specific appears in this repo. Private layers install forbidden-word lists in
  `~/.config/dotfiles/forbidden-words.d/`; the pre-commit and commit-msg hooks refuse matches in
  files, names, messages and the commit identity; CI checks every push against a repository secret;
  and a full-history check runs before the first public push and before each release tag.
- The personal machine's name and the tailnet domain come from per-machine answers, never the repo.
  `ssh personal` tries the tailnet relay name first and falls back to `.local`.
- The command is `dotfiles`, a bash 3.2 script in `cli/` linked into `~/.local/bin`. Built-ins are
  one file each; `dotfiles <x>` runs `dotfiles-<x>` from PATH, so layers add commands without this
  repo knowing them. The old `dots` function is gone with no alias.
- The default branch becomes `main`. License is MIT.

## 2.0: migration

- [x] Tag the old state `v1.0.0` and publish a release.
- [x] Seed the private employer layer from the previous repo's full history, then reshape it.
- [x] Retire the 1.0 files and build the 2.0 tree locally: `home/` chezmoi root, `cli/`,
      `scripts/check-words.sh`, hooks, CI workflow, README, AGENTS.md, this file.
- [x] Personal host and tailnet domain moved into per-machine answers; `ssh personal` block with
      relay-first, `.local` fallback, sharing one known_hosts entry. Both routes tested.
- [x] Keychain unlock moved out of the shared `.zshrc`. It goes into `~/.config/zsh/local.zsh` on
      each machine that needs it during that machine's first apply.
- [x] Create the private shared work layer with the personal-files backup command.
- [x] Read-only preview on the work laptop: `dotfiles status`, `dotfiles diff` and
      `dotfiles apply -n` against test copies of the configs. Nothing written.
- [x] `FORBIDDEN_WORDS` Actions secret set on this repo and the shared work layer.
- [x] **Gate 1, before the first public push.** Review the full-history words check, the tree and
      `git log`. Then push `main`, make it the default branch, delete `master`, set the
      description, turn off the wiki, and push the shared work layer.
- [x] Laptop cutover:
  1. Move `~/code/dots` aside.
  2. Run `chezmoi init --source ~/code/dotfiles` without `--apply`, so it rewrites
     `~/.config/chezmoi/chezmoi.toml` from the new template and asks the two new questions.
  3. Add the layer configs in `~/.config/chezmoi-layers/`.
  4. Append the keychain unlock block to `~/.config/zsh/local.zsh`.
  5. Review `~/code/dotfiles/cli/dotfiles diff`. Use the repo path, because `dotfiles` is not on
     PATH until the first apply creates the link.
  6. Apply, then remove the files the old setup installed that no layer manages any more (the list
     is in the employer layer's docs).
- [x] **Gate 2a.** Laptop diff reviewed against the earlier preview and applied. A shell snapshot
      before and after differs only in the removed `dots` function, the old per-machine ssh helper, and the new
      `personal` function.
- [x] Personal machine cutover over `ssh personal`:
  1. Rename its checkout to `~/code/dotfiles` and point it at the public repo (pulls need no login).
  2. Reset to `main`.
  3. Run `chezmoi init --source ~/code/dotfiles` for the new answers.
  4. Append the keychain unlock block to its `~/.config/zsh/local.zsh`. It has a keychain password
     file too, and the shared `.zshrc` no longer unlocks.
  5. Review the diff and apply.
- [x] **Gate 2b.** Personal machine diff matched the preview and was applied. Its snapshot differs
      only by the new `ccp`, the removed `dots`, and per-session SSH variables.
- [~] The personal machine no longer keeps a keychain password file. Interactive SSH logins ask for
      the login password only while the keychain is locked, so the first connection prompts once.
      Jason confirms the second connection stays quiet.
- [~] Old backups on the personal machine that predate this migration, such as
      `~/.dots-backup-20261012`, may hold tokens. Review and remove them by hand.

- [x] Full-history words check again, then tag `v2.0.0` and publish a release.
- [x] **Gate 3, part 1.** Confirmed the employer layer holds every commit of the previous repo
      (10 of 10, no other refs, issues, pull requests, releases or secrets), then archived the
      previous repo so nothing can push to it.
- [x] **Gate 3, part 2.** Jason deleted the archived previous repo. The retired local copies went
      to the Trash on both machines.

## 2.1: setup

- [ ] `install.sh`: plain bash 3.2, installs Homebrew, chezmoi, clones, runs `dotfiles setup`.
- [ ] `dotfiles setup`: one file per step in `cli/setup/NN-<step>.sh`, each with `check` and `fix`.
      Steps only run when `check` fails, so a halted run resumes. `--redo <step>`, `--redo-all`,
      `--dry-run`, and a flag for every prompt plus `-y` for agents.
- [ ] A `Brewfile` per layer, applied with `brew bundle` only when it changes. Never an automatic
      `brew bundle cleanup`.
- [ ] `dotfiles install <pkg>` and `dotfiles remove <pkg>` (alias `uninstall`): run brew, update
      the chosen layer's Brewfile with `brew bundle add` or `remove`, commit and push.

## 2.2: discoverability

- [ ] [usage](https://github.com/jdx/usage) spec lines in every command file, generating help,
      `docs/cli.md`, zsh completions and an MCP listing. `usage lint` in CI.
- [ ] Bare `dotfiles` in a terminal, or `dotfiles -i`, opens a menu of every command built from the
      specs with [gum](https://github.com/charmbracelet/gum). Picking one prompts for its options,
      prints the equivalent command, and runs it. Plugins join by printing a spec with
      `--usage-spec`; plugins without one get a free-form prompt.
- [ ] `dotfiles doctor`: sources present, remotes, file collisions, forbidden words, env file,
      Brewfile drift. Reports only.
- [ ] `dotfiles edit [layer]`, and `dotfiles hosts` joining a local `devices` map with
      `tailscale status --json`.

## Later

- [ ] Review `v1.0.0` for anything worth bringing into 2.x, such as the macOS defaults.
- [ ] Device descriptions in the tailnet policy file, as comments beside `hosts` aliases.
- [ ] Make the layers Linux-ready (templates already branch on `.chezmoi.os` where needed).
- [ ] The multi-job workstation project lives in the shared work layer's docs.
- [ ] A starter template for new employer layers lives in the shared work layer's `template/`.
