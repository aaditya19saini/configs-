import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "Model.js" as Model

// A weather card on the desktop: sits on the layer just above the
// wallpaper, so windows cover it and it only shows on an empty workspace.
// Clicks pass straight through to the desktop.
//
// Data comes from wttr.in, using the same location the bar's weather widget
// uses (~/.local/state/omarchy/settings/weather.json, else IP auto-detect).
Item {
  id: root

  property var shell: null

  // ---- Placement. Corner: "top-left", "top-right", "bottom-left", "bottom-right".
  readonly property string corner: "bottom-right"
  readonly property int refreshMinutes: 15

  property var report: null
  property var location: ({ name: "", latitude: null, longitude: null })
  readonly property string query: Model.wttrLocationQuery(location.name, location.latitude, location.longitude)

  readonly property var current: report && report.current_condition ? report.current_condition[0] : null
  readonly property var area: report && report.nearest_area ? report.nearest_area[0] : null
  readonly property string place: location.name || (area && area.areaName ? area.areaName[0].value : "")
  readonly property bool night: {
    var h = new Date().getHours()
    return h < 6 || h >= 19
  }
  readonly property var days: report && report.weather ? report.weather : []

  function refresh() {
    if (!fetch.running) fetch.running = true
  }

  function dayLabel(dateString, index) {
    if (index === 0) return "Today"
    var parts = String(dateString).split("-")
    var d = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
    return Qt.formatDate(d, "ddd")
  }

  onQueryChanged: Qt.callLater(refresh)

  FileView {
    id: locationFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.location = Model.parseLocationFile(text())
    onLoadFailed: root.location = Model.parseLocationFile("")
  }

  Process {
    id: fetch
    command: ["curl", "-fsS", "--max-time", "10", "https://wttr.in/" + root.query + "?format=j1"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.report = JSON.parse(String(text || ""))
        } catch (e) {
          retry.restart()
        }
      }
    }
  }

  Timer { id: retry; interval: 30000; onTriggered: root.refresh() }

  Timer {
    interval: root.refreshMinutes * 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  IpcHandler {
    target: "aaditya.desktop-weather"
    function refresh(): void { root.refresh() }
  }

  PanelWindow {
    id: win
    visible: root.current !== null
    screen: Quickshell.screens[0]
    color: "transparent"

    WlrLayershell.namespace: "aaditya-desktop-weather"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal

    anchors {
      top: root.corner.indexOf("top") === 0
      bottom: root.corner.indexOf("bottom") === 0
      left: root.corner.indexOf("left") !== -1
      right: root.corner.indexOf("right") !== -1
    }
    // Same gap from the screen edge as the To-do and Focus cards.
    margins {
      top: Style.gapsOut * 2
      bottom: Style.gapsOut * 2
      left: Style.gapsOut * 2
      right: Style.gapsOut * 2
    }

    implicitWidth: card.width
    implicitHeight: card.height

    // Empty input region: the card never takes clicks from the desktop.
    mask: Region {}

    // Styled like the To-do and Focus desktop cards.
    Rectangle {
      id: card
      width: column.implicitWidth + Style.space(16) * 2
      height: column.implicitHeight + Style.space(14) * 2
      radius: Style.cornerRadius
      color: Util.alpha(Color.popups.background, 0.88)
      border.width: 1
      border.color: Util.alpha(Color.popups.border, 0.5)

      Column {
        id: column
        x: Style.space(16)
        y: Style.space(14)
        spacing: Style.space(10)

        // Header: title left, place right.
        Item {
          width: Math.max(forecast.implicitWidth, hero.implicitWidth, Style.space(300))
          height: Math.max(title.implicitHeight, placeLabel.implicitHeight)

          Text {
            id: title
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Weather"
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Text {
            id: placeLabel
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.place
            color: Qt.darker(Color.popups.text, 1.3)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
        }

        Row {
          id: hero
          spacing: Style.space(16)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.current ? Model.iconForCode(root.current.weatherCode, root.night) : ""
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: 44
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: root.current ? root.current.temp_C + "°C  " + root.current.weatherDesc[0].value.trim() : ""
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.displayLarge
              font.bold: true
            }

            Text {
              text: root.current
                ? "Feels " + root.current.FeelsLikeC + "°  ·  " + root.current.humidity + "% humidity  ·  " + root.current.windspeedKmph + " km/h"
                : ""
              color: Qt.darker(Color.popups.text, 1.3)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Color.popups.text
          opacity: 0.12
        }

        Row {
          id: forecast
          spacing: Style.space(28)

          Repeater {
            model: root.days

            Row {
              required property var modelData
              required property int index
              spacing: Style.space(8)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Model.dayIcon(modelData)
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.title
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.dayLabel(modelData.date, index) + "  " + modelData.maxtempC + "° / " + modelData.mintempC + "°"
                color: Qt.darker(Color.popups.text, 1.15)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
            }
          }
        }
      }
    }
  }
}
