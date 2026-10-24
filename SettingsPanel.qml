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

    readonly property int panelWidth: Style.space(300)
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
        { key: "showDisk", label: "Disk (root partition)" }
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
                text: "YASSM"
                palette.windowText: ShellColor.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle

                bottomPadding: Style.space(8)
            }

            Repeater {
                model: root.moduleSettings

                Toggle {
                    id: control

                    required property var modelData

                    Layout.fillWidth: true
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
        }
    }
}
