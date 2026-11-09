import QtQuick
import Quickshell
import qs.Ui
import qs.Commons
import "FocusData.js" as FocusData

// Bar face of the focus timer: a countdown while a session runs, and a popup
// to name, tune, start and steer sessions. All state lives in Service.qml.
BarWidget {
  id: root
  moduleName: "aaditya.focus"

  readonly property string iconTimer: String.fromCodePoint(0xF051B)
  readonly property string iconBreak: String.fromCodePoint(0xF0176)
  readonly property string iconPause: String.fromCodePoint(0xF03E4)

  property var session: null
  readonly property bool active: session !== null && session.active
  readonly property string icon: !active ? iconTimer : (session.paused ? iconPause : (session.phase === "break" ? iconBreak : iconTimer))

  property bool popupOpen: false
  property string draftName: ""

  function close() { popupOpen = false }

  function startSession() {
    if (session) session.start(draftName)
  }

  function tooltip() {
    if (!active) return "Start a focus session"
    var label = session.phaseLabel + " " + session.round + "/" + session.rounds + (session.paused ? " (paused)" : "")
    return session.name ? session.name + "  ·  " + label : label
  }

  implicitWidth: row.implicitWidth + Style.space(14)
  implicitHeight: barSize

  // The service can come up after the bar, so keep asking until it is there.
  Timer {
    interval: 500
    repeat: true
    triggeredOnStart: true
    running: !root.session
    onTriggered: if (root.bar && root.bar.shell) root.session = root.bar.shell.serviceFor("aaditya.focus")
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton) root.popupOpen = !root.popupOpen
      else if (!root.session) return
      else if (mouse.button === Qt.MiddleButton) root.session.skipBreak()
      else if (root.active) root.session.toggle()
      else root.startSession()
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltip())
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(5)

    Text {
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      text: root.icon
      color: root.active && root.session.phase === "focus" && !root.session.paused ? Color.accent : root.bar.barForeground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
    }

    Text {
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      visible: root.active && !root.vertical
      text: root.active ? root.session.clockText : ""
      color: root.bar.barForeground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  // KeyboardPanel rather than PopupCard: an xdg-popup never gets the
  // keyboard, so the session name could not be typed into one.
  KeyboardPanel {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    focusTarget: root.active ? column : nameField
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
          text: "Focus"
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
          text: root.session ? FocusData.duration(root.session.todaySeconds) + " today  ·  " + root.session.streak + " day streak" : ""
          color: Qt.darker(root.bar.foreground, 1.3)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }

      PanelSeparator {
        foreground: root.bar.foreground
      }

      // Session in progress.
      Column {
        width: parent.width
        visible: root.active
        spacing: Style.space(8)

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          text: root.active ? root.session.clockText : ""
          color: root.active && root.session.phase === "focus" ? Color.accent : root.bar.foreground
          opacity: root.active && root.session.paused ? 0.55 : 1.0
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.displayLarge
          font.bold: true
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          elide: Text.ElideRight
          text: root.tooltip()
          color: Qt.darker(root.bar.foreground, 1.3)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(8)

          Button {
            text: root.active && root.session.paused ? "Resume" : "Pause"
            bordered: true
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onClicked: root.session.toggle()
          }

          Button {
            visible: root.active && root.session.phase === "break"
            text: "Skip break"
            bordered: true
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onClicked: root.session.skipBreak()
          }

          Button {
            text: "Stop"
            bordered: true
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onClicked: root.session.stop()
          }
        }
      }

      // New session.
      Row {
        width: parent.width
        visible: !root.active
        spacing: Style.space(8)

        TextField {
          id: nameField
          width: parent.width - startButton.width - parent.spacing
          anchors.verticalCenter: parent.verticalCenter
          placeholderText: "What are you focusing on?"
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          foreground: root.bar.foreground
          text: root.draftName
          onTextEdited: root.draftName = text
          onAccepted: root.startSession()
          Keys.onEscapePressed: root.close()
          onVisibleChanged: if (visible && root.popupOpen) Qt.callLater(forceActiveFocus)
        }

        Button {
          id: startButton
          anchors.verticalCenter: parent.verticalCenter
          text: "Start"
          bordered: true
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          onClicked: root.startSession()
        }
      }

      // Timer settings. Changes apply from the next block onwards.
      Grid {
        width: parent.width
        visible: root.session !== null
        columns: 3
        columnSpacing: Style.space(8)
        rowSpacing: Style.space(10)

        readonly property real fieldWidth: (width - columnSpacing * 2) / 3

        Repeater {
          model: [
            { key: "focusMinutes", label: "Focus (min)", from: 1, to: 600 },
            { key: "shortBreakMinutes", label: "Break (min)", from: 1, to: 120 },
            { key: "longBreakMinutes", label: "Long break", from: 1, to: 240 },
            { key: "rounds", label: "Rounds", from: 1, to: 24 },
            { key: "longBreakEvery", label: "Long every", from: 1, to: 24 }
          ]

          NumberField {
            required property var modelData

            label: modelData.label
            from: modelData.from
            to: modelData.to
            value: root.session ? Math.round(root.session[modelData.key]) : modelData.from
            fieldWidth: parent.fieldWidth
            // The two long-break fields do nothing while long breaks are off.
            opacity: modelData.key.indexOf("longBreak") === 0 && root.session && !root.session.longBreaksEnabled ? 0.4 : 1.0
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onModified: function(value) { root.session.setSetting(modelData.key, value) }
          }
        }
      }

      Repeater {
        model: [
          { key: "breaksEnabled", label: "Breaks between focus blocks" },
          { key: "longBreaksEnabled", label: "Long breaks" },
          { key: "autoStart", label: "Start the next block automatically" },
          { key: "soundEnabled", label: "Play a sound when focus ends" },
          { key: "panelVisible", label: "Show graph on the desktop" }
        ]

        Item {
          id: option
          required property var modelData

          width: column.width
          height: Math.max(optionLabel.implicitHeight, optionSwitch.implicitHeight)
          visible: root.session !== null

          Text {
            id: optionLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: option.modelData.label
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
          }

          ToggleSwitch {
            id: optionSwitch
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.session !== null && root.session[option.modelData.key]
            foreground: root.bar.foreground
            onToggled: root.session.setSetting(option.modelData.key, !root.session[option.modelData.key])
          }
        }
      }

      PanelSeparator {
        foreground: root.bar.foreground
      }

      Graph {
        id: graph
        anchors.horizontalCenter: parent.horizontalCenter
        days: root.session ? root.session.days : ({})
        weeks: 20
        today: root.session ? root.session.minuteNow : Date.now()
        foreground: root.bar.foreground
      }

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        elide: Text.ElideRight
        text: graph.hoveredText || "Hover a day for details"
        color: Qt.darker(root.bar.foreground, 1.5)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }
}
