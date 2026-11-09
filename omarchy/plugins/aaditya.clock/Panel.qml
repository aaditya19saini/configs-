import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// The clock's popup: an analog clock beside the alarms and timers (the
// calendar now lives in its own plugin, aaditya.calendar).
//
// BarWidget.qml owns the bar label and hands this panel the button to
// anchor against, and the service (Service.qml) that holds the alarms.
Panel {
  id: root
  moduleName: "omarchy.clock"
  ipcTarget: "omarchy.clock"
  manageIpc: false

  property var anchorItem: null

  // The bar tracks the widget mounted in its slot — BarWidget.qml — not this
  // nested panel, so that is what it has to be identified by.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property var service: null

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function openClock() {
    if (!root.opened) root.open()
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function refresh() {}

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
    else if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.fittedContentHeight(Style.space(360))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: clockPage.editing
      onActivateRequested: if (root.service && root.service.ringing) root.service.dismiss()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "a" || t === "A") clockPage.focusNewAlarm()
      }

      ClockPage {
        id: clockPage
        anchors.fill: parent
        service: root.service
        active: root.opened
        foreground: root.contentForeground
        fontFamily: root.contentFontFamily
        onFocusReleased: keyCatcher.forceActiveFocus()
      }
    }
  }
}
