import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

// Bar face of the to-do list: the open task count, and a popup to add, tick
// off and remove tasks. All state lives in Service.qml.
BarWidget {
  id: root
  moduleName: "aaditya.todo"

  readonly property string iconList: String.fromCodePoint(0xF0135)
  readonly property string iconOpen: String.fromCodePoint(0xF0131)
  readonly property string iconDone: String.fromCodePoint(0xF0132)
  readonly property string iconClose: String.fromCodePoint(0xF0156)

  property var todo: null
  readonly property int openCount: todo ? todo.openCount : 0

  property bool popupOpen: false
  property string draft: ""

  function close() { popupOpen = false }

  function addDraft() {
    if (todo && todo.add(draft)) draft = ""
  }

  implicitWidth: row.implicitWidth + Style.space(14)
  implicitHeight: barSize

  // The service can come up after the bar, so keep asking until it is there.
  Timer {
    interval: 500
    repeat: true
    triggeredOnStart: true
    running: !root.todo
    onTriggered: if (root.bar && root.bar.shell) root.todo = root.bar.shell.serviceFor("aaditya.todo")
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton) root.popupOpen = !root.popupOpen
      else if (root.todo) root.todo.setPanelVisible(!root.todo.panelVisible)
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.openCount > 0 ? root.openCount + " task" + (root.openCount === 1 ? "" : "s") + " to do" : "Nothing to do")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(4)

    Text {
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      text: root.iconList
      color: root.bar.barForeground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
    }

    Text {
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      visible: root.openCount > 0 && !root.vertical
      text: root.openCount
      color: root.bar.barForeground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  // KeyboardPanel rather than PopupCard: an xdg-popup never gets the
  // keyboard, so a task could not be typed into one.
  KeyboardPanel {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    focusTarget: taskField
    contentWidth: popup.fittedContentWidth(Style.space(340))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(12)
      Keys.onEscapePressed: root.close()

      Item {
        width: parent.width
        height: Math.max(heading.implicitHeight, totals.implicitHeight)

        Text {
          id: heading
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: "To-do"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Text {
          id: totals
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: root.todo ? root.todo.openCount + " open  ·  " + root.todo.doneCount + " done" : ""
          color: Qt.darker(root.bar.foreground, 1.3)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(8)

        TextField {
          id: taskField
          width: parent.width - addButton.width - parent.spacing
          anchors.verticalCenter: parent.verticalCenter
          placeholderText: "Add a task"
          maximumLength: 200
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          foreground: root.bar.foreground
          text: root.draft
          onTextEdited: root.draft = text
          onAccepted: root.addDraft()
          Keys.onEscapePressed: root.close()
        }

        Button {
          id: addButton
          anchors.verticalCenter: parent.verticalCenter
          text: "Add"
          bordered: true
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          onClicked: root.addDraft()
        }
      }

      PanelSeparator {
        foreground: root.bar.foreground
      }

      Text {
        width: parent.width
        visible: !root.todo || root.todo.tasks.length === 0
        horizontalAlignment: Text.AlignHCenter
        topPadding: Style.space(12)
        bottomPadding: Style.space(12)
        textFormat: Text.PlainText
        text: "Nothing on the list"
        color: Qt.darker(root.bar.foreground, 1.5)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Flickable {
        id: listFlick
        width: parent.width
        height: Math.min(list.implicitHeight, Style.space(360))
        visible: root.todo !== null && root.todo.tasks.length > 0
        contentWidth: width
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        Column {
          id: list
          width: listFlick.width
          spacing: Style.space(6)

          Repeater {
            model: root.todo ? root.todo.sorted : []

            Item {
              id: taskRow
              required property var modelData

              width: list.width
              height: Math.max(label.implicitHeight, removeButton.height)

              MouseArea {
                anchors.left: parent.left
                anchors.right: removeButton.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                cursorShape: Qt.PointingHandCursor
                onClicked: root.todo.toggle(taskRow.modelData.id)
              }

              Text {
                id: box
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: taskRow.modelData.done ? root.iconDone : root.iconOpen
                color: taskRow.modelData.done ? Color.accent : root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.icon
              }

              Text {
                id: label
                anchors.left: box.right
                anchors.leftMargin: Style.space(8)
                anchors.right: removeButton.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: taskRow.modelData.text
                color: taskRow.modelData.done ? Qt.darker(root.bar.foreground, 1.6) : root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                font.strikeout: taskRow.modelData.done
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
              }

              PanelActionButton {
                id: removeButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconText: root.iconClose
                tooltipText: "Remove"
                foreground: root.bar.foreground
                hoverColor: root.bar.foreground
                onClicked: root.todo.remove(taskRow.modelData.id)
              }
            }
          }
        }
      }

      PanelSeparator {
        foreground: root.bar.foreground
      }

      Item {
        width: parent.width
        height: Math.max(desktopLabel.implicitHeight, desktopSwitch.implicitHeight)
        visible: root.todo !== null

        Text {
          id: desktopLabel
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: "Show on the desktop"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
        }

        ToggleSwitch {
          id: desktopSwitch
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          checked: root.todo !== null && root.todo.panelVisible
          foreground: root.bar.foreground
          onToggled: root.todo.setPanelVisible(!root.todo.panelVisible)
        }
      }

      Button {
        visible: root.todo !== null && root.todo.doneCount > 0
        text: "Clear " + (root.todo ? root.todo.doneCount : 0) + " done"
        bordered: true
        foreground: root.bar.foreground
        fontFamily: root.bar.fontFamily
        onClicked: root.todo.clearDone()
      }
    }
  }
}
