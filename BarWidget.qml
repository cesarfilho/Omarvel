import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Keyboard backlight: left click toggles, scroll changes brightness, right
// click cycles a short list of colors. All real work is in kbd.sh.
BarWidget {
  id: root
  moduleName: "io.github.cesarfilho.kbd-backlight"

  property int brightness: 0
  property int maxBrightness: 255
  property int colorIndex: 0

  readonly property string helper: decodeURIComponent(String(Qt.resolvedUrl("kbd.sh")).replace(/^file:\/\//, ""))
  readonly property int stepPercent: Math.max(1, Math.min(50, Number(setting("stepPercent", 10))))
  readonly property int refreshMs: Math.max(1, Number(setting("refreshIntervalSec", 5))) * 1000
  readonly property var palette: ["#ffffff", "#ff3b30", "#ff9500", "#34c759", "#0a84ff", "#bf5af2"]
  readonly property int percent: maxBrightness > 0 ? Math.round(brightness * 100 / maxBrightness) : 0

  function run(args) {
    actionProc.command = ["bash", helper].concat(args)
    actionProc.running = true
  }
  function refresh() { if (!statusProc.running) statusProc.running = true }
  function parse(text) {
    try {
      var s = JSON.parse(String(text).trim())
      brightness = s.brightness
      maxBrightness = s.max
    } catch (e) {}
  }

  function triggerPress(mouseButton) {
    if (mouseButton === Qt.RightButton) {
      colorIndex = (colorIndex + 1) % palette.length
      run(["color", palette[colorIndex]])
    } else {
      run(["toggle"])
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: statusProc
    command: ["bash", root.helper, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parse(text)
    }
  }

  Process {
    id: actionProc
    command: []
    onExited: root.refresh()
  }

  Timer {
    interval: root.refreshMs
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰌌"
    fontSize: root.vertical ? Style.bar.iconFont : Style.font.body
    hasVisualContent: true
    dimmed: root.brightness === 0
    tooltipText: root.brightness === 0 ? "Keyboard backlight off" : "Keyboard backlight " + root.percent + "%"
    onPressed: function(b) { root.triggerPress(b) }
    onWheelMoved: function(delta) { root.run(["step", (delta > 0 ? "+" : "-") + root.stepPercent]) }
  }
}
