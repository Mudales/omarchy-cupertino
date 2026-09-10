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
- **Windows lit and separated the same way.** A soft drop shadow (Omarchy
  ships with `decoration:shadow` off) and a 1px window edge in the card's
  hairline, brighter on the focused window than the rest.

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

### The whole style at once

`bootstrap.sh` installs this plugin *and* [Tahoe Lock
Screen](https://github.com/Mudales/omarchy-tahoe-lock), the macOS-style lock
screen this look was drawn next to:

```bash
git clone https://github.com/Mudales/omarchy-cupertino
./omarchy-cupertino/bootstrap.sh
```

The clone you run it from is just the installer — both plugins land in
`~/.config/omarchy/plugins/` as ordinary git checkouts, so `omarchy plugin
update` keeps working on each of them afterwards. Re-running the script updates
instead of failing.

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
| `borderWidth`  | `1`      | Hairline thickness, px — cards and window edges alike.                            |
| `shadow`       | `true`   | Soft drop shadow under windows.                                                   |
| `shadowRange`  | `24`     | Shadow spread, px.                                                                |
| `windowBorder` | `true`   | 1px window edge in the hairline color, at `borderAlpha` × 1.6 focused and × 0.7 not. |

Anything you want to keep from your theme, set it in
`~/.config/omarchy/shell.toml` — a key in that file beats the preset here.

## What it touches

At runtime only — no config file is rewritten:

- `Style.cornerRadius` (and `Style.gapsOut`, with `panelGap`)
- Hyprland's `decoration:rounding`, `decoration:shadow`, `general:border_size`
  and `general:col.active_border` / `col.inactive_border`, via `hyprctl eval`
  (Omarchy's Lua config parser rejects `hyprctl keyword`; a legacy
  `hyprland.conf` setup falls back to it). The live values are read first, so a
  push that would change nothing is skipped, and only `shadow:enabled` is
  compared — a range or color you tuned yourself survives a reload
- `border` and `border-width` on the `popups`, `tooltip`, `notifications`,
  `menu` and `launcher` surfaces, plus the shared `controls` state tokens
- `border` — the idle one only — on `polkit` and `lock`. Their `border-active`
  and `border-error` states resolve their width through the section's plain
  `border-width`, so pinning that would thin the wrong-password flash to a
  hairline; the opacity rides in the color token for the same reason, since
  those sections apply one `border-alpha` to every state at once

These settings push rather than own: turning one off stops the plugin managing
that option, and Hyprland keeps the last value pushed until its next config
reload — `hyprctl reload`, or any edit to your hypr config — which returns it to
whatever your own config says. Turning one back on applies immediately, on the
`shell.json` save alone.

Shadows need somewhere to land: with `general:gaps_out` at 0 and windows
tiled edge to edge, the shadow is covered by the neighbor it falls on and only
shows around floating windows. A gap of 4-8px is what makes both it and the
window hairline read.

## Uninstall

```bash
omarchy plugin remove io.github.mudales.cupertino
omarchy restart shell
```

Then `hyprctl reload` to return window corners to your Hyprland config.

## License

MIT
