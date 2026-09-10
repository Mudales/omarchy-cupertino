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
//   borderWidth  hairline thickness in px, cards and window edges alike.
//                Default 1.
//   shadow       soft drop shadow under windows. Default true.
//   shadowRange  shadow spread in px. Default 24.
//   windowBorder hairline edge on windows, in the card hairline's color.
//                Default true.
//   workspaceAnimation
//                short movement when switching workspaces, which Omarchy
//                ships disabled. Default true; -Speed (tenths of a second,
//                default 2.5) and -Style (default "slidefade 15%") tune it.
//   resizeOnBorder
//                drag a window's edge to resize it — the 1px edge above is
//                too thin to grab without it. Default true; borderGrabArea
//                (default 8px) is how far from the edge the grab starts.
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
  property bool shadow: true
  property int shadowRange: 24
  property bool windowBorder: true
  property bool workspaceAnimation: true
  property real workspaceAnimationSpeed: 2.5
  property string workspaceAnimationStyle: "slidefade 15%"
  property bool resizeOnBorder: true
  property int borderGrabArea: 8

  readonly property string workspaceAnimationCurve: "easeOutQuint"

  // macOS separates its windows with a light edge that is brighter on the
  // focused one. Both are the card hairline, leaned either side of it.
  readonly property real activeBorderAlpha: Math.min(1, root.borderAlpha * 1.6)
  readonly property real inactiveBorderAlpha: Math.min(1, root.borderAlpha * 0.7)

  readonly property bool active: radius > 0
  readonly property int windowRadius: windowRadiusOverride >= 0 ? windowRadiusOverride : radius

  // Cards whose border is pure decoration: color and thickness are both ours.
  readonly property var cardSections: ["popups", "tooltip", "notifications", "menu", "launcher"]

  // Auth surfaces get the hairline on their idle border and nothing else.
  // Their `border-active` / `border-error` states resolve width through the
  // section's plain `border-width`, so setting that here would thin the
  // wrong-password flash from the 2-3px those plugins ask for down to a
  // hairline — the one moment the border is carrying information. The opacity
  // rides in the color token for the same reason: polkit and lock apply one
  // `border-alpha` to every state at once.
  readonly property var authSections: ["polkit", "lock"]

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

  function positiveOr(value, fallback) {
    var n = Number(value)
    return (isFinite(n) && n > 0) ? n : fallback
  }

  // Guards the Lua string too: a quote or a newline in a theme-adjacent value
  // would otherwise end up inside the payload we hand to `hyprctl eval`.
  function stringOr(value, fallback) {
    if (typeof value !== "string") return fallback
    var trimmed = value.replace(/^\s+|\s+$/g, "")
    if (trimmed.length === 0 || trimmed.match(/["'\\\n\r;]/)) return fallback
    return trimmed
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
    shadow = settingOf(entry, "shadow") !== false
    shadowRange = intOr(settingOf(entry, "shadowRange"), 24)
    windowBorder = settingOf(entry, "windowBorder") !== false
    workspaceAnimation = settingOf(entry, "workspaceAnimation") !== false
    workspaceAnimationSpeed = positiveOr(settingOf(entry, "workspaceAnimationSpeed"), 2.5)
    workspaceAnimationStyle = stringOr(settingOf(entry, "workspaceAnimationStyle"), "slidefade 15%")
    resizeOnBorder = settingOf(entry, "resizeOnBorder") !== false
    borderGrabArea = intOr(settingOf(entry, "borderGrabArea"), 8)
    // A settings edit has to reach Hyprland even when every value it can read
    // back already matches — the animation is the one it cannot read cheaply.
    apply(true)
  }

  function hexByte(unit) {
    var s = Math.max(0, Math.min(255, Math.round(unit * 255))).toString(16)
    return s.length < 2 ? "0" + s : s
  }

  function apply(force) {
    applyShellRadius()
    applyPanelGap()
    applyHyprland(force === true)
    applyChrome()
  }

  // ---------------------------------------------------------------- hyprland

  function applyShellRadius() {
    if (!root.active) return
    if (Style.cornerRadius !== root.radius) Style.cornerRadius = root.radius
  }

  function applyPanelGap() {
    if (!root.active || root.panelGap < 0) return
    if (Style.gapsOut !== root.panelGap) Style.gapsOut = root.panelGap
  }

  function managesHyprland() {
    return root.roundWindows || root.shadow || root.windowBorder
      || root.workspaceAnimation || root.resizeOnBorder
  }

  // `force` skips the read-back comparison. A settings edit uses it, because
  // the values that changed may be ones this plugin cannot read back.
  function applyHyprland(force) {
    if (!root.active || !managesHyprland()) return
    if (queryProc.running || luaProc.running || keywordProc.running) return
    root.pendingForce = force === true
    queryProc.running = true
  }

  property bool pendingForce: false

  // Hyprland echoes a gradient as "aarrggbb <angle>deg".
  function gradientEcho(color, alpha) {
    return (hexByte(alpha) + hexByte(color.r) + hexByte(color.g) + hexByte(color.b) + " 0deg").toLowerCase()
  }

  function rgbaToken(color, alpha) {
    return "rgba(" + hexByte(color.r) + hexByte(color.g) + hexByte(color.b) + hexByte(alpha) + ")"
  }

  // Read the live values before writing: a push that would change nothing is
  // skipped, which is what keeps the config-reload path from becoming a write
  // loop if a Hyprland release ever raises configreloaded for its own eval.
  function needsPush(raw) {
    var seen = ({})
    var animations = ({})
    // Every object in the reply is flat — `getoption` returns one, and each
    // entry of `animations` is one — so a non-greedy brace match splits them
    // without needing a JSON parser for the batch envelope itself.
    var objects = String(raw || "").match(/\{[^{}]*\}/g) || []
    for (var i = 0; i < objects.length; i++) {
      try {
        var json = JSON.parse(objects[i])
        if (!json) continue
        if (json.option) seen[String(json.option)] = json
        else if (json.name) animations[String(json.name)] = json
      } catch (e) {
        // Partial or unparseable reply; the remaining objects still count.
      }
    }

    if (root.roundWindows) {
      var rounding = seen["decoration:rounding"]
      if (!rounding || Number(rounding.int) !== root.windowRadius) return true
    }
    // Only `enabled` is compared: range, power and color are taste, and a
    // hand-tuned value in your own Hyprland config should survive a reload.
    if (root.shadow) {
      var shadowOption = seen["decoration:shadow:enabled"]
      if (!shadowOption || shadowOption.bool !== true) return true
    }
    if (root.windowBorder) {
      var size = seen["general:border_size"]
      if (!size || Number(size.int) !== root.borderWidth) return true
      var activeBorder = seen["general:col.active_border"]
      if (!activeBorder || String(activeBorder.gradient || "").toLowerCase()
        !== gradientEcho(Color.foreground, root.activeBorderAlpha)) return true
      var inactiveBorder = seen["general:col.inactive_border"]
      if (!inactiveBorder || String(inactiveBorder.gradient || "").toLowerCase()
        !== gradientEcho(Color.foreground, root.inactiveBorderAlpha)) return true
    }
    if (root.resizeOnBorder) {
      var resize = seen["general:resize_on_border"]
      if (!resize || resize.bool !== true) return true
      var grab = seen["general:extend_border_grab_area"]
      if (!grab || Number(grab.int) !== root.borderGrabArea) return true
    }
    if (root.workspaceAnimation) {
      var workspaces = animations["workspaces"]
      if (!workspaces || workspaces.enabled !== true) return true
      if (Math.abs(Number(workspaces.speed) - root.workspaceAnimationSpeed) > 0.001) return true
      if (String(workspaces.style || "") !== root.workspaceAnimationStyle) return true
      if (String(workspaces.bezier || "") !== root.workspaceAnimationCurve) return true
    }
    return false
  }

  function shadowColor() {
    return "rgba(0000004d)"
  }

  function hyprlandLua() {
    var decoration = []
    var general = []
    if (root.roundWindows) decoration.push("rounding = " + root.windowRadius)
    if (root.shadow) {
      decoration.push("shadow = { enabled = true, range = " + root.shadowRange
        + ", render_power = 3, color = \"" + shadowColor() + "\" }")
    }
    if (root.windowBorder) {
      general.push("border_size = " + root.borderWidth)
      general.push("col = { active_border = \"" + rgbaToken(Color.foreground, root.activeBorderAlpha)
        + "\", inactive_border = \"" + rgbaToken(Color.foreground, root.inactiveBorderAlpha) + "\" }")
    }
    if (root.resizeOnBorder) {
      general.push("resize_on_border = true")
      general.push("extend_border_grab_area = " + root.borderGrabArea)
    }
    var sections = []
    if (decoration.length > 0) sections.push("decoration = { " + decoration.join(", ") + " }")
    if (general.length > 0) sections.push("general = { " + general.join(", ") + " }")

    var statements = []
    if (sections.length > 0) statements.push("hl.config({ " + sections.join(", ") + " })")
    // Animations are their own call in the Lua config, not a config key.
    if (root.workspaceAnimation) {
      statements.push("hl.animation({ leaf = \"workspaces\", enabled = true"
        + ", speed = " + root.workspaceAnimationSpeed
        + ", bezier = \"" + root.workspaceAnimationCurve + "\""
        + ", style = \"" + root.workspaceAnimationStyle + "\" })")
    }
    return statements.join(" ")
  }

  // The legacy-parser equivalent, for a hyprland.conf setup where `eval` is
  // the call that gets refused instead of `keyword`.
  function hyprlandKeywords() {
    var commands = []
    if (root.roundWindows) commands.push("keyword decoration:rounding " + root.windowRadius)
    if (root.shadow) {
      commands.push("keyword decoration:shadow:enabled true")
      commands.push("keyword decoration:shadow:range " + root.shadowRange)
      commands.push("keyword decoration:shadow:render_power 3")
      commands.push("keyword decoration:shadow:color " + shadowColor())
    }
    if (root.windowBorder) {
      commands.push("keyword general:border_size " + root.borderWidth)
      commands.push("keyword general:col.active_border " + rgbaToken(Color.foreground, root.activeBorderAlpha))
      commands.push("keyword general:col.inactive_border " + rgbaToken(Color.foreground, root.inactiveBorderAlpha))
    }
    if (root.resizeOnBorder) {
      commands.push("keyword general:resize_on_border true")
      commands.push("keyword general:extend_border_grab_area " + root.borderGrabArea)
    }
    if (root.workspaceAnimation) {
      commands.push("keyword animation workspaces,1," + root.workspaceAnimationSpeed
        + "," + root.workspaceAnimationCurve + "," + root.workspaceAnimationStyle)
    }
    return commands.join(" ; ")
  }

  function handleWindowState(raw) {
    var force = root.pendingForce
    root.pendingForce = false
    if (!force && !needsPush(raw)) return
    var lua = hyprlandLua()
    if (lua.length === 0) return
    luaProc.command = ["hyprctl", "eval", lua]
    luaProc.running = true
  }

  Process {
    id: queryProc
    command: ["hyprctl", "-j", "--batch",
      "getoption decoration:rounding"
      + " ; getoption general:border_size"
      + " ; getoption decoration:shadow:enabled"
      + " ; getoption general:col.active_border"
      + " ; getoption general:col.inactive_border"
      + " ; getoption general:resize_on_border"
      + " ; getoption general:extend_border_grab_area"
      + " ; animations"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.handleWindowState(text)
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
        var keywords = root.hyprlandKeywords()
        if (keywords.length === 0) return
        keywordProc.command = ["hyprctl", "--batch", keywords]
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
      preset[root.cardSections[i] + ".border"] = hairline
      preset[root.cardSections[i] + ".border-width"] = String(root.borderWidth)
    }
    for (var j = 0; j < root.authSections.length; j++) {
      preset[root.authSections[j] + ".border"] = hairline
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
    onTriggered: root.apply(false)
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

  Component.onCompleted: apply(false)
}
