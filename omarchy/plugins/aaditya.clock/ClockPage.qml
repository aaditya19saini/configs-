import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Alarms.js" as Alarms

// The popup's second slide: an analog clock beside the alarms and timers.
// Everything it lists lives in Service.qml; this is only the view.
Item {
  id: root

  property var service: null
  // True while the slide is the one on screen, so the second hand is not
  // being driven behind a closed popup.
  property bool active: false
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  // Typing in a field; the panel's key catcher has to stand down meanwhile.
  readonly property bool editing: timeField.activeFocus || labelField.activeFocus || minutesField.activeFocus

  // Asks the panel to take the keyboard back.
  signal focusReleased()

  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property string iconClose: String.fromCodePoint(0xF0156)
  readonly property string iconPause: String.fromCodePoint(0xF03E4)
  readonly property string iconPlay: String.fromCodePoint(0xF040A)

  property var draftDays: []
  property bool timeRejected: false

  function toggleDraftDay(day) {
    var next = draftDays.slice()
    var at = next.indexOf(day)
    if (at === -1) next.push(day)
    else next.splice(at, 1)
    draftDays = next
  }

  function addAlarm() {
    if (!service) return
    var parsed = Alarms.parseTime(timeField.text)
    timeRejected = parsed === null
    if (!parsed) return
    service.addAlarm(parsed.hour, parsed.minute, labelField.text, draftDays)
    timeField.text = ""
    labelField.text = ""
    draftDays = []
    focusReleased()
  }

  function startTimer(minutes) {
    if (service) service.addTimer(minutes, "")
  }

  function startCustomTimer() {
    var minutes = Number(minutesField.text)
    if (!service || !(minutes > 0)) return
    service.addTimer(minutes, "")
    minutesField.text = ""
    focusReleased()
  }

  function focusNewAlarm() {
    timeField.forceActiveFocus()
  }

  function handleFieldKey(event) {
    if (event.key === Qt.Key_Escape) {
      root.focusReleased()
      event.accepted = true
    }
  }

  SystemClock {
    id: clock
    enabled: root.active
    precision: SystemClock.Seconds
  }

  component SectionLabel: Text {
    textFormat: Text.PlainText
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.letterSpacing: 1
    font.bold: true
  }

  // ---- Left: the clock itself.
  Column {
    id: faceColumn
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: face.size
    spacing: Style.space(12)

    AnalogClock {
      id: face
      size: Style.space(200)
      date: clock.date
      foreground: root.foreground
    }

    Column {
      width: parent.width
      spacing: Style.space(2)

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        text: Qt.formatTime(clock.date, "HH:mm:ss")
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.displayLarge
        font.bold: true
      }

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        text: Qt.formatDate(clock.date, "dddd, d MMMM").toUpperCase()
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.letterSpacing: 1
      }
    }
  }

  // ---- Right: alarms and timers.
  Flickable {
    id: scroll
    anchors.left: faceColumn.right
    anchors.leftMargin: Style.space(20)
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    contentWidth: width
    contentHeight: list.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    Column {
      id: list
      width: scroll.width
      spacing: Style.space(8)

      // Going off right now.
      Rectangle {
        visible: root.service !== null && root.service.ringing !== null
        width: parent.width
        height: ringColumn.implicitHeight + Style.space(10) * 2
        radius: Style.cornerRadius
        color: Style.selectedFillFor(root.foreground, Color.accent)
        border.width: Style.spacing.hairline
        border.color: Color.accent

        Column {
          id: ringColumn
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)

          Text {
            width: parent.width
            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: root.service && root.service.ringing
              ? root.service.ringing.title + "  ·  " + root.service.ringing.body : ""
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Row {
            spacing: Style.space(8)

            Button {
              text: "Dismiss"
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.service.dismiss()
            }

            Button {
              text: root.service ? "Snooze " + root.service.snoozeMinutes + " min" : "Snooze"
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.service.snooze()
            }
          }
        }
      }

      SectionLabel { text: "ALARMS" }

      Text {
        visible: root.service !== null && root.service.alarms.length === 0
        textFormat: Text.PlainText
        text: "No alarms set"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Repeater {
        model: root.service ? root.service.alarms : []

        Item {
          id: alarmRow
          required property var modelData

          width: list.width
          height: Math.max(alarmTime.implicitHeight, alarmDetail.implicitHeight, alarmSwitch.implicitHeight)
          opacity: modelData.enabled ? 1.0 : 0.55

          Text {
            id: alarmTime
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: Alarms.timeLabel(alarmRow.modelData.hour, alarmRow.modelData.minute)
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
          }

          Column {
            id: alarmDetail
            anchors.left: alarmTime.right
            anchors.leftMargin: Style.space(10)
            anchors.right: alarmSwitch.left
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              width: parent.width
              visible: alarmRow.modelData.label !== ""
              textFormat: Text.PlainText
              elide: Text.ElideRight
              text: alarmRow.modelData.label
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              elide: Text.ElideRight
              text: {
                var alarm = alarmRow.modelData
                var repeat = Alarms.repeatLabel(alarm.days)
                return alarm.enabled && alarm.nextAt > 0
                  ? repeat + "  ·  " + Alarms.untilLabel(alarm.nextAt - root.service.now) : repeat
              }
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          ToggleSwitch {
            id: alarmSwitch
            anchors.right: alarmDelete.left
            anchors.verticalCenter: parent.verticalCenter
            checked: alarmRow.modelData.enabled
            foreground: root.foreground
            onToggled: root.service.setAlarmEnabled(alarmRow.modelData.id, !alarmRow.modelData.enabled)
          }

          PanelActionButton {
            id: alarmDelete
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: root.iconClose
            tooltipText: "Delete alarm"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.service.removeAlarm(alarmRow.modelData.id)
          }
        }
      }

      // New alarm: time, optional label, then the days it repeats on.
      Row {
        width: parent.width
        spacing: Style.space(6)

        TextField {
          id: timeField
          width: Style.space(64)
          anchors.verticalCenter: parent.verticalCenter
          placeholderText: "07:30"
          foreground: root.timeRejected ? Color.urgent : root.foreground
          font.family: root.fontFamily
          onTextEdited: root.timeRejected = false
          onAccepted: root.addAlarm()
          Keys.onPressed: function(event) { root.handleFieldKey(event) }
        }

        TextField {
          id: labelField
          width: parent.width - timeField.width - addButton.width - parent.spacing * 2
          anchors.verticalCenter: parent.verticalCenter
          placeholderText: "Label"
          foreground: root.foreground
          font.family: root.fontFamily
          onAccepted: root.addAlarm()
          Keys.onPressed: function(event) { root.handleFieldKey(event) }
        }

        Button {
          id: addButton
          anchors.verticalCenter: parent.verticalCenter
          text: "Add"
          bordered: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.addAlarm()
        }
      }

      Row {
        spacing: Style.space(4)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          rightPadding: Style.space(4)
          textFormat: Text.PlainText
          text: "Repeat"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Repeater {
          // Monday first.
          model: [1, 2, 3, 4, 5, 6, 0]

          Rectangle {
            id: chip
            required property int modelData
            readonly property bool chosen: root.draftDays.indexOf(modelData) !== -1

            width: Style.space(24)
            height: Style.space(22)
            radius: Style.cornerRadius
            color: chosen
              ? Style.selectedFillFor(root.foreground, Color.accent)
              : (chipMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent")
            border.width: Style.spacing.hairline
            border.color: chosen ? Color.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2)

            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: Alarms.DAY_INITIALS[chip.modelData]
              color: chip.chosen ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: chip.chosen
            }

            MouseArea {
              id: chipMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleDraftDay(chip.modelData)

              PanelToolTip {
                visible: chipMouse.containsMouse
                text: Alarms.DAY_NAMES[chip.modelData]
                fontFamily: root.fontFamily
              }
            }
          }
        }
      }

      Item { width: 1; height: Style.space(4) }

      SectionLabel { text: "TIMERS" }

      Row {
        id: presetRow
        spacing: Style.space(6)

        Repeater {
          model: [5, 10, 15, 30]

          Button {
            required property int modelData
            anchors.verticalCenter: parent.verticalCenter
            text: modelData + "m"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.startTimer(modelData)
          }
        }

        TextField {
          id: minutesField
          width: Style.space(84)
          anchors.verticalCenter: parent.verticalCenter
          placeholderText: "min " + String.fromCodePoint(0x21B5)
          foreground: root.foreground
          font.family: root.fontFamily
          inputMethodHints: Qt.ImhFormattedNumbersOnly
          onAccepted: root.startCustomTimer()
          Keys.onPressed: function(event) { root.handleFieldKey(event) }
        }

      }

      Repeater {
        model: root.service ? root.service.timers : []

        Item {
          id: timerRow
          required property var modelData
          readonly property bool paused: !(modelData.endsAt > 0)

          width: list.width
          height: Math.max(timerTime.implicitHeight, timerCancel.height)

          Text {
            id: timerTime
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: Alarms.countdown(timerRow.paused
              ? timerRow.modelData.pausedRemaining
              : timerRow.modelData.endsAt - root.service.now)
            color: timerRow.paused ? root.foreground : Color.accent
            opacity: timerRow.paused ? 0.55 : 1.0
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
          }

          Text {
            anchors.left: timerTime.right
            anchors.leftMargin: Style.space(10)
            anchors.right: timerToggle.left
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: (timerRow.modelData.label ? timerRow.modelData.label + "  ·  " : "")
              + "of " + Alarms.countdown(timerRow.modelData.total) + (timerRow.paused ? "  ·  paused" : "")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          PanelActionButton {
            id: timerToggle
            anchors.right: timerCancel.left
            anchors.verticalCenter: parent.verticalCenter
            iconText: timerRow.paused ? root.iconPlay : root.iconPause
            tooltipText: timerRow.paused ? "Resume" : "Pause"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.service.toggleTimer(timerRow.modelData.id)
          }

          PanelActionButton {
            id: timerCancel
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: root.iconClose
            tooltipText: "Cancel timer"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.service.removeTimer(timerRow.modelData.id)
          }
        }
      }
    }
  }
}
