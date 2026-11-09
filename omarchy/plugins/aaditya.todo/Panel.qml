import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// The open tasks, pinned to the desktop. It sits on the layer just above the
// wallpaper, so windows cover it and it never takes space or keyboard focus.
// Clicking a task ticks it off.
Item {
  id: root

  property var shell: null
  // Injected by the host when the service is already up; otherwise looked up.
  property var service: null
  property var found: null
  readonly property var todo: service || found

  readonly property string iconOpen: String.fromCodePoint(0xF0131)
  readonly property int maxShown: 10

  readonly property string position: todo ? todo.panelPosition : "top-left"
  readonly property bool atBottom: position.indexOf("bottom") === 0
  readonly property bool atLeft: position.indexOf("left") !== -1

  readonly property var shown: todo ? todo.openTasks.slice(0, maxShown) : []
  readonly property int hiddenCount: todo ? Math.max(0, todo.openCount - maxShown) : 0

  Timer {
    interval: 500
    repeat: true
    triggeredOnStart: true
    running: !root.todo
    onTriggered: if (root.shell) root.found = root.shell.serviceFor("aaditya.todo")
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: window
      required property var modelData

      screen: modelData
      visible: root.todo !== null && root.todo.panelVisible
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

      WlrLayershell.namespace: "omarchy-todo"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Normal
      exclusiveZone: 0

      Rectangle {
        id: card
        width: Style.space(280)
        height: column.implicitHeight + Style.space(14) * 2
        radius: Style.cornerRadius
        color: Util.alpha(Color.popups.background, 0.88)
        border.width: 1
        border.color: Util.alpha(Color.popups.border, 0.5)

        Column {
          id: column
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(16)
          anchors.rightMargin: Style.space(16)
          spacing: Style.space(8)

          Item {
            width: parent.width
            height: Math.max(title.implicitHeight, count.implicitHeight)

            Text {
              id: title
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: "To-do"
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

            Text {
              id: count
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: root.todo && root.todo.openCount > 0 ? root.todo.openCount + " open" : ""
              color: Qt.darker(Color.popups.text, 1.3)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
          }

          Text {
            width: parent.width
            visible: root.shown.length === 0
            textFormat: Text.PlainText
            text: "Nothing to do"
            color: Qt.darker(Color.popups.text, 1.5)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          Repeater {
            model: root.shown

            Item {
              id: taskRow
              required property var modelData

              width: column.width
              height: label.implicitHeight

              Text {
                id: box
                anchors.left: parent.left
                anchors.top: parent.top
                textFormat: Text.PlainText
                text: root.iconOpen
                color: hit.containsMouse ? Color.accent : Qt.darker(Color.popups.text, 1.3)
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }

              Text {
                id: label
                anchors.left: box.right
                anchors.leftMargin: Style.space(8)
                anchors.right: parent.right
                textFormat: Text.PlainText
                text: taskRow.modelData.text
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
              }

              MouseArea {
                id: hit
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.todo.toggle(taskRow.modelData.id)
              }
            }
          }

          Text {
            width: parent.width
            visible: root.hiddenCount > 0
            textFormat: Text.PlainText
            text: "+" + root.hiddenCount + " more"
            color: Qt.darker(Color.popups.text, 1.5)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
