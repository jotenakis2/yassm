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
            lines.push(Yassm.I18n.tf("settings.deps_required_head", [root.missingRequired.map(function (dep) {
                    return dep.name;
                }).join(", ")]));
        }

        if (root.missingOptional.length > 0) {
            lines.push(Yassm.I18n.tf("settings.deps_optional_head", [root.missingOptional.map(function (dep) {
                    return dep.name;
                }).join(", ")]));
        }

        lines.push("");

        for (let i = 0; i < root.missingDeps.length; i++) {
            const dep = root.missingDeps[i];
            lines.push(dep.name + " — " + Yassm.I18n.t("dep." + dep.name, dep.purpose));
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

    function clampScroll() {
        const max = Math.max(0, settingsFlick.contentHeight - settingsFlick.height);

        if (settingsFlick.contentY > max) {
            settingsFlick.contentY = max;
        }
    }

    readonly property var moduleSettings: [
        {
            key: "showUptime",
            label: Yassm.I18n.t("module.uptime"),
            defaultValue: true
        },
        {
            key: "showCpu",
            label: Yassm.I18n.t("module.cpu")
        },
        {
            key: "showLoad",
            label: Yassm.I18n.t("module.load")
        },
        {
            key: "showGpu",
            label: Yassm.I18n.t("module.gpu")
        },
        {
            key: "showMemory",
            label: Yassm.I18n.t("module.memory")
        },
        {
            key: "showSwap",
            label: Yassm.I18n.t("module.swap")
        },
        {
            key: "showDisk",
            label: Yassm.I18n.t("module.disk")
        },
        {
            key: "showNet",
            label: Yassm.I18n.t("module.net")
        },
        {
            key: "showTemp",
            label: Yassm.I18n.t("module.temp")
        },
        {
            key: "showBattery",
            label: Yassm.I18n.t("module.battery")
        },
        {
            key: "showAlerts",
            label: Yassm.I18n.t("module.alerts"),
            defaultValue: true,
            tooltip: Yassm.I18n.t("settings.alerts_tip")
        }
    ]

    property int dragFrom: -1
    property int dragTo: -1

    // Section disclosure state, kept for the session only.
    property bool modulesOpen: true
    property bool layoutOpen: false
    property bool thresholdsOpen: false
    property bool timersOpen: false

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
        // The top panel sits a few pixels lower than the bare margin: flush
        // against the bar it looked cramped.
        y: root.barPosition === "bottom" ? Math.max(root.panelMargin, root.height - root.panelHeight - root.panelMargin) : (root.barPosition === "left" || root.barPosition === "right") ? Math.max(root.panelMargin, Math.round((root.height - root.panelHeight) / 2)) : root.panelMargin + Style.space(4)

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

            // Keep the MODULES hint from firing under the icon and give the
            // gear its own tooltip, right below it.
            MouseArea {
                id: gearArea

                anchors.fill: parent
                anchors.margins: -Style.space(4)
                hoverEnabled: true
            }

            PanelToolTip {
                parent: settingsPanel
                visible: gearArea.containsMouse
                text: Yassm.I18n.t("settings.gear")
                x: settingsPanel.width - width - root.panelPadding
                y: gearIcon.y + gearIcon.height + Style.space(4)
            }
        }

        Flickable {
            id: settingsFlick

            anchors.fill: parent
            anchors.margins: root.panelPadding
            clip: true
            contentWidth: width
            contentHeight: settingsColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            onContentHeightChanged: root.clampScroll()
            onHeightChanged: root.clampScroll()

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
                            text: depsWarning.hasRequired ? Yassm.I18n.tf("settings.deps_required", [root.missingRequired.map(function (dep) {
                                    return dep.name;
                                }).join(", ")]) : Yassm.I18n.tf("settings.deps_optional", [root.missingOptional.map(function (dep) {
                                    return dep.name;
                                }).join(", ")])
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

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Style.space(2)
                    Layout.bottomMargin: Style.space(2)
                    spacing: Style.space(4)

                    Text {
                        id: modulesChevron

                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: Style.space(10)
                        text: String.fromCodePoint(root.modulesOpen ? 0xF0140 : 0xF0142)
                        color: modulesChevronArea.containsMouse ? ShellColor.popups.text : Qt.darker(ShellColor.popups.text, 1.4)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body

                        MouseArea {
                            id: modulesChevronArea

                            anchors.fill: parent
                            anchors.margins: -Style.space(4)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: root.modulesOpen = !root.modulesOpen
                        }
                    }

                    PanelSectionHeader {
                        text: Yassm.I18n.t("settings.modules")
                        foreground: ShellColor.popups.text
                        fontFamily: Style.font.family

                        HoverHandler {
                            id: modulesHeaderHover
                        }

                        PanelToolTip {
                            visible: modulesHeaderHover.hovered
                            text: Yassm.I18n.t("settings.drag_hint")
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                ColumnLayout {
                    id: moduleList

                    Layout.fillWidth: true
                    visible: root.modulesOpen
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

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Style.space(10)
                    Layout.bottomMargin: Style.space(2)
                    spacing: Style.space(4)

                    Text {
                        id: layoutChevron

                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: Style.space(10)
                        text: String.fromCodePoint(root.layoutOpen ? 0xF0140 : 0xF0142)
                        color: layoutChevronArea.containsMouse ? ShellColor.popups.text : Qt.darker(ShellColor.popups.text, 1.4)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body

                        MouseArea {
                            id: layoutChevronArea

                            anchors.fill: parent
                            anchors.margins: -Style.space(4)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: root.layoutOpen = !root.layoutOpen
                        }
                    }

                    PanelSectionHeader {
                        text: Yassm.I18n.t("settings.layout")
                        foreground: ShellColor.popups.text
                        fontFamily: Style.font.family
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(4)
                    visible: root.layoutOpen

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
                            label: Yassm.I18n.t("settings.boxes")
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
                            label: Yassm.I18n.t("settings.colors")
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
                            label: Yassm.I18n.t("settings.extended")
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
                        visible: root.hostWidget ? root.hostWidget.setting("showBoxes", true) : false

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
                            id: boxBorderHover
                        }

                        PanelToolTip {
                            visible: boxBorderHover.hovered
                            text: Yassm.I18n.t("settings.box_border_tip")
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: Yassm.I18n.t("settings.box_border")
                            palette.windowText: ShellColor.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                        }

                        Text {
                            Layout.preferredWidth: Style.space(28)
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            text: String(Math.round(borderSlider.liveValue)) + " px"
                            color: ShellColor.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                        }

                        PanelSlider {
                            id: borderSlider

                            Layout.preferredWidth: Style.space(160)
                            Layout.alignment: Qt.AlignVCenter
                            bar: root.hostBar
                            minimum: 1
                            maximum: 4
                            step: 1
                            integer: true
                            value: root.hostWidget ? root.hostWidget.boxBorder : Style.normalBorderWidth

                            onReleased: function (value) {
                                if (root.hostWidget) {
                                    root.hostWidget.updateSetting("boxBorder", Math.round(value));
                                }
                            }
                        }
                    }

                    RowLayout {
                        visible: root.hostWidget ? root.hostWidget.setting("showBoxes", true) : false

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
                            id: boxRadiusHover
                        }

                        PanelToolTip {
                            visible: boxRadiusHover.hovered
                            text: Yassm.I18n.t("settings.box_radius_tip")
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: Yassm.I18n.t("settings.box_radius")
                            palette.windowText: ShellColor.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                        }

                        Text {
                            Layout.preferredWidth: Style.space(28)
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            text: String(Math.round(radiusSlider.liveValue)) + " px"
                            color: ShellColor.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                        }

                        PanelSlider {
                            id: radiusSlider

                            Layout.preferredWidth: Style.space(160)
                            Layout.alignment: Qt.AlignVCenter
                            bar: root.hostBar
                            minimum: 0
                            maximum: 12
                            step: 1
                            integer: true
                            value: root.hostWidget ? root.hostWidget.boxRadius : 4

                            onReleased: function (value) {
                                if (root.hostWidget) {
                                    root.hostWidget.updateSetting("boxRadius", Math.round(value));
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
                            text: Yassm.I18n.t("settings.modules_gap_tip")
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: Yassm.I18n.t("settings.modules_gap")
                            palette.windowText: ShellColor.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                        }

                        Text {
                            Layout.preferredWidth: Style.space(14)
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            text: String(Math.round(spacingSlider.liveValue))
                            color: ShellColor.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                        }

                        PanelSlider {
                            id: spacingSlider

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
                            text: Yassm.I18n.t("settings.icon_gap_tip")
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: Yassm.I18n.t("settings.icon_gap")
                            palette.windowText: ShellColor.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                        }

                        Text {
                            Layout.preferredWidth: Style.space(14)
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            text: String(Math.round(iconGapSlider.liveValue))
                            color: ShellColor.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                        }

                        PanelSlider {
                            id: iconGapSlider

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
                            text: Yassm.I18n.t("settings.processes_shown_tip")
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: Yassm.I18n.t("settings.processes_shown")
                            palette.windowText: ShellColor.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                        }

                        Text {
                            Layout.preferredWidth: Style.space(28)
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            text: String(Math.round(maxProcessesSlider.liveValue))
                            color: ShellColor.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                        }

                        PanelSlider {
                            id: maxProcessesSlider

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
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: Style.space(12)
                    Layout.preferredHeight: 1
                    color: Qt.rgba(ShellColor.popups.text.r, ShellColor.popups.text.g, ShellColor.popups.text.b, 0.12)
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Style.space(10)
                    Layout.bottomMargin: Style.space(2)
                    spacing: Style.space(4)

                    Text {
                        id: temperatureChevron

                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: Style.space(10)
                        text: String.fromCodePoint(root.thresholdsOpen ? 0xF0140 : 0xF0142)
                        color: temperatureChevronArea.containsMouse ? ShellColor.popups.text : Qt.darker(ShellColor.popups.text, 1.4)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body

                        MouseArea {
                            id: temperatureChevronArea

                            anchors.fill: parent
                            anchors.margins: -Style.space(4)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: root.thresholdsOpen = !root.thresholdsOpen
                        }
                    }

                    PanelSectionHeader {
                        text: Yassm.I18n.t("settings.thresholds")
                        foreground: ShellColor.popups.text
                        fontFamily: Style.font.family
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.thresholdsOpen
                    spacing: Style.space(6)

                    ThresholdRow {
                        hostWidget: root.hostWidget
                        title: Yassm.I18n.t("settings.thresholds_percent")
                        prefix: "percent"
                        defaultGreen: 10
                        defaultOrange: 33
                        defaultRed: 66
                        fromGreen: 0
                        toGreen: 100
                        fromOrange: 0
                        toOrange: 100
                        fromRed: 0
                        toRed: 100
                    }

                    ThresholdRow {
                        hostWidget: root.hostWidget
                        title: Yassm.I18n.t("settings.thresholds_disk")
                        prefix: "disk"
                        defaultGreen: 20
                        defaultOrange: 33
                        defaultRed: 90
                        fromGreen: 0
                        toGreen: 100
                        fromOrange: 0
                        toOrange: 100
                        fromRed: 0
                        toRed: 100
                    }

                    ThresholdRow {
                        hostWidget: root.hostWidget
                        title: Yassm.I18n.t("settings.thresholds_load")
                        prefix: "load"
                        defaultGreen: 10
                        defaultOrange: 50
                        defaultRed: 90
                        fromGreen: 0
                        toGreen: 200
                        fromOrange: 0
                        toOrange: 200
                        fromRed: 0
                        toRed: 200
                    }

                    ThresholdRow {
                        hostWidget: root.hostWidget
                        title: Yassm.I18n.t("settings.thresholds_network")
                        prefix: "net"
                        stepSize: 10
                        defaultGreen: 10
                        defaultOrange: 500
                        defaultRed: 1000
                        fromGreen: 0
                        toGreen: 10000
                        fromOrange: 0
                        toOrange: 10000
                        fromRed: 0
                        toRed: 10000
                    }

                    ThresholdRow {
                        hostWidget: root.hostWidget
                        title: Yassm.I18n.t("settings.thresholds_battery")
                        tooltip: Yassm.I18n.t("settings.battery_inverted_tip")
                        prefix: "battery"
                        inverted: true
                        defaultGreen: 50
                        defaultOrange: 20
                        defaultRed: 10
                        fromGreen: 0
                        toGreen: 100
                        fromOrange: 0
                        toOrange: 100
                        fromRed: 0
                        toRed: 100
                    }

                    ThresholdRow {
                        hostWidget: root.hostWidget
                        title: Yassm.I18n.t("settings.thresholds_temperature")
                        keyGreen: "tempWarm"
                        keyOrange: "tempHot"
                        keyRed: "tempCritical"
                        propertyGreen: "temperatureWarm"
                        propertyOrange: "temperatureHot"
                        propertyRed: "temperatureCritical"
                        defaultGreen: 40
                        defaultOrange: 50
                        defaultRed: 60
                        fromGreen: 0
                        toGreen: 120
                        fromOrange: 0
                        toOrange: 130
                        fromRed: 0
                        toRed: 140
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: Style.space(12)
                    Layout.preferredHeight: 1
                    color: Qt.rgba(ShellColor.popups.text.r, ShellColor.popups.text.g, ShellColor.popups.text.b, 0.12)
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Style.space(10)
                    Layout.bottomMargin: Style.space(2)
                    spacing: Style.space(4)

                    Text {
                        id: timersChevron

                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: Style.space(10)
                        text: String.fromCodePoint(root.timersOpen ? 0xF0140 : 0xF0142)
                        color: timersChevronArea.containsMouse ? ShellColor.popups.text : Qt.darker(ShellColor.popups.text, 1.4)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body

                        MouseArea {
                            id: timersChevronArea

                            anchors.fill: parent
                            anchors.margins: -Style.space(4)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: root.timersOpen = !root.timersOpen
                        }
                    }

                    PanelSectionHeader {
                        text: Yassm.I18n.t("settings.timers")
                        foreground: ShellColor.popups.text
                        fontFamily: Style.font.family
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(4)
                    visible: root.timersOpen

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
                            text: Yassm.I18n.t("settings.refresh_tip")
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: Yassm.I18n.t("settings.refresh")
                            palette.windowText: ShellColor.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                        }

                        Text {
                            Layout.preferredWidth: Style.space(28)
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            text: String(Math.round(fastSlider.liveValue)) + " s"
                            color: ShellColor.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                        }

                        PanelSlider {
                            id: fastSlider

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
                            id: slowHover
                        }

                        PanelToolTip {
                            visible: slowHover.hovered
                            text: Yassm.I18n.t("settings.slow_tip")
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: Yassm.I18n.t("settings.slow")
                            palette.windowText: ShellColor.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                        }

                        Text {
                            Layout.preferredWidth: Style.space(28)
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            text: String(Math.round(slowSlider.liveValue)) + " s"
                            color: ShellColor.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                        }

                        PanelSlider {
                            id: slowSlider

                            Layout.preferredWidth: Style.space(160)
                            Layout.alignment: Qt.AlignVCenter
                            bar: root.hostBar
                            minimum: 5
                            maximum: 30
                            step: 1
                            integer: true
                            value: root.hostWidget ? root.hostWidget.slowInterval : 10

                            onReleased: function (value) {
                                if (root.hostWidget) {
                                    root.hostWidget.updateSetting("slowInterval", Math.round(value));
                                }
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
