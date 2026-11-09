import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// CPU and GPU temperatures, read straight from sysfs. The NVIDIA card has no
// hwmon node, so it goes through nvidia-smi, and only while the card is
// already awake: asking a suspended card for its temperature would power it up.
BarWidget {
  id: root
  moduleName: "aaditya.temps"

  readonly property string iconTemp: String.fromCodePoint(0xF050F)
  readonly property string iconCpu: String.fromCodePoint(0xF061A)
  readonly property string iconGpu: String.fromCodePoint(0xF08AE)

  readonly property int interval: Math.max(1, Number(setting("interval", 3)) || 3)
  readonly property int warnAt: Number(setting("warnAt", 85)) || 85

  // Degrees Celsius, or -1 when the sensor is missing or asleep.
  property int cpu: -1
  property int igpu: -1
  property int dgpu: -1
  property bool dgpuAsleep: false

  readonly property int hottest: Math.max(cpu, igpu, dgpu)

  function degrees(value) {
    return value >= 0 ? value + "°" : "–"
  }

  property bool popupOpen: false

  function close() { popupOpen = false }

  function load(text) {
    var values = ({})
    var parts = String(text || "").trim().split(/\s+/)
    for (var i = 0; i < parts.length; i++) {
      var pair = parts[i].split("=")
      if (pair.length === 2) values[pair[0]] = pair[1]
    }
    cpu = values.cpu ? Math.round(Number(values.cpu) / 1000) : -1
    igpu = values.igpu ? Math.round(Number(values.igpu) / 1000) : -1
    dgpuAsleep = values.nvidia === "asleep"
    dgpu = values.nvidia && !dgpuAsleep && !isNaN(Number(values.nvidia)) ? Math.round(Number(values.nvidia)) : -1
  }

  implicitWidth: glyph.implicitWidth + Style.space(14)
  implicitHeight: barSize

  Process {
    id: readProc
    command: ["bash", "-c",
      "for h in /sys/class/hwmon/hwmon*; do\n" +
      "  case \"$(<\"$h/name\")\" in\n" +
      "    k10temp|zenpower|coretemp) printf 'cpu=%s ' \"$(<\"$h/temp1_input\")\" ;;\n" +
      "    amdgpu|i915|xe) [[ -r $h/temp1_input ]] && printf 'igpu=%s ' \"$(<\"$h/temp1_input\")\" ;;\n" +
      "  esac\n" +
      "done 2>/dev/null\n" +
      "for d in /sys/bus/pci/devices/*; do\n" +
      "  [[ $(<\"$d/vendor\") == 0x10de && $(<\"$d/class\") == 0x03* ]] || continue\n" +
      "  if [[ $(<\"$d/power/runtime_status\") == suspended ]]; then printf 'nvidia=asleep'\n" +
      "  else printf 'nvidia=%s' \"$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1)\"\n" +
      "  fi\n" +
      "  break\n" +
      "done\n" +
      "true"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.load(text)
    }
  }

  Timer {
    interval: root.interval * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: if (!readProc.running) readProc.running = true
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) root.bar.run("omarchy-launch-or-focus-tui btop")
      else root.popupOpen = !root.popupOpen
    }
    onEntered: if (root.bar && !root.popupOpen) root.bar.showTooltip(root, "Temperatures")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  Text {
    id: glyph
    textFormat: Text.PlainText
    anchors.centerIn: parent
    text: root.iconTemp
    color: root.hottest >= root.warnAt ? root.bar.urgent : root.bar.barForeground
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.body
  }

  component Reading: Item {
    id: reading

    property string icon: ""
    property string label: ""
    property int value: -1
    property bool asleep: false

    width: parent ? parent.width : 0
    height: Math.max(name.implicitHeight, temp.implicitHeight)

    Text {
      id: name
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: reading.icon + "  " + reading.label
      color: root.bar.foreground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
    }

    Text {
      id: temp
      textFormat: Text.PlainText
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: reading.asleep ? "asleep" : root.degrees(reading.value) + (reading.value >= 0 ? "C" : "")
      color: reading.value >= root.warnAt ? root.bar.urgent : root.bar.foreground
      opacity: reading.asleep ? 0.55 : 1.0
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(200))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(8)

      Reading {
        icon: root.iconCpu
        label: "CPU"
        value: root.cpu
      }

      Reading {
        visible: root.igpu >= 0
        icon: root.iconGpu
        label: "Radeon"
        value: root.igpu
      }

      Reading {
        visible: root.dgpu >= 0 || root.dgpuAsleep
        icon: root.iconGpu
        label: "NVIDIA"
        value: root.dgpu
        asleep: root.dgpuAsleep
      }
    }
  }
}
