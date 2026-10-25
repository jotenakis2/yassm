pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

PanelWindow {
    id: root

    property var hostWidget: null
    property real panelX: 0
    property real panelY: 0

    readonly property int panelWidth: Style.space(440)
    readonly property int panelPadding: Style.space(16)
    readonly property int barVisibleOffset: {
        const bar = hostWidget ? hostWidget.bar : null;
        const barSize = bar ? Number(bar.barSize) : 0;
        const gap = Number(Style.space(4));

        if (!(barSize > 0)) {
            return 30;
        }

        return Math.round(barSize + (Number.isFinite(gap) ? gap : 4));
    }

    readonly property var moduleSettings: [
        { key: "showCpu", label: "CPU" },
        { key: "showLoad", label: "Load" },
        { key: "showGpu", label: "GPU" },
        { key: "showMemory", label: "Memory" },
        { key: "showSwap", label: "Swap" },
        { key: "showDisk", label: "Disk" },
        { key: "showNet", label: "Network" },
        { key: "showTemp", label: "Temperature" },
        { key: "showBattery", label: "Battery" }
    ]

    visible: false
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MouseArea {
        anchors.fill: parent

        onPressed: {
            if (root.hostWidget) {
                root.hostWidget.close();
            }
        }
    }

    BorderSurface {
        id: settingsPanel

        width: root.panelWidth
        height: settingsColumn.implicitHeight + root.panelPadding * 2
        radius: Style.cornerRadius
        color: ShellColor.popups.background
        borderSpec: Border.surfaceSpec("menu", "border", ShellColor.popups.border, Style.normalBorderWidth)
        palette.windowText: ShellColor.popups.text
        antialiasing: true
        smooth: true

        x: root.panelX
        y: root.panelY

        MouseArea {
            anchors.fill: parent

            onPressed: {
                // Consume clicks inside the panel.
            }
        }

        ColumnLayout {
            id: settingsColumn

            anchors.fill: parent
            anchors.margins: root.panelPadding
            spacing: Style.space(4)

            Label {
                Layout.fillWidth: true
                text: "Settings"
                wrapMode: Text.NoWrap
                palette.windowText: ShellColor.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle

                bottomPadding: Style.space(8)
            }

            PanelSectionHeader {
                Layout.fillWidth: true
                Layout.topMargin: Style.space(2)
                Layout.bottomMargin: Style.space(2)
                text: "MODULES"
                foreground: ShellColor.popups.text
                fontFamily: Style.font.family
            }

            Repeater {
                model: root.moduleSettings

                Toggle {
                    id: control

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(40)
                    label: control.modelData.label
                    fontFamily: Style.font.family
                    titleSize: Style.font.body
                    foreground: ShellColor.popups.text
                    checked: root.hostWidget ? root.hostWidget.setting(control.modelData.key, true) : false

                    onClicked: {
                        if (root.hostWidget) {
                            root.hostWidget.updateSetting(control.modelData.key, !control.checked);
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Style.space(12)
                Layout.preferredHeight: 1
                color: Qt.rgba(
                    ShellColor.popups.text.r,
                    ShellColor.popups.text.g,
                    ShellColor.popups.text.b,
                    0.12
                )
            }

            PanelSectionHeader {
                Layout.fillWidth: true
                Layout.topMargin: Style.space(10)
                Layout.bottomMargin: Style.space(2)
                text: "LAYOUT"
                foreground: ShellColor.popups.text
                fontFamily: Style.font.family
            }

            Toggle {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(40)
                label: "Boxes"
                fontFamily: Style.font.family
                titleSize: Style.font.body
                foreground: ShellColor.popups.text
                checked: root.hostWidget ? root.hostWidget.setting("showBoxes", true) : false

                onClicked: {
                    if (root.hostWidget) {
                        root.hostWidget.updateSetting("showBoxes", !checked);
                    }
                }
            }

            Toggle {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(40)
                label: "Colors"
                fontFamily: Style.font.family
                titleSize: Style.font.body
                foreground: ShellColor.popups.text
                checked: root.hostWidget ? root.hostWidget.setting("showColors", true) : false

                onClicked: {
                    if (root.hostWidget) {
                        root.hostWidget.updateSetting("showColors", !checked);
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(40)
                spacing: Style.space(8)

                Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Between modules"
                    palette.windowText: ShellColor.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                }

                Text {
                    Layout.preferredWidth: Style.space(14)
                    Layout.alignment: Qt.AlignVCenter
                    horizontalAlignment: Text.AlignRight
                    text: root.hostWidget ? String(root.hostWidget.moduleSpacing) : "2"
                    color: ShellColor.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                }

                PanelSlider {
                    Layout.preferredWidth: Style.space(160)
                    Layout.alignment: Qt.AlignVCenter
                    bar: root.hostWidget ? root.hostWidget.bar : null
                    minimum: 0
                    maximum: 5
                    step: 1
                    integer: true
                    value: root.hostWidget ? root.hostWidget.moduleSpacing : 2

                    onReleased: function(value) {
                        if (root.hostWidget) {
                            root.hostWidget.updateSetting("spacing", Math.round(value));
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(40)
                spacing: Style.space(8)

                Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Between icon and value"
                    palette.windowText: ShellColor.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                }

                Text {
                    Layout.preferredWidth: Style.space(14)
                    Layout.alignment: Qt.AlignVCenter
                    horizontalAlignment: Text.AlignRight
                    text: root.hostWidget ? String(root.hostWidget.iconGap) : "1"
                    color: ShellColor.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                }

                PanelSlider {
                    Layout.preferredWidth: Style.space(160)
                    Layout.alignment: Qt.AlignVCenter
                    bar: root.hostWidget ? root.hostWidget.bar : null
                    minimum: 0
                    maximum: 3
                    step: 1
                    integer: true
                    value: root.hostWidget ? root.hostWidget.iconGap : 1

                    onReleased: function(value) {
                        if (root.hostWidget) {
                            root.hostWidget.updateSetting("iconGap", Math.round(value));
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Style.space(12)
                Layout.preferredHeight: 1
                color: Qt.rgba(
                    ShellColor.popups.text.r,
                    ShellColor.popups.text.g,
                    ShellColor.popups.text.b,
                    0.12
                )
            }

            PanelSectionHeader {
                Layout.fillWidth: true
                Layout.topMargin: Style.space(10)
                Layout.bottomMargin: Style.space(2)
                text: "TIMERS"
                foreground: ShellColor.popups.text
                fontFamily: Style.font.family
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(40)
                spacing: Style.space(8)

                HoverHandler {
                    id: refreshHover
                }

                PanelToolTip {
                    visible: refreshHover.hovered
                    text: "Fast sampling: CPU, RAM, swap, load and network.\nDisk, temperature, GPU and zram stay at 10 s."
                }

                Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Refresh"
                    palette.windowText: ShellColor.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                }

                Text {
                    Layout.preferredWidth: Style.space(28)
                    Layout.alignment: Qt.AlignVCenter
                    horizontalAlignment: Text.AlignRight
                    text: (root.hostWidget ? String(root.hostWidget.refreshInterval) : "1") + " s"
                    color: ShellColor.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                }

                PanelSlider {
                    Layout.preferredWidth: Style.space(160)
                    Layout.alignment: Qt.AlignVCenter
                    bar: root.hostWidget ? root.hostWidget.bar : null
                    minimum: 1
                    maximum: 5
                    step: 1
                    integer: true
                    value: root.hostWidget ? root.hostWidget.refreshInterval : 1

                    onReleased: function(value) {
                        if (root.hostWidget) {
                            root.hostWidget.updateSetting("refreshInterval", Math.round(value));
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(40)
                spacing: Style.space(8)

                HoverHandler {
                    id: processesHover
                }

                PanelToolTip {
                    visible: processesHover.hovered
                    text: "Top processes refresh while a CPU/RAM tooltip is open.\nOne ps per tick; 2 s minimum."
                }

                Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Processes"
                    palette.windowText: ShellColor.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                }

                Text {
                    Layout.preferredWidth: Style.space(28)
                    Layout.alignment: Qt.AlignVCenter
                    horizontalAlignment: Text.AlignRight
                    text: (root.hostWidget ? String(root.hostWidget.processInterval) : "5") + " s"
                    color: ShellColor.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                }

                PanelSlider {
                    Layout.preferredWidth: Style.space(160)
                    Layout.alignment: Qt.AlignVCenter
                    bar: root.hostWidget ? root.hostWidget.bar : null
                    minimum: 2
                    maximum: 10
                    step: 1
                    integer: true
                    value: root.hostWidget ? root.hostWidget.processInterval : 5

                    onReleased: function(value) {
                        if (root.hostWidget) {
                            root.hostWidget.updateSetting("processInterval", Math.round(value));
                        }
                    }
                }
            }
        }
    }
}
