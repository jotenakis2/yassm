pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "lib" as Yassm

// One threshold family: a small title and three number fields (green, orange,
// red). The host widget exposes <prefix>Green/<prefix>Orange/<prefix>Red as
// normalised, ordered properties; edits are clamped here so the order can
// never be broken from the UI.
ColumnLayout {
    id: root

    property var hostWidget: null
    property string title: ""
    property string tooltip: ""
    property string prefix: ""
    property int defaultGreen: 10
    property int defaultOrange: 33
    property int defaultRed: 66
    property int fromGreen: 0
    property int toGreen: 100
    property int fromOrange: 0
    property int toOrange: 100
    property int fromRed: 0
    property int toRed: 100
    property int stepSize: 1
    property bool inverted: false

    readonly property int greenValue: root.hostWidget ? root.hostWidget[root.prefix + "Green"] : root.defaultGreen
    readonly property int orangeValue: root.hostWidget ? root.hostWidget[root.prefix + "Orange"] : root.defaultOrange
    readonly property int redValue: root.hostWidget ? root.hostWidget[root.prefix + "Red"] : root.defaultRed

    Layout.fillWidth: true
    spacing: Style.space(2)

    Label {
        Layout.fillWidth: true
        text: root.title
        palette.windowText: Qt.darker(ShellColor.popups.text, 1.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true

        HoverHandler {
            id: titleHover
        }

        PanelToolTip {
            visible: titleHover.hovered && root.tooltip !== ""
            text: root.tooltip
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(50)
        spacing: Style.space(8)

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            NumberField {
                anchors.centerIn: parent
                label: Yassm.I18n.t("settings.green")
                from: root.fromGreen
                to: root.toGreen
                stepSize: root.stepSize
                value: root.greenValue
                fieldWidth: Style.space(64)
                foreground: ShellColor.popups.text
                fontFamily: Style.font.family

                onModified: function (value) {
                    if (!root.hostWidget) {
                        return;
                    }

                    const next = root.inverted ? Math.max(root.fromGreen, Math.min(root.toGreen, Math.round(value)), root.orangeValue + 1) : Math.max(root.fromGreen, Math.min(root.toGreen, Math.round(value), root.orangeValue - 1));

                    root.hostWidget.updateSetting(root.prefix + "Green", next);
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            NumberField {
                anchors.centerIn: parent
                label: Yassm.I18n.t("settings.orange")
                from: root.fromOrange
                to: root.toOrange
                stepSize: root.stepSize
                value: root.orangeValue
                fieldWidth: Style.space(64)
                foreground: ShellColor.popups.text
                fontFamily: Style.font.family

                onModified: function (value) {
                    if (!root.hostWidget) {
                        return;
                    }

                    const low = root.inverted ? root.redValue + 1 : root.greenValue + 1;
                    const high = root.inverted ? root.greenValue - 1 : root.redValue - 1;
                    const next = Math.max(root.fromOrange, low, Math.min(root.toOrange, high, Math.round(value)));

                    root.hostWidget.updateSetting(root.prefix + "Orange", next);
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            NumberField {
                anchors.centerIn: parent
                label: Yassm.I18n.t("settings.red")
                from: root.fromRed
                to: root.toRed
                stepSize: root.stepSize
                value: root.redValue
                fieldWidth: Style.space(64)
                foreground: ShellColor.popups.text
                fontFamily: Style.font.family

                onModified: function (value) {
                    if (!root.hostWidget) {
                        return;
                    }

                    const next = root.inverted ? Math.max(root.fromRed, Math.min(root.toRed, root.orangeValue - 1, Math.round(value))) : Math.max(root.fromRed, root.orangeValue + 1, Math.min(root.toRed, Math.round(value)));

                    root.hostWidget.updateSetting(root.prefix + "Red", next);
                }
            }
        }
    }
}
