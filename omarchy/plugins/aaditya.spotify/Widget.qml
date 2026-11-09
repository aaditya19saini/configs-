import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons

// Spotify-only bar control. Unlike omarchy.media, which follows whichever
// MPRIS player is active, this always targets Spotify, so a browser tab
// playing video never steals the controls.
BarWidget {
  id: root
  moduleName: "aaditya.spotify"

  readonly property string iconSpotify: String.fromCodePoint(0xF1BC)
  readonly property string iconPrevious: String.fromCodePoint(0xF04AE)
  readonly property string iconNext: String.fromCodePoint(0xF04AD)
  readonly property string iconPlay: String.fromCodePoint(0xF040A)
  readonly property string iconPause: String.fromCodePoint(0xF03E4)
  readonly property string iconShuffle: String.fromCodePoint(0xF049D)
  readonly property string iconRepeat: String.fromCodePoint(0xF0456)
  readonly property string iconRepeatOnce: String.fromCodePoint(0xF0458)
  readonly property string iconVolume: String.fromCodePoint(0xF057E)

  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var player: {
    for (var i = 0; i < players.length; i++) {
      if (players[i] && isSpotify(players[i])) return players[i]
    }
    return null
  }

  readonly property bool running: player !== null
  readonly property bool playing: running && player.isPlaying
  readonly property string title: running ? (player.trackTitle || "") : ""
  readonly property string artist: running ? (player.trackArtist || "") : ""
  readonly property string album: running ? (player.trackAlbum || "") : ""
  readonly property string artUrl: running ? (player.trackArtUrl || "") : ""
  readonly property real length: running && player.lengthSupported ? player.length : 0
  readonly property string summary: title + (artist ? "  ·  " + artist : "")

  readonly property bool showControls: setting("showControls", false) === true
  readonly property bool showLabel: setting("showLabel", false) === true
  readonly property real maxLabelWidth: Number(setting("maxLabelWidth", 220)) || 220

  property bool popupOpen: false

  function close() { popupOpen = false }

  function isSpotify(p) {
    var haystack = [p.dbusName, p.desktopEntry, p.identity].join(" ").toLowerCase()
    return haystack.indexOf("spotify") !== -1
  }

  function launch() {
    Quickshell.execDetached(["omarchy", "launch", "spotify"])
  }

  function playPause() {
    if (running && player.canTogglePlaying) player.togglePlaying()
  }

  function next() {
    if (running && player.canGoNext) player.next()
  }

  function previous() {
    if (running && player.canGoPrevious) player.previous()
  }

  function toggleShuffle() {
    if (running && player.shuffleSupported) player.shuffle = !player.shuffle
  }

  function cycleLoop() {
    if (!running || !player.loopSupported) return
    if (player.loopState === MprisLoopState.None) player.loopState = MprisLoopState.Playlist
    else if (player.loopState === MprisLoopState.Playlist) player.loopState = MprisLoopState.Track
    else player.loopState = MprisLoopState.None
  }

  function formatTime(seconds) {
    var total = Math.max(0, Math.floor(Number(seconds) || 0))
    var s = total % 60
    return Math.floor(total / 60) + ":" + (s < 10 ? "0" + s : s)
  }

  implicitWidth: row.implicitWidth + Style.space(14)
  implicitHeight: barSize

  // MPRIS does not push position updates; poke it while the seek bar shows.
  Timer {
    interval: 1000
    repeat: true
    running: root.popupOpen && root.playing
    onTriggered: root.player.positionChanged()
  }

  component BarGlyph: Text {
    id: glyphRoot

    property bool available: true
    signal activated()

    textFormat: Text.PlainText
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    color: glyphArea.containsMouse && available ? Color.accent : root.bar.barForeground
    opacity: available ? 1.0 : 0.4
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.body

    MouseArea {
      id: glyphArea
      anchors.fill: parent
      anchors.margins: -Style.space(3)
      hoverEnabled: true
      cursorShape: glyphRoot.available ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: if (glyphRoot.available) glyphRoot.activated()
    }
  }

  // Sits behind the row: the icon and label open the popup, while the
  // transport glyphs above it take their own clicks.
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: function(mouse) {
      if (!root.running || mouse.button === Qt.RightButton) root.launch()
      else root.popupOpen = !root.popupOpen
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.running ? (root.title ? root.title + (root.artist ? " — " + root.artist : "") : "Spotify") : "Open Spotify")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(8)

    Text {
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      text: root.iconSpotify
      color: root.bar.barForeground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
    }

    BarGlyph {
      visible: root.running && root.showControls && !root.vertical
      text: root.iconPrevious
      available: root.running && root.player.canGoPrevious
      onActivated: root.previous()
    }

    BarGlyph {
      visible: root.running && root.showControls && !root.vertical
      text: root.playing ? root.iconPause : root.iconPlay
      available: root.running && root.player.canTogglePlaying
      onActivated: root.playPause()
    }

    BarGlyph {
      visible: root.running && root.showControls && !root.vertical
      text: root.iconNext
      available: root.running && root.player.canGoNext
      onActivated: root.next()
    }

    Text {
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      visible: root.running && root.showLabel && !root.vertical && root.title !== ""
      width: Math.min(root.maxLabelWidth, implicitWidth)
      text: root.summary
      color: root.bar.barForeground
      elide: Text.ElideRight
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
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Row {
        spacing: Style.space(10)
        width: parent.width

        BorderSurface {
          width: Style.space(64)
          height: Style.space(64)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.bar.foreground, Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)

          Image {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: root.artUrl
            visible: root.artUrl !== ""
          }

          Text {
            anchors.centerIn: parent
            visible: root.artUrl === ""
            text: root.iconSpotify
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          spacing: Style.space(4)
          width: parent.width - Style.space(74)

          Text {
            textFormat: Text.PlainText
            text: root.title || "Nothing playing"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            textFormat: Text.PlainText
            text: root.artist
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }

          Text {
            textFormat: Text.PlainText
            text: root.album
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }
        }
      }

      Column {
        width: parent.width
        spacing: Style.space(2)
        visible: root.length > 0

        PanelSlider {
          id: seek
          width: parent.width
          bar: root.bar
          minimum: 0
          maximum: Math.max(1, root.length)
          value: root.running ? root.player.position : 0
          enabled: root.running && root.player.canSeek
          onReleased: function(value) {
            if (root.running && root.player.canSeek) root.player.position = value
          }
        }

        Item {
          width: parent.width
          height: elapsed.implicitHeight

          Text {
            id: elapsed
            anchors.left: parent.left
            textFormat: Text.PlainText
            text: root.formatTime(seek.liveValue)
            color: Qt.darker(root.bar.foreground, 1.5)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            anchors.right: parent.right
            textFormat: Text.PlainText
            text: root.formatTime(root.length)
            color: Qt.darker(root.bar.foreground, 1.5)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)

        Button {
          iconText: root.iconShuffle
          tooltipText: "Shuffle"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          visible: root.running && root.player.shuffleSupported
          selected: root.running && root.player.shuffle
          onClicked: root.toggleShuffle()
        }

        Button {
          iconText: root.iconPrevious
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.running && root.player.canGoPrevious
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.previous()
        }

        Button {
          iconText: root.playing ? root.iconPause : root.iconPlay
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.panelGap
          verticalPadding: Style.spacing.controlPaddingY
          iconSize: Style.font.iconLarge
          enabled: root.running && root.player.canTogglePlaying
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.playPause()
        }

        Button {
          iconText: root.iconNext
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.running && root.player.canGoNext
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.next()
        }

        Button {
          iconText: root.running && root.player.loopState === MprisLoopState.Track ? root.iconRepeatOnce : root.iconRepeat
          tooltipText: "Repeat"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          visible: root.running && root.player.loopSupported
          selected: root.running && root.player.loopState !== MprisLoopState.None
          onClicked: root.cycleLoop()
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(8)
        visible: root.running && root.player.volumeSupported && root.player.canControl

        Text {
          id: volumeGlyph
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          text: root.iconVolume
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
        }

        PanelSlider {
          width: parent.width - volumeGlyph.width - parent.spacing
          anchors.verticalCenter: parent.verticalCenter
          bar: root.bar
          minimum: 0
          maximum: 1
          value: root.running ? root.player.volume : 0
          onMoved: function(value) {
            if (root.running) root.player.volume = value
          }
        }
      }

      PanelSeparator {
        foreground: root.bar.foreground
      }

      Button {
        width: parent.width
        text: "Open Spotify"
        iconText: root.iconSpotify
        foreground: root.bar.foreground
        onClicked: {
          root.launch()
          root.close()
        }
      }
    }
  }
}
