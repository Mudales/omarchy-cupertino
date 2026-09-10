# Cupertino

A macOS-flavored look for the Omarchy shell, in one installable plugin.

- **One radius everywhere.** Panels, popups, menus, notifications, buttons,
  sliders, toggles, and Hyprland window corners.
- **Hairline cards instead of an accent frame.** Themes frame every surface
  with the Hyprland active-border color (a 2px amber band on Golden Hour);
  Cupertino replaces it with a 1px hairline derived from the theme's own
  foreground.
- **Controls that carry state in the fill.** Segmented controls, fields, and
  dropdowns lose their 40%-opacity outlines and read as macOS-style filled
  chips. Keyboard focus keeps an accent ring.

Both halves exist because a theme can't express them. `Style.cornerRadius`
mirrors Hyprland's `decoration:rounding`, so anything that zeroes that option —
the `window-no-gaps` toggle, for one — squares off the whole UI. And a theme's
own `shell.toml` is the file this plugin has to override, so the values layer
onto `Color.userShellValues` instead: the same override layer
`~/.config/omarchy/shell.toml` feeds, which means a key you set there yourself
still wins, and both survive a theme switch.

## Install

```bash
omarchy plugin add https://github.com/Mudales/omarchy-cupertino.git --enable --yes
omarchy restart shell
```

The restart is needed once: the shell hot-reloads plugin *code*, but a newly
added `service` plugin is only instantiated at shell start.

Or by hand:

```bash
git clone https://github.com/Mudales/omarchy-cupertino.git \
  ~/.config/omarchy/plugins/io.github.mudales.cupertino
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.mudales.cupertino
omarchy restart shell
```

## Settings

Settings live on the plugin's own entry in `~/.config/omarchy/shell.json`.
Radius and chrome changes hot-reload on save; nothing needs a restart.

```json
{
  "plugins": [
    { "id": "io.github.mudales.cupertino", "radius": 12, "chrome": true }
  ]
}
```

| Key            | Default  | What it does                                                                      |
|----------------|----------|-----------------------------------------------------------------------------------|
| `radius`       | `12`     | Shell surface rounding. `0` hands the radius back to Hyprland.                    |
| `windows`      | `true`   | Also set Hyprland's `decoration:rounding`.                                        |
| `windowRadius` | `radius` | Window rounding, when it should differ from the shell's.                          |
| `panelGap`     | *unset*  | Distance from panels to the screen edge. Unset follows Hyprland's `general:gaps_out` (halved, as the shell does). |
| `chrome`       | `true`   | Hairline card borders and borderless controls. `false` restores the theme's frame. |
| `borderAlpha`  | `0.14`   | Hairline opacity, 0-1.                                                            |
| `borderWidth`  | `1`      | Hairline thickness, px.                                                           |

Anything you want to keep from your theme, set it in
`~/.config/omarchy/shell.toml` — a key in that file beats the preset here.

## What it touches

At runtime only — no config file is rewritten:

- `Style.cornerRadius` (and `Style.gapsOut`, with `panelGap`)
- Hyprland's `decoration:rounding`, via `hyprctl eval` (Omarchy's Lua config
  parser rejects `hyprctl keyword`; a legacy `hyprland.conf` setup falls back
  to it)
- `border` / `border-width` on the `popups`, `tooltip`, `notifications`,
  `menu`, `launcher`, `polkit`, and `lock` surfaces, plus the shared `controls`
  state tokens. Auth surfaces keep their vivid state colors: only the idle
  border is replaced, and the hairline's opacity rides in the color token
  rather than in the `border-alpha` companion those sections share across
  states.

## Uninstall

```bash
omarchy plugin remove io.github.mudales.cupertino
omarchy restart shell
```

Then `hyprctl reload` to return window corners to your Hyprland config.

## License

MIT
