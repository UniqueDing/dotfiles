# Colorscheme OpenCode Integration Design

## Goal

Make `cs` switch OpenCode's terminal UI theme through its official TUI
configuration, while making the existing multi-application theme switcher safer
and easier to maintain. Preserve the current selector names and the existing
theme behaviour for all other tools.

## Scope

- Keep the six existing profiles: `catppuccin_mocha`, `tokyonight_moon`,
  `nord`, `onedark`, `dracula`, and `gruvbox_dark`.
- Refactor `conf/zsh/fun/colorscheme.zsh` so per-tool theme aliases are held in
  one centralized profile mapping rather than scattered `case` statements.
- Add OpenCode's tracked TUI `theme` setting to `conf/opencode/tui.json`.
- Update OpenCode through `~/.config/opencode/tui.json`, not
  `opencode.jsonc`.
- Validate the selected profile, required configuration files, and external
  theme assets before changing any configuration.
- Use temporary files and atomic replacement for rewritten configuration files.
- Preserve the existing tmux reload and clearly report that other applications,
  including OpenCode, must be restarted to display the new theme.

## Non-goals

- Do not change the set of selectable profiles.
- Do not change OpenCode providers, credentials, agents, MCPs, permissions, or
  plugins.
- Do not reconcile the separate plugin declarations in `opencode.jsonc` and
  `tui.json`.
- Do not add desktop, archived, or unrelated application themes to `cs`.
- Do not implement live reload for applications that do not support it.

## Theme mapping

The profile name remains the default alias for tools whose asset names already
match it. Explicit aliases are defined only where a consumer uses a different
identifier.

| Profile | Neovim | Yazi | eza | OpenCode |
| --- | --- | --- | --- | --- |
| `catppuccin_mocha` | `catppuccin-nvim` | `catppuccin-mocha` | `catppuccin` | `catppuccin` |
| `tokyonight_moon` | `tokyonight` | `tokyo-night` | `tokyonight` | `tokyonight` |
| `nord` | `nordic` | `nord` | `nord` | `nord` |
| `onedark` | `onedark` | `onedark` | `onedark` | `one-dark` |
| `dracula` | `dracula` | `dracula` | `dracula` | `dracula` |
| `gruvbox_dark` | `gruvbox` | `gruvbox-dark` | `gruvbox-dark` | `gruvbox` |

OpenCode's `catppuccin` built-in theme is its Mocha palette. The distinct
`catppuccin-macchiato` theme is deliberately not used for the Mocha profile.

## Switch flow

1. `cs` shows the current profile and prompts from the existing six-item list.
2. `modify_scheme` rejects an empty or unknown profile before making changes.
3. It resolves all consumer aliases from the central mapping and verifies that
   every target configuration file exists. It additionally checks the selected
   eza, tmux, and Lazygit theme files.
4. It stages textual updates in temporary files beside their targets:
   Starship palette, Neovim colorscheme, Yazi dark flavor, bat theme, tmux theme
   source, Lazygit theme block, Git Delta syntax theme, and OpenCode TUI theme.
5. The OpenCode update targets the top-level `theme` property in
   `~/.config/opencode/tui.json`; the tracked file contains the property from
   the start. The replacement preserves valid JSON and does not touch
   `opencode.jsonc`.
6. Once all staging succeeds, the function atomically moves the staged files
   into place, updates the eza symlink, reloads tmux, then writes the selected
   canonical profile to `~/.config/colorscheme`.
7. The function prints a concise completion message that tmux was reloaded and
   that OpenCode and other affected applications need restarting.

## Failure behaviour

- `set -x` is removed so normal switching does not emit command traces.
- Quoted variable expansions are used for paths and values.
- A failed validation or failed staging operation leaves the existing live
  configuration untouched.
- A tmux reload failure is reported after files are updated; it does not undo
  the selected configuration because the next tmux startup will read it.
- The design does not promise rollback for a filesystem failure during the final
  sequence of atomic moves, but it minimizes that window by completing all
  fallible generation before altering live files.

## Verification

- Add or update a focused shell test covering every profile's OpenCode alias,
  including `catppuccin_mocha -> catppuccin` and `onedark -> one-dark`.
- Test that the TUI configuration, rather than `opencode.jsonc`, receives the
  OpenCode theme update.
- Test that missing required config or theme assets stop before any target file
  changes.
- Run `zsh -n conf/zsh/fun/colorscheme.zsh` and `git diff --check`.
- Manually run `cs`, select a profile, restart OpenCode, and confirm its TUI
  theme matches the selected profile.
