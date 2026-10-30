import QtQuick
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.cesarfilho.kbd-backlight"
  manageIpc: false

  property Item anchorItem: null
  property var hostWidget: null
  property int cursorIndex: 0
  property string customHex: "#ffffff"
  property string customError: ""

  readonly property int paletteCount: hostWidget ? hostWidget.palette.length : 0
  readonly property int customInputIndex: paletteCount + 2
  readonly property int applyCustomIndex: paletteCount + 3
  readonly property int saveFavoriteIndex: paletteCount + 4
  readonly property int favoriteStartIndex: paletteCount + 5
  readonly property int themeIndex: favoriteStartIndex + (hostWidget ? hostWidget.favorites.length * 2 : 0)
  readonly property int controlCount: themeIndex + 1
  readonly property color foreground: root.barForeground
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  function closeForPopoutSwitch() {
    popoutSwitchClosing = true
    close()
    Qt.callLater(function() { root.popoutSwitchClosing = false })
  }

  onOpenedChanged: {
    if (!opened) return
    if (hostWidget) customHex = hostWidget.activeColorHex
    customError = ""
    if (cursorIndex >= controlCount) cursorIndex = 0
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function moveCursor(dx, dy) {
    if (!hostWidget) return
    if (cursorIndex === 1 && hostWidget.available && dx !== 0) {
      var nextPercent = Math.max(0, Math.min(100, brightnessSlider.liveValue + (dx > 0 ? 1 : -1) * hostWidget.stepPercent))
      brightnessSlider.liveValue = nextPercent
      setBrightness(nextPercent)
      return
    }
    var delta = dx !== 0 ? dx : dy
    cursorIndex = (cursorIndex + delta + controlCount) % controlCount
  }

  function activateCursor() {
    if (!hostWidget || cursorIndex === 1) return
    if (cursorIndex === 0 && hostWidget.available) hostWidget.run(["toggle"])
    else if (cursorIndex < paletteCount + 2 && hostWidget.available) chooseColor(cursorIndex - 2)
    else if (cursorIndex === customInputIndex) colorInput.forceActiveFocus()
    else if (cursorIndex === applyCustomIndex && hostWidget.available) applyCustomColor()
    else if (cursorIndex === saveFavoriteIndex) saveFavorite()
    else if (cursorIndex < themeIndex) {
      var favoriteOffset = cursorIndex - favoriteStartIndex
      var favoriteIndex = Math.floor(favoriteOffset / 2)
      if (favoriteOffset % 2 === 0) {
        if (hostWidget.available) chooseFavorite(favoriteIndex)
      } else removeFavorite(favoriteIndex)
    } else if (cursorIndex === themeIndex && hostWidget.available) applyThemeColor()
  }

  function chooseColor(index) {
    if (!hostWidget || index < 0 || index >= paletteCount) return
    cursorIndex = index + 2
    hostWidget.pendingColorIndex = index
    hostWidget.activeColorIndex = index
    hostWidget.currentColor = hostWidget.palette[index].hex
    hostWidget.run(["color", hostWidget.palette[index].hex])
  }

  function normalizedCustomHex() {
    var value = String(customHex).trim()
    if (/^[0-9a-fA-F]{6}$/.test(value)) value = "#" + value
    if (!/^#[0-9a-fA-F]{6}$/.test(value)) return ""
    return value.toLowerCase()
  }

  function applyHexColor(hex) {
    if (!hostWidget || !hostWidget.available) return
    var value = normalizedCustomHex()
    if (hex !== undefined) value = String(hex).toLowerCase()
    if (!/^#[0-9a-f]{6}$/.test(value)) return
    var red = parseInt(value.slice(1, 3), 16)
    var green = parseInt(value.slice(3, 5), 16)
    var blue = parseInt(value.slice(5, 7), 16)
    customHex = value
    var paletteIndex = hostWidget.indexForRgb(red, green, blue)
    hostWidget.pendingColorIndex = paletteIndex
    hostWidget.activeColorIndex = paletteIndex
    hostWidget.currentColor = value
    customError = ""
    hostWidget.run(["color", value])
  }

  function applyCustomColor() {
    if (!normalizedCustomHex()) {
      customError = "Enter a valid HEX color, for example #0a84ff."
      return
    }
    applyHexColor()
  }

  function saveFavorite() {
    var value = normalizedCustomHex()
    if (!value) {
      customError = "Enter a valid HEX color before saving it."
      return
    }
    customError = ""
    hostWidget.run(["favorite", "add", value])
  }

  function chooseFavorite(index) {
    if (!hostWidget || !hostWidget.available || index < 0 || index >= hostWidget.favorites.length) return
    cursorIndex = favoriteStartIndex + index * 2
    applyHexColor(hostWidget.favorites[index])
  }

  function removeFavorite(index) {
    if (!hostWidget || index < 0 || index >= hostWidget.favorites.length) return
    cursorIndex = favoriteStartIndex + index * 2 + 1
    hostWidget.run(["favorite", "remove", hostWidget.favorites[index]])
  }

  function applyThemeColor() {
    if (!hostWidget || !hostWidget.available) return
    hostWidget.pendingColorIndex = -1
    hostWidget.run(["theme"])
  }

  function setBrightness(value) {
    if (!hostWidget || !hostWidget.available) return
    var percent = Math.max(0, Math.min(100, Math.round(value)))
    hostWidget.brightness = Math.round(hostWidget.maxBrightness * percent / 100)
    hostWidget.run(["brightness", String(percent)])
  }

  function setHovered(index, hovered) {
    if (hovered) cursorIndex = index
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      blocked: colorInput.activeFocus

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        Row {
          width: parent.width
          spacing: Style.space(12)

          Text {
            id: keyboardIcon
            text: "󰌌"
            color: root.hostWidget && root.hostWidget.available && root.hostWidget.brightness > 0
              ? root.hostWidget.currentColor
              : Qt.darker(root.foreground, 1.8)
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 180 } }
          }

          Column {
            width: Math.max(0, parent.width - keyboardIcon.implicitWidth - parent.spacing * 2 - powerButton.implicitWidth)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: "Keyboard backlight"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: !root.hostWidget || !root.hostWidget.available
                ? "LED device not detected"
                : (root.hostWidget.brightness === 0 ? "Off" : root.hostWidget.percent + "% brightness")
              color: Qt.darker(root.foreground, 1.5)
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }
          }

          Button {
            id: powerButton
            iconText: root.hostWidget && root.hostWidget.brightness > 0 ? "󰐥" : "󰑙"
            text: root.hostWidget && root.hostWidget.brightness > 0 ? "Turn off" : "Turn on"
            tooltipText: root.hostWidget && root.hostWidget.brightness > 0 ? "Turn keyboard backlight off" : "Turn keyboard backlight on"
            foreground: root.foreground
            fontFamily: root.fontFamily
            active: root.hostWidget && root.hostWidget.brightness > 0
            hasCursor: root.cursorIndex === 0
            enabled: root.hostWidget && root.hostWidget.available
            onClicked: root.hostWidget.run(["toggle"])
            onHovered: function(hovered) { root.setHovered(0, hovered) }
            Accessible.name: "Toggle keyboard backlight"
          }
        }

        PanelSeparator { foreground: root.foreground }

        Column {
          width: parent.width
          spacing: Style.space(5)

          PanelSectionHeader {
            text: "BRIGHTNESS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            PanelSlider {
              id: brightnessSlider
              width: parent.width - percentLabel.implicitWidth - parent.spacing
              bar: root.bar
              minimum: 0
              maximum: 100
              step: root.hostWidget ? root.hostWidget.stepPercent : 10
              integer: true
              value: root.hostWidget ? root.hostWidget.percent : 0
              enabled: root.hostWidget && root.hostWidget.available
              onMoved: function(value) { root.setHovered(1, true) }
              onReleased: function(value) { root.setBrightness(value) }

              HoverHandler { onHoveredChanged: root.setHovered(1, hovered) }
            }

            Text {
              id: percentLabel
              text: Math.round(brightnessSlider.liveValue) + "%"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "COLOR PRESETS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Row {
            id: paletteRow
            spacing: Style.space(10)
            Repeater {
              model: root.hostWidget ? root.hostWidget.palette : []
              Item {
                id: swatch
                required property var modelData
                required property int index
                width: Style.space(30)
                height: Style.space(30)
                Accessible.name: modelData.name + " keyboard backlight color"

                Rectangle {
                  id: swatchFill
                  anchors.centerIn: parent
                  width: Style.space(20)
                  height: width
                  radius: width / 2
                  color: modelData.hex
                  border.width: root.hostWidget && root.hostWidget.activeColorIndex === swatch.index ? Style.space(2) : Style.space(1)
                  border.color: root.hostWidget && root.hostWidget.activeColorIndex === swatch.index
                    ? root.foreground
                    : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)
                  scale: swatchMouse.containsMouse || root.cursorIndex === swatch.index + 2 ? 1.14 : 1
                  Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                Text {
                  anchors.centerIn: parent
                  visible: root.hostWidget && root.hostWidget.activeColorIndex === swatch.index
                  text: "✓"
                  color: ["#ffffff", "#34c759", "#0a84ff", "#bf5af2"].indexOf(swatch.modelData.hex) >= 0 ? "#111111" : "#ffffff"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                MouseArea {
                  id: swatchMouse
                  anchors.fill: parent
                  enabled: root.hostWidget && root.hostWidget.available
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: root.setHovered(swatch.index + 2, true)
                  onClicked: root.chooseColor(swatch.index)
                }

                PanelToolTip {
                  visible: swatchMouse.containsMouse
                  text: swatch.modelData.name
                  fontFamily: root.fontFamily
                }
              }
            }
          }

          Text {
            text: root.hostWidget
              ? ((root.hostWidget.activeColorIndex >= 0
                  ? root.hostWidget.palette[root.hostWidget.activeColorIndex].name
                  : "Custom color") + " · " + root.hostWidget.activeColorHex)
              : "Color unavailable"
            color: Qt.darker(root.foreground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        PanelSeparator { foreground: root.foreground }

        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "CUSTOM COLOR"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            TextField {
              id: colorInput
              width: parent.width - applyButton.implicitWidth - parent.spacing
              text: root.customHex
              placeholderText: "#RRGGBB"
              hasCursor: root.cursorIndex === root.customInputIndex
              foreground: root.foreground
              font.family: root.fontFamily
              onTextEdited: {
                root.customHex = text
                root.customError = ""
              }
              onAccepted: root.applyCustomColor()
              onHoveredChanged: root.setHovered(root.customInputIndex, hovered)
              Keys.onEscapePressed: root.close()
              Keys.onTabPressed: {
                root.cursorIndex = root.applyCustomIndex
                keyCatcher.forceActiveFocus()
              }
            }

            Button {
              id: applyButton
              iconText: "󰄬"
              text: "Apply"
              foreground: root.foreground
              fontFamily: root.fontFamily
              hasCursor: root.cursorIndex === root.applyCustomIndex
              enabled: root.hostWidget && root.hostWidget.available
              onClicked: root.applyCustomColor()
              onHovered: function(hovered) { root.setHovered(root.applyCustomIndex, hovered) }
            }
          }

          Button {
            width: parent.width
            leftAlign: true
            iconText: "󰆴"
            text: "Save as favorite"
            tooltipText: "Save this color for quick access (up to 8)"
            foreground: root.foreground
            fontFamily: root.fontFamily
            bordered: true
            hasCursor: root.cursorIndex === root.saveFavoriteIndex
            enabled: !!root.hostWidget
            onClicked: root.saveFavorite()
            onHovered: function(hovered) { root.setHovered(root.saveFavoriteIndex, hovered) }
          }

          Text {
            width: parent.width
            visible: !!root.customError
            text: root.customError
            color: root.bar ? root.bar.urgent : "#ff5f57"
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }
        }

        PanelSeparator { foreground: root.foreground }

        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "SAVED COLORS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Text {
            width: parent.width
            visible: !root.hostWidget || root.hostWidget.favorites.length === 0
            text: "No saved colors yet. Enter a HEX value and save it above."
            color: Qt.darker(root.foreground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Flow {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.hostWidget ? root.hostWidget.favorites : []

              Item {
                id: favoriteItem
                required property string modelData
                required property int index
                width: (parent.width - parent.spacing) / 2
                height: Style.space(32)

                Button {
                  id: favoriteButton
                  width: parent.width - removeButton.width - Style.space(4)
                  height: parent.height
                  leftAlign: true
                  text: ""
                  Accessible.name: "Apply favorite color " + favoriteItem.modelData
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  hasCursor: root.cursorIndex === root.favoriteStartIndex + favoriteItem.index * 2
                  enabled: root.hostWidget && root.hostWidget.available
                  onClicked: root.chooseFavorite(favoriteItem.index)
                  onHovered: function(hovered) {
                    root.setHovered(root.favoriteStartIndex + favoriteItem.index * 2, hovered)
                  }

                  Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(12)
                    height: width
                    radius: width / 2
                    color: favoriteItem.modelData
                  }

                  Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(26)
                    anchors.verticalCenter: parent.verticalCenter
                    text: favoriteItem.modelData
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                }

                PanelActionButton {
                  id: removeButton
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  size: Style.space(26)
                  iconText: "×"
                  tooltipText: "Remove saved color"
                  foreground: root.foreground
                  hasCursor: root.cursorIndex === root.favoriteStartIndex + favoriteItem.index * 2 + 1
                  onClicked: root.removeFavorite(favoriteItem.index)
                  onHovered: function(hovered) {
                    root.setHovered(root.favoriteStartIndex + favoriteItem.index * 2 + 1, hovered)
                  }
                }
              }
            }
          }
        }

        Button {
          id: themeButton
          width: parent.width
          leftAlign: true
          iconText: "󰏘"
          text: "Apply theme accent color"
          tooltipText: "Set the keyboard to the current Omarchy theme accent"
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          hasCursor: root.cursorIndex === root.themeIndex
          enabled: root.hostWidget && root.hostWidget.available
          onClicked: root.applyThemeColor()
          onHovered: function(hovered) { root.setHovered(root.themeIndex, hovered) }
          Accessible.name: "Apply current theme accent to the keyboard"
        }

        Text {
          width: parent.width
          visible: root.hostWidget && !!root.hostWidget.lastActionError
          text: root.hostWidget ? root.hostWidget.lastActionError : ""
          color: root.bar ? root.bar.urgent : "#ff5f57"
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Text {
          width: parent.width
          visible: !root.hostWidget || !root.hostWidget.available
          text: "Check that the TUXEDO/Clevo driver is loaded. Color control also requires the optional udev rule."
          color: Qt.darker(root.foreground, 1.5)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
