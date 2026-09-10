import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons

// Cupertino — a macOS-flavored look for the Omarchy shell.
//
// Two things the shell can't express through a theme:
//
//   Radius. Every corner in the UI kit derives from Style.cornerRadius, which
//   mirrors Hyprland's decoration:rounding — so anything that zeroes that
//   option (the window-no-gaps toggle, for one) squares off panels, popups,
//   menus and controls along with the windows. This service holds Style at the
//   configured value and pushes the same value onto Hyprland.
//
//   Chrome. Themes frame every card with the Hyprland active-border accent and
//   outline every control at 40% foreground. macOS does neither: cards get a
//   hairline, controls get a fill. The values below layer onto Color's user
//   shell.toml dict — the same override layer ~/.config/omarchy/shell.toml
//   feeds, so a key you set there yourself still wins, and both survive theme
//   switches.
//
// Settings live on this plugin's own entry in ~/.config/omarchy/shell.json and
// hot-reload on save:
//
//   { "id": "io.github.mudales.cupertino", "radius": 12, "chrome": true }
//
//   radius       shell surfaces (panels, popups, menus, notifications,
//                buttons, sliders, toggles). 0 leaves the radius to Hyprland.
//   windows      also set Hyprland's decoration:rounding. Default true.
//   windowRadius window rounding, when it should differ from `radius`.
//   panelGap     distance from panel edges to the screen edge. Omit to keep
//                following Hyprland's general:gaps_out.
//   chrome       hairline card borders and borderless controls. Default true.
//   borderAlpha  hairline opacity, 0-1. Default 0.14.
//   borderWidth  hairline thickness in px. Default 1.
Item {
  id: root

  // Injected by the shell host.
  property var shell: null
  property var manifest: null

  readonly property string fallbackId: "io.github.mudales.cupertino"
  readonly property string pluginId: (manifest && manifest.id) ? String(manifest.id) : fallbackId
  readonly property int defaultRadius: 12

  property int radius: defaultRadius
  property bool roundWindows: true
  property int windowRadiusOverride: -1
  property int panelGap: -1
  property bool chrome: true
  property real borderAlpha: 0.14
  property int borderWidth: 1

  readonly property bool active: radius > 0
  readonly property int windowRadius: windowRadiusOverride >= 0 ? windowRadiusOverride : radius

  // Cards whose border is the theme's accent frame. Auth surfaces are in the
  // list for their idle border only: polkit's `border-error` and lock's
  // `border-active` / `border-error` keep the theme's vivid state colors, so
  // the alpha rides in the color token rather than the shared `border-alpha`
  // companion those sections apply to every state at once.
  readonly property var cardSections: ["popups", "tooltip", "notifications", "menu", "launcher", "polkit", "lock"]

  // ------------------------------------------------------------------ config

  function settingOf(entry, key) {
    return (entry && key in entry) ? entry[key] : undefined
  }

  // Anything absent or unparseable keeps `fallback`, so a typo in shell.json
  // degrades to the default instead of to zero.
  function intOr(value, fallback) {
    var n = Number(value)
    return (isFinite(n) && n >= 0) ? Math.round(n) : fallback
  }

  function realOr(value, fallback) {
    var n = Number(value)
    return isFinite(n) ? Math.max(0, Math.min(1, n)) : fallback
  }

  function ownEntry(raw) {
    try {
      var json = JSON.parse(raw || "{}")
      var list = Array.isArray(json.plugins) ? json.plugins : []
      for (var i = 0; i < list.length; i++) {
        if (list[i] && String(list[i].id) === root.pluginId) return list[i]
      }
    } catch (e) {
      // Malformed shell.json — the shell reports that itself; keep defaults.
    }
    return null
  }

  function applySettings(raw) {
    var entry = ownEntry(raw)
    radius = intOr(settingOf(entry, "radius"), defaultRadius)
    roundWindows = settingOf(entry, "windows") !== false
    windowRadiusOverride = intOr(settingOf(entry, "windowRadius"), -1)
    panelGap = intOr(settingOf(entry, "panelGap"), -1)
    chrome = settingOf(entry, "chrome") !== false
    borderAlpha = realOr(settingOf(entry, "borderAlpha"), 0.14)
    borderWidth = intOr(settingOf(entry, "borderWidth"), 1)
    apply()
  }

  function apply() {
    applyShellRadius()
    applyPanelGap()
    applyWindowRadius()
    applyChrome()
  }

  // ------------------------------------------------------------------ radius

  function applyShellRadius() {
    if (!root.active) return
    if (Style.cornerRadius !== root.radius) Style.cornerRadius = root.radius
  }

  function applyPanelGap() {
    if (!root.active || root.panelGap < 0) return
    if (Style.gapsOut !== root.panelGap) Style.gapsOut = root.panelGap
  }

  function applyWindowRadius() {
    if (!root.active || !root.roundWindows) return
    if (queryProc.running || luaProc.running || keywordProc.running) return
    queryProc.running = true
  }

  // Read Hyprland's live value before writing: a no-op write is skipped, which
  // keeps the config-reload path from turning into a write loop.
  function handleWindowRounding(raw) {
    var current = -1
    try {
      var json = JSON.parse(raw || "{}")
      var n = Number(json.int)
      if (isFinite(n)) current = n
    } catch (e) {
      return // hyprctl missing or Hyprland not up — leave windows alone.
    }
    if (current < 0 || current === root.windowRadius) return
    luaProc.command = ["hyprctl", "eval",
      "hl.config({ decoration = { rounding = " + root.windowRadius + " } })"]
    luaProc.running = true
  }

  Process {
    id: queryProc
    command: ["hyprctl", "-j", "getoption", "decoration:rounding"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.handleWindowRounding(text)
    }
  }

  // Omarchy configures Hyprland in Lua, and the Lua parser refuses `hyprctl
  // keyword` ("keyword can't work with non-legacy parsers"). Take the eval
  // path first and fall back to keyword for a legacy hyprland.conf setup;
  // both report failure on stdout with exit code 0, so read the reply.
  Process {
    id: luaProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (String(text).replace(/^\s+|\s+$/g, "").indexOf("ok") === 0) {
          Style.scheduleRefresh()
          return
        }
        keywordProc.command = ["hyprctl", "keyword", "decoration:rounding", String(root.windowRadius)]
        keywordProc.running = true
      }
    }
  }

  Process {
    id: keywordProc
    // Neither write raises configreloaded, so re-poll Style by hand to keep
    // its idea of Hyprland's rounding honest.
    onExited: Style.scheduleRefresh()
  }

  // ------------------------------------------------------------------ chrome

  // Keys this service put into Color.userShellValues last round, so a stale
  // hairline from the previous theme is withdrawn instead of accumulating.
  property var injected: ({})

  function hexByte(unit) {
    var s = Math.max(0, Math.min(255, Math.round(unit * 255))).toString(16)
    return s.length < 2 ? "0" + s : s
  }

  // "#rrggbbaa". Baking opacity into the color keeps each surface independent
  // of its `*-alpha` companion, which polkit and lock share across states.
  function withAlpha(color, alpha) {
    return "#" + hexByte(color.r) + hexByte(color.g) + hexByte(color.b) + hexByte(alpha)
  }

  function chromePreset() {
    var preset = ({})
    if (!root.chrome) return preset

    var hairline = withAlpha(Color.foreground, root.borderAlpha)
    for (var i = 0; i < root.cardSections.length; i++) {
      var section = root.cardSections[i]
      preset[section + ".border"] = hairline
      preset[section + ".border-width"] = String(root.borderWidth)
    }

    // `selected-border` has no width of its own, so it inherits the card's
    // `border-width` through Border's fallback chain and boxes in every
    // selected menu row. macOS fills the row and leaves it unstroked.
    preset["menu.selected-border-width"] = "0"
    preset["launcher.selected-border-width"] = "0"

    // Controls carry their state in the fill, the way macOS draws segmented
    // controls and fields. Focus keeps a ring — it is the keyboard's only cue.
    preset["controls.normal-border-width"] = "0"
    preset["controls.normal-fill-alpha"] = "0.05"
    preset["controls.hover-cursor-border-width"] = "0"
    preset["controls.hover-cursor-fill-alpha"] = "0.10"
    preset["controls.selected-border-width"] = "0"
    preset["controls.selected-fill-alpha"] = "0.20"
    preset["controls.focus-color"] = "accent"
    preset["controls.focus-border-width"] = "1"
    preset["controls.focus-border-alpha"] = "0.55"
    preset["controls.focus-fill-alpha"] = "0.12"
    return preset
  }

  function sameDict(a, b) {
    for (var ak in a) if (b[ak] !== a[ak]) return false
    for (var bk in b) if (a[bk] !== b[bk]) return false
    return true
  }

  function applyChrome() {
    var preset = chromePreset()
    var current = Color.userShellValues || ({})
    var next = ({})

    // Everything the user's own shell.toml says, minus what we injected last
    // round; then the preset fills the gaps. A key present in both is the
    // user's — their file wins over this plugin's opinion.
    for (var k in current) {
      if (root.injected[k] !== undefined && root.injected[k] === current[k]) continue
      next[k] = current[k]
    }
    var applied = ({})
    for (var pk in preset) {
      if (pk in next) continue
      next[pk] = preset[pk]
      applied[pk] = preset[pk]
    }

    if (sameDict(next, current)) return
    root.injected = applied
    Color.userShellValues = next
    Color.mergeShell()
  }

  // ------------------------------------------------------------------ watches

  // Style re-polls Hyprland on theme changes and gap toggles, and a config
  // reload drops any runtime rounding we set. Re-assert on both.
  Connections {
    target: Style
    function onCornerRadiusChanged() { root.applyShellRadius() }
    function onGapsOutChanged() { root.applyPanelGap() }
  }

  // A theme switch replaces the palette and the theme half of shellValues, and
  // an edit to ~/.config/omarchy/shell.toml replaces the user half. Both land
  // here; re-derive the hairline from the palette that is current now.
  Connections {
    target: Color
    function onUserShellValuesChanged() { root.applyChrome() }
    function onForegroundChanged() { root.applyChrome() }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event && String(event.name) === "configreloaded") reapplyTimer.restart()
    }
  }

  // Hyprland finishes a reload asynchronously; give it a beat before asking
  // what the rounding ended up as.
  Timer {
    id: reapplyTimer
    interval: 250
    repeat: false
    onTriggered: root.apply()
  }

  FileView {
    id: shellConfigFile
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.applySettings(text())
    onLoadFailed: root.applySettings("")
    // `text()` is stale inside the change signal, so route changes through
    // reload() → onLoaded and always parse fresh content.
    onFileChanged: reload()
  }

  Component.onCompleted: apply()
}
