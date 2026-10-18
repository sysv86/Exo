# Contributing

## Ground rules

Keep changes scoped. Do not mix bug fixes, refactors, formatting sweeps and
feature work in one pull request. UI changes need a screenshot or a short
description of the before/after.

## Development setup

```bash
./bin/ignis-bin init -c exo/config.lua       # run from the repository
./scripts/install_exo.sh                     # install to ~/.config/ignis-lua
ignis reload                                 # reload a running instance
```

Runtime errors and `run-lua` output go to `~/.cache/exo.log`.

## Code style

- Lua: `snake_case` functions and variables, `PascalCase` classes.
- SCSS: use the Material 3 tokens in `exo/styles/m3.scss` and the palette in
  `colors.scss`; never hardcode colours.
- Widgets are built from `modules/m3components` (buttons, sliders, shapes)
  rather than raw GTK where a Material 3 component exists.
- Keep LDoc annotations on public module functions.
- No narration comments: comment the reason, not the mechanics.

## Testing a change

1. Run the shell from the repository with the config above.
2. Check `~/.cache/exo.log` for warnings or runtime errors.
3. Exercise the affected window: bar widgets, launcher, quick center, settings.
4. Test both light and dark theme when the change touches styling.

## Pull requests

Include the component affected, what changed, how it was verified, and any
compositor-specific behavior (Niri vs Hyprland). Remove unrelated formatting and
local configuration before opening the PR.
