import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "FocusData.js" as FocusData

// The focus graph, pinned to the desktop. It sits on the layer just above the
// wallpaper, so windows cover it and it never takes space or keyboard focus.
Item {
  id: root

  property var shell: null
  // Injected by the host when the service is already up; otherwise looked up.
  property var service: null
  property var found: null
  readonly property var session: service || found

  readonly property string position: session ? session.panelPosition : "top-right"
  readonly property bool atBottom: position.indexOf("bottom") === 0
  readonly property bool atLeft: position.indexOf("left") !== -1

  Timer {
    interval: 500
    repeat: true
    triggeredOnStart: true
    running: !root.session
    onTriggered: if (root.shell) root.found = root.shell.serviceFor("aaditya.focus")
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: window
      required property var modelData

      screen: modelData
      visible: root.session !== null && root.session.panelVisible
      color: "transparent"
      anchors {
        top: !root.atBottom
        bottom: root.atBottom
        left: root.atLeft
        right: !root.atLeft
      }
      margins {
        top: Style.gapsOut * 2
        bottom: Style.gapsOut * 2
        left: Style.gapsOut * 2
        right: Style.gapsOut * 2
      }
      implicitWidth: card.width
      implicitHeight: card.height

      WlrLayershell.namespace: "omarchy-focus"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Normal
      exclusiveZone: 0

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
          anchors.centerIn: parent
          spacing: Style.space(10)

          Item {
            width: graph.implicitWidth
            height: Math.max(title.implicitHeight, totals.implicitHeight)

            Text {
              id: title
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: "Focus"
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

            Text {
              id: totals
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: root.session
                ? FocusData.duration(root.session.todaySeconds) + " today  ·  " + root.session.streak + " day streak"
                : ""
              color: Qt.darker(Color.popups.text, 1.3)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
          }

          Graph {
            id: graph
            days: root.session ? root.session.days : ({})
            weeks: root.session ? root.session.panelWeeks : 26
            today: root.session ? root.session.minuteNow : Date.now()
            foreground: Color.popups.text
          }

          // The hovered day, else the session in progress, else the legend.
          Item {
            width: graph.implicitWidth
            height: Math.max(status.implicitHeight, legend.implicitHeight)

            Text {
              id: status
              anchors.left: parent.left
              anchors.right: legend.left
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              elide: Text.ElideRight
              text: {
                if (graph.hoveredText) return graph.hoveredText
                if (!root.session || !root.session.active) return "No session running"
                var label = root.session.phaseLabel + " " + root.session.round + "/" + root.session.rounds
                  + "  ·  " + root.session.clockText + (root.session.paused ? " paused" : "")
                return root.session.name ? root.session.name + "  ·  " + label : label
              }
              color: !graph.hoveredText && root.session && root.session.phase === "focus" && !root.session.paused
                ? Color.accent : Qt.darker(Color.popups.text, 1.3)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            Row {
              id: legend
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: graph.gap

              Text {
                anchors.verticalCenter: parent.verticalCenter
                rightPadding: Style.space(3)
                textFormat: Text.PlainText
                text: "Less"
                color: Qt.darker(Color.popups.text, 1.5)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }

              Repeater {
                model: 5

                Rectangle {
                  required property int index

                  anchors.verticalCenter: parent.verticalCenter
                  width: graph.cell
                  height: graph.cell
                  radius: Math.min(Style.cornerRadius, Style.space(2))
                  color: graph.levelColor(index)
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: Style.space(3)
                textFormat: Text.PlainText
                text: "More"
                color: Qt.darker(Color.popups.text, 1.5)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }
        }
      }
    }
  }
}
