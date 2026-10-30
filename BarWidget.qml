import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.cesarfilho.kbd-backlight"

  property int brightness: 0
  property int maxBrightness: 255
  property bool available: false
  property color currentColor: "#ffffff"
  property int activeColorIndex: -1
  property int pendingColorIndex: -1
  property string lastActionError: ""
  property string activeAction: ""
  property var favorites: []
  property bool favoritesReloadPending: false
  property var actionQueue: []

  readonly property string helper: decodeURIComponent(String(Qt.resolvedUrl("kbd.sh")).replace(/^file:\/\//, ""))
  readonly property int stepPercent: Math.max(1, Math.min(50, Number(setting("stepPercent", 10))))
  readonly property int refreshMs: Math.max(1, Number(setting("refreshIntervalSec", 5))) * 1000
  readonly property int percent: maxBrightness > 0 ? Math.round(brightness * 100 / maxBrightness) : 0
  readonly property string activeColorHex: rgbHex(currentColor)
  readonly property var palette: [
    { name: "White", hex: "#ffffff" },
    { name: "Red", hex: "#ff3b30" },
    { name: "Orange", hex: "#ff9500" },
    { name: "Green", hex: "#34c759" },
    { name: "Blue", hex: "#0a84ff" },
    { name: "Purple", hex: "#bf5af2" }
  ]
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  function rgbHex(color) {
    function hexPart(value) {
      var part = Math.max(0, Math.min(255, Math.round(value * 255))).toString(16)
      return part.length === 1 ? "0" + part : part
    }
    return "#" + hexPart(color.r) + hexPart(color.g) + hexPart(color.b)
  }

  function indexForRgb(red, green, blue) {
    for (var i = 0; i < palette.length; i++) {
      var hex = palette[i].hex.slice(1)
      var itemRed = parseInt(hex.slice(0, 2), 16)
      var itemGreen = parseInt(hex.slice(2, 4), 16)
      var itemBlue = parseInt(hex.slice(4, 6), 16)
      if (red === itemRed && green === itemGreen && blue === itemBlue) return i
    }
    return -1
  }

  function run(args) {
    actionQueue = actionQueue.concat([args.slice()])
    startNextAction()
  }

  function startNextAction() {
    if (actionProc.running || actionQueue.length === 0) return
    var next = actionQueue[0]
    actionQueue = actionQueue.slice(1)
    activeAction = next[0] === "favorite" ? "favorite-" + next[1] : next[0]
    lastActionError = ""
    actionProc.command = ["bash", helper].concat(next)
    actionProc.running = true
  }

  function loadFavorites() {
    if (favoritesProc.running) {
      favoritesReloadPending = true
      return
    }
    favoritesReloadPending = false
    favoritesProc.running = true
  }

  function parseFavorites(text) {
    var lines = String(text).split(/\r?\n/)
    var parsed = []
    for (var i = 0; i < lines.length; i++) {
      var hex = lines[i].trim().toLowerCase()
      if (/^#[0-9a-f]{6}$/.test(hex) && parsed.indexOf(hex) < 0) parsed.push(hex)
    }
    favorites = parsed
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function parse(text) {
    try {
      var state = JSON.parse(String(text).trim())
      var rgb = String(state.color).trim().split(/\s+/).map(Number)
      var nextBrightness = Number(state.brightness)
      var nextMaxBrightness = Number(state.max)
      if (rgb.length !== 3 || !isFinite(rgb[0]) || !isFinite(rgb[1]) || !isFinite(rgb[2])
          || !isFinite(nextBrightness) || !isFinite(nextMaxBrightness) || nextMaxBrightness <= 0) {
        throw new Error("Invalid keyboard backlight state")
      }
      available = true
      if (actionProc.running || actionQueue.length > 0) return
      maxBrightness = nextMaxBrightness
      brightness = Math.max(0, Math.min(maxBrightness, nextBrightness))
      currentColor = Qt.rgba(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1)
      activeColorIndex = indexForRgb(rgb[0], rgb[1], rgb[2])
      pendingColorIndex = activeColorIndex
    } catch (error) {
      available = false
    }
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function cycleColor() {
    var baseIndex = pendingColorIndex >= 0 ? pendingColorIndex : activeColorIndex
    var nextIndex = baseIndex < 0 ? 0 : (baseIndex + 1) % palette.length
    pendingColorIndex = nextIndex
    activeColorIndex = nextIndex
    currentColor = palette[nextIndex].hex
    run(["color", palette[nextIndex].hex])
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  Process {
    id: statusProc
    command: ["bash", root.helper, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parse(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.available = false
    }
  }

  Process {
    id: actionProc
    command: []
    onExited: function(exitCode) {
      if (exitCode === 2) root.lastActionError = "Keyboard LED not detected. Check that the driver is loaded."
      else if (exitCode === 3) root.lastActionError = "Color access denied. Check the udev rule and input group."
      else if (exitCode === 4) root.lastActionError = "Theme accent not found in the current Omarchy theme."
      else if (exitCode === 5) root.lastActionError = "You can save up to 8 favorite colors. Remove one to add another."
      else if (root.activeAction.indexOf("favorite-") === 0 && exitCode !== 0) root.lastActionError = "Could not update saved colors."
      else if (exitCode !== 0) root.lastActionError = "Could not update keyboard lighting."
      if (root.actionQueue.length > 0) root.startNextAction()
      else {
        root.refresh()
        root.loadFavorites()
      }
    }
  }

  Timer {
    interval: root.refreshMs
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.refresh()
      root.loadFavorites()
    }
  }

  Process {
    id: favoritesProc
    command: ["bash", root.helper, "favorite", "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseFavorites(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && exitCode !== 2) root.lastActionError = "Could not load saved colors."
      if (root.favoritesReloadPending) root.loadFavorites()
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰌌"
    fontSize: root.vertical ? Style.bar.iconFont : Style.font.body
    hasVisualContent: true
    active: root.available && root.brightness > 0
    activeColor: root.currentColor
    dimmed: !root.available || root.brightness === 0
    tooltipText: !root.available
      ? "Keyboard backlight unavailable"
      : root.brightness === 0
        ? "Keyboard backlight off · click to open controls"
        : "Keyboard backlight " + root.percent + "% · click for controls"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) root.toggle()
      else if (mouseButton === Qt.RightButton && root.available) root.cycleColor()
    }
    onWheelMoved: function(delta) {
      if (root.available) root.run(["step", (delta > 0 ? "+" : "-") + root.stepPercent])
    }
  }

}
