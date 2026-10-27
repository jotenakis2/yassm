pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "lib" as Yassm

PanelWindow {
    id: root

    property var hostWidget: null
    property real panelX: 0

    readonly property var missingDeps: Yassm.SystemMetrics.missingDeps
    readonly property var missingRequired: root.missingDeps.filter(function (dep) {
        return dep.kind === "required";
    })
    readonly property var missingOptional: root.missingDeps.filter(function (dep) {
        return dep.kind === "optional";
    })

    function depsTooltip() {
        const lines = [];

        if (root.missingRequired.length > 0) {
            lines.push("Required: " + root.missingRequired.map(function (dep) {
                return dep.name;
            }).join(", "));
        }

        if (root.missingOptional.length > 0) {
            lines.push("Optional: " + root.missingOptional.map(function (dep) {
                return dep.name;
            }).join(", "));
        }

        lines.push("");

        for (let i = 0; i < root.missingDeps.length; i++) {
            const dep = root.missingDeps[i];
            lines.push(dep.name + " — " + dep.purpose);
        }

        return lines.join("\n");
    }

    readonly property int panelWidth: Math.min(Style.space(440), Math.max(Style.space(280), (root.screen ? root.screen.width : Style.space(440)) - root.panelMargin * 2))
    readonly property int panelPadding: Style.space(16)
    readonly property int toggleRowHeight: Style.space(34)
    readonly property int panelMargin: Style.space(4)
    // Plain properties updated once hostWidget is known: binding the sliders
    // to a not-yet-initialised readonly property logged QML warnings on open.
    property QtObject hostBar: null
    property string barPosition: "top"

    function refreshHostBar() {
        const widget = root.hostWidget;
        const bar = widget && widget.bar ? widget.bar : null;

        root.hostBar = bar;
        root.barPosition = bar && bar.position ? String(bar.position) : "top";
    }

    onHostWidgetChanged: root.refreshHostBar()
    Component.onCompleted: root.refreshHostBar()
    readonly property int maxPanelHeight: Math.max(Style.space(160), root.height - root.panelMargin * 2)
    readonly property int panelHeight: Math.min(settingsColumn.implicitHeight + root.panelPadding * 2, root.maxPanelHeight)

    function scrollPanel(deltaY) {
        const max = Math.max(0, settingsFlick.contentHeight - settingsFlick.height);

        if (max <= 0) {
            return;
        }

        settingsFlick.contentY = Math.max(0, Math.min(max, settingsFlick.contentY - deltaY));
    }

    readonly property var moduleSettings: [
        {
            key: "showUptime",
            label: "Uptime",
            defaultValue: true
        },
        {
            key: "showCpu",
            label: "CPU"
        },
        {
            key: "showLoad",
            label: "Load"
        },
        {
            key: "showGpu",
            label: "GPU"
        },
        {
            key: "showMemory",
            label: "Memory"
        },
        {
            key: "showSwap",
            label: "Swap"
        },
        {
            key: "showDisk",
            label: "Disk"
        },
        {
            key: "showNet",
            label: "Network"
        },
        {
            key: "showTemp",
            label: "Temperature"
        },
        {
            key: "showBattery",
            label: "Battery"
        },
        {
            key: "showAlerts",
            label: "Alerts",
            defaultValue: true,
            tooltip: "Alerts on systemd failed units, zombies older than 60 s, a root disk at 95 % or more and RAM at 95 % or more.\nRed icon: systemd, disk or RAM; orange icon: zombies only. Refreshed every 60 s."
        }
    ]

    property int dragFrom: -1
    property int dragTo: -1

    function orderKey(settingKey) {
        return settingKey.startsWith("show") ? settingKey.charAt(4).toLowerCase() + settingKey.slice(5) : settingKey;
    }

    readonly property var orderedModules: {
        const meta = {};

        for (let i = 0; i < root.moduleSettings.length; i++) {
            const entry = root.moduleSettings[i];
            meta[root.orderKey(entry.key)] = entry;
        }

        const order = root.hostWidget ? root.hostWidget.moduleOrder : [];
        const modules = [];

        for (let i = 0; i < order.length; i++) {
            const entry = meta[order[i]];

            if (entry) {
                modules.push(entry);
            }
        }

        return modules;
    }

    function moveModule(from, to) {
        if (!root.hostWidget || from === to) {
            return;
        }

        const order = root.hostWidget.moduleOrder.slice();

        if (from < 0 || from >= order.length || to < 0 || to >= order.length) {
            return;
        }

        const moved = order.splice(from, 1)[0];
        order.splice(to, 0, moved);
        root.hostWidget.updateSetting("moduleOrder", order);
    }

    visible: false
    color: "transparent"

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

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
        height: root.panelHeight
        radius: Style.cornerRadius
        color: ShellColor.popups.background
        borderSpec: Border.surfaceSpec("menu", "border", ShellColor.popups.border, Style.normalBorderWidth)
        palette.windowText: ShellColor.popups.text
        antialiasing: true
        smooth: true

        x: root.panelX
        y: root.barPosition === "bottom" ? Math.max(root.panelMargin, root.height - root.panelHeight - root.panelMargin) : (root.barPosition === "left" || root.barPosition === "right") ? Math.max(root.panelMargin, Math.round((root.height - root.panelHeight) / 2)) : root.panelMargin

        MouseArea {
            anchors.fill: parent

            onPressed: {
                // Consume clicks inside the panel.
            }
        }

        Text {
            id: gearIcon

            text: String.fromCodePoint(0xF0493)
            color: ShellColor.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            x: settingsPanel.width - width - root.panelPadding
            y: root.panelPadding - Math.round(Style.space(2) / 2)
            z: 2
        }

        Flickable {
            id: settingsFlick

            anchors.fill: parent
            anchors.margins: root.panelPadding
            clip: true
            contentWidth: width
            contentHeight: settingsColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: settingsColumn

                width: settingsFlick.width - Style.space(6)
                spacing: Style.space(4)

                Rectangle {
                    id: depsWarning

                    readonly property bool hasRequired: root.missingRequired.length > 0

                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(34)
                    visible: root.missingDeps.length > 0
                    radius: Style.space(4)
                    color: depsWarning.hasRequired ? Qt.rgba(Yassm.ThemePalette.red.r, Yassm.ThemePalette.red.g, Yassm.ThemePalette.red.b, 0.16) : Qt.rgba(Yassm.ThemePalette.orange.r, Yassm.ThemePalette.orange.g, Yassm.ThemePalette.orange.b, 0.16)
                    border.width: 1
                    border.color: depsWarning.hasRequired ? Qt.rgba(Yassm.ThemePalette.red.r, Yassm.ThemePalette.red.g, Yassm.ThemePalette.red.b, 0.55) : Qt.rgba(Yassm.ThemePalette.orange.r, Yassm.ThemePalette.orange.g, Yassm.ThemePalette.orange.b, 0.55)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(8)
                        anchors.rightMargin: Style.space(8)
                        spacing: Style.space(6)

                        Text {
                            text: "\uF071"
                            color: depsWarning.hasRequired ? Yassm.ThemePalette.red : Yassm.ThemePalette.orange
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                        }

                        Label {
                            Layout.fillWidth: true
                            text: depsWarning.hasRequired ? "Missing required tools: " + root.missingRequired.map(function (dep) {
                                return dep.name;
                            }).join(", ") : "Missing optional tools: " + root.missingOptional.map(function (dep) {
                                return dep.name;
                            }).join(", ")
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            palette.windowText: ShellColor.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                        }
                    }

                    HoverHandler {
                        id: depsHover
                    }

                    PanelToolTip {
                        visible: depsHover.hovered
                        text: root.depsTooltip()
                    }
                }

                PanelSectionHeader {
                    Layout.fillWidth: true
                    Layout.topMargin: Style.space(2)
                    Layout.bottomMargin: Style.space(2)
                    text: "MODULES"
                    foreground: ShellColor.popups.text
                    fontFamily: Style.font.family

                    HoverHandler {
                        id: modulesHeaderHover
                    }

                    PanelToolTip {
                        visible: modulesHeaderHover.hovered
                        text: "Drag the handle to reorder the modules."
                    }
                }

                ColumnLayout {
                    id: moduleList

                    Layout.fillWidth: true
                    spacing: Style.space(2)

                    Repeater {
                        model: root.orderedModules

                        Rectangle {
                            id: moduleRow

                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            Layout.preferredHeight: root.toggleRowHeight
                            radius: Style.space(4)
                            color: root.dragFrom >= 0 && root.dragTo === moduleRow.index ? Qt.rgba(ShellColor.accent.r, ShellColor.accent.g, ShellColor.accent.b, 0.12) : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                spacing: Style.space(6)

                                Rectangle {
                                    id: dragHandle

                                    Layout.preferredWidth: Style.space(18)
                                    Layout.fillHeight: true
                                    radius: Style.space(4)
                                    color: dragArea.containsMouse ? Qt.rgba(ShellColor.popups.text.r, ShellColor.popups.text.g, ShellColor.popups.text.b, 0.08) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "⠿"
                                        color: ShellColor.popups.text
                                        opacity: 0.7
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.body
                                    }

                                    MouseArea {
                                        id: dragArea

                                        anchors.fill: parent
                                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                        preventStealing: true

                                        property real pressY: 0
                                        property bool moved: false

                                        onPressed: function (mouse) {
                                            root.dragFrom = moduleRow.index;
                                            root.dragTo = moduleRow.index;
                                            pressY = mouse.y;
                                            moved = false;
                                        }

                                        onPositionChanged: function (mouse) {
                                            if (!pressed) {
                                                return;
                                            }

                                            if (Math.abs(mouse.y - pressY) > 3) {
                                                moved = true;
                                            }

                                            if (!moved) {
                                                return;
                                            }

                                            const point = mapToItem(moduleList, mouse.x, mouse.y);
                                            const pitch = root.toggleRowHeight + moduleList.spacing;
                                            const target = Math.floor((point.y + moduleList.spacing / 2) / pitch);

                                            root.dragTo = Math.max(0, Math.min(root.orderedModules.length - 1, target));
                                        }

                                        onReleased: {
                                            if (moved && root.dragFrom >= 0 && root.dragTo !== root.dragFrom) {
                                                root.moveModule(root.dragFrom, root.dragTo);
                                            }

                                            root.dragFrom = -1;
                                            root.dragTo = -1;
                                        }

                                        onCanceled: {
                                            root.dragFrom = -1;
                                            root.dragTo = -1;
                                        }
                                    }
                                }

                                Toggle {
                                    id: control

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    label: moduleRow.modelData.label
                                    fontFamily: Style.font.family
                                    titleSize: Style.font.body
                                    foreground: ShellColor.popups.text
                                    checked: root.hostWidget ? root.hostWidget.setting(moduleRow.modelData.key, moduleRow.modelData.defaultValue !== false) : false

                                    onClicked: {
                                        if (root.hostWidget) {
                                            root.hostWidget.updateSetting(moduleRow.modelData.key, !control.checked);
                                        }
                                    }

                                    HoverHandler {
                                        id: moduleHover
                                    }

                                    PanelToolTip {
                                        visible: moduleHover.hovered && moduleRow.modelData.tooltip !== undefined
                                        text: moduleRow.modelData.tooltip || ""
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: Style.space(12)
                    Layout.preferredHeight: 1
                    color: Qt.rgba(ShellColor.popups.text.r, ShellColor.popups.text.g, ShellColor.popups.text.b, 0.12)
                }

                PanelSectionHeader {
                    Layout.fillWidth: true
                    Layout.topMargin: Style.space(10)
                    Layout.bottomMargin: Style.space(2)
                    text: "LAYOUT"
                    foreground: ShellColor.popups.text
                    fontFamily: Style.font.family
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.toggleRowHeight
                    spacing: Style.space(6)

                    // Spacer matching the drag handle of the module rows, so
                    // the Layout boxes line up with the module boxes.
                    Item {
                        Layout.preferredWidth: Style.space(18)
                    }

                    Toggle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.toggleRowHeight
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
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.toggleRowHeight
                    spacing: Style.space(6)

                    // Spacer matching the drag handle of the module rows, so
                    // the Layout boxes line up with the module boxes.
                    Item {
                        Layout.preferredWidth: Style.space(18)
                    }

                    Toggle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.toggleRowHeight
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
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.toggleRowHeight
                    spacing: Style.space(6)

                    // Spacer matching the drag handle of the module rows, so
                    // the Layout boxes line up with the module boxes.
                    Item {
                        Layout.preferredWidth: Style.space(18)
                    }

                    Toggle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.toggleRowHeight
                        label: "Extended data in tooltips"
                        fontFamily: Style.font.family
                        titleSize: Style.font.body
                        foreground: ShellColor.popups.text
                        checked: root.hostWidget ? root.hostWidget.setting("extendedTooltips", true) : true

                        onClicked: {
                            if (root.hostWidget) {
                                root.hostWidget.updateSetting("extendedTooltips", !checked);
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(32)
                    spacing: Style.space(8)

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse

                        onWheel: function (event) {
                            root.scrollPanel(event.angleDelta.y);
                            event.accepted = true;
                        }
                    }

                    HoverHandler {
                        id: modulesGapHover
                    }

                    PanelToolTip {
                        visible: modulesGapHover.hovered
                        text: "Gap between module boxes, in character cells.\n0–5 cells, with a 2 px minimum at 0."
                    }

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
                        bar: root.hostBar
                        minimum: 0
                        maximum: 5
                        step: 1
                        integer: true
                        value: root.hostWidget ? root.hostWidget.moduleSpacing : 2

                        onReleased: function (value) {
                            if (root.hostWidget) {
                                root.hostWidget.updateSetting("spacing", Math.round(value));
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(32)
                    spacing: Style.space(8)

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse

                        onWheel: function (event) {
                            root.scrollPanel(event.angleDelta.y);
                            event.accepted = true;
                        }
                    }

                    HoverHandler {
                        id: iconGapHover
                    }

                    PanelToolTip {
                        visible: iconGapHover.hovered
                        text: "Gap between each icon and its value, in cells.\n0–3 cells, with a 2 px minimum at 0."
                    }

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
                        bar: root.hostBar
                        minimum: 0
                        maximum: 3
                        step: 1
                        integer: true
                        value: root.hostWidget ? root.hostWidget.iconGap : 1

                        onReleased: function (value) {
                            if (root.hostWidget) {
                                root.hostWidget.updateSetting("iconGap", Math.round(value));
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(32)
                    spacing: Style.space(8)

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse

                        onWheel: function (event) {
                            root.scrollPanel(event.angleDelta.y);
                            event.accepted = true;
                        }
                    }

                    HoverHandler {
                        id: maxProcessesHover
                    }

                    PanelToolTip {
                        visible: maxProcessesHover.hovered
                        text: "Maximum userland processes listed in CPU and RAM tooltips.\nThe kernel line (extended data) is extra."
                    }

                    Label {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: "Processes shown"
                        palette.windowText: ShellColor.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                    }

                    Text {
                        Layout.preferredWidth: Style.space(28)
                        Layout.alignment: Qt.AlignVCenter
                        horizontalAlignment: Text.AlignRight
                        text: root.hostWidget ? String(root.hostWidget.maxProcesses) : "10"
                        color: ShellColor.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                    }

                    PanelSlider {
                        Layout.preferredWidth: Style.space(160)
                        Layout.alignment: Qt.AlignVCenter
                        bar: root.hostBar
                        minimum: 1
                        maximum: 20
                        step: 1
                        integer: true
                        value: root.hostWidget ? root.hostWidget.maxProcesses : 10

                        onReleased: function (value) {
                            if (root.hostWidget) {
                                root.hostWidget.updateSetting("maxProcesses", Math.round(value));
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: Style.space(12)
                    Layout.preferredHeight: 1
                    color: Qt.rgba(ShellColor.popups.text.r, ShellColor.popups.text.g, ShellColor.popups.text.b, 0.12)
                }

                PanelSectionHeader {
                    Layout.fillWidth: true
                    Layout.topMargin: Style.space(10)
                    Layout.bottomMargin: Style.space(2)
                    text: "TEMPERATURE (°C)"
                    foreground: ShellColor.popups.text
                    fontFamily: Style.font.family
                }

                Item {
                    id: tempBlock

                    property string tipText: tempWarmArea.containsMouse ? tempWarmArea.tip : tempHotArea.containsMouse ? tempHotArea.tip : tempCriticalArea.containsMouse ? tempCriticalArea.tip : ""

                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(50)

                    RowLayout {
                        anchors.fill: parent
                        spacing: Style.space(8)

                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse

                            onWheel: function (event) {
                                root.scrollPanel(event.angleDelta.y);
                                event.accepted = true;
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Column {
                                width: Style.space(64)
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Style.spacing.xs

                                // The whole strip above the field is the hover
                                // target: the 4-letter label is too small to
                                // aim at, and the field itself stays tooltip-free.
                                Item {
                                    id: tempWarmLabelBox

                                    width: Style.space(64)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    height: Style.space(16)
                                    Label {
                                        anchors.centerIn: parent
                                        text: "Green"
                                        palette.windowText: Qt.darker(ShellColor.popups.text, 1.4)
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.bodySmall
                                    }

                                    MouseArea {
                                        id: tempWarmArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.ArrowCursor

                                        property string tip: "Value turns green and the icon becomes a thermometer here.\nKept below Orange."
                                    }
                                }

                                NumberField {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    label: ""
                                    from: 20
                                    to: 80
                                    stepSize: 1
                                    value: root.hostWidget ? root.hostWidget.temperatureWarm : 40
                                    fieldWidth: Style.space(64)
                                    foreground: ShellColor.popups.text
                                    fontFamily: Style.font.family

                                    onModified: function (value) {
                                        if (root.hostWidget) {
                                            root.hostWidget.updateSetting("tempWarm", Math.min(Math.round(value), root.hostWidget.temperatureHot - 1));
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Column {
                                width: Style.space(64)
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Style.spacing.xs

                                // The whole strip above the field is the hover
                                // target: the 4-letter label is too small to
                                // aim at, and the field itself stays tooltip-free.
                                Item {
                                    id: tempHotLabelBox

                                    width: Style.space(64)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    height: Style.space(16)

                                    Label {
                                        anchors.centerIn: parent
                                        text: "Orange"
                                        palette.windowText: Qt.darker(ShellColor.popups.text, 1.4)
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.bodySmall
                                    }

                                    MouseArea {
                                        id: tempHotArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.ArrowCursor

                                        property string tip: "Value turns orange and the icon becomes a heat wave here.\nKept between Green and Red."
                                    }
                                }

                                NumberField {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    label: ""
                                    from: 21
                                    to: 100
                                    stepSize: 1
                                    value: root.hostWidget ? root.hostWidget.temperatureHot : 50
                                    fieldWidth: Style.space(64)
                                    foreground: ShellColor.popups.text
                                    fontFamily: Style.font.family

                                    onModified: function (value) {
                                        if (root.hostWidget) {
                                            const low = root.hostWidget.temperatureWarm + 1;
                                            const high = root.hostWidget.temperatureCritical - 1;
                                            root.hostWidget.updateSetting("tempHot", Math.max(low, Math.min(Math.round(value), high)));
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Column {
                                width: Style.space(64)
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Style.spacing.xs

                                // The whole strip above the field is the hover
                                // target: the 4-letter label is too small to
                                // aim at, and the field itself stays tooltip-free.
                                Item {
                                    id: tempCriticalLabelBox

                                    width: Style.space(64)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    height: Style.space(16)

                                    Label {
                                        anchors.centerIn: parent
                                        text: "Red"
                                        palette.windowText: Qt.darker(ShellColor.popups.text, 1.4)
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.bodySmall
                                    }

                                    MouseArea {
                                        id: tempCriticalArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.ArrowCursor

                                        property string tip: "Value turns red and the icon becomes an alert here.\nKept above Orange."
                                    }
                                }

                                NumberField {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    label: ""
                                    from: 22
                                    to: 120
                                    stepSize: 1
                                    value: root.hostWidget ? root.hostWidget.temperatureCritical : 60
                                    fieldWidth: Style.space(64)
                                    foreground: ShellColor.popups.text
                                    fontFamily: Style.font.family

                                    onModified: function (value) {
                                        if (root.hostWidget) {
                                            root.hostWidget.updateSetting("tempCritical", Math.max(root.hostWidget.temperatureHot + 1, Math.round(value)));
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // In-panel tooltip: a plain rectangle so it stays inside
                    // the window and never gets stuck like a popup bubble.
                    Rectangle {
                        id: tempTip

                        x: Style.space(4)
                        y: -height - Style.space(2)
                        width: tempTipText.implicitWidth + Style.space(16)
                        height: tempTipText.implicitHeight + Style.space(10)
                        visible: tempBlock.tipText !== ""
                        radius: Style.cornerRadius
                        color: ShellColor.tooltip.background
                        border.width: 1
                        border.color: ShellColor.tooltip.border

                        Text {
                            id: tempTipText

                            anchors.centerIn: parent
                            text: tempBlock.tipText
                            color: ShellColor.tooltip.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: Style.space(12)
                    Layout.preferredHeight: 1
                    color: Qt.rgba(ShellColor.popups.text.r, ShellColor.popups.text.g, ShellColor.popups.text.b, 0.12)
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
                    Layout.preferredHeight: Style.space(32)
                    spacing: Style.space(8)

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse

                        onWheel: function (event) {
                            root.scrollPanel(event.angleDelta.y);
                            event.accepted = true;
                        }
                    }

                    HoverHandler {
                        id: refreshHover
                    }

                    PanelToolTip {
                        visible: refreshHover.hovered
                        text: "Fast sampling: CPU, RAM, swap, load and network.\nDisk, temperature, GPU and zram always stay at 10 s\nto limit CPU overhead."
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
                        bar: root.hostBar
                        minimum: 1
                        maximum: 5
                        step: 1
                        integer: true
                        value: root.hostWidget ? root.hostWidget.refreshInterval : 1

                        onReleased: function (value) {
                            if (root.hostWidget) {
                                root.hostWidget.updateSetting("refreshInterval", Math.round(value));
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(32)
                    spacing: Style.space(8)

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse

                        onWheel: function (event) {
                            root.scrollPanel(event.angleDelta.y);
                            event.accepted = true;
                        }
                    }

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
                        bar: root.hostBar
                        minimum: 2
                        maximum: 10
                        step: 1
                        integer: true
                        value: root.hostWidget ? root.hostWidget.processInterval : 5

                        onReleased: function (value) {
                            if (root.hostWidget) {
                                root.hostWidget.updateSetting("processInterval", Math.round(value));
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: scrollIndicator

            readonly property real maxOffset: Math.max(1, settingsFlick.contentHeight - settingsFlick.height)
            readonly property real handleHeight: Math.max(Style.space(24), settingsFlick.height * settingsFlick.height / Math.max(1, settingsFlick.contentHeight))

            visible: settingsFlick.contentHeight > settingsFlick.height
            width: Style.space(4)
            height: handleHeight
            radius: width / 2
            color: Qt.rgba(ShellColor.popups.text.r, ShellColor.popups.text.g, ShellColor.popups.text.b, 0.45)
            x: settingsFlick.x + settingsFlick.width - width
            y: settingsFlick.y + (settingsFlick.height - height) * (settingsFlick.contentY / maxOffset)

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                property real dragStartY: 0
                property real dragStartContentY: 0

                onPressed: function (mouse) {
                    dragStartY = mouse.y;
                    dragStartContentY = settingsFlick.contentY;
                }

                onPositionChanged: function (mouse) {
                    if (!pressed) {
                        return;
                    }

                    const range = Math.max(1, settingsFlick.height - scrollIndicator.height);
                    const offset = (mouse.y - dragStartY) * scrollIndicator.maxOffset / range;
                    settingsFlick.contentY = Math.max(0, Math.min(scrollIndicator.maxOffset, dragStartContentY + offset));
                }
            }
        }

        PanelKeyCatcher {
            anchors.fill: parent

            onCloseRequested: {
                if (root.hostWidget) {
                    root.hostWidget.close();
                }
            }
        }
    }
}
