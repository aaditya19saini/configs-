import QtQuick
import qs.Commons

// An analog face drawn from plain rectangles so it takes the theme's colors
// and stays sharp at any size. The owner feeds it `date`.
Item {
  id: root

  property date date: new Date()
  property real size: Style.space(200)
  property color foreground: Color.foreground
  property color accent: Color.accent

  readonly property real seconds: date.getSeconds()
  readonly property real minutes: date.getMinutes() + seconds / 60
  readonly property real hours: (date.getHours() % 12) + minutes / 60
  readonly property real center: size / 2

  implicitWidth: size
  implicitHeight: size

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
    border.width: Math.max(1, Math.round(root.size / 100))
    border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.25)
  }

  // Sixty ticks; every fifth is an hour mark.
  Repeater {
    model: 60

    Item {
      id: tick
      required property int index
      readonly property bool hour: index % 5 === 0

      x: root.center
      y: root.center
      rotation: index * 6

      Rectangle {
        width: tick.hour ? Math.max(2, root.size / 80) : 1
        height: tick.hour ? root.size * 0.06 : root.size * 0.025
        x: -width / 2
        y: -root.center + root.size * 0.045
        radius: width / 2
        antialiasing: true
        color: root.foreground
        opacity: tick.hour ? 0.75 : 0.3
      }
    }
  }

  component Hand: Item {
    id: hand
    property real angle: 0
    property real length: 0
    property real tail: 0
    property real thickness: 2
    property color tint: root.foreground

    x: root.center
    y: root.center
    rotation: angle

    Rectangle {
      width: hand.thickness
      height: hand.length + hand.tail
      x: -width / 2
      y: -hand.length
      radius: width / 2
      antialiasing: true
      color: hand.tint
    }
  }

  Hand {
    angle: root.hours * 30
    length: root.size * 0.25
    tail: root.size * 0.04
    thickness: Math.max(4, root.size / 34)
  }

  Hand {
    angle: root.minutes * 6
    length: root.size * 0.37
    tail: root.size * 0.04
    thickness: Math.max(3, root.size / 50)
  }

  Hand {
    angle: root.seconds * 6
    length: root.size * 0.4
    tail: root.size * 0.08
    thickness: Math.max(1.5, root.size / 130)
    tint: root.accent
  }

  Rectangle {
    width: Math.max(8, root.size / 20)
    height: width
    radius: width / 2
    anchors.centerIn: parent
    antialiasing: true
    color: root.accent
  }
}
