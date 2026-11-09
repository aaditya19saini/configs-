import QtQuick
import qs.Commons
import "FocusData.js" as FocusData

// Contribution graph: one column per week, one square per day, shaded by how
// long was spent in focus that day.
Item {
  id: root

  property var days: ({})
  property int weeks: 26
  property real today: Date.now()
  property int cell: Style.space(11)
  property int gap: Style.space(3)
  property bool showLabels: true
  property color foreground: Color.foreground
  property color accent: Color.accent
  property string fontFamily: Style.font.family

  readonly property int pitch: cell + gap
  readonly property var columns: FocusData.grid(Math.max(1, weeks), today)
  readonly property int labelWidth: showLabels ? dayLabels.implicitWidth + Style.space(6) : 0
  readonly property int headerHeight: showLabels ? Style.font.caption + Style.space(5) : 0
  // The day under the pointer, or null.
  property var hoveredCell: null
  readonly property string hoveredText: hoveredCell ? FocusData.describeDay(days, hoveredCell) : ""

  function levelColor(level) {
    if (level === 0) return Util.alpha(root.foreground, 0.09)
    return Util.alpha(root.accent, [0.3, 0.5, 0.75, 1.0][level - 1])
  }

  implicitWidth: labelWidth + columns.length * pitch - gap
  implicitHeight: headerHeight + 7 * pitch - gap

  Repeater {
    model: root.showLabels ? root.columns : []

    Text {
      required property var modelData
      required property int index

      x: root.labelWidth + index * root.pitch
      visible: modelData.label !== ""
      textFormat: Text.PlainText
      text: modelData.label
      color: Qt.darker(root.foreground, 1.5)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Column {
    id: dayLabels
    y: root.headerHeight
    visible: root.showLabels

    Repeater {
      model: ["", "Mon", "", "Wed", "", "Fri", ""]

      Text {
        required property string modelData

        // Positioners drop zero-width items, which would close up the blank rows.
        width: Math.max(1, implicitWidth)
        height: root.pitch
        verticalAlignment: Text.AlignTop
        textFormat: Text.PlainText
        text: modelData
        color: Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Math.min(Style.font.caption, root.cell)
      }
    }
  }

  Row {
    id: cells
    x: root.labelWidth
    y: root.headerHeight
    spacing: root.gap

    Repeater {
      model: root.columns

      Column {
        id: week
        required property var modelData

        spacing: root.gap

        Repeater {
          model: week.modelData.cells

          Rectangle {
            required property var modelData

            width: root.cell
            height: root.cell
            radius: Math.min(Style.cornerRadius, Style.space(2))
            visible: !modelData.future
            color: root.levelColor(FocusData.level(FocusData.secondsOn(root.days, modelData.key)))
            border.width: root.hoveredCell && root.hoveredCell.key === modelData.key ? 1 : 0
            border.color: root.foreground
          }
        }
      }
    }
  }

  MouseArea {
    x: cells.x
    y: cells.y
    width: root.columns.length * root.pitch
    height: 7 * root.pitch
    hoverEnabled: true
    acceptedButtons: Qt.NoButton

    function pick(mouseX, mouseY) {
      var column = root.columns[Math.floor(mouseX / root.pitch)]
      var found = column ? column.cells[Math.floor(mouseY / root.pitch)] : null
      root.hoveredCell = found && !found.future ? found : null
    }

    onPositionChanged: function(mouse) { pick(mouse.x, mouse.y) }
    onExited: root.hoveredCell = null
  }
}
