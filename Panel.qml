import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "edofic.charger-monitor"
  ipcTarget: "edofic.charger-monitor"

  property bool pdOnline: false
  property bool acOnline: false
  property string batteryStatus: "Unknown"
  property int batteryCapacity: 0
  property real batteryWatts: 0
  property real pdVoltage: 0
  property real pdCurrent: 0
  property real pdCurrentMax: 0
  property real contractWatts: 0
  property string usbType: "Disconnected"
  property string chargingProfile: "unsupported"
  property string profileError: ""

  readonly property string compactFlow: batteryStatus === "Charging"
    ? "+" + Math.abs(batteryWatts).toFixed(0) + " W"
    : batteryStatus === "Discharging"
      ? "−" + Math.abs(batteryWatts).toFixed(0) + " W"
      : "0 W"
  readonly property string barText: pdOnline
    ? contractWatts.toFixed(0) + " W · " + compactFlow
    : compactFlow
  readonly property string adapterState: !pdOnline ? "On battery"
    : acOnline ? "Accepted AC" : "Limited USB-C PD"
  readonly property string flowText: batteryStatus === "Charging"
    ? "+" + Math.abs(batteryWatts).toFixed(1) + " W into battery"
    : batteryStatus === "Discharging"
      ? "−" + Math.abs(batteryWatts).toFixed(1) + " W from battery"
      : batteryStatus
  readonly property string profileLabel: chargingProfile === "high_capacity" ? "Full capacity"
    : chargingProfile === "balanced" ? "Reduced capacity (~90%)"
    : chargingProfile === "stationary" ? "Stationary use (~80%)"
    : "Unsupported"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function setChargingProfile(profile) {
    if (profileProc.running || chargingProfile === "unsupported") return
    profileError = ""
    profileProc.command = [
      "/usr/bin/pkexec",
      "/usr/local/libexec/omarchy-charger-monitor/charger-profile",
      "set",
      profile
    ]
    profileProc.running = true
  }

  function update(raw) {
    var fields = String(raw || "").trim().split("\t")
    if (fields.length < 11) return
    pdOnline = fields[0] === "1"
    acOnline = fields[1] === "1"
    batteryStatus = fields[2]
    batteryCapacity = Number(fields[3])
    batteryWatts = Number(fields[4])
    pdVoltage = Number(fields[5])
    pdCurrent = Number(fields[6])
    pdCurrentMax = Number(fields[7])
    contractWatts = Number(fields[8])
    usbType = fields[9]
    chargingProfile = fields[10]
  }

  Process {
    id: statusProc
    command: [(Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/edofic.charger-monitor/charger-info"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.update(text) }
  }

  Process {
    id: profileProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim()) root.profileError = String(text).trim()
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && !root.profileError) root.profileError = "Could not change charging profile"
      root.refresh()
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barText
    fontSize: Style.font.caption
    horizontalMargin: 7
    verticalPadding: 7
    tooltipText: "Power & charger"
    onPressed: root.toggle()
  }

  KeyboardPanel {
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: fittedContentWidth(Style.space(390))
    contentHeight: fittedContentHeight(content.implicitHeight)

    Column {
      id: content
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: Style.space(14)

      Text {
        width: parent.width
        text: "POWER & CHARGER"
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }
      InfoPair { label: "Adapter"; value: root.adapterState }
      InfoPair { label: "Battery"; value: root.batteryCapacity + "%" }
      InfoPair { label: "Power flow"; value: root.flowText }

      PanelSeparator { foreground: root.bar.foreground }
      PanelSectionHeader { text: "CHARGE LIMIT"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
      InfoPair { label: "Active profile"; value: root.profileLabel }

      Row {
        width: parent.width
        spacing: Style.space(6)

        Button {
          width: (parent.width - parent.spacing * 2) / 3
          text: "Full"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          bordered: true
          active: root.chargingProfile === "high_capacity"
          enabled: !profileProc.running && root.chargingProfile !== "unsupported"
          onClicked: root.setChargingProfile("high_capacity")
        }
        Button {
          width: (parent.width - parent.spacing * 2) / 3
          text: "Reduced"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          bordered: true
          active: root.chargingProfile === "balanced"
          enabled: !profileProc.running && root.chargingProfile !== "unsupported"
          onClicked: root.setChargingProfile("balanced")
        }
        Button {
          width: (parent.width - parent.spacing * 2) / 3
          text: "Station"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          bordered: true
          active: root.chargingProfile === "stationary"
          enabled: !profileProc.running && root.chargingProfile !== "unsupported"
          onClicked: root.setChargingProfile("stationary")
        }
      }

      Text {
        visible: root.profileError !== ""
        width: parent.width
        text: root.profileError
        wrapMode: Text.WordWrap
        color: Color.urgent
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Text {
        width: parent.width
        text: "TUXEDO firmware rescales the displayed 100% to the selected capacity. Changing profiles requires administrator authorization."
        wrapMode: Text.WordWrap
        color: root.bar.foreground
        opacity: 0.6
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      PanelSeparator { foreground: root.bar.foreground }
      PanelSectionHeader { text: "USB-C POWER DELIVERY"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
      InfoPair { label: "Contract"; value: root.pdOnline ? root.contractWatts.toFixed(0) + " W" : "Disconnected" }
      InfoPair { label: "Voltage"; value: root.pdOnline ? root.pdVoltage.toFixed(1) + " V" : "—" }
      InfoPair { label: "Current"; value: root.pdOnline ? root.pdCurrent.toFixed(2) + " A requested" : "—" }
      InfoPair { label: "Maximum"; value: root.pdOnline ? root.pdCurrentMax.toFixed(2) + " A" : "—" }
      InfoPair { label: "USB type"; value: root.usbType }

      Text {
        width: parent.width
        text: root.pdOnline && !root.acOnline
          ? "The charger negotiated PD, but firmware did not accept it as a full AC source. The battery may supplement it."
          : root.pdOnline
            ? "Firmware accepts this adapter as an AC source. Battery watts are net charge, not wall draw."
            : "Connect a USB-C PD charger to inspect its contract."
        wrapMode: Text.WordWrap
        color: root.bar.foreground
        opacity: 0.6
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""
    width: parent.width
    spacing: Style.space(8)
    Text { text: label; color: root.bar.foreground; opacity: 0.6; font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    Text { text: value; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall }
  }
}
